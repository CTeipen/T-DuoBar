import AppKit
import Combine
import Foundation
import UserNotifications

@MainActor
final class HomebrewUpdateService: ObservableObject {
    static let shared = HomebrewUpdateService()
    nonisolated static let notificationCategory = "TDB_UPDATE_AVAILABLE"
    nonisolated static let installAction = "TDB_INSTALL_HOMEBREW"
    @Published private(set) var availableUpdate: HomebrewRelease?
    @Published private(set) var isChecking = false
    private enum MessageState { case check(HomebrewUpdateCheckResult), installFailed }
    @Published private var messageState: MessageState?
    @Published private(set) var lastChecked: Date?

    private let client: any HomebrewReleaseFetching
    private let defaults: UserDefaults
    private let currentVersion: String
    private let currentBuild: Int
    private let now: () -> Date
    private let notify: (HomebrewRelease) async -> Bool
    private var timer: Timer?

    var installedVersionDescription: String {
        Self.versionDescription(currentVersion, build: currentBuild)
    }

    var statusMessage: String? {
        switch messageState {
        case .check(.updateAvailable(let update)):
            localized("Installed: %@. Update available: %@.", installedVersionDescription, versionDescription(for: update))
        case .check(.upToDate): localized("DuoBar %@ is up to date", installedVersionDescription)
        case .check(.failed): localized("Update check failed. Will retry later.")
        case .installFailed: localized("Unable to start Homebrew. Use the update command below.")
        case nil: nil
        }
    }

    func versionDescription(for release: HomebrewRelease) -> String {
        Self.versionDescription(release.version, build: release.build)
    }

    private static func versionDescription(_ version: String, build: Int) -> String {
        localized("%@ (build %d)", version, build)
    }

    init(client: any HomebrewReleaseFetching = HomebrewReleaseClient(), defaults: UserDefaults = .standard,
         currentVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0",
         currentBuild: Int = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0") ?? 0,
         now: @escaping () -> Date = Date.init,
         notify: ((HomebrewRelease) async -> Bool)? = nil) {
        self.client = client
        self.defaults = defaults
        self.currentVersion = currentVersion
        self.currentBuild = currentBuild
        self.now = now
        self.notify = notify ?? { update in
            await Self.sendNotification(update, currentVersion: currentVersion, currentBuild: currentBuild)
        }
        lastChecked = defaults.object(forKey: PreferenceKeys.lastUpdateCheck) as? Date
        if let data = defaults.data(forKey: PreferenceKeys.cachedHomebrewRelease),
           let cached = try? HomebrewRelease.decode(data), cached.isNewer(than: currentVersion, build: currentBuild) {
            availableUpdate = cached
        }
    }

