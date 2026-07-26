import SwiftUI

/// The live tracking pill shown in the Today toolbar (2a): pulsing dot + `Group:Activity` + `mm:ss`.
struct TrackingPill: View {
    @Environment(TrackingEngine.self) private var engine

    var body: some View {
        if let activity = engine.currentActivity {
            HStack(spacing: 8) {
                PulsingDot(size: 7)
                Text(activity.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(Format.stopwatch(engine.elapsed))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .monospacedDigit()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Theme.accentTint, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(Theme.accent.opacity(0.25), lineWidth: 0.5)
            )
        } else if engine.isPaused, let label = engine.lastActivityLabel {
            HStack(spacing: 8) {
                Image(systemName: "pause.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Theme.fieldTint, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.button, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 0.5)
            )
        }
    }
}
