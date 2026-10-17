import AppKit
import XCTest
@testable import DuoBar

final class PersonalHotspotTests: XCTestCase {
    func testMeteredWiFiSelectsHotspotGlyphWithoutChangingBatteryOrVolume() {
        var status = SystemStatus.unavailable
        status.network = DebugNetworkState.strong.status
        status.battery = BatteryStatus(percentage: 68, isCharging: false, isPluggedIn: false,
            isFullyCharged: false, isAvailable: true)
        let wifi = DuoGlyphState(status: status)
        status.network.isExpensive = true
        let hotspot = DuoGlyphState(status: status)
        XCTAssertEqual(hotspot.centerState, .personalHotspot)
        XCTAssertEqual(hotspot.ringPresentation, wifi.ringPresentation)
        XCTAssertEqual(hotspot.volumeActiveDotCount, wifi.volumeActiveDotCount)
        status.network.isExpensive = false
        XCTAssertEqual(DuoGlyphState(status: status).centerState, .wifi(.strong))
    }

    func testExpensiveFlagDoesNotOverrideOfflineWiredOrDisabledWiFi() {
        for var network in [DebugNetworkState.ethernet.status, DebugNetworkState.disconnected.status,
                            DebugNetworkState.wifiDisabled.status, .unavailable] {
            network.isExpensive = true
            XCTAssertFalse(network.usesPersonalHotspotSymbol)
        }
    }

    func testSSIDDoesNotGuessHotspotAndDetectionDoesNotNeedLocationPermission() {
        var network = DebugNetworkState.strong.status
        network.ssid = "iPhone Android Mobile Hotspot"
        XCTAssertFalse(network.usesPersonalHotspotSymbol)
        network.ssid = nil
        network.ssidAuthorization = .denied
        network.isExpensive = true
        XCTAssertTrue(network.usesPersonalHotspotSymbol)
    }

    @MainActor
    func testNativeHotspotSymbolIsAvailable() {
        XCTAssertNotNil(NSImage(systemSymbolName: "personalhotspot", accessibilityDescription: nil))
    }
}
