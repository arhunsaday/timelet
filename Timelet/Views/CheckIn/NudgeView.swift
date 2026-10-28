import SwiftUI

/// The gentle scheduled check-in: a small card in the top-right corner that never takes the
/// keyboard. One click keeps going or opens the full check-in; ignoring it keeps the task.
struct NudgeView: View {
    let engine: TrackingEngine
    let lifetime: TimeInterval
    let onKeepGoing: () -> Void
    let onChange: () -> Void
    let onSnooze: (TimeInterval) -> Void

    @State private var shownAt = Date.now
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                AppIconBadge(size: 30)
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
                Menu {
                    Button("Don't ask for 30 minutes") { onSnooze(30 * 60) }
                    Button("Don't ask for 1 hour") { onSnooze(3600) }
                    Button("Don't ask for 2 hours") { onSnooze(2 * 3600) }
                } label: {
                    Image(systemName: "bell.slash")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .opacity(hovering ? 1 : 0.5)
                .help("Stop asking for a while")
            }
            HStack(spacing: 8) {
                Button(engine.runningEntry != nil ? "Keep going" : "Not now", action: onKeepGoing)
                    .buttonStyle(SecondaryButtonStyle())
                Button(engine.runningEntry != nil ? "Switch…" : "Start…", action: onChange)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .font(.system(size: 12))
            TimelineView(.periodic(from: shownAt, by: 1)) { context in
                GeometryReader { geo in
                    Capsule().fill(Theme.accent.opacity(0.25))
                        .frame(width: geo.size.width * max(0, 1 - context.date.timeIntervalSince(shownAt) / lifetime))
                        .animation(.linear(duration: 1), value: context.date)
                }
                .frame(height: 2)
            }
        }
        .padding(14)
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.1), lineWidth: 0.5))
        .onHover { hovering = $0 }
    }

    private var title: String {
        if let label = engine.currentActivity?.label { return "Still on \(label.asDisplayLabel)?" }
        return "What are you working on?"
    }

    private var subtitle: String {
        if engine.runningEntry != nil { return "\(Format.duration(engine.elapsed)) so far · ignore to keep going" }
        return "Nothing is being tracked"
    }
}
