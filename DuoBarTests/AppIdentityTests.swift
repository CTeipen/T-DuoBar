import AppKit
import XCTest
@testable import DuoBar

final class AppIdentityTests: XCTestCase {
    @MainActor
    func testAboutPanelUsesInstalledBundleMetadataAndBundledIcon() throws {
        let options = AboutPanel.options()
        XCTAssertEqual(options[.applicationName] as? String, "T-DuoBar")
        XCTAssertEqual(options[.applicationVersion] as? String,
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        XCTAssertEqual(options[.version] as? String,
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        let icon = try XCTUnwrap(options[.applicationIcon] as? NSImage)
        XCTAssertTrue(icon.isValid)
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.mikeli.duobar", "Existing preferences must keep their identity")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, AppIdentity.name)
    }

    @MainActor
    func testAboutPanelPreservesUpstreamCreditAndAllProjectLinks() throws {
        let credits = try XCTUnwrap(AboutPanel.options()[.credits] as? NSAttributedString)
        XCTAssertTrue(credits.string.contains("squazaryu"))
        XCTAssertTrue(credits.string.contains("Mike Li"))
        XCTAssertTrue(credits.string.contains("Mikeli7666"))
        var links: [URL] = []
        credits.enumerateAttribute(.link, in: NSRange(location: 0, length: credits.length)) { value, _, _ in
            if let url = value as? URL { links.append(url) }
        }
        XCTAssertEqual(links.map(\.absoluteString), [
            "https://github.com/squazaryu/T-DuoBar",
            "https://github.com/squazaryu/T-DuoBar/releases",
            "https://github.com/Mikeli7666/DuoBar",
            "https://github.com/squazaryu/T-DuoBar/blob/main/LICENSE"
        ])
    }
}
