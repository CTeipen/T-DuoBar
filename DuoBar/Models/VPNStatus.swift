import Foundation

enum VPNState: Equatable, Sendable {
    case connected, connecting, disconnecting, disconnected, notConfigured, unavailable

    var title: String {
        switch self {
        case .connected: localized("Connected")
        case .connecting: localized("Connecting…")
        case .disconnecting: localized("Disconnecting…")
        case .disconnected: localized("Disconnected")
        case .notConfigured: localized("Not configured")
        case .unavailable: localized("Unavailable")
        }
    }
}

struct VPNConnection: Identifiable, Equatable, Sendable {
    let id: String
    let name: String?
    let state: VPNState
    let interfaceName: String?

    var displayName: String { name ?? localized("Unnamed VPN") }
}

struct VPNStatus: Equatable, Sendable {
    let connections: [VPNConnection]
    var isAvailable = true

    static let unavailable = VPNStatus(connections: [], isAvailable: false)

    var state: VPNState {
        guard isAvailable else { return .unavailable }
        guard !connections.isEmpty else { return .notConfigured }
        for state in [VPNState.connected, .connecting, .disconnecting, .unavailable] {
            if connections.contains(where: { $0.state == state }) { return state }
        }
        return .disconnected
    }

    var summary: String {
        guard isAvailable else { return localized("VPN status unavailable") }
        guard !connections.isEmpty else { return localized("No macOS VPN profiles found") }
        let matching = connections.filter { $0.state == state }
        return (matching.isEmpty ? connections : matching).map(\.displayName).joined(separator: ", ")
    }
}
