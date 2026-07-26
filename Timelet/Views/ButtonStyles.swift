import SwiftUI

/// Primary accent button (Save ⏎, Start tracking).
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 9)
            .padding(.horizontal, 18)
            .background(
                Theme.accent.opacity(configuration.isPressed ? 0.85 : 1),
                in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
            )
            .shadow(color: Theme.accent.opacity(0.4), radius: 2, y: 1)
            .contentShape(Rectangle())
    }
}

/// Secondary bordered button (Continue previous).
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Theme.textPrimary)
            .padding(.vertical, 9)
            .padding(.horizontal, 14)
            .background(
                Theme.insetRow.opacity(configuration.isPressed ? 0.7 : 1),
                in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 1, y: 1)
            .contentShape(Rectangle())
    }
}
