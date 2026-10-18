import Foundation
import XCTest
@testable import DuoBar

final class MenuSectionOrderTests: XCTestCase {
    func testMissingAndMalformedPreferencesKeepEverySection() {
        for rawValue in ["", "not JSON", "{}", "[]", "[1,2]"] {
            XCTAssertEqual(MenuSectionOrder.decode(rawValue), MenuSection.allCases)
        }
    }

    func testOldOrNewPreferencesPreserveKnownOrderAndRecoverMissingSections() {
        let sections = MenuSectionOrder.decode(#"["battery","futureSection","network","battery"]"#)
        XCTAssertEqual(sections, [.battery, .network, .vpn, .volume, .accessories, .audioOutput, .microphone])
    }

    func testMoveWorksInBothDirectionsWithoutLosingOrDuplicatingSections() {
        let batteryFirst = MenuSectionOrder.moving(.battery, to: .network, in: MenuSection.allCases)
        XCTAssertEqual(batteryFirst, [.battery, .network, .vpn, .volume, .accessories, .audioOutput, .microphone])
        let networkLast = MenuSectionOrder.moving(.network, to: .microphone, in: batteryFirst)
        XCTAssertEqual(networkLast, [.battery, .vpn, .volume, .accessories, .audioOutput, .microphone, .network])
        XCTAssertEqual(MenuSectionOrder.moving(.network, to: .network, in: networkLast), networkLast)
    }

    func testOrderPersistsIndependentlyOfVisibilityAndSurvivesReload() throws {
        let suite = "MenuSectionOrderTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: PreferenceKeys.showNetwork)
        let order = MenuSectionOrder.moving(.battery, to: .network, in: MenuSection.allCases)
        defaults.set(MenuSectionOrder.encode(order), forKey: PreferenceKeys.menuSectionOrder)

        let reloaded = try XCTUnwrap(UserDefaults(suiteName: suite))
        XCTAssertEqual(MenuSectionOrder.decode(try XCTUnwrap(reloaded.string(forKey: PreferenceKeys.menuSectionOrder))), order)
        XCTAssertFalse(reloaded.bool(forKey: PreferenceKeys.showNetwork))
        reloaded.set(true, forKey: PreferenceKeys.showNetwork)
        XCTAssertEqual(MenuSectionOrder.decode(try XCTUnwrap(reloaded.string(forKey: PreferenceKeys.menuSectionOrder))), order)
    }

    func testDragPayloadRejectsForeignTextAndUnknownSections() {
        XCTAssertNil(MenuSection(dragIdentifier: "battery"))
        XCTAssertNil(MenuSection(dragIdentifier: "https://example.com/battery"))
        XCTAssertNil(MenuSection(dragIdentifier: "com.mikeli.duobar.menu-section.unknown"))
        XCTAssertEqual(MenuSection(dragIdentifier: MenuSection.battery.dragIdentifier), .battery)
    }

    func testLegacyOrderAddsVPNBesideNetworkAndExplicitVPNPositionIsRetained() {
        let legacy = #"["volume","battery","network","accessories","audioOutput","microphone"]"#
        XCTAssertEqual(MenuSectionOrder.decode(legacy), [.volume, .battery, .network, .vpn, .accessories, .audioOutput, .microphone])
        let explicit = [.vpn, .volume, .battery, .network, .accessories, .audioOutput, .microphone] as [MenuSection]
        XCTAssertEqual(MenuSectionOrder.decode(MenuSectionOrder.encode(explicit)), explicit)
    }
}
