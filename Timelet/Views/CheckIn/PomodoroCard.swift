import SwiftUI

/// The corner card shown when a focus session or a break ends. Like the reminder card it never
/// takes the keyboard, and ignoring it lets the cycle carry on.
struct PomodoroCard: View {
    let event: Pomodoro.Event
    let pomodoro: Pomodoro
    let engine: TrackingEngine
    let onSwitch: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: event == .breakEnded ? "target" : "cup.and.saucer.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Theme.iconGradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                switch event {
                case .focusEnded:
                    Button("Stop focus") { pomodoro.stop(); onClose() }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Skip break") { pomodoro.skipBreak(); onClose() }
                        .buttonStyle(SecondaryButtonStyle())
                case .breakEnded:
                    Button("Stop focus") { pomodoro.stop(); onClose() }
                        .buttonStyle(SecondaryButtonStyle())
                    Button("Switch task…", action: onSwitch)
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .font(.system(size: 12))
        }
        .padding(14)
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.1), lineWidth: 0.5))
    }

    private var title: String {
        switch event {
        case .focusEnded(let next):
            "Focus done · \(pomodoro.minutes(for: next))-minute \(next == .longBreak ? "long break" : "break")"
        case .breakEnded:
            "Back to \(engine.currentActivity?.label.asDisplayLabel ?? "work")"
        }
    }

    private var subtitle: String {
        switch event {
        case .focusEnded:
            "Session \(pomodoro.completed) finished · tracking is paused"
        case .breakEnded:
            "\(pomodoro.minutes(for: .focus)) minutes of focus · tracking resumed"
        }
    }
}
