import AppKit
import Darwin
import Foundation
import SwiftUI
import XCTest
@testable import DuoBar

private final class ControlledAccessoryReader: @unchecked Sendable {
    let firstStarted = XCTestExpectation(description: "First accessory read started")
    let secondStarted = XCTestExpectation(description: "Second accessory read started")
    let firstRelease = DispatchSemaphore(value: 0)
    let secondRelease = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var calls = 0

    var readCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    func read() -> [AccessoryBattery]? {
        lock.lock()
        calls += 1
        let call = calls
        lock.unlock()
        if call == 1 {
            firstStarted.fulfill()
            _ = firstRelease.wait(timeout: .now() + 5)
        } else {
            secondStarted.fulfill()
            _ = secondRelease.wait(timeout: .now() + 5)
        }
        return [AccessoryBattery(id: "fixture", name: "Fixture", levels: ["main": call == 1 ? 10 : 90])]
    }
}

final class AccessoryPollingLifecycleTests: XCTestCase {
    @MainActor
    func testClosingMenuClearsPendingRefreshAndRejectsLateResult() async {
        let reader = ControlledAccessoryReader()
        let service = AccessoryBatteryService(reportReader: { reader.read() })
        defer { reader.firstRelease.signal(); service.stop() }
        service.start()
        await fulfillment(of: [reader.firstStarted], timeout: 2)
        service.stop()
        XCTAssertFalse(service.isRefreshing, "A hidden menu must not remain in the reading state")
        reader.firstRelease.signal()
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(service.accessories.isEmpty, "A closed menu must ignore a late report")
    }

    @MainActor
    func testReopeningAfterCancellationStartsFreshReadWithoutStaleOverwrite() async {
        let reader = ControlledAccessoryReader()
        let service = AccessoryBatteryService(reportReader: { reader.read() })
        defer { reader.firstRelease.signal(); reader.secondRelease.signal(); service.stop() }
        service.start()
        await fulfillment(of: [reader.firstStarted], timeout: 2)
        service.stop()
        service.start()
        await fulfillment(of: [reader.secondStarted], timeout: 2)
        reader.secondRelease.signal()
        for _ in 0..<50 where service.isRefreshing {
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(service.accessories.first?.percentage, 90)
        reader.firstRelease.signal()
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(service.accessories.first?.percentage, 90, "The cancelled read must not overwrite the reopened menu")
    }

    @MainActor
    func testSuccessfulReadIsCachedAcrossQuickReopen() async {
        let reader = ControlledAccessoryReader()
        let service = AccessoryBatteryService(reportReader: { reader.read() })
        defer { reader.firstRelease.signal(); reader.secondRelease.signal(); service.stop() }
        service.start()
        await fulfillment(of: [reader.firstStarted], timeout: 2)
        reader.firstRelease.signal()
        for _ in 0..<50 where service.isRefreshing { try? await Task.sleep(for: .milliseconds(10)) }
        XCTAssertEqual(service.accessories.first?.percentage, 10)
        service.stop()
        service.start()
        XCTAssertFalse(service.isRefreshing)
        XCTAssertEqual(service.accessories.first?.percentage, 10)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(reader.readCount, 1, "A quick reopen should reuse the completed report")
    }

    @MainActor
    func testConstructingAndRenderingAccessoryViewDoesNotStartHardwarePolling() {
        let service = AccessoryBatteryService(reportReader: { [] })
        let host = NSHostingView(rootView: AccessoryBatterySection(service: service))
        host.frame = NSRect(x: 0, y: 0, width: 280, height: 100)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        XCTAssertFalse(service.isPolling)
        XCTAssertFalse(service.isRefreshing)
    }

    @MainActor
    func testPopoverEventsAndVisibilityPreferenceOwnAccessoryPolling() async throws {
        let suite = "AccessoryPollingLifecycleTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: PreferenceKeys.showAccessories)
        defaults.set(false, forKey: PreferenceKeys.showVPN)
        let service = AccessoryBatteryService(reportReader: { [] })
        let store = SystemStatusStore(startServices: false, accessoryBatteryService: service)
        let controller = MenuBarController(statusStore: store, defaults: defaults)
        defer { controller.invalidate() }
        XCTAssertFalse(service.isPolling, "A retained hidden popover must not start polling")
        controller.popoverDidShow(Notification(name: NSPopover.didShowNotification))
        XCTAssertTrue(service.isPolling)
        defaults.set(false, forKey: PreferenceKeys.showAccessories)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        for _ in 0..<50 where service.isPolling { try? await Task.sleep(for: .milliseconds(10)) }
        XCTAssertFalse(service.isPolling)
        defaults.set(true, forKey: PreferenceKeys.showAccessories)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        for _ in 0..<50 where !service.isPolling { try? await Task.sleep(for: .milliseconds(10)) }
        XCTAssertTrue(service.isPolling)
        controller.popoverWillClose(Notification(name: NSPopover.willCloseNotification))
        XCTAssertFalse(service.isPolling)
        XCTAssertFalse(service.isRefreshing)
        controller.popoverDidClose(Notification(name: NSPopover.didCloseNotification))
        controller.popoverDidShow(Notification(name: NSPopover.didShowNotification))
        XCTAssertTrue(service.isPolling)
        controller.invalidate()
        XCTAssertFalse(service.isPolling)
    }

    func testReportCancellationTerminatesTheOwnedHelper() async throws {
        let pidFile = FileManager.default.temporaryDirectory.appendingPathComponent("duobar-helper-test-\(UUID().uuidString).pid")
        defer { try? FileManager.default.removeItem(at: pidFile) }
        let script = "import os,time; open(\"\(pidFile.path)\", 'w').write(str(os.getpid())); time.sleep(60)"
        let worker = Task.detached {
            AccessoryBatteryService.readReport(executable: URL(fileURLWithPath: "/usr/bin/python3"), arguments: ["-c", script])
        }
        defer { worker.cancel() }
        for _ in 0..<100 where !FileManager.default.fileExists(atPath: pidFile.path) {
            try await Task.sleep(for: .milliseconds(20))
        }
        let pid = try XCTUnwrap(Int32(try String(contentsOf: pidFile)))
        let started = ProcessInfo.processInfo.systemUptime
        worker.cancel()
        let result = await worker.value
        XCTAssertNil(result)
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started, 1)
        XCTAssertEqual(kill(pid, 0), -1, "Cancelled helper must not be left running")
    }

    func testReportTimeoutKillsHelperThatIgnoresTermination() async throws {
        let pidFile = FileManager.default.temporaryDirectory.appendingPathComponent("duobar-timeout-test-\(UUID().uuidString).pid")
        defer { try? FileManager.default.removeItem(at: pidFile) }
        let script = "import os,signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); open(\"\(pidFile.path)\", 'w').write(str(os.getpid())); time.sleep(60)"
        let started = ProcessInfo.processInfo.systemUptime
        let result = await Task.detached {
            AccessoryBatteryService.readReport(executable: URL(fileURLWithPath: "/usr/bin/python3"),
                arguments: ["-c", script], timeout: 1)
        }.value
        let pid = try XCTUnwrap(Int32(try String(contentsOf: pidFile)))
        XCTAssertNil(result)
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - started, 2.5)
        XCTAssertEqual(kill(pid, 0), -1, "A timed-out helper must not survive its reader")
    }
}
