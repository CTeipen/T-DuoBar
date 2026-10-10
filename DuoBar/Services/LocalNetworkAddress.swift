import Darwin
import Foundation

enum LocalNetworkAddress {
    static func ipv4(interface: String?) -> String? {
        guard let interface else { return nil }
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            guard String(cString: entry.pointee.ifa_name) == interface,
                  let address = entry.pointee.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET) else { continue }
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(address.pointee.sa_len), &buffer,
                socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            return String(cString: buffer)
        }
        return nil
    }
}
