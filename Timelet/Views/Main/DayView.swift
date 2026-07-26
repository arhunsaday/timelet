import SwiftUI
import SwiftData

/// Day screen (2a detail): headline total + grouped project cards for `date`. Tapping a
/// block opens the entry editor. Falls back to an empty state when nothing was tracked.
struct DayView: View {
    let date: Date
    @Environment(TrackingEngine.self) private var engine
    @Query(sort: \Entry.start, order: .reverse) private var entries: [Entry]
    @State private var editing: Entry?

    var body: some View {
        let summary = DaySummary.build(
            entries: entries, day: date, runningElapsed: runningElapsed, now: engine.now
        )

        Group {
            if summary.isEmpty && !runningCountsForDay {
                if isToday {
                    EmptyStateView()
                } else {
                    emptyDay
                }
            } else {
                ScrollView {
                    DayContent(summary: summary, onSelect: { editing = $0 })
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.contentBackground)
        .sheet(item: $editing) { EntryEditorView(entry: $0) }
    }

    private var isToday: Bool { Calendar.current.isDateInToday(date) }

    private var runningCountsForDay: Bool {
        isToday && (engine.runningEntry != nil || engine.isPaused)
    }

    private var runningElapsed: TimeInterval {
        guard isToday, let running = engine.runningEntry,
              Calendar.current.isDate(running.start, inSameDayAs: engine.now) else { return 0 }
        return engine.elapsed
    }

    private var emptyDay: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz")
                .font(.system(size: 34))
                .foregroundStyle(Theme.textQuaternary)
            Text("No time tracked")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(Format.longDate(date))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The scrollable body of a day: headline + cards. Pure (takes a prebuilt summary) so it
/// can be rendered outside a ScrollView.
struct DayContent: View {
    let summary: DaySummary
    var onSelect: (Entry) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header(total: summary.totalTracked)

            if summary.isEmpty {
                InProgressCard()
            } else {
                ForEach(fullCards) { ProjectCard(project: $0, onSelect: onSelect) }
                ForEach(Array(compactRows.enumerated()), id: \.offset) { _, pair in
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(pair) { CompactProjectCard(project: $0, onSelect: onSelect) }
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
            Text("tracked")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 4)
    }

    private var fullCards: [ProjectGroup] {
        summary.projects.filter { !$0.isCompact }
    }

    private var compactRows: [[ProjectGroup]] {
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
            Text((engine.currentActivity?.label ?? engine.lastActivityLabel ?? "Tracking").asDisplayLabel)
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
