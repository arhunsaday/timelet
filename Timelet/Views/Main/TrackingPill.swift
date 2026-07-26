import SwiftUI

/// Live tracking indicator in the Today toolbar (2a): pulsing dot + `Group:Activity` + `mm:ss`.
/// Rendered as a plain toolbar button (tap to change task) with no background of its own, so on
/// macOS 26 the toolbar's Liquid Glass provides the single capsule — no pill-inside-a-pill.
struct TrackingPill: View {
    @Environment(TrackingEngine.self) private var engine
    @Environment(CheckInController.self) private var checkIn

    var body: some View {
        if let activity = engine.currentActivity {
            Button { checkIn.present() } label: {
                HStack(spacing: 7) {
                    PulsingDot(size: 7)
                    Text(activity.label.asDisplayLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(Format.stopwatch(engine.elapsed))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .monospacedDigit()
                }
            }
            .help("Change task…")
        } else if engine.isPaused, let label = engine.lastActivityLabel {
            Button { engine.togglePause() } label: {
                HStack(spacing: 7) {
                    Image(systemName: "pause.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Text(label.asDisplayLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .help("Resume tracking")
        }
    }
}
