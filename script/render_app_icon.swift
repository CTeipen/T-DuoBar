#!/usr/bin/env swift
// Deterministic vector source for the T-DuoBar AppIcon. Run with full Xcode selected.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let output = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    : root.appendingPathComponent("DuoBar/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 255) / 255,
        CGFloat((hex >> 8) & 255) / 255, CGFloat(hex & 255) / 255, alpha])!
}

func gradient(_ context: CGContext, colors: [CGColor], from: CGPoint, to: CGPoint) {
    let gradient = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
    context.drawLinearGradient(gradient, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func roundedPolygon(_ points: [CGPoint], radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    let first = points[0], last = points[points.count - 1]
    path.move(to: CGPoint(x: (first.x + last.x) / 2, y: (first.y + last.y) / 2))
    for index in points.indices {
        path.addArc(tangent1End: points[index], tangent2End: points[(index + 1) % points.count], radius: radius)
    }
    path.closeSubpath()
    return path
}

func render(pixels: Int) throws -> CGImage {
    guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
        bytesPerRow: pixels * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw CocoaError(.coderInvalidValue)
    }
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let tile = CGPath(roundedRect: CGRect(x: 64, y: 64, width: 896, height: 896),
        cornerWidth: 200, cornerHeight: 200, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: color(0x000000, alpha: 0.28))
    context.addPath(tile)
    context.setFillColor(color(0x121B24))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tile)
    context.clip()
    gradient(context, colors: [color(0x0C121A), color(0x1A2831), color(0x2B3B44)],
        from: CGPoint(x: 512, y: 64), to: CGPoint(x: 512, y: 960))
    context.restoreGState()
    context.addPath(tile)
    context.setStrokeColor(color(0xCEDFE7, alpha: 0.22))
    context.setLineWidth(2)
    context.strokePath()

    func ring(start: CGFloat, end: CGFloat, colors: [CGColor]) {
        let arc = CGMutablePath()
        arc.addArc(center: CGPoint(x: 512, y: 514), radius: 298,
            startAngle: start * .pi / 180, endAngle: end * .pi / 180, clockwise: false)
        let stroke = arc.copy(strokingWithWidth: pixels <= 32 ? 64 : 56,
            lineCap: .round, lineJoin: .round, miterLimit: 1)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -3), blur: 8, color: color(0x000000, alpha: 0.25))
        context.addPath(stroke)
        context.setFillColor(colors[0])
        context.fillPath()
        context.restoreGState()
        context.saveGState()
        context.addPath(stroke)
        context.clip()
        gradient(context, colors: colors, from: CGPoint(x: 512, y: 200), to: CGPoint(x: 512, y: 825))
        context.restoreGState()
    }
    ring(start: 98, end: 252, colors: [color(0x1EBAA9), color(0x86F4DF)])
    ring(start: 278, end: 432, colors: [color(0x3D7FEF), color(0x8CB9FF)])

    let monogram = roundedPolygon([
        CGPoint(x: 354, y: 684), CGPoint(x: 670, y: 684), CGPoint(x: 670, y: 604),
        CGPoint(x: 559, y: 604), CGPoint(x: 559, y: 344), CGPoint(x: 465, y: 344),
        CGPoint(x: 465, y: 604), CGPoint(x: 354, y: 604)
    ], radius: 14)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -5), blur: 12, color: color(0x000000, alpha: 0.4))
    context.addPath(monogram)
    context.setFillColor(color(0xE3EDF0))
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(monogram)
    context.clip()
    gradient(context, colors: [color(0xCADCE4), color(0xFAFCFE)],
        from: CGPoint(x: 512, y: 344), to: CGPoint(x: 512, y: 684))
    context.restoreGState()
    context.addPath(monogram)
    context.setStrokeColor(color(0xFFFFFF, alpha: 0.35))
    context.setLineWidth(1.5)
    context.strokePath()
    guard let image = context.makeImage() else { throw CocoaError(.coderInvalidValue) }
    return image
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let filename = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        let url = output.appendingPathComponent(filename)
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, try render(pixels: size * scale), nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
print("Rendered T-DuoBar AppIcon at 16–1024 px: \(output.path)")
