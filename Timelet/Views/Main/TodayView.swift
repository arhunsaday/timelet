import SwiftUI
import SwiftData

/// Today screen (2a detail): headline total + grouped project cards. Falls back to the
/// empty state (2e) when nothing has been tracked and nothing is running.
struct TodayView: View {
    @Environment(TrackingEngine.self) private var engine
    @Query(sort: \Entry.start, order: .reverse) private var entries: [Entry]

    var body: some View {
        let summary = TodaySummary.build(
            entries: entries,
            runningElapsedToday: runningElapsedToday,
            now: engine.now
        )

        Group {
            if summary.isEmpty && engine.runningEntry == nil && !engine.isPaused {
                EmptyStateView()
            } else {
                ScrollView {
                    TodayContent(summary: summary)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.contentBackground)
    }

    private var runningElapsedToday: TimeInterval {
        guard let running = engine.runningEntry,
              Calendar.current.isDate(running.start, inSameDayAs: engine.now) else { return 0 }
        return engine.elapsed
    }
}

/// The scrollable body of Today: headline + cards. Pure (takes a prebuilt summary) so it
/// can be rendered outside a ScrollView.
struct TodayContent: View {
    let summary: TodaySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(total: summary.totalTracked)

            if summary.isEmpty {
                InProgressCard()
            } else {
                ForEach(fullCards) { ProjectCard(project: $0) }
                ForEach(Array(compactRows.enumerated()), id: \.offset) { _, pair in
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(pair) { CompactProjectCard(project: $0) }
                        if pair.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                    }
                }
            }
        }
    }

    private func header(total: TimeInterval) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(Format.duration(total))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .tracking(-0.5)
            Text("tracked today")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 4)
    }

    private var fullCards: [ProjectSummary] {
        summary.projects.filter { !$0.isCompact }
    }

    private var compactRows: [[ProjectSummary]] {
        let compact = summary.projects.filter(\.isCompact)
        return stride(from: 0, to: compact.count, by: 2).map {
            Array(compact[$0..<min($0 + 2, compact.count)])
        }
    }
}

/// Shown when a task is running but nothing has been filed into a card yet.
private struct InProgressCard: View {
    @Environment(TrackingEngine.self) private var engine
    var body: some View {
        HStack(spacing: 10) {
            PulsingDot(size: 8)
            Text(engine.currentActivity?.label ?? engine.lastActivityLabel ?? "Tracking")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text(Format.stopwatch(engine.elapsed))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .groupedCard()
    }
}
