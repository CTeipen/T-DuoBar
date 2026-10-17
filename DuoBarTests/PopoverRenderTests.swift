import AppKit
import SwiftUI
import XCTest
@testable import DuoBar

final class PopoverRenderTests: XCTestCase {
    func testBatteryPopoverTrailingPercentageFollowsLivePreference() {
        let plugged = BatteryStatusRow(
            battery: BatteryStatus(percentage: 96, isCharging: false, isPluggedIn: true, isFullyCharged: false, isAvailable: true),
            showPercentage: true
        )
        XCTAssertEqual(plugged.trailingValue, localized("%d%%", 96))
        XCTAssertEqual(plugged.detail, localized("Power adapter connected"))

        let unplugged = BatteryStatusRow(
            battery: BatteryStatus(percentage: 96, isCharging: false, isPluggedIn: false, isFullyCharged: false, isAvailable: true),
            showPercentage: true
        )
        XCTAssertEqual(unplugged.trailingValue, localized("%d%%", 96))
        XCTAssertEqual(unplugged.detail, localized("Using battery power"))

        let hidden = BatteryStatusRow(
            battery: BatteryStatus(percentage: 96, isCharging: false, isPluggedIn: true, isFullyCharged: false, isAvailable: true),
            showPercentage: false
        )
        XCTAssertNil(hidden.trailingValue)
    }

    @MainActor
    func testRenderActualBatteryStatusRowWithTrailingPercentage() throws {
        let view = BatteryStatusRow(
            battery: BatteryStatus(percentage: 96, isCharging: false, isPluggedIn: true, isFullyCharged: false, isAvailable: true),
            showPercentage: true
        )
        .frame(width: 280)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.colorScheme, .dark)

        try writePNG(view, named: "DuoBar-Battery-Row-96.png")
    }

    @MainActor
    func testRenderFinalPopover() throws {
        let store = SystemStatusStore(startServices: false)
        store.applyDebugBatteryLevel(.full)
        store.applyDebugNetworkState(.strong)
        store.applyDebugAudioDeviceState(.builtIn)
        store.applyDebugVolumeState(.fiftyOne)

        let view = StatusPopoverView(statusStore: store, onClose: {})
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, .dark)

        try writePNG(view, named: "DuoBar-1.0-Popover.png")
    }

    @MainActor
    func testHeaderStaysAtTopWhilePopoverHostAndContentHeightsDiffer() throws {
        let store = SystemStatusStore(startServices: false)
        let view = StatusPopoverView(statusStore: store, onClose: {})
            .frame(width: 304, height: 600)
            .background(Color.black)
            .environment(\.colorScheme, .dark)
        let host = NSHostingView(rootView: view)
        host.appearance = NSAppearance(named: .darkAqua)
        host.frame = NSRect(x: 0, y: 0, width: 304, height: 600)
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let scale = CGFloat(bitmap.pixelsWide) / host.bounds.width
        var headerInkPixels = 0
        for y in 0..<Int(40 * scale) {
            for x in Int(14 * scale)..<Int(150 * scale) {
                if let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
                   min(color.redComponent, color.greenComponent, color.blueComponent) > 0.55 {
                    headerInkPixels += 1
                }
            }
        }
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("T-DuoBar-Top-Aligned-Popover.png"))
        XCTAssertGreaterThan(headerInkPixels, 20, "The title moved away from the top while the host resized")
    }

    @MainActor
    func testRenderNativeMenuBarScaleComparison() throws {
        let status = DebugAudioDeviceState.builtIn.status
        let systemStatus = SystemStatus(
            battery: BatteryStatus(percentage: 75, isCharging: false, isPluggedIn: false, isFullyCharged: false, isAvailable: true),
            network: DebugNetworkState.strong.status,
            audio: status,
            bluetooth: .unavailable
        )

        let view = HStack(spacing: 11) {
            Image(systemName: "wifi")
            Image(systemName: "speaker.wave.2.fill")
            DuoGlyphView(status: systemStatus, animationsEnabled: false)
            Image(systemName: "battery.75percent")
        }
        .font(.system(size: 13, weight: .semibold))
        .symbolRenderingMode(.monochrome)
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Color.black)

        try writePNG(view, named: "DuoBar-1.0-MenuBar-Comparison.png")
    }

    @MainActor
    func testRenderLongLocalizedPopoverLabelsWithoutCollision() throws {
        let longNetwork = StatusRow(
            symbol: "wifi",
            title: localized("Network"),
            detail: "A-very-long-network-name-that-must-truncate-cleanly",
            stateText: localized("Connected"),
            tint: .primary,
            trailing: AnyView(
                Toggle(localized("Wi-Fi power"), isOn: .constant(true))
                    .labelsHidden()
                    .toggleStyle(.switch)
            )
        )
        let longAudio = StatusRow(
            symbol: "speaker.wave.2",
            title: localized("Audio Output"),
            detail: "Bluetooth Headphones — A Very Long Device Name",
            stateText: localized("Bluetooth"),
            tint: .primary
        )
        let view = VStack(spacing: 8) {
            longNetwork
            VolumeStatusRow(
                volume: OutputVolumeStatus(level: 0.5, isMuted: false, isSettable: false),
                hasOutputDevice: true,
                playbackDeviceIdentifier: nil,
                onSetVolume: { _ in true },
                onSetMuted: { _ in true }
            )
            longAudio
        }
        .padding(12)
        .frame(width: 304)
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(\.colorScheme, .dark)

        try writePNG(view, named: "DuoBar-Popover-Long-Labels.png")
    }

    @MainActor
    private func writePNG<Content: View>(_ content: Content, named name: String) throws {
        let hostingView = NSHostingView(rootView: content)
        hostingView.appearance = NSAppearance(named: .darkAqua)
        hostingView.frame = NSRect(origin: .zero, size: hostingView.fittingSize)
        hostingView.layoutSubtreeIfNeeded()
        let representation = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
        let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent(name), options: .atomic)
        XCTAssertGreaterThan(png.count, 1_000)
    }
}
