import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage(PreferenceKeys.language) private var languageRaw = AppLanguage.system.rawValue
    @AppStorage(PreferenceKeys.scrollToAdjustVolume) private var scrollToAdjustVolume = false
    @AppStorage(PreferenceKeys.showBatteryPercentage) private var showBatteryPercentage = true
    @AppStorage(PreferenceKeys.animationsEnabled) private var animationsEnabled = true
    @AppStorage(PreferenceKeys.menuBarIconScale) private var iconScale = MenuBarIconSize.defaultScale
    @AppStorage(PreferenceKeys.batteryColorCoding) private var batteryColorCoding = false
    @AppStorage(PreferenceKeys.showBatteryTime) private var showBatteryTime = true
    @AppStorage(PreferenceKeys.adaptiveRingPriority) private var adaptiveRingPriorityRaw = PerformancePreference.automatic.rawValue
    @AppStorage(PreferenceKeys.adaptiveRingColorCoding) private var adaptiveRingColorCoding = false
    @AppStorage(PreferenceKeys.openOnHover) private var openOnHover = false
    @StateObject private var launchAtLogin = LaunchAtLoginService()
    @ObservedObject private var adaptiveRingMonitor = AdaptiveRingMonitor.shared
    private let deviceContext = DeviceContextService().current()
    #if DEBUG
    @AppStorage(PreferenceKeys.simulateDesktopMac) private var simulateDesktopMac = false
    @State private var showsDiagnostics = false
    #endif

    var body: some View {
        Form {
            Section(localized("Appearance")) {
                Picker(localized("Language"), selection: Binding(
                    get: { (AppLanguage(rawValue: languageRaw) ?? .system).rawValue },
                    set: { languageRaw = $0 })) {
                    ForEach(AppLanguage.allCases) { language in Text(language.name).tag(language.rawValue) }
                }
                Toggle(localized("Show battery percentage in popover"), isOn: $showBatteryPercentage)
                Toggle(localized("Enable animations"), isOn: $animationsEnabled)
                LabeledContent(localized("Icon Size")) {
                    HStack(spacing: 10) {
                        Slider(value: resolvedIconScale, in: MenuBarIconSize.minimumScale...MenuBarIconSize.maximumScale,
                            step: MenuBarIconSize.step)
                            .accessibilityLabel(localized("Menu bar icon size"))
                            .accessibilityValue(localized("%d%%", Int((MenuBarIconSize.resolve(iconScale) * 100).rounded())))
                        Text(localized("%d%%", Int((MenuBarIconSize.resolve(iconScale) * 100).rounded())))
                            .monospacedDigit().foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                    }.frame(width: 220)
                }
            }

            MenuSectionsSettingsView()

            Section(localized("Battery")) {
                Toggle(localized("Show battery time"), isOn: $showBatteryTime)
                if showsBatteryRingSettings {
                    Toggle(localized("Battery Color Coding"), isOn: $batteryColorCoding)
                }
            }

            if showsAdaptiveRingSettings {
                Section(localized("Adaptive Ring")) {
                    Picker(localized("Adaptive Ring Priority"), selection: adaptiveRingPriority) {
                        ForEach(PerformancePreference.allCases, id: \.self) { preference in
                            Text(preference.localizedDisplayName).tag(preference)
                        }
                    }
                    Text(localized("Used only when multiple system conditions need attention. Critical conditions can still take priority."))
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle(localized("Adaptive Ring Color Coding"), isOn: $adaptiveRingColorCoding)
                }
            }

            Section(localized("Behavior")) {
                Toggle(localized("Adjust volume by scrolling over the icon"), isOn: $scrollToAdjustVolume)
                    .help(localized("Scroll up to raise volume, down to lower it. Trackpad momentum is ignored."))
                Toggle(localized("Open on Hover"), isOn: $openOnHover)
                    .help(localized("Open DuoBar when the pointer moves over the menu bar icon."))
                Toggle(localized("Launch DuoBar at login"), isOn: Binding(
                    get: { launchAtLogin.isEnabled }, set: launchAtLogin.setEnabled))
                if launchAtLogin.requiresApproval {
                    Text(localized("Approval is required in System Settings → General → Login Items."))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let error = launchAtLogin.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                }
            }

            #if DEBUG
            if !MarketingCaptureMode.isEnabled {
                Section {
                    DisclosureGroup(localized("Developer diagnostics"), isExpanded: $showsDiagnostics) {
                        if showsDiagnostics {
                            DebugPerformanceDiagnosticsView()
                            DebugDuoGlyphTuningView()
                        }
                    }
                }
            }
            #endif
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .controlSize(.small)
        .onAppear {
            launchAtLogin.refresh()
            if showsAdaptiveRingSettings { adaptiveRingMonitor.setPreference(adaptiveRingPriority.wrappedValue) }
        }
        .onChange(of: adaptiveRingPriorityRaw) { _ in
            if showsAdaptiveRingSettings { adaptiveRingMonitor.setPreference(adaptiveRingPriority.wrappedValue) }
        }
    }

    private var resolvedIconScale: Binding<Double> {
        Binding(get: { MenuBarIconSize.resolve(iconScale) }, set: { iconScale = MenuBarIconSize.resolve($0) })
    }

    private var adaptiveRingPriority: Binding<PerformancePreference> {
        Binding(get: { PerformancePreference(rawValue: adaptiveRingPriorityRaw) ?? .automatic },
            set: { adaptiveRingPriorityRaw = $0.rawValue })
    }

    private var showsAdaptiveRingSettings: Bool {
        #if DEBUG
        AdaptiveRingSettingsEligibility.isEligible(for: deviceContext, simulateDesktop: simulateDesktopMac)
        #else
        AdaptiveRingSettingsEligibility.isEligible(for: deviceContext)
        #endif
    }

    private var showsBatteryRingSettings: Bool {
        #if DEBUG
        !simulateDesktopMac && deviceContext.ringBehavior == .batteryRing
        #else
        deviceContext.ringBehavior == .batteryRing
        #endif
    }
}
