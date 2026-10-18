import AppKit
import XCTest
@testable import DuoBar

@MainActor
final class GlassPopoverToggleTests: XCTestCase {
    func testPinnedMenuStaysOpenUntilTheOwnerButtonMouseUpThenCloses() throws {
        try withPanel { panel, point in
            var interaction = HoverPopoverInteraction()
            XCTAssertEqual(interaction.statusItemClicked(), [.cancelClose, .open])
            panel.onClose = { _ = interaction.popoverClosedExternally() }

            // A menu-bar click may be reported outside this process before the
            // button's mouse-up action. Focus loss must not reset the toggle.
            panel.handleOutsideMouseDown(at: point)
            panel.handleKeyResignation(at: point, pressedMouseButtons: 1)
            XCTAssertTrue(panel.isVisible)
            panel.handleOutsideMouseUp(at: point)
            panel.handleKeyResignation(at: point, pressedMouseButtons: 0)
            XCTAssertTrue(panel.isVisible, "Focus loss during mouse-up must wait for the button action")
            XCTAssertEqual(interaction.statusItemClicked(), [.cancelClose, .close])
            panel.dismiss()
            XCTAssertFalse(panel.isVisible)
            XCTAssertFalse(panel.hasClickMonitors)
        }
    }

    func testOwnerFocusLossBeforeMouseMonitorDoesNotReopenMenu() throws {
        try withPanel { panel, point in
            var interaction = HoverPopoverInteraction()
            _ = interaction.statusItemClicked()
            panel.onClose = { _ = interaction.popoverClosedExternally() }
            panel.handleKeyResignation(at: point, pressedMouseButtons: 1)
            panel.handleOutsideMouseDown(at: point)
            XCTAssertTrue(panel.isVisible)
            panel.handleOutsideMouseUp(at: point)
            XCTAssertEqual(interaction.statusItemClicked(), [.cancelClose, .close])
        }
    }

    func testHoverMenuCanStillBePinnedByOwnerClick() throws {
        try withPanel { panel, point in
            var interaction = HoverPopoverInteraction(isEnabled: true)
            XCTAssertEqual(interaction.statusItemEntered(), [.cancelClose, .open])
            panel.onClose = { _ = interaction.popoverClosedExternally() }
            panel.handleOutsideMouseDown(at: point)
            panel.handleKeyResignation(at: point, pressedMouseButtons: 1)
            panel.handleOutsideMouseUp(at: point)
            XCTAssertEqual(interaction.statusItemClicked(), [.cancelClose])
            XCTAssertEqual(interaction.state, .pinned)
            XCTAssertTrue(panel.isVisible)
        }
    }

    func testKeyboardFocusLossOverOwnerStillDismissesMenu() throws {
        try withPanel { panel, point in
            panel.handleKeyResignation(at: point, pressedMouseButtons: 0)
            XCTAssertFalse(panel.isVisible)
            XCTAssertFalse(panel.hasClickMonitors)
        }
    }

    func testMouseDownAwayFromOwnerDismissesMenu() throws {
        try withPanel { panel, point in
            panel.handleOutsideMouseDown(at: NSPoint(x: point.x - 100, y: point.y - 100))
            XCTAssertFalse(panel.isVisible)
        }
    }

    func testDraggingOwnerPressAwayDismissesWithoutAButtonAction() throws {
        try withPanel { panel, point in
            panel.handleOutsideMouseDown(at: point)
            panel.handleKeyResignation(at: point, pressedMouseButtons: 1)
            panel.handleOutsideMouseUp(at: NSPoint(x: point.x - 100, y: point.y - 100))
            XCTAssertFalse(panel.isVisible)
            XCTAssertFalse(panel.hasClickMonitors)
        }
    }

    private func withPanel(_ body: (GlassPopoverPanel, NSPoint) throws -> Void) throws {
        let window = NSWindow(contentRect: NSRect(x: 300, y: 600, width: 40, height: 30),
            styleMask: [.borderless], backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 40, height: 30))
        window.contentView = anchor
        window.orderFrontRegardless()
        let panel = GlassPopoverPanel()
        let content = NSViewController()
        content.view = NSView(frame: NSRect(x: 0, y: 0, width: 304, height: 200))
        panel.setHostedController(content)
        panel.show(relativeTo: anchor, contentSize: NSSize(width: 304, height: 200))
        defer {
            panel.dismiss()
            panel.setHostedController(nil)
            window.orderOut(nil)
        }
        XCTAssertTrue(panel.isVisible)
        let rect = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        try body(panel, NSPoint(x: rect.midX, y: rect.midY))
    }
}
