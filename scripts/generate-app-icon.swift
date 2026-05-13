#!/usr/bin/env swift

import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconsetURL = rootURL
    .appendingPathComponent(".build", isDirectory: true)
    .appendingPathComponent("AppIcon.iconset", isDirectory: true)
let resourcesURL = rootURL
    .appendingPathComponent("Sources/MacLauncher/Resources", isDirectory: true)
let previewURL = rootURL
    .appendingPathComponent("Assets/AppIcon/AppIcon.png", isDirectory: false)
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns", isDirectory: false)

let fileManager = FileManager.default
try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
try fileManager.createDirectory(at: previewURL.deletingLastPathComponent(), withIntermediateDirectories: true)

struct IconImage {
    let name: String
    let pixels: Int
}

let images = [
    IconImage(name: "icon_16x16.png", pixels: 16),
    IconImage(name: "icon_16x16@2x.png", pixels: 32),
    IconImage(name: "icon_32x32.png", pixels: 32),
    IconImage(name: "icon_32x32@2x.png", pixels: 64),
    IconImage(name: "icon_128x128.png", pixels: 128),
    IconImage(name: "icon_128x128@2x.png", pixels: 256),
    IconImage(name: "icon_256x256.png", pixels: 256),
    IconImage(name: "icon_256x256@2x.png", pixels: 512),
    IconImage(name: "icon_512x512.png", pixels: 512),
    IconImage(name: "icon_512x512@2x.png", pixels: 1024)
]

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func roundedRect(_ rect: CGRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func savePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }

    try data.write(to: url, options: [.atomic])
}

func drawIcon(pixels: Int) throws -> NSBitmapImageRep {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw CocoaError(.fileWriteUnknown)
    }

    let context = NSGraphicsContext(bitmapImageRep: bitmap)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer {
        NSGraphicsContext.restoreGraphicsState()
    }

    NSGraphicsContext.current?.imageInterpolation = .high
    NSColor.clear.setFill()
    let size = CGFloat(pixels)
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    func s(_ value: CGFloat) -> CGFloat { value * size / 1024 }

    let outer = CGRect(x: s(82), y: s(82), width: s(860), height: s(860))
    let outerPath = roundedRect(outer, radius: s(214))

    let shadow = NSShadow()
    shadow.shadowColor = color(2, 6, 23, 0.34)
    shadow.shadowBlurRadius = s(42)
    shadow.shadowOffset = NSSize(width: 0, height: -s(34))
    shadow.set()

    let baseGradient = NSGradient(colorsAndLocations:
        (color(17, 24, 39), 0),
        (color(13, 148, 136), 0.42),
        (color(56, 189, 248), 0.72),
        (color(244, 63, 94), 1)
    )
    baseGradient?.draw(in: outerPath, angle: -42)
    NSShadow().set()

    let glowGradient = NSGradient(colorsAndLocations:
        (color(255, 255, 255, 0.58), 0),
        (color(103, 232, 249, 0.22), 0.34),
        (color(15, 23, 42, 0), 1)
    )
    glowGradient?.draw(in: outerPath, relativeCenterPosition: NSPoint(x: 0.45, y: 0.45))

    color(255, 255, 255, 0.22).setStroke()
    let insetPath = roundedRect(outer.insetBy(dx: s(23), dy: s(23)), radius: s(194))
    insetPath.lineWidth = s(16)
    insetPath.stroke()

    drawTiles(scale: s)
    drawLaunchArrow(scale: s)

    color(255, 255, 255, 0.88).setFill()
    NSBezierPath(ovalIn: CGRect(x: s(680), y: s(598), width: s(68), height: s(68))).fill()
    color(34, 211, 238, 0.9).setFill()
    NSBezierPath(ovalIn: CGRect(x: s(701), y: s(619), width: s(26), height: s(26))).fill()

    return bitmap
}

func drawTiles(scale s: (CGFloat) -> CGFloat) {
    let positions: [(CGFloat, CGFloat, CGFloat)] = [
        (250, 636, 0.82), (446, 636, 0.76), (642, 636, 0.58),
        (250, 440, 0.70), (446, 440, 0.44), (642, 440, 0.68),
        (250, 244, 0.48), (446, 244, 0.58), (642, 244, 0.50)
    ]

    for (x, y, alpha) in positions {
        let rect = CGRect(x: s(x), y: s(y), width: s(132), height: s(132))
        let path = roundedRect(rect, radius: s(34))
        let gradient = NSGradient(colorsAndLocations:
            (color(255, 255, 255, 0.74 * alpha), 0),
            (color(255, 255, 255, 0.16 * alpha), 1)
        )
        gradient?.draw(in: path, angle: -45)
    }
}

