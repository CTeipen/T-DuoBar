import SwiftUI

struct HomebrewUpdateSettingsView: View {
    @AppStorage(PreferenceKeys.weeklyUpdateChecks) private var enabled = true
    @ObservedObject private var service = HomebrewUpdateService.shared

    var body: some View {
        Section(localized("Application updates")) {
            HStack {
                Text(localized("Installed version"))
                Spacer()
                Text(service.installedVersionDescription)
                    .foregroundStyle(.secondary).textSelection(.enabled)
            }
            Toggle(localized("Check for updates weekly"), isOn: $enabled)
                .onChange(of: enabled) { value in if value { service.checkIfDue() } }
            Text(localized("Checks run while DuoBar is open, including after launch or waking your Mac."))
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button(localized("Check for updates now")) {
                    Task { @MainActor in
                        if let result = await service.check(force: true) {
                            service.showCheckResult(result)
                        }
                    }
                }.disabled(service.isChecking)
                if service.isChecking { ProgressView().controlSize(.small) }
            }
            if let message = service.statusMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
            if let date = service.lastChecked {
                HStack { Text(localized("Last checked")); Text(date, style: .date) }
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let update = service.availableUpdate {
                HStack {
                    Text(localized("Available version"))
                    Spacer()
                    Text(service.versionDescription(for: update))
                        .foregroundStyle(.secondary).textSelection(.enabled)
                }
                Button(localized("Install with Homebrew")) { service.offerInstallation() }
                Link(localized("Release notes"), destination: update.releaseURL)
            }
            Text(HomebrewRelease.updateCommand).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
            Button(localized("Copy update command")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(HomebrewRelease.updateCommand, forType: .string)
            }
            Button(localized("Allow update notifications")) {
                Task { @MainActor in _ = await BatteryNotificationService.shared.requestPermission() }
            }
        }
    }
}
