import SwiftUI
import AppKit

extension Color {
    /// Build a color from a hex string: `RRGGBB` or `RRGGBBAA` (with or without a leading `#`).
    init(hex: String) {
        self = Color(nsColor: .fromHex(hex))
    }

    /// An appearance-adaptive color. Light and dark are both hex strings.
    /// This lets us match the light-mode handoff hex exactly while still supporting dark mode.
    init(light: String, dark: String) {
        self = Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return .fromHex(isDark ? dark : light)
        })
    }
}

extension NSColor {
    static func fromHex(_ hex: String) -> NSColor {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)

        let r, g, b, a: CGFloat
        if s.count == 8 { // RRGGBBAA
            r = CGFloat((value & 0xFF00_0000) >> 24) / 255
            g = CGFloat((value & 0x00FF_0000) >> 16) / 255
            b = CGFloat((value & 0x0000_FF00) >> 8) / 255
            a = CGFloat(value & 0x0000_00FF) / 255
        } else { // RRGGBB
            r = CGFloat((value & 0xFF0000) >> 16) / 255
            g = CGFloat((value & 0x00FF00) >> 8) / 255
            b = CGFloat(value & 0x0000FF) / 255
            a = 1
        }
        return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
