import Foundation
import SystemConfiguration

enum SystemConfigurationVPNReader {
    static func read() -> VPNStatus {
        guard let preferences = SCPreferencesCreate(nil, "T-DuoBar VPN status" as CFString, nil),
              let services = SCNetworkServiceCopyAll(preferences) as? [SCNetworkService] else {
            return .unavailable
        }
        var connections = [VPNConnection]()
        for service in services {
            var interface = SCNetworkServiceGetInterface(service)
            var types = [String]()
            while let current = interface, types.count < 8 {
                guard let type = SCNetworkInterfaceGetInterfaceType(current) else { break }
                types.append(type as String)
                interface = SCNetworkInterfaceGetInterface(current)
            }
            guard isVPN(interfaceTypes: types) else { continue }
            guard let id = SCNetworkServiceGetServiceID(service) else { return .unavailable }
            let name = normalized(SCNetworkServiceGetName(service) as String?)
            let connection = SCNetworkConnectionCreateWithServiceID(nil, id, nil, nil)
            let state = connection.map { Self.state(for: SCNetworkConnectionGetStatus($0)) } ?? .unavailable
            var interfaceName: String?
            if state == .connected, let connection,
               let extended = SCNetworkConnectionCopyExtendedStatus(connection) as? [String: Any] {
                interfaceName = ["IPv4", "IPv6"].lazy.compactMap { entity in
                    normalized((extended[entity] as? [String: Any])?["InterfaceName"] as? String)
                }.first
            }
            connections.append(VPNConnection(id: id as String, name: name,
                state: state, interfaceName: interfaceName))
        }
        connections.sort {
            let comparison = ($0.name ?? "").localizedCaseInsensitiveCompare($1.name ?? "")
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
        return VPNStatus(connections: connections)
    }

    static func isVPN(interfaceTypes: [String]) -> Bool {
        // A utun interface alone is not evidence of a VPN. Use configured
        // connection services, including third-party Network Extension profiles.
        interfaceTypes.contains("VPN")
            || interfaceTypes.contains(kSCNetworkInterfaceTypeIPSec as String)
            || interfaceTypes.contains(kSCNetworkInterfaceTypeL2TP as String)
    }

    private static func state(for status: SCNetworkConnectionStatus) -> VPNState {
        switch status {
        case .connected: .connected
        case .connecting: .connecting
        case .disconnecting: .disconnecting
        case .disconnected: .disconnected
        case .invalid: .unavailable
        @unknown default: .unavailable
        }
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }
}
