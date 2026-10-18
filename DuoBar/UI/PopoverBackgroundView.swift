import AppKit

/// A separate tint layer leaves content opacity untouched and does not blur.
final class PopoverBackgroundView: NSView {
    var fillOpacity: Double = 1 {
        didSet {
            if oldValue != fillOpacity { needsDisplay = true }
        }
    }

    override var isOpaque: Bool { fillOpacity == 1 }
    override var wantsUpdateLayer: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(fillOpacity).cgColor
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
