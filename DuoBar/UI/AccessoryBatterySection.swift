import SwiftUI

struct AccessoryBatterySection: View {
    @ObservedObject var service: AccessoryBatteryService
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(localized("Accessory batteries")).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            if service.accessories.isEmpty {
                Text(service.isRefreshing ? localized("Reading accessories…") : service.errorMessage ?? localized("No connected accessories"))
                    .font(.system(size: 10.5)).foregroundStyle(.secondary)
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
        }.frame(maxWidth: .infinity, alignment: .leading).padding(10)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11))
            .onAppear { service.start() }
            .onDisappear { service.stop() }
    }

    private func componentSummary(_ item: AccessoryBattery) -> String {
        let values = [("left", "Left"), ("right", "Right"), ("case", "Case")].compactMap { key, title in
            item.levels[key].map { localized(title) + " " + localized("%d%%", $0) }
        }
        if !values.isEmpty { return values.joined(separator: " · ") }
        return item.percentage == nil ? localized("Battery reading unavailable") : localized("Connected")
    }
}
