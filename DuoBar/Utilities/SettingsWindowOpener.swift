import AppKit

@MainActor
enum SettingsWindowOpener {
    @discardableResult
    static func open() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        guard let item = settingsItem(in: NSApp.mainMenu), let action = item.action else { return false }
        return NSApp.sendAction(action, to: item.target, from: item)
    }

    static func settingsItem(in menu: NSMenu?) -> NSMenuItem? {
        guard let menu else { return nil }
        menu.update()
        for item in menu.items {
            if item.keyEquivalent == ",", item.keyEquivalentModifierMask.contains(.command), item.action != nil {
                return item
            }
            if let found = settingsItem(in: item.submenu) { return found }
        }
        return nil
    }
}
