import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class BatteryTimeTests: XCTestCase {
    private func battery(pluggedIn: Bool = false, charging: Bool = false) -> BatteryStatus {
        BatteryStatus(
            percentage: 55, isCharging: charging, isPluggedIn: pluggedIn,
            isFullyCharged: false, isAvailable: true,
            timeToEmptyMinutes: 260, timeToFullChargeMinutes: 45
        )
    }

    func testPowerStateSelectsOnlyTheMatchingEstimate() {
        XCTAssertEqual(battery().remainingTimeMinutes, 260)
        let charging = battery(pluggedIn: true, charging: true)
        XCTAssertEqual(charging.remainingTimeMinutes, 45)
        XCTAssertEqual(charging.remainingTimeDescription, localized("Until full charge: ≈%@", localized("%d min", 45)))
    }

    func testMissingAndNegativeEstimatesNeverBecomeDurations() {
        for invalid in [nil, -1, -2] as [Int?] {
            var discharging = battery()
            discharging.timeToEmptyMinutes = invalid
            XCTAssertNil(discharging.remainingTimeMinutes)
            XCTAssertEqual(discharging.remainingTimeDescription, localized("Battery time estimate unavailable"))
            var charging = battery(pluggedIn: true, charging: true)
            charging.timeToFullChargeMinutes = invalid
            XCTAssertNil(charging.remainingTimeMinutes)
            XCTAssertEqual(charging.remainingTimeDescription, localized("Battery time estimate unavailable"))
        }
    }

    func testDurationFormatsShortEstimatesAndHourBoundaries() {
        let cases = [
            (0, localized("Less than one minute")),
            (59, localized("%d min", 59)),
            (60, localized("%d h %d min", 1, 0)),
            (125, localized("%d h %d min", 2, 5))
        ]
        for (minutes, duration) in cases {
            var status = battery()
            status.timeToEmptyMinutes = minutes
            XCTAssertEqual(status.remainingTimeDescription, localized("Until empty: ≈%@", duration))
        }
    }

    func testPausedAndFullyChargedBatteryDoNotShowStaleEstimate() {
        var status = battery(pluggedIn: true)
        XCTAssertEqual(status.remainingTimeDescription, localized("Battery connected, not charging"))
        XCTAssertNil(status.remainingTimeMinutes)
        status.isFullyCharged = true
        XCTAssertNil(status.remainingTimeDescription)
        status.isCharging = true
        XCTAssertEqual(status.remainingTimeMinutes, 45)
    }

    func testUnavailableBatteryHasNoTimeLabel() {
        XCTAssertNil(BatteryStatus.unavailable.remainingTimeMinutes)
        XCTAssertNil(BatteryStatus.unavailable.remainingTimeDescription)
    }

    func testEstimateChangePublishesAsAChangedBatteryStatus() {
        let old = battery()
        var new = old
        new.timeToEmptyMinutes = 259
        XCTAssertNotEqual(old, new)
    }

    @MainActor
    func testRenderBatterySectionStates() throws {
        var unknown = battery(pluggedIn: true, charging: true)
        unknown.timeToFullChargeMinutes = -1
        var full = battery(pluggedIn: true)
        full.isFullyCharged = true
        full.percentage = 100
        let states = [battery(), battery(pluggedIn: true, charging: true), unknown, battery(pluggedIn: true), full, .unavailable]
        let view = VStack(spacing: 8) {
            ForEach(Array(states.enumerated()), id: \.offset) { _, status in
                BatteryStatusRow(battery: status, showPercentage: true, showsDisclosure: true)
            }
        }
        .frame(width: 280)
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.colorScheme, .dark)
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: .darkAqua)
        host.frame = NSRect(origin: .zero, size: host.fittingSize)
        host.layoutSubtreeIfNeeded()
        XCTAssertEqual(host.bounds.width, 304, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(host.bounds.height, 416)
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-Battery-Popover.png"))
    }
}
