import SwiftUI

struct AccessoryBatterySection: View {
    @ObservedObject var service: AccessoryBatteryService
    var onOpenSettings: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if service.accessories.isEmpty {
                emptyState
            } else {
                connectedAccessories
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                StatusRow(symbol: "keyboard", title: localized("Accessory batteries"),
                    detail: service.isRefreshing ? localized("Reading accessories…")
                        : localized(service.errorMessage == nil ? "No connected accessories" : "Accessory battery data unavailable"),
                    stateText: "", tint: .primary, drawsBackground: false)
                if let onOpenSettings {
                    SystemSettingsButton(title: localized("Bluetooth Settings…"), action: onOpenSettings)
                        .padding(.trailing, 8)
                }
            }
            if service.errorMessage != nil {
                VStack(alignment: .leading, spacing: 6) {
                    Text(localized("Could not read accessory data. Check the Bluetooth connection and try again."))
                        .font(.system(size: 10.5)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(localized("Try again")) { service.refresh(force: true) }
                        .buttonStyle(.link).controlSize(.small).disabled(service.isRefreshing)
                }
                .padding(.horizontal, 10).padding(.bottom, 10)
            }
        }
    }

    private var connectedAccessories: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(localized("Accessory batteries")).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 2)
                if let onOpenSettings {
                    SystemSettingsButton(title: localized("Bluetooth Settings…"), action: onOpenSettings)
                }
            }
            ForEach(service.accessories) { accessory in
                HStack(spacing: 9) {
                    Image(systemName: accessory.symbol).font(.system(size: 16)).frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(accessory.name).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
                        Text(componentSummary(accessory)).font(.system(size: 9.5)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    Text(accessory.percentage.map { localized("%d%%", $0) } ?? "—")
                        .font(.system(size: 10.5, weight: .medium)).monospacedDigit()
                    Image(systemName: accessory.percentage == nil ? "questionmark.circle" : (accessory.percentage ?? 100) < 20 ? "battery.25percent" : "battery.75percent")
                        .foregroundStyle((accessory.percentage ?? 100) < 20 ? Color.red : Color.secondary)
                }.padding(.vertical, 3)
                if accessory.id != service.accessories.last?.id { Divider().opacity(0.4) }
            }
        }.padding(10)
    }

    private func componentSummary(_ item: AccessoryBattery) -> String {
        let values = [("left", "Left"), ("right", "Right"), ("case", "Case")].compactMap { key, title in
            item.levels[key].map { localized(title) + " " + localized("%d%%", $0) }
        }
        if !values.isEmpty { return values.joined(separator: " · ") }
        return item.percentage == nil ? localized("macOS has not reported a battery level.") : localized("Connected")
    }
}
