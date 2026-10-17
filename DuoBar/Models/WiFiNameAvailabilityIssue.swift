import Foundation

enum WiFiNameAvailabilityIssue: Equatable {
    case needsLocationAccess, locationAccessDenied, locationAccessRestricted, notReported

    init?(network: NetworkStatus) {
        guard network.isAvailable, network.isConnected, network.transport == .wifi,
              SSIDValue.normalized(network.ssid) == nil else { return nil }
        switch network.ssidAuthorization {
        case .notDetermined: self = .needsLocationAccess
        case .denied: self = .locationAccessDenied
        case .restricted: self = .locationAccessRestricted
        case .authorized: self = .notReported
        }
    }

    var message: String {
        switch self {
        case .needsLocationAccess:
            localized("Allow location access to show the Wi-Fi name.")
        case .locationAccessDenied:
            // CLAuthorizationStatus.denied also covers globally disabled services.
            localized("Location access is off. Check Location Services and access for T-DuoBar.")
        case .locationAccessRestricted:
            localized("Location access is restricted on this Mac. Check the privacy settings.")
        case .notReported:
            localized("macOS has not provided the Wi-Fi name. Check the connection in Wi-Fi Settings.")
        }
    }
}
