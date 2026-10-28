// Generates the app icon (every size in AppIcon.appiconset) and brand/logo.svg from the
// geometry below, so they can never drift apart. Run from the repo root:
//   swift scripts/brand.swift
import AppKit
import CoreGraphics
import Foundation

let canvas = 1024.0
// macOS icon grid: 824 pt body inset 100 pt, continuous corners.
let body = (inset: 100.0, size: 824.0, radius: 185.0)
let top = "#FFB43A", bottom = "#FF6A1F"

// A stopwatch: ring, crown and side button, and a slice of time (12 → 4 o'clock) filled in.
let center = CGPoint(x: 512, y: 548)
let ringRadius = 262.0, ringWidth = 58.0
let sliceRadius = 196.0, sliceEnd = 0.34 // fraction of a turn
let crown = CGRect(x: 512 - 46, y: 548 - 262 - 96, width: 92, height: 62)
let stem = CGRect(x: 512 - 20, y: 548 - 262 - 44, width: 40, height: 40)

func color(_ hex: String, _ alpha: CGFloat = 1) -> CGColor {
    let v = UInt64(hex.dropFirst(), radix: 16)!
    return CGColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: alpha)
}

func point(_ turn: Double, _ r: Double) -> CGPoint {
    let a = turn * 2 * .pi
    return CGPoint(x: center.x + r * sin(a), y: center.y - r * cos(a))
}

func draw(size: Int) -> Data {
    let scale = Double(size) / canvas
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Work in a 1024, y-down space.
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))

    let rect = CGRect(x: body.inset, y: body.inset, width: body.size, height: body.size)
    let tile = CGPath(roundedRect: rect, cornerWidth: body.radius, cornerHeight: body.radius, transform: nil)
    let gradient = CGGradient(colorsSpace: space, colors: [color(top), color(bottom)] as CFArray, locations: [0, 1])!

    // Shadows ignore the CTM, so "down" is negative in device space.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 24 * scale, color: CGColor(gray: 0, alpha: 0.3))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.addPath(tile)
    ctx.clip()
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    // Soft light from the top.
    let shine = CGGradient(colorsSpace: space, colors: [CGColor(gray: 1, alpha: 0.22), CGColor(gray: 1, alpha: 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(shine, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 520), options: [])
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    let white = color("#FFFFFF")
    ctx.setFillColor(white)
    ctx.setStrokeColor(white)

    // Crown and stem.
    ctx.addPath(CGPath(roundedRect: crown, cornerWidth: 18, cornerHeight: 18, transform: nil))
    ctx.fillPath()
    ctx.fill(stem)

    // Side button at 1:30.
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.rotate(by: .pi / 4)
    ctx.addPath(CGPath(roundedRect: CGRect(x: -22, y: -ringRadius - 66, width: 44, height: 54), cornerWidth: 12, cornerHeight: 12, transform: nil))
    ctx.fillPath()
    ctx.restoreGState()

    // Ring.
    ctx.setLineWidth(ringWidth)
    ctx.addArc(center: center, radius: ringRadius, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
    ctx.strokePath()

    // Slice of time.
    ctx.move(to: center)
    ctx.addArc(center: center, radius: sliceRadius, startAngle: -.pi / 2, endAngle: sliceEnd * 2 * .pi - .pi / 2, clockwise: false)
    ctx.closePath()
    ctx.fillPath()

    // Hand at the end of the slice, and the pivot.
    ctx.setStrokeColor(color("#FFFFFF", 0.85))
    ctx.setLineWidth(20)
    ctx.setLineCap(.round)
    ctx.move(to: center)
    ctx.addLine(to: point(sliceEnd, sliceRadius))
    ctx.strokePath()
    ctx.setFillColor(color(bottom))
    ctx.fillEllipse(in: CGRect(x: center.x - 26, y: center.y - 26, width: 52, height: 52))
    ctx.setFillColor(white)
    ctx.fillEllipse(in: CGRect(x: center.x - 12, y: center.y - 12, width: 24, height: 24))

    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

func svg() -> String {
    func f(_ v: Double) -> String { String(format: "%.1f", v) }
    let p1 = point(sliceEnd, sliceRadius)
    return """
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024" role="img" aria-label="Timelet">
      <defs>
        <linearGradient id="bg" x1="0" y1="100" x2="0" y2="924" gradientUnits="userSpaceOnUse">
          <stop offset="0" stop-color="\(top)"/><stop offset="1" stop-color="\(bottom)"/>
        </linearGradient>
      </defs>
      <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bg)"/>
      <g fill="#fff">
        <rect x="\(f(crown.minX))" y="\(f(crown.minY))" width="\(f(crown.width))" height="\(f(crown.height))" rx="18"/>
        <rect x="\(f(stem.minX))" y="\(f(stem.minY))" width="\(f(stem.width))" height="\(f(stem.height))"/>
        <rect x="-22" y="\(f(-ringRadius - 66))" width="44" height="54" rx="12" transform="translate(\(f(center.x)) \(f(center.y))) rotate(45)"/>
        <path d="M\(f(center.x)) \(f(center.y)) L\(f(center.x)) \(f(center.y - sliceRadius)) A\(f(sliceRadius)) \(f(sliceRadius)) 0 0 1 \(f(p1.x)) \(f(p1.y)) Z"/>
      </g>
      <circle cx="\(f(center.x))" cy="\(f(center.y))" r="\(f(ringRadius))" fill="none" stroke="#fff" stroke-width="\(f(ringWidth))"/>
      <circle cx="\(f(center.x))" cy="\(f(center.y))" r="26" fill="\(bottom)"/>
      <circle cx="\(f(center.x))" cy="\(f(center.y))" r="12" fill="#fff"/>
    </svg>

    """
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("Timelet/Assets.xcassets/AppIcon.appiconset")
for size in [16, 32, 64, 128, 256, 512, 1024] {
    try draw(size: size).write(to: iconset.appendingPathComponent("icon_\(size).png"))
}
try FileManager.default.createDirectory(at: root.appendingPathComponent("brand"), withIntermediateDirectories: true)
try draw(size: 256).write(to: root.appendingPathComponent("brand/icon-256.png"))
try svg().write(to: root.appendingPathComponent("brand/logo.svg"), atomically: true, encoding: .utf8)
print("Icon: AppIcon.appiconset (16–1024), brand/icon-256.png, brand/logo.svg")
