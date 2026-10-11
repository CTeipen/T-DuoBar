import Foundation

protocol HomebrewReleaseFetching: Sendable {
    func fetch() async throws -> HomebrewRelease
}

struct HomebrewReleaseClient: HomebrewReleaseFetching {
    static let manifestURL = URL(string: "https://raw.githubusercontent.com/squazaryu/homebrew-tap/main/updates/t-duobar.json")!
    var session: URLSession = .shared

    func fetch() async throws -> HomebrewRelease {
        var request = URLRequest(url: Self.manifestURL)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200,
              response.url == Self.manifestURL else { throw UpdateCheckError.invalidResponse }
        return try HomebrewRelease.decode(data)
    }
}
