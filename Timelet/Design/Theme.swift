import SwiftUI

/// Design tokens transcribed from the handoff (README "Design Tokens").
/// Light values match the mockup hex exactly; dark values are tuned equivalents so
/// the Appearance setting (Light / Dark / Auto) has a coherent dark mode.
enum Theme {

    // MARK: Accent

    /// Selection, primary buttons, active tracking, links. Sourced from the asset catalog.
    static let accent = Color.accentColor
    /// Tracking-pill background — 10% accent fill.
    static let accentTint = Color.accentColor.opacity(0.10)
    /// Toggle "on" green.
    static let toggleOn = Color(hex: "34C759")

    // MARK: Text

    static let textPrimary = Color(light: "1D1D1F", dark: "F5F5F7")
    static let textSecondary = Color(light: "3C3C43", dark: "C7C7CC")
    static let textTertiary = Color(light: "8E8E93", dark: "98989D")
    static let textQuaternary = Color(light: "A1A1A6", dark: "7C7C82")

    // MARK: Surfaces

    /// Detail / content area background.
    static let contentBackground = Color(light: "F5F5F7", dark: "1C1C1E")
    /// Grouped list card background.
    static let cardBackground = Color(light: "FFFFFF", dark: "2C2C2E")
    /// Project header row background.
    static let cardHeaderBackground = Color(light: "FAFAFA", dark: "323234")
    /// Menu / picker button fill.
    static let fieldTint = Color(light: "F2F2F7", dark: "3A3A3C")
    /// White inset rows inside vibrant surfaces (check-in field, menu-bar row).
    static let insetRow = Color(light: "FFFFFF", dark: "3A3A3C")

    // MARK: Hairlines

    /// Card outline (≈6%).
    static let stroke = Color(light: "0000000F", dark: "FFFFFF1A")
    /// Row separators (≈8%).
    static let divider = Color(light: "00000014", dark: "FFFFFF1A")
    /// Field / button borders (≈12%).
    static let border = Color(light: "0000001F", dark: "FFFFFF26")

    // MARK: Project palette (assigned in order to new projects)

    static let palette: [String] = [
        "FF9500", // orange
        "007AFF", // blue
        "AF52DE", // purple
        "34C759", // green
        "FF3B30", // red
        "FFCC00", // yellow
        "5856D6", // indigo
        "32ADE6", // cyan
        "00C7BE", // mint
        "A2845E", // brown
        "FF2D55", // pink
    ]

    /// App-icon gradient (#FFB43A → #FF6A1F), matching scripts/brand.swift.
    static let iconGradient = LinearGradient(
        colors: [Color(hex: "FFB43A"), Color(hex: "FF6A1F")],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// Corner-radius tokens (README "Radius").
enum Radius {
    static let window: CGFloat = 11
    static let card: CGFloat = 11
    static let button: CGFloat = 8
    static let field: CGFloat = 9
    static let popover: CGFloat = 12
    static let panel: CGFloat = 16
    static let swatch: CGFloat = 3
    static let navRow: CGFloat = 7
}
