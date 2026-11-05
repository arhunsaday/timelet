import SwiftUI

/// Live tracking indicator in the Today toolbar (2a): pulsing dot + `Group:Activity` + `mm:ss`.
/// Rendered as a plain toolbar button (tap to change task) with no background of its own, so on
/// macOS 26 the toolbar's Liquid Glass provides the single capsule — no pill-inside-a-pill.
struct TrackingPill: View {
    @Environment(TrackingEngine.self) private var engine
    @Environment(CheckInController.self) private var checkIn
    @Environment(Pomodoro.self) private var pomodoro

    var body: some View {
        if pomodoro.isOnBreak {
            Button { pomodoro.skipBreak() } label: {
                HStack(spacing: 7) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.accent)
                    Text("Break")
                        .font(.system(size: 12, weight: .medium))
                    Text(Format.stopwatch(pomodoro.remaining))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .monospacedDigit()
                }
            }
            .help("Skip the break and resume \(engine.lastActivityLabel?.asDisplayLabel ?? "the task")")
        } else if let activity = engine.currentActivity {
            Button { checkIn.present() } label: {
                HStack(spacing: 7) {
                    if pomodoro.isFocusing {
                        Image(systemName: "target").font(.system(size: 11)).foregroundStyle(Theme.accent)
                    } else {
                        PulsingDot(size: 7)
                    }
                    Text(activity.label.asDisplayLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(Format.stopwatch(pomodoro.isFocusing ? pomodoro.remaining : engine.elapsed))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .monospacedDigit()
                }
            }
            .help(pomodoro.isFocusing ? "Focus · \(Format.duration(pomodoro.remaining)) left — change task…" : "Change task…")
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
