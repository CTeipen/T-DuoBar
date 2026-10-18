import AppKit

/// Owns one native glass surface, without NSPopover's additional backdrop.
@MainActor
final class GlassPopoverPanel: NSPanel, NSWindowDelegate {
    var onShow: (() -> Void)?
    var onWillClose: (() -> Void)?
    var onClose: (() -> Void)?

    private let containerController = NSViewController()
    private let surface: NSView
    private var hostedController: NSViewController?
    private var localClickMonitor: Any?
    private var globalClickMonitor: Any?
    private weak var anchorView: NSView?
    private var isDismissing = false
    private var isTrackingAnchorPress = false
    private var anchorPressGeneration: UInt = 0

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    init() {
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.style = .clear
            glass.cornerRadius = 18
            surface = glass
        } else {
            surface = NSView()
        }
        super.init(contentRect: NSRect(x: 0, y: 0, width: 304, height: 316),
            styleMask: [.borderless], backing: .buffered, defer: false)
        isReleasedWhenClosed = false
        isFloatingPanel = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        animationBehavior = .none
        collectionBehavior = [.transient, .moveToActiveSpace, .fullScreenAuxiliary]
        containerController.view = surface
        contentViewController = containerController
        title = AppIdentity.name
        delegate = self
    }

    func setHostedController(_ controller: NSViewController?) {
        guard hostedController !== controller else { return }
        hostedController?.view.removeFromSuperview()
        hostedController?.removeFromParent()
        hostedController = controller
        if #available(macOS 26.0, *), let glass = surface as? NSGlassEffectView {
            glass.contentView = controller?.view
        }
        if let controller {
            containerController.addChild(controller)
            controller.view.frame = surface.bounds
            controller.view.autoresizingMask = [.width, .height]
        }
    }

    func show(relativeTo anchor: NSView, contentSize: NSSize) {
        guard !isVisible, let window = anchor.window else { return }
        anchorView = anchor
        let anchorRect = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? anchorRect
        setFrame(Self.frame(contentSize: contentSize, anchor: anchorRect, visibleFrame: visibleFrame), display: false)
        makeKeyAndOrderFront(nil)
        installClickMonitors()
        onShow?()
    }

    func resizeContent(to size: NSSize) {
        guard isVisible, let anchor = anchorView, let window = anchor.window else {
            setContentSize(size)
            return
        }
        let rect = window.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let visible = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? rect
        setFrame(Self.frame(contentSize: size, anchor: rect, visibleFrame: visible), display: true)
    }

    static func frame(contentSize: NSSize, anchor: NSRect, visibleFrame: NSRect) -> NSRect {
        let margin: CGFloat = 6
        let width = min(contentSize.width, max(0, visibleFrame.width - margin * 2))
        let height = min(contentSize.height, max(0, visibleFrame.height - margin * 2))
        let x = min(max(anchor.midX - width / 2, visibleFrame.minX + margin), visibleFrame.maxX - width - margin)
        let y = max(visibleFrame.minY + margin, min(anchor.minY, visibleFrame.maxY) - height - margin)
        return NSRect(x: x, y: y, width: width, height: height)
    }

    override func cancelOperation(_ sender: Any?) { dismiss() }
    override func close() { dismiss() }
    func windowDidResignKey(_ notification: Notification) {
        if !isKeyWindow {
            handleKeyResignation(at: NSEvent.mouseLocation, pressedMouseButtons: Int(NSEvent.pressedMouseButtons))
        }
    }

    func handleKeyResignation(at point: NSPoint, pressedMouseButtons: Int) {
        guard isVisible, !isDismissing else { return }
        // Menu-bar tracking can take key focus before the button sends mouseUp.
        // Keep that entire gesture owned by the button's normal toggle action.
        if isTrackingAnchorPress || (pressedMouseButtons & 3 != 0 && isPointOverAnchor(point)) {
            if !isTrackingAnchorPress { beginAnchorPress() }
            return
        }
        dismiss()
    }

    func handleOutsideMouseDown(at point: NSPoint) {
        guard isVisible, !isDismissing else { return }
        if isPointOverAnchor(point) { beginAnchorPress() } else { dismiss() }
    }

    func handleOutsideMouseUp(at point: NSPoint) {
        guard isVisible, isTrackingAnchorPress else { return }
        guard isPointOverAnchor(point) else {
            dismiss() // A press dragged away from the status button was cancelled.
            return
        }
        let generation = anchorPressGeneration
        // Run after NSStatusBarButton's mouse-up action. Pinned menus close;
        // a hover-open menu that was pinned by this click regains key focus.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isVisible, self.isTrackingAnchorPress,
                  self.anchorPressGeneration == generation else { return }
            self.isTrackingAnchorPress = false
            self.makeKey()
        }
    }

    private func beginAnchorPress() {
        anchorPressGeneration &+= 1
        isTrackingAnchorPress = true
    }

    private func isPointOverAnchor(_ point: NSPoint) -> Bool {
        guard let anchor = anchorView, let window = anchor.window else { return false }
        return window.convertToScreen(anchor.convert(anchor.bounds, to: nil)).contains(point)
    }

    func dismiss() {
        guard isVisible, !isDismissing else { return }
        isDismissing = true
        anchorPressGeneration &+= 1
        isTrackingAnchorPress = false
        onWillClose?()
        removeClickMonitors()
        orderOut(nil)
        anchorView = nil
        isDismissing = false
        onClose?()
    }

    var hasClickMonitors: Bool { localClickMonitor != nil || globalClickMonitor != nil }

    private func installClickMonitors() {
        removeClickMonitors()
        let mouseEvents: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .leftMouseUp, .rightMouseUp]
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            guard let self else { return event }
            let point = event.window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
            if event.type == .leftMouseUp || event.type == .rightMouseUp {
                self.handleOutsideMouseUp(at: point)
            } else if event.window !== self {
                self.handleOutsideMouseDown(at: point)
            }
            return event
        }
        // Mouse observation only; no keyboard event tap or input permission.
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseEvents) { [weak self] event in
            if event.type == .leftMouseUp || event.type == .rightMouseUp {
                self?.handleOutsideMouseUp(at: NSEvent.mouseLocation)
            } else {
                self?.handleOutsideMouseDown(at: NSEvent.mouseLocation)
            }
        }
    }

    private func removeClickMonitors() {
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        localClickMonitor = nil
        globalClickMonitor = nil
    }

    deinit {
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
    }
}
