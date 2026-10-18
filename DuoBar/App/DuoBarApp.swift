import SwiftUI

@main
struct DuoBarApp: App {
    @AppStorage(PreferenceKeys.language) private var languageRaw = AppLanguage.system.rawValue
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(localized("About T-DuoBar")) { AboutPanel.show() }
                    .id(languageRaw)
            }
        }
    }
}
