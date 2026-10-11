import Foundation

struct HomebrewRelease: Codable, Equatable, Sendable {
    let schema: Int
    let version: String
    let build: Int

    var releaseURL: URL { URL(string: "https://github.com/squazaryu/T-DuoBar/releases/tag/v\(version)")! }
    static let tap = "squazaryu/tap/t-duobar"
    static let updateCommand = "brew update && brew upgrade --cask squazaryu/tap/t-duobar"

    static func versionParts(_ version: String) -> [Int]? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, version.count <= 32 else { return nil }
        var result: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(part) else { return nil }
            result.append(value)
        }
        return result
    }

    static func decode(_ data: Data) throws -> HomebrewRelease {
        guard data.count <= 16_384 else { throw UpdateCheckError.invalidManifest }
        let release = try JSONDecoder().decode(Self.self, from: data)
        guard release.schema == 1, release.build > 0, versionParts(release.version) != nil else {
            throw UpdateCheckError.invalidManifest
        }
        return release
    }

    func isNewer(than version: String, build currentBuild: Int) -> Bool {
        guard let target = Self.versionParts(self.version), let current = Self.versionParts(version) else { return false }
        if target != current { return current.lexicographicallyPrecedes(target) }
        return build > currentBuild
    }

    var identifier: String { "\(version):\(build)" }
}

enum UpdateCheckError: Error { case invalidManifest, invalidResponse }

struct WeeklyUpdateSchedule {
    static let interval: TimeInterval = 7 * 24 * 60 * 60
    static let retryInterval: TimeInterval = 6 * 60 * 60

    static func isDue(now: Date, lastSuccess: Date?, lastAttempt: Date?) -> Bool {
        let success = lastSuccess.flatMap { $0 <= now ? $0 : nil }
        let attempt = lastAttempt.flatMap { $0 <= now ? $0 : nil }
        return (success.map { now.timeIntervalSince($0) >= interval } ?? true)
            && (attempt.map { now.timeIntervalSince($0) >= retryInterval } ?? true)
    }
}
