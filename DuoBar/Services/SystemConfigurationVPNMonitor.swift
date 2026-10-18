import Foundation
import SystemConfiguration

@MainActor
protocol VPNChangeMonitoring: AnyObject {
    func start(onChange: @escaping @Sendable () -> Void) -> Bool
    func stop()
}

@MainActor
final class SystemConfigurationVPNMonitor: VPNChangeMonitoring {
    private final class Callback: Sendable {
        let onChange: @Sendable () -> Void
        init(_ onChange: @escaping @Sendable () -> Void) { self.onChange = onChange }
    }

    private var store: SCDynamicStore?

    func start(onChange: @escaping @Sendable () -> Void) -> Bool {
        stop()
        let callback = Callback(onChange)
        var context = SCDynamicStoreContext(version: 0,
            info: Unmanaged.passUnretained(callback).toOpaque(),
            retain: { pointer in
                _ = Unmanaged<Callback>.fromOpaque(pointer).retain()
                return pointer
            }, release: { pointer in
                Unmanaged<Callback>.fromOpaque(pointer).release()
            }, copyDescription: nil)
        guard let store = SCDynamicStoreCreate(nil, "T-DuoBar VPN observation" as CFString, { _, _, pointer in
            guard let pointer else { return }
            Unmanaged<Callback>.fromOpaque(pointer).takeUnretainedValue().onChange()
        }, &context) else { return false }

        let patterns = [
            "^State:/Network/Service/.*/(VPN|PPP|IPSec|IPv4|IPv6)$",
            "^Setup:/Network/Service/.*",
            "^State:/Network/Global/(IPv4|IPv6)$"
        ] as CFArray
        guard SCDynamicStoreSetNotificationKeys(store, nil, patterns),
              SCDynamicStoreSetDispatchQueue(store, .main) else { return false }
        self.store = store
        return true
    }

    func stop() {
        if let store { SCDynamicStoreSetDispatchQueue(store, nil) }
        store = nil
    }

    deinit {
        if let store { SCDynamicStoreSetDispatchQueue(store, nil) }
    }
}
