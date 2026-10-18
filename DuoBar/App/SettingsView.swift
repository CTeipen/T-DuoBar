import SwiftUI

struct SettingsView: View {
    var onPreviewPopover: (() -> Void)? = nil
    private enum Tab: Hashable { case general, notifications, updates }
    @State private var selectedTab: Tab = .general
    @AppStorage(PreferenceKeys.language) private var languageRaw = AppLanguage.system.rawValue
    private let identity = AppIdentity()

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                GeneralSettingsView(onPreviewPopover: onPreviewPopover)
                    .tabItem { Label(localized("General"), systemImage: "gearshape") }
                    .tag(Tab.general)
                NotificationSettingsView()
                    .tabItem { Label(localized("Notifications"), systemImage: "bell") }
                    .tag(Tab.notifications)
                Form { HomebrewUpdateSettingsView() }
                    .formStyle(.grouped)
                    .controlSize(.small)
                    .tabItem { Label(localized("Updates"), systemImage: "arrow.triangle.2.circlepath") }
                    .tag(Tab.updates)
            }
            .id(languageRaw)
            Divider()
            HStack {
                Text("\(AppIdentity.name) \(identity.version) (\(identity.build))")
                    .foregroundStyle(.secondary)
                Spacer()
                Button(localized("About T-DuoBar")) { AboutPanel.show() }
                    .buttonStyle(.link)
            }
            .font(.caption)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .frame(width: 560, height: 630)
        .navigationTitle(localized("T-DuoBar Settings"))
        .environment(\.locale, (AppLanguage(rawValue: languageRaw) ?? .system).locale)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}
