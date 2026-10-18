import AppKit
import Foundation

enum SystemSettingsOpener {
    enum Pane: Equatable, Sendable {
        case wifi
        case network
        case vpn
        case battery
        case sound
        case bluetooth
        case locationServices
    }

    static func pane(for network: NetworkStatus) -> Pane {
        switch network.transport {
        case .ethernet, .other:
            return .network
        case .wifi, .none:
            return .wifi
        }
    }

    static func urlStrings(for pane: Pane) -> [String] {
        switch pane {
        case .wifi:
            [
                "x-apple.systempreferences:com.apple.wifi-settings-extension",
                "x-apple.systempreferences:com.apple.Network-Settings.extension",
            ]
        case .network:
            [
                "x-apple.systempreferences:com.apple.Network-Settings.extension",
                "x-apple.systempreferences:com.apple.wifi-settings-extension",
            ]
        case .vpn:
            [
                "x-apple.systempreferences:com.apple.NetworkExtensionSettingsUI.NESettingsUIExtension",
                "x-apple.systempreferences:com.apple.Network-Settings.extension",
            ]
        case .battery:
            [
                "x-apple.systempreferences:com.apple.Battery-Settings.extension",
            ]
        case .sound:
            [
                "x-apple.systempreferences:com.apple.Sound-Settings.extension",
            ]
        case .bluetooth:
            ["x-apple.systempreferences:com.apple.BluetoothSettings"]
        case .locationServices:
            ["x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"]
        }
    }

    @discardableResult
    @MainActor
    static func open(_ pane: Pane) -> Bool {
        open(pane, using: NSWorkspace.shared.open)
    }

    @discardableResult
    static func open(_ pane: Pane, using openURL: (URL) -> Bool) -> Bool {
        for string in urlStrings(for: pane) {
            if let url = URL(string: string), openURL(url) {
                return true
            }
        }

        return openURL(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
