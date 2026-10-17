import Foundation

enum StatusTooltip {
    static func text(battery: BatteryStatus, hasInternalBattery: Bool, showsRemainingTime: Bool = true) -> String {
        guard battery.isAvailable else {
            return hasInternalBattery
                ? AppIdentity.name + "\n" + localized("Battery data unavailable")
                : AppIdentity.name
        }
        var lines = [AppIdentity.name]
        if let percentage = battery.percentage {
            lines.append(localized("Battery: %d%%", percentage) + " · " + battery.powerStateDescription)
        } else {
            lines.append(localized("Battery") + " · " + battery.powerStateDescription)
        }
        if showsRemainingTime, let estimate = battery.remainingTimeDescription {
            lines.append(estimate)
        }
        return lines.joined(separator: "\n")
    }
}
