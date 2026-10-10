enum PreferenceKeys {
    static let showBatteryPercentage = "showBatteryPercentage"
    static let animationsEnabled = "animationsEnabled"
    static let menuBarIconScale = MenuBarIconSize.preferenceKey
    static let batteryColorCoding = "batteryColorCoding"
    static let adaptiveRingPriority = "adaptiveRingPriority"
    static let adaptiveRingColorCoding = "adaptiveRingColorCoding"
    static let openOnHover = "duoBar.openOnHover"

    static let showNetwork = "menu.showNetwork"
    static let showVolume = "menu.showVolume"
    static let showBattery = "menu.showBattery"
    static let showAccessories = "menu.showAccessories"
    static let showAudioOutput = "menu.showAudioOutput"
    static let showMicrophone = "menu.showMicrophone"
    static let showBatteryTime = "menu.showBatteryTime"
    static let favoriteOutputUIDs = "audio.favoriteOutputUIDs"
    static let lowBatteryNotificationEnabled = "battery.notificationEnabled"
    static let lowBatteryNotificationThreshold = "battery.notificationThreshold"
    static let lowBatteryNotificationSound = "battery.notificationSound"

    #if DEBUG
    static let simulateDesktopMac = "debug.simulateDesktopMac"
    #endif
}
