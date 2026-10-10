import SwiftUI

struct StatusDetailSection<Header: View, Content: View>: View {
    @State private var expanded = false
    @ViewBuilder let header: Header
    @ViewBuilder let content: Content

    init(initiallyExpanded: Bool = false, @ViewBuilder header: () -> Header, @ViewBuilder content: () -> Content) {
        self.header = header()
        self.content = content()
        _expanded = State(initialValue: initiallyExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { expanded.toggle() } label: { header.environment(\.statusSectionExpanded, expanded) }
                .buttonStyle(.plain)
                .accessibilityHint(localized("Show details"))
                .accessibilityValue(expanded ? localized("Expanded") : localized("Collapsed"))
            if expanded {
                VStack(alignment: .leading, spacing: 7) {
                    Divider()
                    content
                }.font(.system(size: 10.5)).padding(10)
            }
        }
        .background(.primary.opacity(expanded ? 0.045 : 0), in: RoundedRectangle(cornerRadius: 11))
    }
}

struct StatusDetailLine: View {
    let title: String
    let value: String?
    var body: some View {
        HStack {
            Text(localized(title)).foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text(value ?? localized("Unavailable")).monospacedDigit()
                .textSelection(.enabled)
        }
    }
}

private struct StatusSectionExpandedKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var statusSectionExpanded: Bool {
        get { self[StatusSectionExpandedKey.self] }
        set { self[StatusSectionExpandedKey.self] = newValue }
    }
}
