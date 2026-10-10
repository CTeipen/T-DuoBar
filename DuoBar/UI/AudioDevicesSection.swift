import SwiftUI

struct AudioDevicesSection: View {
    let title: String
    let symbol: String
    let devices: [AudioDeviceStatus]
    let selectedUID: String?
    var allowsFavorites = false
    let onSelect: (String) -> Bool
    let onOpenSettings: () -> Void
    @AppStorage(PreferenceKeys.favoriteOutputUIDs) private var favoriteRaw = "[]"
    @State private var errorMessage: String?

    private var favorites: Set<String> { AudioFavorites.decode(favoriteRaw) }
    private var ordered: [AudioDeviceStatus] {
        devices.sorted {
            let left = allowsFavorites && favorites.contains($0.uid)
            let right = allowsFavorites && favorites.contains($1.uid)
            if left != right { return left }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var body: some View {
        StatusDetailSection {
            StatusRow(symbol: symbol, title: localized(title),
                detail: devices.first(where: { $0.uid == selectedUID })?.name ?? localized("Unavailable"),
                stateText: "", tint: .primary, accessory: .disclosure)
        } content: {
            if ordered.isEmpty { Text(localized("No audio devices")).foregroundStyle(.secondary) }
            ForEach(ordered) { device in
                HStack(spacing: 6) {
                    Button {
                        errorMessage = onSelect(device.uid) ? nil : localized("Unable to select audio device")
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: device.uid == selectedUID ? "checkmark" : "")
                                .frame(width: 12)
                            Text(device.name).lineLimit(2)
                            Spacer(minLength: 0)
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    if allowsFavorites {
                        Button {
                            var values = favorites
                            if !values.insert(device.uid).inserted { values.remove(device.uid) }
                            favoriteRaw = AudioFavorites.encode(values)
                        } label: {
                            Image(systemName: favorites.contains(device.uid) ? "star.fill" : "star")
                                .foregroundStyle(favorites.contains(device.uid) ? Color.accentColor : Color.secondary)
                        }.buttonStyle(.plain).accessibilityLabel(localized("Favorite audio device") + ": " + device.name)
                    }
                }.padding(.vertical, 4)
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            Button(localized("Sound Settings…"), action: onOpenSettings).buttonStyle(.link)
        }
    }
}
