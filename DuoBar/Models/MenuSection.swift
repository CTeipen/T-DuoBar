import Foundation

enum MenuSection: String, CaseIterable, Identifiable {
    case network, vpn, volume, battery, accessories, audioOutput, microphone

    var id: String { rawValue }

    var title: String {
        switch self {
        case .network: localized("Network")
        case .vpn: localized("VPN")
        case .volume: localized("Volume")
        case .battery: localized("Battery")
        case .accessories: localized("Accessory batteries")
        case .audioOutput: localized("Audio Output")
        case .microphone: localized("Microphone")
        }
    }

    var visibilityKey: String {
        switch self {
        case .network: PreferenceKeys.showNetwork
        case .vpn: PreferenceKeys.showVPN
        case .volume: PreferenceKeys.showVolume
        case .battery: PreferenceKeys.showBattery
        case .accessories: PreferenceKeys.showAccessories
        case .audioOutput: PreferenceKeys.showAudioOutput
        case .microphone: PreferenceKeys.showMicrophone
        }
    }

    var defaultVisibility: Bool { self != .microphone }

    var dragIdentifier: String { "com.mikeli.duobar.menu-section.\(rawValue)" }

    init?(dragIdentifier: String) {
        let prefix = "com.mikeli.duobar.menu-section."
        guard dragIdentifier.hasPrefix(prefix) else { return nil }
        self.init(rawValue: String(dragIdentifier.dropFirst(prefix.count)))
    }
}

enum MenuSectionOrder {
    static let defaultValue = encode(MenuSection.allCases)

    /// Keep known IDs once and recover new or missing sections without losing
    /// the relative order stored by older or newer builds.
    static func decode(_ rawValue: String) -> [MenuSection] {
        let ids = (try? JSONDecoder().decode([String].self, from: Data(rawValue.utf8))) ?? []
        return normalized(ids.compactMap(MenuSection.init(rawValue:)))
    }

    static func encode(_ sections: [MenuSection]) -> String {
        let data = try? JSONEncoder().encode(normalized(sections).map(\.rawValue))
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    static func moving(_ section: MenuSection, to target: MenuSection, in sections: [MenuSection]) -> [MenuSection] {
        var result = normalized(sections)
        guard let source = result.firstIndex(of: section), let destination = result.firstIndex(of: target),
              source != destination else { return result }
        result.remove(at: source)
        result.insert(section, at: destination)
        return result
    }

    private static func normalized(_ sections: [MenuSection]) -> [MenuSection] {
        var seen = Set<MenuSection>()
        var result = sections.filter { seen.insert($0).inserted }
        // Older preferences contain no VPN section. Place it beside Network
        // while preserving the relative order of all existing sections.
        if !seen.contains(.vpn), let networkIndex = result.firstIndex(of: .network) {
            result.insert(.vpn, at: networkIndex + 1)
            seen.insert(.vpn)
        }
        result.append(contentsOf: MenuSection.allCases.filter { seen.insert($0).inserted })
        return result
    }
}
