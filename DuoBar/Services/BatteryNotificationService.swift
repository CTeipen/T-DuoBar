import Combine
import Foundation
import UserNotifications

@MainActor
final class BatteryNotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = BatteryNotificationService()
    @Published private(set) var permissionMessage: String?
    private var gate = LowBatteryAlertGate()

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            permissionMessage = granted ? nil : localized("Allow DuoBar notifications in System Settings.")
            return granted
        } catch {
            permissionMessage = localized("Unable to enable notifications")
            return false
        }
    }

    func update(_ battery: BatteryStatus, defaults: UserDefaults = .standard) {
        let enabled = defaults.bool(forKey: PreferenceKeys.lowBatteryNotificationEnabled)
        let threshold = defaults.integer(forKey: PreferenceKeys.lowBatteryNotificationThreshold)
        guard gate.shouldAlert(battery: battery, threshold: threshold, enabled: enabled) else { return }
        let content = UNMutableNotificationContent()
        content.title = localized("Low battery")
        content.body = localized("battery %d percent", battery.percentage ?? 0)
        if let minutes = battery.remainingTimeMinutes {
            content.body += ". " + localized("Estimated %d minutes of battery remaining", minutes)
        }
        if defaults.bool(forKey: PreferenceKeys.lowBatteryNotificationSound) { content.sound = .default }
        let request = UNNotificationRequest(identifier: "duobar.low-battery", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            guard error != nil else { return }
            Task { @MainActor in self.permissionMessage = localized("Unable to deliver battery notification") }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
