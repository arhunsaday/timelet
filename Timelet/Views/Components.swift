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

/// Active-tracking indicator: a filled dot with a native repeating pulse. Uses `symbolEffect`
/// (rather than a manual `@State` animation) so it stays smooth even inside a toolbar that
/// rebuilds every second as the timer ticks.
struct PulsingDot: View {
    var color: Color = Theme.accent
    var size: CGFloat = 7
    var body: some View {
        Image(systemName: "circle.fill")
            .font(.system(size: size))
            .foregroundStyle(color)
            .symbolEffect(.pulse, options: .repeating)
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

extension String {
    /// Insert a single space after the first ":" for display (`A:B` → `A: B`). Visual only —
    /// the stored `Group:Activity` form is unchanged, so parsing/round-tripping still works.
    var asDisplayLabel: String {
        guard let colon = firstIndex(of: ":") else { return self }
        let after = index(after: colon)
        guard after < endIndex, self[after] != " " else { return self }
        return "\(self[...colon]) \(self[after...])"
    }
}

/// A rotating disclosure chevron used to expand/collapse an entry's note.
struct DisclosureChevron: View {
    @Binding var expanded: Bool
    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
        } label: {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textQuaternary)
                .rotationEffect(.degrees(expanded ? 90 : 0))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(expanded ? "Hide note" : "Show note")
    }
}

/// The revealed note block under an entry row (indented, in a subtle tinted box).
struct EntryNoteView: View {
    let note: String
    var leadingInset: CGFloat = 34
    var trailingInset: CGFloat = 14

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "note.text")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .padding(.top, 1)
            Text(note)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.fieldTint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.bottom, 10)
    }
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
