import AppKit
import XCTest
@testable import DuoBar

@MainActor
final class StatusItemClickTests: XCTestCase {
    func testSecondClickClosesOnMouseDownAndMouseUpCannotReopen() throws {
        try withController { controller, anchor in
            controller.previewPopover(relativeTo: anchor)
            let panel = try XCTUnwrap(controller.menuWindow as? GlassPopoverPanel)
            XCTAssertTrue(panel.isVisible)

            let down = try event(.leftMouseDown, on: anchor, number: 1)
            XCTAssertNil(controller.filterStatusItemMouseDown(down, relativeTo: anchor), "The down event must be consumed before native button tracking")
            XCTAssertFalse(panel.isVisible)
            panel.handleKeyResignation(at: .zero, pressedMouseButtons: 0)
            let up = try event(.leftMouseUp, on: anchor, number: 2)
            XCTAssertTrue(controller.filterStatusItemMouseDown(up, relativeTo: anchor) === up)
            XCTAssertFalse(MenuBarController.statusItemActionEvents.contains(.leftMouseUp), "Mouse-up must not send another toggle action")
            XCTAssertFalse(panel.isVisible)

            // The next distinct click must still open normally; no debounce or
            // stale suppression flag may consume it.
            XCTAssertNil(controller.filterStatusItemMouseDown(try event(.leftMouseDown, on: anchor, number: 3), relativeTo: anchor))
            XCTAssertTrue(panel.isVisible)
            XCTAssertNil(controller.filterStatusItemMouseDown(try event(.leftMouseDown, on: anchor, number: 5), relativeTo: anchor))
            XCTAssertFalse(panel.isVisible)
        }
    }

    func testLateMouseUpAndFocusCallbacksNeverReopenAcrossRepeatedClicks() throws {
        try withController { controller, anchor in
            for number in 0..<30 {
                XCTAssertNil(controller.filterStatusItemMouseDown(try event(.leftMouseDown, on: anchor, number: number * 4 + 1), relativeTo: anchor))
                let panel = try XCTUnwrap(controller.menuWindow as? GlassPopoverPanel)
                XCTAssertTrue(panel.isVisible)
                XCTAssertNil(controller.filterStatusItemMouseDown(try event(.leftMouseDown, on: anchor, number: number * 4 + 3), relativeTo: anchor))
                panel.handleOutsideMouseUp(at: .zero)
                panel.handleKeyResignation(at: .zero, pressedMouseButtons: 0)
                _ = controller.filterStatusItemMouseDown(try event(.leftMouseUp, on: anchor, number: number * 4 + 4), relativeTo: anchor)
                XCTAssertFalse(panel.isVisible, "Repeated click \(number) reopened the menu")
            }
        }
    }

    func testUnrelatedControlClickAndInvalidatedControllerLeaveEventsUntouched() throws {
        try withController { controller, anchor in
            let control = try event(.leftMouseDown, on: anchor, number: 1, flags: .control)
            XCTAssertTrue(controller.filterStatusItemMouseDown(control, relativeTo: anchor) === control)
            XCTAssertTrue(MenuBarController.opensContextMenu(for: control))
            let outside = try event(.leftMouseDown, on: anchor, number: 2, location: NSPoint(x: -20, y: -20))
            XCTAssertTrue(controller.filterStatusItemMouseDown(outside, relativeTo: anchor) === outside)
            controller.invalidate()
            let down = try event(.leftMouseDown, on: anchor, number: 3)
            XCTAssertTrue(controller.filterStatusItemMouseDown(down, relativeTo: anchor) === down)
        }
    }

    private func event(_ type: NSEvent.EventType, on anchor: NSView, number: Int,
                       flags: NSEvent.ModifierFlags = [], location: NSPoint? = nil) throws -> NSEvent {
        let point = location ?? NSPoint(x: anchor.bounds.midX, y: anchor.bounds.midY)
        return try XCTUnwrap(NSEvent.mouseEvent(with: type, location: anchor.convert(point, to: nil),
            modifierFlags: flags, timestamp: Double(number), windowNumber: try XCTUnwrap(anchor.window).windowNumber,
            context: nil, eventNumber: number, clickCount: 1, pressure: 1))
    }

    private func withController(_ body: (MenuBarController, NSView) throws -> Void) throws {
        guard #available(macOS 26.0, *), !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency else {
            throw XCTSkip("Requires native glass without Reduce Transparency")
        }
        let name = "StatusItemClickTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.set("liquidGlass", forKey: PreferenceKeys.popoverStyle)
        defaults.set(false, forKey: PreferenceKeys.animationsEnabled)
        defaults.set(false, forKey: PreferenceKeys.showNetwork)
        defaults.set(false, forKey: PreferenceKeys.showVPN)
        defaults.set(false, forKey: PreferenceKeys.showAccessories)
        let controller = MenuBarController(statusStore: SystemStatusStore(startServices: false), defaults: defaults)
        let window = NSWindow(contentRect: NSRect(x: 300, y: 600, width: 40, height: 30),
            styleMask: [.borderless], backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 30))
        window.contentView = anchor
        window.orderFrontRegardless()
        defer {
            controller.invalidate()
            window.orderOut(nil)
            defaults.removePersistentDomain(forName: name)
        }
        try body(controller, anchor)
    }
}
