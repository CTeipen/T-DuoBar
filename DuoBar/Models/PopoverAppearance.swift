import Foundation

enum PopoverStyle: String, CaseIterable, Identifiable {
    case classic
    case liquidGlass

    var id: String { rawValue }

    var title: String {
        localized(self == .classic ? "Classic" : "Liquid Glass")
    }

    static var supportsLiquidGlass: Bool {
        if #available(macOS 26.0, *) { return true }
        return false
    }
}

struct PopoverAppearance: Equatable {
    static let defaultTransparency = 0.65

    let style: PopoverStyle
    let transparency: Double

    init(styleRaw: String?, transparency: Double = defaultTransparency) {
        style = styleRaw.flatMap(PopoverStyle.init(rawValue:)) ?? .classic
        self.transparency = Self.resolveTransparency(transparency)
    }

    init(defaults: UserDefaults) {
        self.init(styleRaw: defaults.string(forKey: PreferenceKeys.popoverStyle),
            transparency: (defaults.object(forKey: PreferenceKeys.popoverTransparency) as? NSNumber)?.doubleValue
                ?? Self.defaultTransparency)
    }

    static func resolveTransparency(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 1) : defaultTransparency
    }

    func backgroundOpacity(supportsLiquidGlass: Bool, reduceTransparency: Bool) -> Double {
        guard usesLiquidGlass(supportsLiquidGlass: supportsLiquidGlass, reduceTransparency: reduceTransparency) else { return 1 }
        return 1 - transparency
    }

    func usesLiquidGlass(supportsLiquidGlass: Bool, reduceTransparency: Bool) -> Bool {
        style == .liquidGlass && supportsLiquidGlass && !reduceTransparency
    }
}
