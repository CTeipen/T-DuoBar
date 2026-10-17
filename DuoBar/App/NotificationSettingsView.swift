import SwiftUI

struct NotificationSettingsView: View {
    @AppStorage(PreferenceKeys.lowBatteryNotificationEnabled) private var enabled = false
    @AppStorage(PreferenceKeys.lowBatteryNotificationThreshold) private var threshold = 20
    @AppStorage(PreferenceKeys.lowBatteryNotificationSound) private var sound = false
    @State private var requestingPermission = false
    @ObservedObject private var service = BatteryNotificationService.shared

    var body: some View {
        Form {
            Section(localized("Low battery")) {
                Toggle(localized("Low battery"), isOn: Binding(
                    get: { enabled },
                    set: { value in
                        guard value else { enabled = false; return }
                        requestingPermission = true
                        Task { @MainActor in
                            enabled = await service.requestPermission()
                            requestingPermission = false
                        }
                    }
                )).disabled(requestingPermission)
                if enabled {
                    Picker(localized("Battery threshold"), selection: $threshold) {
                        ForEach([10, 20, 30], id: \.self) { value in
                            Text(localized("%d%%", value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    Toggle(localized("Notification sound"), isOn: $sound)
                }
                Text(localized("One alert when battery crosses the threshold."))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section(localized("Notification access")) {
                Text(localized("Allow DuoBar notifications in System Settings."))
                    .font(.callout).foregroundStyle(.secondary)
                Button(localized("Notification Settings…")) {
                    guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
                    NSWorkspace.shared.open(url)
                }
                if let message = service.permissionMessage {
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .controlSize(.small)
    }
}
