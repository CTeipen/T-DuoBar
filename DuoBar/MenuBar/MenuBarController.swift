import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private static let hoverCloseDelay: TimeInterval = 0.25

    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let statusStore: SystemStatusStore
    private let defaults: UserDefaults
    private var hostingView: PassthroughHostingView<DuoStatusView>?
    private var popoverTrackingView: HoverTrackingContainerView?
    private var lengthAnimationTimer: Timer?
    private var pendingHoverClose: DispatchWorkItem?
    private var hoverCloseGeneration: UInt = 0
    private var defaultsObserver: NSObjectProtocol?
    private var applicationResignObserver: NSObjectProtocol?
    private var batteryObservation: AnyCancellable?
    private var hoverInteraction: HoverPopoverInteraction
    private var isInvalidated = false
    private var isPopoverVisible = false

    init(statusStore: SystemStatusStore, defaults: UserDefaults = .standard) {
        self.statusStore = statusStore
        self.defaults = defaults
        hoverInteraction = HoverPopoverInteraction(isEnabled: defaults.bool(forKey: PreferenceKeys.openOnHover))
        statusItem = NSStatusBar.system.statusItem(
            withLength: MenuBarIconSize.statusItemWidth(for: MenuBarIconSize.storedScale())
        )
        super.init()
        configureStatusItem()
        configurePopover()
        observeBatteryStatus()
        observePreferences()
        observeApplicationActivity()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.image = nil
        button.title = ""
        updateTooltip(for: statusStore.status.battery)

        let rootView = DuoStatusView(statusStore: statusStore) { [weak self] width in
            self?.setStatusItemLength(width)
        }
        let hostingView = PassthroughHostingView(rootView: rootView)
        hostingView.onHoverChanged = { [weak self] isInside in
            guard let self else { return }
            let commands = isInside
                ? self.hoverInteraction.statusItemEntered()
                : self.hoverInteraction.statusItemExited()
            self.perform(commands)
        }
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
        ])
        self.hostingView = hostingView
    }

    private func observeBatteryStatus() {
        // The existing store already receives battery events. Tooltips must not
        // introduce a second timer or hardware read, even while the menu is shut.
        batteryObservation = statusStore.$status.map(\.battery).removeDuplicates().sink { [weak self] battery in
            guard let self, !self.isInvalidated else { return }
            self.updateTooltip(for: battery)
        }
    }

    private func updateTooltip(for battery: BatteryStatus) {
        let text = StatusTooltip.text(battery: battery,
            hasInternalBattery: statusStore.deviceContext.hasInternalBattery,
            showsRemainingTime: defaults.object(forKey: PreferenceKeys.showBatteryTime) as? Bool ?? true)
        if statusItem.button?.toolTip != text { statusItem.button?.toolTip = text }
    }

    var tooltipText: String? { statusItem.button?.toolTip }

    private func configurePopover() {
        updatePopoverBehavior()
        popover.delegate = self
        popover.animates = true
        popover.contentSize = NSSize(width: 304, height: 316)
        let hostingController = NSHostingController(
            rootView: StatusPopoverView(statusStore: statusStore, onHeightChange: { [weak self] height in
                DispatchQueue.main.async {
                    guard let self, !self.isInvalidated,
                          abs(self.popover.contentSize.height - height) > 0.5 else { return }
                    self.popover.contentSize = NSSize(width: 304, height: height)
                }
            }) { [weak self] in
                self?.closePopoverFromContent()
            }
        )
        let trackingView = HoverTrackingContainerView()
        trackingView.onHoverChanged = { [weak self] isInside in
            guard let self else { return }
            let commands = isInside
                ? self.hoverInteraction.popoverEntered()
                : self.hoverInteraction.popoverExited()
            self.perform(commands)
        }
        let contentViewController = NSViewController()
        contentViewController.view = trackingView
        contentViewController.addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        trackingView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: trackingView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trackingView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: trackingView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: trackingView.bottomAnchor)
        ])
        popover.contentViewController = contentViewController
        popoverTrackingView = trackingView
    }

    @objc private func togglePopover() {
        guard !isInvalidated else { return }
        if Self.opensContextMenu(for: NSApp.currentEvent), let event = NSApp.currentEvent,
           let button = statusItem.button {
            perform(hoverInteraction.contextMenuOpened())
            defer { perform(hoverInteraction.contextMenuClosed()) }
            NSMenu.popUpContextMenu(makeContextMenu(), with: event, for: button)
            return
        }
        perform(hoverInteraction.statusItemClicked())
    }

    static func opensContextMenu(for event: NSEvent?) -> Bool {
        guard let event else { return false }
        return event.type == .rightMouseUp || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))
    }

    func makeContextMenu() -> NSMenu {
        let menu = NSMenu(title: AppIdentity.name)
        menu.autoenablesItems = false
        let settings = NSMenuItem(title: localized("Settings…"), action: #selector(openSettingsFromContextMenu), keyEquivalent: ",")
        settings.target = self
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settings)
        let updates = NSMenuItem(title: localized("Check for updates…"), action: #selector(checkUpdatesFromContextMenu), keyEquivalent: "")
        updates.target = self
        updates.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        updates.isEnabled = !HomebrewUpdateService.shared.isChecking
        menu.addItem(updates)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: localized("Quit T-DuoBar"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
        return menu
    }

    @objc private func openSettingsFromContextMenu() {
        Task { @MainActor in SettingsWindowOpener.open() }
    }

    @objc private func checkUpdatesFromContextMenu() {
        Task { @MainActor in await HomebrewUpdateService.shared.checkManually() }
    }

    private func showPopover() {
        guard !popover.isShown, let button = statusItem.button else { return }

        updatePopoverBehavior()
        statusStore.refresh()
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        // Let the accessory app finish activating and the popover become key
        // before asking CoreLocation to present its native authorization UI.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isInvalidated, self.popover.isShown,
                  self.defaults.object(forKey: PreferenceKeys.showNetwork) as? Bool ?? true else { return }
            self.statusStore.requestWiFiSSIDAccess(trigger: .popoverOpened)
        }
    }

    private func closePopover() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    private func closePopoverFromContent() {
        perform(hoverInteraction.popoverClosedExternally())
        closePopover()
    }

    private func perform(_ commands: [HoverPopoverCommand]) {
        guard !isInvalidated else { return }
        for command in commands {
            switch command {
            case .open:
                showPopover()
            case .close:
                closePopover()
            case .scheduleClose:
                scheduleHoverClose()
            case .cancelClose:
                cancelHoverClose()
            }
        }
    }

    private func scheduleHoverClose() {
        cancelHoverClose()
        let generation = hoverCloseGeneration
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.hoverCloseGeneration == generation else { return }
                self.pendingHoverClose = nil
                self.perform(self.hoverInteraction.closeDelayElapsed())
            }
        }
        pendingHoverClose = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.hoverCloseDelay,
            execute: workItem
        )
    }

    private func cancelHoverClose() {
        hoverCloseGeneration &+= 1
        pendingHoverClose?.cancel()
        pendingHoverClose = nil
    }

    private func observePreferences() {
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let enabled = self.defaults.bool(forKey: PreferenceKeys.openOnHover)
                let commands = self.hoverInteraction.setEnabled(enabled)
                self.updatePopoverBehavior()
                self.perform(commands)
                self.updateAccessoryPolling()
                self.updateTooltip(for: self.statusStore.status.battery)
            }
        }
    }

    private func observeApplicationActivity() {
        applicationResignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: NSApp,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.perform(self.hoverInteraction.applicationResignedActive())
            }
        }
    }

    private func updatePopoverBehavior() {
        #if DEBUG
        if MarketingCaptureMode.isEnabled {
            popover.behavior = .applicationDefined
            return
        }
        #endif
        popover.behavior = hoverInteraction.isEnabled ? .applicationDefined : .transient
    }

    private func updateAccessoryPolling() {
        let enabled = defaults.object(forKey: PreferenceKeys.showAccessories) as? Bool ?? true
        if !isInvalidated && isPopoverVisible && enabled {
            statusStore.accessoryBatteryService.start()
        } else {
            statusStore.accessoryBatteryService.stop()
        }
    }

    #if DEBUG
    func setPopoverVisibleForMarketingCapture(_ visible: Bool) {
        guard popover.isShown != visible else { return }
        if visible {
            showPopover()
        } else {
            closePopoverFromContent()
        }
    }
    #endif

    private func setStatusItemLength(_ targetLength: CGFloat) {
        guard !isInvalidated else { return }
        lengthAnimationTimer?.invalidate()

        guard defaults.bool(forKey: PreferenceKeys.animationsEnabled) else {
            statusItem.length = targetLength
            return
        }

        let startLength = statusItem.length
        guard abs(startLength - targetLength) > 0.5 else { return }
        let startDate = Date()
        let duration: TimeInterval = 0.34

        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else {
                    timer.invalidate()
                    return
                }

                let elapsed = Date().timeIntervalSince(startDate)
                let progress = min(max(elapsed / duration, 0), 1)
                let eased = 1 - pow(1 - progress, 3)
                self.statusItem.length = startLength + (targetLength - startLength) * eased

                if progress >= 1 {
                    self.statusItem.length = targetLength
                    timer.invalidate()
                    self.lengthAnimationTimer = nil
                }
            }
        }
        lengthAnimationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        isPopoverVisible = false
        batteryObservation?.cancel()
        batteryObservation = nil
        statusStore.accessoryBatteryService.stop()
        cancelHoverClose()
        lengthAnimationTimer?.invalidate()
        lengthAnimationTimer = nil
        popover.performClose(nil)
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
            self.defaultsObserver = nil
        }
        if let applicationResignObserver {
            NotificationCenter.default.removeObserver(applicationResignObserver)
            self.applicationResignObserver = nil
        }
        popoverTrackingView?.removeFromSuperview()
        popoverTrackingView = nil
        hostingView?.removeFromSuperview()
        hostingView = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    deinit {
        pendingHoverClose?.cancel()
        lengthAnimationTimer?.invalidate()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
        if let applicationResignObserver {
            NotificationCenter.default.removeObserver(applicationResignObserver)
        }
        if !isInvalidated {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}

extension MenuBarController: NSPopoverDelegate {
    func popoverDidShow(_ notification: Notification) {
        isPopoverVisible = true
        updateAccessoryPolling()
    }

    func popoverWillClose(_ notification: Notification) {
        isPopoverVisible = false
        statusStore.accessoryBatteryService.stop()
    }

    func popoverDidClose(_ notification: Notification) {
        isPopoverVisible = false
        statusStore.accessoryBatteryService.stop()
        perform(hoverInteraction.popoverClosedExternally())
    }
}

private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    var onHoverChanged: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

final class HoverTrackingContainerView: NSView {
    var onHoverChanged: ((Bool) -> Void)?
    private var hoverTrackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }
        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

}