    func start() {
        guard timer == nil else { return }
        registerNotificationCategory()
        let timer = Timer(timeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
        timer.tolerance = 60
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        checkIfDue()
    }

    func refreshNotificationLanguage() {
        guard timer != nil else { return }
        registerNotificationCategory()
    }

    private func registerNotificationCategory() {
        let install = UNNotificationAction(identifier: Self.installAction, title: localized("Install with Homebrew"), options: .foreground)
        let category = UNNotificationCategory(identifier: Self.notificationCategory, actions: [install], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    func checkIfDue() { Task { await check() } }

    @discardableResult
    func check(force: Bool = false) async -> HomebrewUpdateCheckResult? {
        guard !isChecking else { return nil }
        let enabled = defaults.object(forKey: PreferenceKeys.weeklyUpdateChecks) as? Bool ?? true
        let date = now()
        guard force || (enabled && WeeklyUpdateSchedule.isDue(now: date,
            lastSuccess: defaults.object(forKey: PreferenceKeys.lastUpdateCheck) as? Date,
            lastAttempt: defaults.object(forKey: PreferenceKeys.lastUpdateAttempt) as? Date)) else { return nil }
        isChecking = true
        defaults.set(date, forKey: PreferenceKeys.lastUpdateAttempt)
        defer { isChecking = false }
        do {
            let release = try await client.fetch()
            defaults.set(date, forKey: PreferenceKeys.lastUpdateCheck)
            defaults.set(try JSONEncoder().encode(release), forKey: PreferenceKeys.cachedHomebrewRelease)
            lastChecked = date
            availableUpdate = release.isNewer(than: currentVersion, build: currentBuild) ? release : nil
            messageState = .check(availableUpdate.map(HomebrewUpdateCheckResult.updateAvailable) ?? .upToDate)
            let stillEnabled = defaults.object(forKey: PreferenceKeys.weeklyUpdateChecks) as? Bool ?? true
            if !force, stillEnabled, let update = availableUpdate,
               defaults.string(forKey: PreferenceKeys.lastNotifiedUpdate) != update.identifier,
               await notify(update) {
                defaults.set(update.identifier, forKey: PreferenceKeys.lastNotifiedUpdate)
            }
            return availableUpdate.map(HomebrewUpdateCheckResult.updateAvailable) ?? .upToDate
        } catch {
            messageState = .check(.failed)
            return .failed
        }
    }

    func offerInstallation() {
        guard let update = availableUpdate else { return }
        showCheckResult(.updateAvailable(update))
    }

    func checkManually() async {
        if let result = await check(force: true) { showCheckResult(result) }
    }

    func showCheckResult(_ result: HomebrewUpdateCheckResult) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = makeCheckResultAlert(result)
        let response = alert.runModal()
        if case .updateAvailable = result, response == .alertFirstButtonReturn { installUpdate() }
    }

    func makeCheckResultAlert(_ result: HomebrewUpdateCheckResult) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .informational
        let installed = localized("Installed DuoBar version: %@", installedVersionDescription)
        switch result {
        case .updateAvailable(let update):
            alert.messageText = localized("Update available: %@", versionDescription(for: update))
            alert.informativeText = installed + "\n\n" + localized("Terminal will update DuoBar with Homebrew and restart it. No other packages are upgraded.")
            alert.addButton(withTitle: localized("Install with Homebrew"))
            alert.addButton(withTitle: localized("Later"))
        case .upToDate:
            alert.messageText = localized("DuoBar %@ is up to date", installedVersionDescription)
            alert.informativeText = localized("No updates are available.")
            alert.addButton(withTitle: localized("OK"))
        case .failed:
            alert.alertStyle = .warning
            alert.messageText = localized("Unable to check for updates")
            alert.informativeText = installed + "\n\n" + localized("Check your internet connection and try again.")
            alert.addButton(withTitle: localized("OK"))
        }
        return alert
    }

    func installUpdate() {
        do {
            guard let source = Bundle.main.url(forResource: "UpdateWithHomebrew", withExtension: "command") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true).appendingPathComponent("T-DuoBar/Updater", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let script = directory.appendingPathComponent("UpdateWithHomebrew.command")
            try Data(contentsOf: source).write(to: script, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
            let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            NSWorkspace.shared.open([script], withApplicationAt: terminal, configuration: .init()) { _, error in
                guard error != nil else { return }
                Task { @MainActor in
                    self.messageState = .installFailed
                }
            }
        } catch { messageState = .installFailed }
    }

    static func makeUpdateNotificationContent(_ update: HomebrewRelease, currentVersion: String,
        currentBuild: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = localized("DuoBar update available")
        content.body = localized("Installed: %@. Update available: %@.",
            versionDescription(currentVersion, build: currentBuild), versionDescription(update.version, build: update.build))
        content.categoryIdentifier = notificationCategory
        content.userInfo = ["homebrewUpdate": true]
        return content
    }

    private static func sendNotification(_ update: HomebrewRelease, currentVersion: String,
        currentBuild: Int) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            guard await BatteryNotificationService.shared.requestPermission() else { return false }
        } else if settings.authorizationStatus == .denied { return false }
        let content = makeUpdateNotificationContent(update, currentVersion: currentVersion, currentBuild: currentBuild)
        do {
            try await center.add(UNNotificationRequest(identifier: "duobar.update", content: content, trigger: nil))
            return true
        } catch { return false }
    }

    deinit { timer?.invalidate() }
}
