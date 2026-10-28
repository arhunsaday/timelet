import SwiftUI

/// Menu-bar status item: icon plus the timer, task, or today's total (Settings › Menu bar).
struct MenuBarLabel: View {
    @Environment(TrackingEngine.self) private var engine
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let icon = engine.isPaused ? "pause.circle" : (engine.runningEntry != nil ? "timer" : "timer.circle")
        if let text {
            Label(text, systemImage: icon).monospacedDigit()
        } else {
            Image(systemName: icon)
        }
    }

    private var text: String? {
        switch settings.menuBarDisplay {
        case .iconOnly:
            return nil
        case .todayTotal:
            return Format.durationCompact(engine.total(on: engine.now))
        case .timer:
            return engine.runningEntry != nil ? Format.stopwatchCompact(engine.elapsed) : nil
        case .taskAndTimer:
            guard let activity = engine.currentActivity else { return nil }
            let name = activity.name.count > 22 ? String(activity.name.prefix(21)) + "…" : activity.name
            return "\(name) \(Format.stopwatchCompact(engine.elapsed))"
        }
    }
}
