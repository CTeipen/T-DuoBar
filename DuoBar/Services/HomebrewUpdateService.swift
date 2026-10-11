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
    @Published private(set) var statusMessage: String?
    @Published private(set) var lastChecked: Date?

    private let client: any HomebrewReleaseFetching
    private let defaults: UserDefaults
    private let currentVersion: String
    private let currentBuild: Int
    private let now: () -> Date
    private let notify: (HomebrewRelease) async -> Bool
    private var timer: Timer?

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
        self.notify = notify ?? Self.sendNotification
        lastChecked = defaults.object(forKey: PreferenceKeys.lastUpdateCheck) as? Date
        if let data = defaults.data(forKey: PreferenceKeys.cachedHomebrewRelease),
           let cached = try? HomebrewRelease.decode(data), cached.isNewer(than: currentVersion, build: currentBuild) {
            availableUpdate = cached
        }
    }

    func start() {
        guard timer == nil else { return }
        let install = UNNotificationAction(identifier: Self.installAction, title: localized("Install with Homebrew"), options: .foreground)
        let category = UNNotificationCategory(identifier: Self.notificationCategory, actions: [install], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
        let timer = Timer(timeInterval: 60 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        checkIfDue()
    }

    func checkIfDue() { Task { await check() } }

    func check(force: Bool = false) async {
        guard !isChecking else { return }
        let enabled = defaults.object(forKey: PreferenceKeys.weeklyUpdateChecks) as? Bool ?? true
        let date = now()
        guard force || (enabled && WeeklyUpdateSchedule.isDue(now: date,
            lastSuccess: defaults.object(forKey: PreferenceKeys.lastUpdateCheck) as? Date,
            lastAttempt: defaults.object(forKey: PreferenceKeys.lastUpdateAttempt) as? Date)) else { return }
        isChecking = true
        defaults.set(date, forKey: PreferenceKeys.lastUpdateAttempt)
        defer { isChecking = false }
        do {
            let release = try await client.fetch()
            defaults.set(date, forKey: PreferenceKeys.lastUpdateCheck)
            defaults.set(try JSONEncoder().encode(release), forKey: PreferenceKeys.cachedHomebrewRelease)
            lastChecked = date
            availableUpdate = release.isNewer(than: currentVersion, build: currentBuild) ? release : nil
            statusMessage = availableUpdate == nil ? localized("You have the latest version") : localized("Update available: %@", release.version)
            let stillEnabled = defaults.object(forKey: PreferenceKeys.weeklyUpdateChecks) as? Bool ?? true
            if !force, stillEnabled, let update = availableUpdate,
               defaults.string(forKey: PreferenceKeys.lastNotifiedUpdate) != update.identifier,
               await notify(update) {
                defaults.set(update.identifier, forKey: PreferenceKeys.lastNotifiedUpdate)
            }
        } catch {
            statusMessage = localized("Update check failed. Will retry later.")
        }
    }

    func offerInstallation() {
        guard let update = availableUpdate else { return }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = localized("Update available: %@", update.version)
        alert.informativeText = localized("Terminal will update DuoBar with Homebrew and restart it. No other packages are upgraded.")
        alert.addButton(withTitle: localized("Install with Homebrew"))
        alert.addButton(withTitle: localized("Later"))
        if alert.runModal() == .alertFirstButtonReturn { installUpdate() }
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
                    self.statusMessage = localized("Unable to start Homebrew. Use the update command below.")
                }
            }
        } catch { statusMessage = localized("Unable to start Homebrew. Use the update command below.") }
    }

    private static func sendNotification(_ update: HomebrewRelease) async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            guard await BatteryNotificationService.shared.requestPermission() else { return false }
        } else if settings.authorizationStatus == .denied { return false }
        let content = UNMutableNotificationContent()
        content.title = localized("DuoBar update available")
        content.body = localized("Version %@ is ready to install with Homebrew.", update.version)
        content.categoryIdentifier = notificationCategory
        content.userInfo = ["homebrewUpdate": true]
        do {
            try await center.add(UNNotificationRequest(identifier: "duobar.update", content: content, trigger: nil))
            return true
        } catch { return false }
    }

    deinit { timer?.invalidate() }
}
