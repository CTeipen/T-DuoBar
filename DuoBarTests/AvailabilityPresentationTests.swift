import XCTest
@testable import DuoBar

final class AvailabilityPresentationTests: XCTestCase {
    func testMissingSSIDExplainsTheActualAuthorizationState() {
        var network = DebugNetworkState.strong.status
        network.ssid = nil
        for (authorization, expected) in [
            (SSIDAuthorizationState.notDetermined, WiFiNameAvailabilityIssue.needsLocationAccess),
            (.denied, .locationAccessDenied), (.restricted, .locationAccessRestricted), (.authorized, .notReported)
        ] {
            network.ssidAuthorization = authorization
            XCTAssertEqual(WiFiNameAvailabilityIssue(network: network), expected)
        }
    }

    func testSSIDPrivacyExplanationDoesNotAppearForOfflineWiredOrNamedNetworks() {
        for network in [DebugNetworkState.strong.status, DebugNetworkState.ethernet.status,
                        DebugNetworkState.disconnected.status, .unavailable] {
            XCTAssertNil(WiFiNameAvailabilityIssue(network: network))
        }
    }

    func testEmptySSIDIsTreatedAsMissingEvenIfTheFrameworkReturnedWhitespace() {
        var network = DebugNetworkState.strong.status
        network.ssid = " \n "
        XCTAssertEqual(WiFiNameAvailabilityIssue(network: network), .needsLocationAccess)
    }

    func testSettingsOpenerStopsAfterTheFirstAcceptedDestination() {
        var attempted: [URL] = []
        XCTAssertTrue(SystemSettingsOpener.open(.wifi) { attempted.append($0); return true })
        XCTAssertEqual(attempted.count, 1)
        XCTAssertEqual(attempted.first?.scheme, "x-apple.systempreferences")
    }

    func testSettingsOpenerFallsBackToTheAppIfPaneURLsAreRejected() {
        var attempted: [URL] = []
        XCTAssertTrue(SystemSettingsOpener.open(.wifi) { url in
            attempted.append(url)
            return url.isFileURL
        })
        XCTAssertEqual(attempted.count, SystemSettingsOpener.urlStrings(for: .wifi).count + 1)
        XCTAssertEqual(attempted.last?.path, "/System/Applications/System Settings.app")
        XCTAssertFalse(SystemSettingsOpener.open(.locationServices, using: { _ in false }))
    }

    func testDesktopBatteryRowDoesNotSuggestAReadErrorForAbsentHardware() {
        let desktop = BatteryStatusRow(battery: .unavailable, showPercentage: true, hasInternalBattery: false)
        let laptop = BatteryStatusRow(battery: .unavailable, showPercentage: true, hasInternalBattery: true)
        XCTAssertEqual(desktop.detail, localized("No internal battery"))
        XCTAssertEqual(laptop.detail, localized("Battery data unavailable"))
    }
}
