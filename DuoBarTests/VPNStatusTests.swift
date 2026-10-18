import AppKit
import Combine
import SwiftUI
import XCTest
@testable import DuoBar

@MainActor
final class TestVPNChangeMonitor: VPNChangeMonitoring {
    var startResult = true
    private(set) var starts = 0
    private(set) var stops = 0
    var onChange: (@Sendable () -> Void)?

    func start(onChange: @escaping @Sendable () -> Void) -> Bool {
        starts += 1
        self.onChange = startResult ? onChange : nil
        return startResult
    }

    func stop() { stops += 1; onChange = nil }
}

private actor PendingVPNReads {
    private(set) var count = 0
    private var waiting = [Int: CheckedContinuation<VPNStatus, Never>]()

    func read() async -> VPNStatus {
        count += 1
        let id = count
        return await withCheckedContinuation { waiting[id] = $0 }
    }

    func complete(_ id: Int, with value: VPNStatus) {
        waiting.removeValue(forKey: id)?.resume(returning: value)
    }

    func finish() {
        let pending = Array(waiting.values)
        waiting.removeAll()
        for continuation in pending { continuation.resume(returning: .unavailable) }
    }
}

final class VPNStatusTests: XCTestCase {
    private let connected = VPNStatus(connections: [VPNConnection(id: "vpn", name: "Shadowrocket",
        state: .connected, interfaceName: "utun2")])
    private let disconnected = VPNStatus(connections: [VPNConnection(id: "vpn", name: "Shadowrocket",
        state: .disconnected, interfaceName: nil)])

    func testVPNClassificationDoesNotTreatUtunOrModemInterfacesAsVPN() {
        XCTAssertTrue(SystemConfigurationVPNReader.isVPN(interfaceTypes: ["VPN", "com.example.Client", "IPv4"]))
        XCTAssertTrue(SystemConfigurationVPNReader.isVPN(interfaceTypes: ["IPSec", "IPv4"]))
        XCTAssertTrue(SystemConfigurationVPNReader.isVPN(interfaceTypes: ["PPP", "L2TP", "IPv4"]))
        XCTAssertFalse(SystemConfigurationVPNReader.isVPN(interfaceTypes: ["utun", "IPv4"]))
        XCTAssertFalse(SystemConfigurationVPNReader.isVPN(interfaceTypes: ["PPP", "Modem"]))
        XCTAssertFalse(SystemConfigurationVPNReader.isVPN(interfaceTypes: ["Ethernet"]))
    }

    func testUnavailableAndNoProfilesAreDistinctFromDisconnected() {
        XCTAssertEqual(VPNStatus.unavailable.state, .unavailable)
        XCTAssertEqual(VPNStatus(connections: []).state, .notConfigured)
        XCTAssertEqual(disconnected.state, .disconnected)
    }

    func testAggregatePrioritizesActiveProfilesAndDoesNotClaimDisconnectedOnReadFailure() {
        let unknown = VPNConnection(id: "unknown", name: "Work", state: .unavailable, interfaceName: nil)
        let both = VPNStatus(connections: [unknown] + connected.connections + disconnected.connections)
        XCTAssertEqual(both.state, .connected)
        XCTAssertEqual(both.summary, "Shadowrocket")
        XCTAssertEqual(VPNStatus(connections: [unknown] + disconnected.connections).state, .unavailable)
        let connecting = VPNConnection(id: "next", name: "Next", state: .connecting, interfaceName: nil)
        XCTAssertEqual(VPNStatus(connections: [connecting] + disconnected.connections).state, .connecting)
    }

    @MainActor
    func testChangesCoalesceWhileAReadIsRunning() async throws {
        let reads = PendingVPNReads()
        let monitor = TestVPNChangeMonitor()
        let service = VPNStatusService(reader: { await reads.read() }, monitor: monitor)
        defer { service.stop(); Task { await reads.finish() } }
        service.start()
        service.start()
        try await waitUntil { await reads.count == 1 }
        for _ in 0..<20 { service.refresh() }
        XCTAssertEqual(monitor.starts, 1)
        await reads.complete(1, with: connected)
        try await waitUntil { await reads.count == 2 }
        await reads.complete(2, with: disconnected)
        try await waitUntil { !service.isRefreshing }
        XCTAssertEqual(service.status, disconnected)
        let count = await reads.count
        XCTAssertEqual(count, 2)
        let callback = try XCTUnwrap(monitor.onChange)
        callback()
        try await waitUntil { await reads.count == 3 }
        await reads.complete(3, with: connected)
        try await waitUntil { service.status == self.connected && !service.isRefreshing }
    }

    @MainActor
    func testClosingAndReopeningRejectsLateReadsAndOldCallbacks() async throws {
        let reads = PendingVPNReads()
        let monitor = TestVPNChangeMonitor()
        let service = VPNStatusService(reader: { await reads.read() }, monitor: monitor)
        defer { service.stop(); Task { await reads.finish() } }
        service.start()
        try await waitUntil { await reads.count == 1 }
        let oldCallback = try XCTUnwrap(monitor.onChange)
        service.stop()
        service.start()
        try await waitUntil { await reads.count == 2 }
        await reads.complete(2, with: disconnected)
        try await waitUntil { !service.isRefreshing }
        await reads.complete(1, with: connected)
        oldCallback()
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertEqual(service.status, disconnected)
        let count = await reads.count
        XCTAssertEqual(count, 2)
    }

