import SwiftUI

@main
struct DuoBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button(localized("About T-DuoBar")) { AboutPanel.show() }
            }
        }
    }
}
