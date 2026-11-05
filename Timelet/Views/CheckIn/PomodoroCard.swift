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
        CornerCard(icon: event == .breakEnded ? "target" : "cup.and.saucer.fill", title: title, subtitle: subtitle) {
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