    @MainActor
    func testReopeningKeepsKnownStateUntilTheNewReadCompletes() async throws {
        let reads = PendingVPNReads()
        let monitor = TestVPNChangeMonitor()
        let service = VPNStatusService(reader: { await reads.read() }, monitor: monitor)
        defer { service.stop(); Task { await reads.finish() } }
        service.start()
        try await waitUntil { await reads.count == 1 }
        await reads.complete(1, with: connected)
        try await waitUntil { !service.isRefreshing }
        service.stop()
        service.start()
        try await waitUntil { await reads.count == 2 }
        XCTAssertEqual(service.status, connected, "Reopening must not flash an unavailable icon while refreshing")
        await reads.complete(2, with: disconnected)
        try await waitUntil { !service.isRefreshing }
        XCTAssertEqual(service.status, disconnected, "A newly observed disconnection must still replace cached state")
        service.stop()
        monitor.startResult = false
        service.start()
        XCTAssertEqual(service.status, .unavailable, "An actual observation failure must not retain a connected claim")
    }

    @MainActor
    func testImmediateCloseDoesNotStartAQueuedRead() async throws {
        let reads = PendingVPNReads()
        let service = VPNStatusService(reader: { await reads.read() }, monitor: TestVPNChangeMonitor())
        defer { service.stop(); Task { await reads.finish() } }
        service.start()
        service.stop()
        try await Task.sleep(for: .milliseconds(30))
        let count = await reads.count
        XCTAssertEqual(count, 0, "A read cancelled before it starts must not query system configuration after closing")
    }

    @MainActor
    func testStoppingAnInactiveServiceDoesNotInvalidateTheView() {
        let service = VPNStatusService(reader: { .unavailable }, monitor: TestVPNChangeMonitor())
        var updates = 0
        let subscription = service.objectWillChange.sink { updates += 1 }
        service.stop()
        service.stop()
        XCTAssertEqual(updates, 0, "An already inactive service has no visible state to update")
        subscription.cancel()
    }

    @MainActor
    func testAnUnchangedSnapshotDoesNotPublishStatusAgain() async throws {
        let value = connected
        let service = VPNStatusService(reader: { value }, monitor: TestVPNChangeMonitor())
        defer { service.stop() }
        service.start()
        try await waitUntil { !service.isRefreshing }
        var updates = 0
        let subscription = service.$status.dropFirst().sink { _ in updates += 1 }
        service.refresh()
        try await waitUntil { !service.isRefreshing }
        XCTAssertEqual(updates, 0, "Unchanged OS readings must not invalidate the status content")
        subscription.cancel()
    }

    @MainActor
    func testMonitoringFailureStaysUnavailableAndCanBeRetried() async throws {
        let monitor = TestVPNChangeMonitor()
        monitor.startResult = false
        let value = connected
        let service = VPNStatusService(reader: { value }, monitor: monitor)
        defer { service.stop() }
        service.start()
        XCTAssertFalse(service.isMonitoring)
        XCTAssertFalse(service.isRefreshing)
        XCTAssertEqual(service.status.state, .unavailable)
        monitor.startResult = true
        service.start()
        try await waitUntil { !service.isRefreshing }
        XCTAssertEqual(service.status, connected)
        XCTAssertTrue(service.isMonitoring)
    }

    @MainActor
    func testMonitoringFollowsRealPopoverVisibilityAndVPNPreference() async throws {
        let suite = "VPNVisibilityTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: PreferenceKeys.showAccessories)
        let monitor = TestVPNChangeMonitor()
        let value = connected
        let service = VPNStatusService(reader: { value }, monitor: monitor)
        let store = SystemStatusStore(startServices: false, vpnStatusService: service)
        let controller = MenuBarController(statusStore: store, defaults: defaults)
        defer { controller.invalidate() }
        XCTAssertFalse(service.isMonitoring)
        XCTAssertEqual(monitor.starts, 0)
        controller.popoverDidShow(Notification(name: NSPopover.didShowNotification))
        try await waitUntil { service.status == value }
        XCTAssertTrue(service.isMonitoring)
        defaults.set(false, forKey: PreferenceKeys.showVPN)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        try await waitUntil { !service.isMonitoring }
        defaults.set(true, forKey: PreferenceKeys.showVPN)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        try await waitUntil { service.isMonitoring && !service.isRefreshing }
        controller.popoverWillClose(Notification(name: NSPopover.willCloseNotification))
        XCTAssertFalse(service.isMonitoring)
        controller.popoverDidShow(Notification(name: NSPopover.didShowNotification))
        XCTAssertTrue(service.isMonitoring)
        controller.invalidate()
        XCTAssertFalse(service.isMonitoring)
        XCTAssertNil(monitor.onChange)
    }

    @MainActor
    func testRenderingRetainedVPNContentDoesNotStartMonitoring() {
        let monitor = TestVPNChangeMonitor()
        let service = VPNStatusService(reader: { .unavailable }, monitor: monitor)
        let host = NSHostingView(rootView: VPNSection(service: service, onOpenSettings: {}).frame(width: 280))
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(host.fittingSize.height, 40)
        XCTAssertFalse(service.isMonitoring)
        XCTAssertEqual(monitor.starts, 0)
    }

    @MainActor
    private func waitUntil(file: StaticString = #filePath, line: UInt = #line,
                           _ condition: @MainActor () async -> Bool) async throws {
        for _ in 0..<100 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("VPN state did not settle", file: file, line: line)
        throw CocoaError(.coderValueNotFound)
    }
}