func drawLaunchArrow(scale s: (CGFloat) -> CGFloat) {
    let shadow = NSShadow()
    shadow.shadowColor = color(2, 44, 34, 0.42)
    shadow.shadowBlurRadius = s(16)
    shadow.shadowOffset = NSSize(width: 0, height: -s(18))
    shadow.set()

    let path = NSBezierPath()
    path.move(to: NSPoint(x: s(332), y: s(320)))
    path.curve(to: NSPoint(x: s(401), y: s(251)), controlPoint1: NSPoint(x: s(313), y: s(301)), controlPoint2: NSPoint(x: s(313), y: s(270)))
    path.line(to: NSPoint(x: s(665), y: s(515)))
    path.line(to: NSPoint(x: s(669), y: s(394)))
    path.curve(to: NSPoint(x: s(721), y: s(346)), controlPoint1: NSPoint(x: s(670), y: s(366)), controlPoint2: NSPoint(x: s(693), y: s(345)))
    path.curve(to: NSPoint(x: s(768), y: s(398)), controlPoint1: NSPoint(x: s(748), y: s(347)), controlPoint2: NSPoint(x: s(769), y: s(370)))
    path.line(to: NSPoint(x: s(758), y: s(642)))
    path.curve(to: NSPoint(x: s(710), y: s(690)), controlPoint1: NSPoint(x: s(757), y: s(668)), controlPoint2: NSPoint(x: s(736), y: s(689)))
    path.line(to: NSPoint(x: s(466), y: s(700)))
    path.curve(to: NSPoint(x: s(414), y: s(653)), controlPoint1: NSPoint(x: s(438), y: s(701)), controlPoint2: NSPoint(x: s(413), y: s(681)))
    path.curve(to: NSPoint(x: s(462), y: s(601)), controlPoint1: NSPoint(x: s(415), y: s(625)), controlPoint2: NSPoint(x: s(434), y: s(600)))
    path.line(to: NSPoint(x: s(583), y: s(597)))
    path.close()

    let gradient = NSGradient(colorsAndLocations:
        (color(248, 250, 252), 0),
        (color(167, 243, 208), 0.5),
        (color(236, 254, 255), 1)
    )
    gradient?.draw(in: path, angle: -45)
    NSShadow().set()

    color(255, 255, 255, 0.24).setFill()
    let highlight = NSBezierPath()
    highlight.move(to: NSPoint(x: s(344), y: s(271)))
    highlight.curve(to: NSPoint(x: s(400), y: s(246)), controlPoint1: NSPoint(x: s(352), y: s(263)), controlPoint2: NSPoint(x: s(392), y: s(254)))
    highlight.line(to: NSPoint(x: s(674), y: s(520)))
    highlight.line(to: NSPoint(x: s(679), y: s(362)))
    highlight.curve(to: NSPoint(x: s(736), y: s(390)), controlPoint1: NSPoint(x: s(679), y: s(346)), controlPoint2: NSPoint(x: s(735), y: s(374)))
    highlight.line(to: NSPoint(x: s(726), y: s(634)))
    highlight.curve(to: NSPoint(x: s(696), y: s(662)), controlPoint1: NSPoint(x: s(726), y: s(650)), controlPoint2: NSPoint(x: s(711), y: s(662)))
    highlight.line(to: NSPoint(x: s(538), y: s(667)))
    highlight.line(to: NSPoint(x: s(344), y: s(472)))
    highlight.curve(to: NSPoint(x: s(344), y: s(271)), controlPoint1: NSPoint(x: s(323), y: s(451)), controlPoint2: NSPoint(x: s(323), y: s(292)))
    highlight.close()
    highlight.fill()
}

for item in images {
    let image = try drawIcon(pixels: item.pixels)
    try savePNG(image, to: iconsetURL.appendingPathComponent(item.name))
}

try savePNG(try drawIcon(pixels: 1024), to: previewURL)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "-c", "icns",
    iconsetURL.path,
    "-o", icnsURL.path
]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw CocoaError(.fileWriteUnknown)
}

print("Generated \(icnsURL.path)")
print("Generated \(previewURL.path)")
