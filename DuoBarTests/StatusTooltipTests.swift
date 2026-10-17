import AppKit
import XCTest
@testable import DuoBar

final class StatusTooltipTests: XCTestCase {
    func testDischargingUsesOnlyTimeToEmpty() {
        let battery = status(charging: false, pluggedIn: false)
        let tooltip = StatusTooltip.text(battery: battery, hasInternalBattery: true)
        XCTAssertTrue(tooltip.contains(localized("Battery: %d%%", 68)))
        XCTAssertTrue(tooltip.contains(localized("Until empty: ≈%@", localized("%d h %d min", 4, 20))))
        XCTAssertFalse(tooltip.contains(localized("%d min", 45)))
    }

    func testChargingUsesOnlyTimeToFullCharge() {
        let tooltip = StatusTooltip.text(battery: status(charging: true, pluggedIn: true), hasInternalBattery: true)
        XCTAssertTrue(tooltip.contains(localized("Until full charge: ≈%@", localized("%d min", 45))))
        XCTAssertFalse(tooltip.contains(localized("%d h %d min", 4, 20)))
    }

    func testFullAndPausedChargingNeverShowStaleEstimates() {
        var battery = status(charging: false, pluggedIn: true)
        let paused = StatusTooltip.text(battery: battery, hasInternalBattery: true)
        XCTAssertTrue(paused.contains(localized("Battery connected, not charging")))
        battery.isFullyCharged = true
        battery.percentage = 100
        let full = StatusTooltip.text(battery: battery, hasInternalBattery: true)
        XCTAssertTrue(full.contains(localized("Fully charged")))
        for tooltip in [paused, full] {
            XCTAssertFalse(tooltip.contains(localized("%d min", 45)))
            XCTAssertFalse(tooltip.contains(localized("%d h %d min", 4, 20)))
        }
    }

    func testMissingEstimateAndBatteryAreReportedWithoutInventedNumbers() {
        var battery = status(charging: false, pluggedIn: false)
        battery.timeToEmptyMinutes = nil
        XCTAssertTrue(StatusTooltip.text(battery: battery, hasInternalBattery: true)
            .contains(localized("Battery time estimate unavailable")))
        XCTAssertEqual(StatusTooltip.text(battery: .unavailable, hasInternalBattery: true),
            AppIdentity.name + "\n" + localized("Battery data unavailable"))
        XCTAssertEqual(StatusTooltip.text(battery: .unavailable, hasInternalBattery: false), AppIdentity.name)
    }

    func testRemainingTimePreferenceHidesTheEstimate() {
        let tooltip = StatusTooltip.text(battery: status(charging: true, pluggedIn: true),
            hasInternalBattery: true, showsRemainingTime: false)
        XCTAssertEqual(tooltip.components(separatedBy: "\n").count, 2)
        XCTAssertFalse(tooltip.contains(localized("%d min", 45)))
    }

    @MainActor
    func testControllerUpdatesFromExistingStoreAndStopsObservingAfterInvalidation() async throws {
        let suite = "StatusTooltipTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SystemStatusStore(startServices: false, deviceContext: DeviceContext(hasInternalBattery: true))
        let controller = MenuBarController(statusStore: store, defaults: defaults)
        defer { controller.invalidate() }

        let battery = status(charging: false, pluggedIn: false)
        store.applyDebugBatteryStatus(battery)
        XCTAssertEqual(controller.tooltipText, StatusTooltip.text(battery: battery, hasInternalBattery: true))
        XCTAssertFalse(store.accessoryBatteryService.isPolling)

        defaults.set(false, forKey: PreferenceKeys.showBatteryTime)
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: defaults)
        let expected = StatusTooltip.text(battery: battery, hasInternalBattery: true, showsRemainingTime: false)
        for _ in 0..<50 where controller.tooltipText != expected {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(controller.tooltipText, expected)

        controller.invalidate()
        let frozen = controller.tooltipText
        store.applyDebugBatteryStatus(status(charging: true, pluggedIn: true))
        XCTAssertEqual(controller.tooltipText, frozen)
    }

    private func status(charging: Bool, pluggedIn: Bool) -> BatteryStatus {
        BatteryStatus(percentage: 68, isCharging: charging, isPluggedIn: pluggedIn,
            isFullyCharged: false, isAvailable: true, timeToEmptyMinutes: 260, timeToFullChargeMinutes: 45)
    }
}
