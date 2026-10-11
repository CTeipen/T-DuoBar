import Foundation
import XCTest
@testable import DuoBar

private actor StubReleaseClient: HomebrewReleaseFetching {
    var release: HomebrewRelease
    var fail = false
    private var count = 0
    init(_ release: HomebrewRelease) { self.release = release }
    func fetch() async throws -> HomebrewRelease {
        count += 1
        if fail { throw UpdateCheckError.invalidResponse }
        return release
    }
    func setFailure() { fail = true }
    func setRelease(_ value: HomebrewRelease) { release = value }
    func requests() -> Int { count }
}

final class HomebrewUpdateTests: XCTestCase {
    func testVersionComparisonUsesNumbersAndBuildNumbers() {
        XCTAssertTrue(HomebrewRelease(schema: 1, version: "1.10.0", build: 1).isNewer(than: "1.9.0", build: 8))
        XCTAssertTrue(HomebrewRelease(schema: 1, version: "1.6.0", build: 10).isNewer(than: "1.6.0", build: 9))
        XCTAssertFalse(HomebrewRelease(schema: 1, version: "1.6.0", build: 9).isNewer(than: "1.6.0", build: 9))
        XCTAssertFalse(HomebrewRelease(schema: 1, version: "1.5.0", build: 50).isNewer(than: "1.6.0", build: 9))
    }

