import SwiftUI

struct MenuSectionsSettingsView: View {
    @AppStorage(PreferenceKeys.hideEmptyAccessories) private var hideEmptyAccessories = false
    @AppStorage(PreferenceKeys.menuSectionOrder) private var orderRaw = MenuSectionOrder.defaultValue
    private var sections: [MenuSection] { MenuSectionOrder.decode(orderRaw) }

    var body: some View {
        Section(localized("Menu sections")) {
            ForEach(sections) { section in
                MenuSectionSettingsRow(section: section,
                    canMoveUp: sections.first != section, canMoveDown: sections.last != section,
                    onMove: { offset in
                        guard let index = sections.firstIndex(of: section), sections.indices.contains(index + offset) else { return }
                        move(section, to: sections[index + offset])
                    }, onDropSection: { move($0, to: section) })
            }
            HStack {
                Text(localized("Drag the handles to reorder sections. Right-click a row for move actions."))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button(localized("Reset order")) {
                    orderRaw = MenuSectionOrder.defaultValue
                }
                .buttonStyle(.link)
                .disabled(sections == MenuSection.allCases)
            }
            Toggle(localized("Hide empty accessory section"), isOn: $hideEmptyAccessories)
                .help(localized("Connected devices appear automatically. Read errors remain visible."))
        }
    }

    private func move(_ section: MenuSection, to target: MenuSection) {
        orderRaw = MenuSectionOrder.encode(MenuSectionOrder.moving(section, to: target, in: sections))
    }
}

private struct MenuSectionSettingsRow: View {
    let section: MenuSection
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMove: (Int) -> Void
    let onDropSection: (MenuSection) -> Void
    @AppStorage private var isVisible: Bool
    @State private var isDropTarget = false

    init(section: MenuSection, canMoveUp: Bool, canMoveDown: Bool,
         onMove: @escaping (Int) -> Void, onDropSection: @escaping (MenuSection) -> Void) {
        self.section = section
        self.canMoveUp = canMoveUp
        self.canMoveDown = canMoveDown
        self.onMove = onMove
        self.onDropSection = onDropSection
        _isVisible = AppStorage(wrappedValue: section.defaultVisibility, section.visibilityKey)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .padding(.vertical, 5).padding(.horizontal, 2)
                .contentShape(Rectangle())
                .draggable(section.dragIdentifier)
                .help(localized("Drag to reorder"))
                .accessibilityHidden(true)
            Toggle(section.title, isOn: $isVisible)
        }
        .contentShape(Rectangle())
        .background(isDropTarget ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .dropDestination(for: String.self, action: { values, _ in
            guard values.count == 1, let value = values.first,
                  let dragged = MenuSection(dragIdentifier: value), dragged != section else { return false }
            onDropSection(dragged)
            return true
        }, isTargeted: { isDropTarget = $0 })
        .contextMenu {
            Button(localized("Move up")) { onMove(-1) }.disabled(!canMoveUp)
            Button(localized("Move down")) { onMove(1) }.disabled(!canMoveDown)
        }
        .accessibilityAction(named: Text(localized("Move up"))) { if canMoveUp { onMove(-1) } }
        .accessibilityAction(named: Text(localized("Move down"))) { if canMoveDown { onMove(1) } }
    }
}
