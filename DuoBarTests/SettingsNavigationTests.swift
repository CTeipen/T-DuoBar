import AppKit
import XCTest
@testable import DuoBar

final class SettingsNavigationTests: XCTestCase {
    @MainActor
    func testRightClickAndControlClickOpenContextMenuButOrdinaryLeftClickDoesNot() throws {
        func event(_ type: NSEvent.EventType, flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
            try XCTUnwrap(NSEvent.mouseEvent(with: type, location: .zero, modifierFlags: flags, timestamp: 0,
                windowNumber: 0, context: nil, eventNumber: 0, clickCount: 1, pressure: 0))
        }
        XCTAssertTrue(MenuBarController.opensContextMenu(for: try event(.rightMouseUp)))
        XCTAssertTrue(MenuBarController.opensContextMenu(for: try event(.leftMouseUp, flags: .control)))
        XCTAssertFalse(MenuBarController.opensContextMenu(for: try event(.leftMouseUp)))
        XCTAssertFalse(MenuBarController.opensContextMenu(for: nil))
    }

    @MainActor
    func testContextMenuContainsSettingsUpdateAndQuitCommands() {
        let controller = MenuBarController(statusStore: SystemStatusStore(startServices: false))
        defer { controller.invalidate() }
        let menu = controller.makeContextMenu()
        XCTAssertEqual(menu.items.count, 4)
        XCTAssertEqual(menu.items[0].keyEquivalent, ",")
        XCTAssertNotNil(menu.items[0].action)
        XCTAssertNotNil(menu.items[1].action)
        XCTAssertTrue(menu.items[2].isSeparatorItem)
        XCTAssertEqual(menu.items[3].action, #selector(NSApplication.terminate(_:)))
        XCTAssertEqual(menu.items[3].keyEquivalent, "q")
    }

    @MainActor
    func testSettingsRoutingFindsLocalizedNestedCommandByShortcut() {
        let menu = NSMenu()
        let appItem = NSMenuItem(title: "Application", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        let unrelated = NSMenuItem(title: "Other", action: #selector(NSApplication.hide(_:)), keyEquivalent: ",")
        unrelated.keyEquivalentModifierMask = .option
        submenu.addItem(unrelated)
        let settings = NSMenuItem(title: "Einstellungen…", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ",")
        settings.keyEquivalentModifierMask = .command
        submenu.addItem(settings)
        appItem.submenu = submenu
        menu.addItem(appItem)
        XCTAssertTrue(SettingsWindowOpener.settingsItem(in: menu) === settings)
        XCTAssertNil(SettingsWindowOpener.settingsItem(in: nil))
    }
}
