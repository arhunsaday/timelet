import SwiftUI

/// Colored rounded-square project swatch (radius 3).
struct ColorSwatch: View {
    let hex: String
    var size: CGFloat = 10
    var body: some View {
        RoundedRectangle(cornerRadius: Radius.swatch, style: .continuous)
            .fill(Color(hex: hex))
            .frame(width: size, height: size)
    }
}

/// Orange-gradient app-icon badge with a white `timer` glyph (screens 2b / 2e).
struct AppIconBadge: View {
    var size: CGFloat
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
            .fill(Theme.iconGradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "timer")
                    .font(.system(size: size * 0.55, weight: .medium))
                    .foregroundStyle(.white)
            )
            .shadow(color: Color(hex: "FF9500").opacity(0.35), radius: size * 0.18, y: size * 0.12)
    }
}

/// Active-tracking indicator: a subtle ~1.6s opacity pulse.
struct PulsingDot: View {
    var color: Color = Theme.accent
    var size: CGFloat = 7
    @State private var pulsing = false
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .opacity(pulsing ? 0.3 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
    }
}

/// White grouped-list card: hairline outline + very soft drop shadow (README "Shadows").
struct GroupedCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
    }
}

extension View {
    func groupedCard() -> some View { modifier(GroupedCard()) }
}

/// A 0.5pt hairline separator.
struct Hairline: View {
    var color: Color = Theme.divider
    var body: some View { Rectangle().fill(color).frame(height: 0.5) }
}

/// A small keyboard-key cap (e.g. `⌘⇧T`).
struct KeyCap: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Theme.fieldTint, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 0.5)
            )
    }
}
