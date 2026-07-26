import SwiftUI

/// Menu-bar status item: `timer` glyph + live `m:ss` while tracking (2c).
struct MenuBarLabel: View {
    @Environment(TrackingEngine.self) private var engine

    var body: some View {
        if engine.runningEntry != nil {
            Label(Format.stopwatchCompact(engine.elapsed), systemImage: "timer")
                .monospacedDigit()
        } else {
            Image(systemName: engine.isPaused ? "pause.circle" : "timer")
        }
    }
}
