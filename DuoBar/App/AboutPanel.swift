import AppKit

@MainActor
enum AboutPanel {
    static func show() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: options())
    }

    static func options(bundle: Bundle = .main) -> [NSApplication.AboutPanelOptionKey: Any] {
        let identity = AppIdentity(bundle: bundle)
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: AppIdentity.name,
            .applicationVersion: identity.version,
            .version: identity.build,
            .credits: credits(),
            NSApplication.AboutPanelOptionKey(rawValue: "Copyright"): "© 2026 Mike Li · MIT License"
        ]
        // Load the bundled icon directly so the panel does not depend on Finder's icon cache.
        if let url = bundle.url(forResource: "AppIcon", withExtension: "icns"), let icon = NSImage(contentsOf: url) {
            options[.applicationIcon] = icon
        }
        return options
    }

    private static func credits() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 3
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]
        let text = NSMutableAttributedString(string:
            localized("Battery, network and audio at a glance.") + "\n\n" +
            localized("Community fork by squazaryu.") + "\n" +
            localized("Based on DuoBar by Mike Li (Mikeli7666).") + "\n\n", attributes: attributes)
        let links = [
            (localized("Project"), AppIdentity.projectURL),
            (localized("Release notes"), AppIdentity.releasesURL),
            (localized("Original DuoBar"), AppIdentity.upstreamURL),
            (localized("MIT License"), AppIdentity.licenseURL)
        ]
        for (index, link) in links.enumerated() {
            if index > 0 { text.append(NSAttributedString(string: index == 2 ? "\n" : "  ·  ", attributes: attributes)) }
            var linkAttributes = attributes
            linkAttributes[.link] = link.1
            linkAttributes[.foregroundColor] = NSColor.linkColor
            text.append(NSAttributedString(string: link.0, attributes: linkAttributes))
        }
        return text
    }
}