    func testManifestRejectsUntrustedAndInvalidVersionData() throws {
        let valid = Data(#"{"schema":1,"version":"1.6.0","build":9}"#.utf8)
        XCTAssertEqual(try HomebrewRelease.decode(valid).releaseURL.absoluteString,
            "https://github.com/squazaryu/T-DuoBar/releases/tag/v1.6.0")
        for version in ["../other", "1.6", "1.6.0;rm", "-1.6.0", "1.6.0-beta", "١.٦.٠"] {
            let data = try JSONSerialization.data(withJSONObject: ["schema": 1, "version": version, "build": 9])
            XCTAssertThrowsError(try HomebrewRelease.decode(data))
        }
        XCTAssertThrowsError(try HomebrewRelease.decode(Data(#"{"schema":2,"version":"1.6.0","build":9}"#.utf8)))
        XCTAssertThrowsError(try HomebrewRelease.decode(Data(#"{"schema":1,"version":"1.6.0","build":0}"#.utf8)))
        XCTAssertThrowsError(try HomebrewRelease.decode(Data(repeating: 32, count: 16_385)))
    }

    func testWeeklyScheduleAndFailureBackoff() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        XCTAssertTrue(WeeklyUpdateSchedule.isDue(now: now, lastSuccess: nil, lastAttempt: nil))
        XCTAssertFalse(WeeklyUpdateSchedule.isDue(now: now, lastSuccess: now.addingTimeInterval(-6 * 86400), lastAttempt: nil))
        XCTAssertFalse(WeeklyUpdateSchedule.isDue(now: now, lastSuccess: now.addingTimeInterval(-8 * 86400), lastAttempt: now.addingTimeInterval(-60)))
        XCTAssertTrue(WeeklyUpdateSchedule.isDue(now: now, lastSuccess: now.addingTimeInterval(-7 * 86400), lastAttempt: now.addingTimeInterval(-7 * 86400)))
        XCTAssertTrue(WeeklyUpdateSchedule.isDue(now: now, lastSuccess: now.addingTimeInterval(1), lastAttempt: now.addingTimeInterval(1)))
    }

    @MainActor
    func testSuccessfulWeeklyChecksPersistAndNotifyOncePerRelease() async throws {
        let suite = "HomebrewUpdateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var date = Date(timeIntervalSince1970: 2_000_000)
        let client = StubReleaseClient(HomebrewRelease(schema: 1, version: "1.7.0", build: 10))
        var notifications: [String] = []
        let service = HomebrewUpdateService(client: client, defaults: defaults,
            currentVersion: "1.6.0", currentBuild: 9, now: { date }, notify: { release in
                notifications.append(release.identifier)
                return true
            })
        await service.check()
        XCTAssertEqual(service.availableUpdate?.version, "1.7.0")
        XCTAssertEqual(notifications, ["1.7.0:10"])
        await service.check()
        let firstCount = await client.requests()
        XCTAssertEqual(firstCount, 1)
        date = date.addingTimeInterval(WeeklyUpdateSchedule.interval)
        await service.check()
        XCTAssertEqual(notifications.count, 1)
        let restored = HomebrewUpdateService(client: client, defaults: defaults, currentVersion: "1.6.0", currentBuild: 9,
            now: { date }, notify: { _ in false })
        XCTAssertEqual(restored.availableUpdate?.version, "1.7.0")
        await client.setRelease(HomebrewRelease(schema: 1, version: "1.7.1", build: 11))
        date = date.addingTimeInterval(WeeklyUpdateSchedule.interval)
        await service.check()
        XCTAssertEqual(notifications, ["1.7.0:10", "1.7.1:11"])
    }

    @MainActor
    func testDisabledChecksAndManualChecksDoNotNotify() async throws {
        let suite = "HomebrewUpdateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(false, forKey: PreferenceKeys.weeklyUpdateChecks)
        let client = StubReleaseClient(HomebrewRelease(schema: 1, version: "1.7.0", build: 10))
        var notified = false
        let service = HomebrewUpdateService(client: client, defaults: defaults, currentVersion: "1.6.0", currentBuild: 9,
            notify: { _ in notified = true; return true })
        await service.check()
        let before = await client.requests()
        XCTAssertEqual(before, 0)
        let result = await service.check(force: true)
        XCTAssertEqual(result, .updateAvailable(HomebrewRelease(schema: 1, version: "1.7.0", build: 10)))
        XCTAssertNotNil(service.availableUpdate)
        XCTAssertFalse(notified)
    }

    @MainActor
    func testManualCheckReportsUpToDateForEqualOrOlderRelease() async throws {
        let suite = "HomebrewUpdateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let client = StubReleaseClient(HomebrewRelease(schema: 1, version: "1.6.0", build: 9))
        let service = HomebrewUpdateService(client: client, defaults: defaults,
            currentVersion: "1.6.0", currentBuild: 9, notify: { _ in
                XCTFail("Manual checks must not send automatic notifications")
                return false
            })
        let equalResult = await service.check(force: true)
        XCTAssertEqual(equalResult, .upToDate)
        XCTAssertNil(service.availableUpdate)
        await client.setRelease(HomebrewRelease(schema: 1, version: "1.5.0", build: 8))
        let olderResult = await service.check(force: true)
        XCTAssertEqual(olderResult, .upToDate)
        XCTAssertNil(service.availableUpdate)
    }

    @MainActor
    func testFailedManualCheckDoesNotOfferCachedUpdateAsSuccessfulResult() async throws {
        let suite = "HomebrewUpdateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let cached = HomebrewRelease(schema: 1, version: "1.7.0", build: 10)
        defaults.set(try JSONEncoder().encode(cached), forKey: PreferenceKeys.cachedHomebrewRelease)
        let client = StubReleaseClient(cached)
        await client.setFailure()
        let service = HomebrewUpdateService(client: client, defaults: defaults,
            currentVersion: "1.6.0", currentBuild: 9, notify: { _ in false })
        XCTAssertEqual(service.availableUpdate, cached)
        let result = await service.check(force: true)
        XCTAssertEqual(result, .failed)
        XCTAssertNil(service.lastChecked)
        XCTAssertFalse(service.isChecking)
    }

    @MainActor
    func testDialogsIdentifyInstalledVersionAndUpdateTarget() async throws {
        let suite = "HomebrewUpdateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let update = HomebrewRelease(schema: 1, version: "1.7.0", build: 12)
        let service = HomebrewUpdateService(client: StubReleaseClient(update), defaults: defaults,
            currentVersion: "1.6.1", currentBuild: 11, notify: { _ in false })
        XCTAssertTrue(service.installedVersionDescription.contains("1.6.1"))
        XCTAssertTrue(service.installedVersionDescription.contains("11"))
        let checked = await service.check(force: true)
        let result = try XCTUnwrap(checked)
        let prompt = service.makeCheckResultAlert(result)
        XCTAssertTrue(prompt.messageText.contains("1.7.0"))
        XCTAssertTrue(prompt.messageText.contains("12"))
        XCTAssertTrue(prompt.informativeText.contains(service.installedVersionDescription))
        let latest = service.makeCheckResultAlert(.upToDate)
        XCTAssertTrue(latest.messageText.contains(service.installedVersionDescription))
        let failure = service.makeCheckResultAlert(.failed)
        XCTAssertTrue(failure.informativeText.contains(service.installedVersionDescription))
    }

    @MainActor
    func testNotificationIdentifiesSameVersionBuildUpdate() {
        let update = HomebrewRelease(schema: 1, version: "1.6.1", build: 12)
        let content = HomebrewUpdateService.makeUpdateNotificationContent(update,
            currentVersion: "1.6.1", currentBuild: 11)
        XCTAssertTrue(content.body.contains("1.6.1"))
        XCTAssertTrue(content.body.contains("11"), "Installed build must be identified")
        XCTAssertTrue(content.body.contains("12"), "Target build must be identified")
        XCTAssertEqual(content.categoryIdentifier, HomebrewUpdateService.notificationCategory)
    }

    @MainActor
    func testFailedRequestDoesNotConsumeAWeek() async throws {
        let suite = "HomebrewUpdateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var date = Date(timeIntervalSince1970: 2_000_000)
        let client = StubReleaseClient(HomebrewRelease(schema: 1, version: "1.6.0", build: 9))
        await client.setFailure()
        let service = HomebrewUpdateService(client: client, defaults: defaults, now: { date }, notify: { _ in false })
        await service.check()
        XCTAssertNil(service.lastChecked)
        await service.check()
        let blocked = await client.requests()
        XCTAssertEqual(blocked, 1)
        date = date.addingTimeInterval(WeeklyUpdateSchedule.retryInterval)
        await service.check()
        let retried = await client.requests()
        XCTAssertEqual(retried, 2)
    }

    func testUpdateScriptIsBundledAndUsesOnlyFixedHomebrewCommands() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "UpdateWithHomebrew", withExtension: "command"))
        let script = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(script.contains("squazaryu/tap/t-duobar"))
        XCTAssertTrue(script.contains("upgrade --cask --no-ask"))
        XCTAssertFalse(script.contains("--no-quarantine"))
        XCTAssertFalse(script.contains("curl"))
    }
}
