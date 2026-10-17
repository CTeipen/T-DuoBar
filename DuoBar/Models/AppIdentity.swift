import Foundation

struct AppIdentity {
    static let name = "T-DuoBar"
    static let projectURL = URL(string: "https://github.com/squazaryu/T-DuoBar")!
    static let releasesURL = projectURL.appendingPathComponent("releases")
    static let upstreamURL = URL(string: "https://github.com/Mikeli7666/DuoBar")!
    static let licenseURL = projectURL.appendingPathComponent("blob/main/LICENSE")

    let version: String
    let build: String

    init(bundle: Bundle = .main) {
        version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
