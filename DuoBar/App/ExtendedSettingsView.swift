import SwiftUI

struct ExtendedSettingsView: View {
    @AppStorage(PreferenceKeys.showNetwork) private var network = true
    @AppStorage(PreferenceKeys.showVolume) private var volume = true
    @AppStorage(PreferenceKeys.showBattery) private var battery = true
    @AppStorage(PreferenceKeys.showAccessories) private var accessories = true
    @AppStorage(PreferenceKeys.showAudioOutput) private var output = true
    @AppStorage(PreferenceKeys.showMicrophone) private var input = false
    @AppStorage(PreferenceKeys.showBatteryTime) private var batteryTime = true
    @AppStorage(PreferenceKeys.lowBatteryNotificationEnabled) private var notifications = false
    @AppStorage(PreferenceKeys.lowBatteryNotificationThreshold) private var threshold = 20
    @AppStorage(PreferenceKeys.lowBatteryNotificationSound) private var sound = false
    @State private var requestingPermission = false
    @ObservedObject private var notificationService = BatteryNotificationService.shared

    var body: some View {
        Section(localized("Menu sections")) {
            Toggle(localized("Network"), isOn: $network)
            Toggle(localized("Volume"), isOn: $volume)
            Toggle(localized("Battery"), isOn: $battery)
            Toggle(localized("Accessory batteries"), isOn: $accessories)
            Toggle(localized("Audio Output"), isOn: $output)
            Toggle(localized("Microphone"), isOn: $input)
            Toggle(localized("Show battery time"), isOn: $batteryTime)
        }
        Section(localized("Notifications")) {
            Toggle(localized("Low battery"), isOn: Binding(
                get: { notifications },
                set: { enabled in
                    guard enabled else { notifications = false; return }
                    requestingPermission = true
                    Task { @MainActor in
                        notifications = await notificationService.requestPermission()
                        requestingPermission = false
                    }
                }
            )).disabled(requestingPermission)
            if notifications {
                Picker(localized("Battery threshold"), selection: $threshold) {
                    ForEach([10, 20, 30], id: \.self) { value in
                        Text(localized("%d%%", value)).tag(value)
                    }
                }
                Toggle(localized("Notification sound"), isOn: $sound)
            }
            Text(localized("One alert when battery crosses the threshold."))
                .font(.caption).foregroundStyle(.secondary)
            if let message = notificationService.permissionMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
                Button(localized("Notification Settings…")) {
                    guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}
