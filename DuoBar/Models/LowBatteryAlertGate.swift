import Foundation

struct LowBatteryAlertGate {
    private var previousPercentage: Int?
    private var hasAlerted = false
    private var previousThreshold: Int?

    mutating func shouldAlert(battery: BatteryStatus, threshold: Int, enabled: Bool) -> Bool {
        let threshold = Self.validatedThreshold(threshold)
        if previousThreshold != threshold || !enabled {
            previousPercentage = nil
            hasAlerted = false
            previousThreshold = threshold
        }
        guard enabled, battery.isAvailable, let percentage = battery.percentage else { return false }
        if battery.isPluggedIn || percentage >= threshold + 5 {
            hasAlerted = false
            previousPercentage = percentage
            return false
        }
        defer { previousPercentage = percentage }
        guard let previousPercentage else { return false }
        guard !hasAlerted, previousPercentage > threshold, percentage <= threshold else { return false }
        hasAlerted = true
        return true
    }

    static func validatedThreshold(_ value: Int) -> Int { [10, 20, 30].contains(value) ? value : 20 }
}
