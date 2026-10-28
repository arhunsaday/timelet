import SwiftUI
import SwiftData

/// Day screen (2a detail): headline total, a timeline of the day with clickable gaps, and
/// project cards. Clicking a block opens the editor.
struct DayView: View {
    let date: Date
    @Environment(TrackingEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(UICoordinator.self) private var ui
    @Query(sort: \Entry.start, order: .reverse) private var entries: [Entry]
    @State private var editing: Entry?

    var body: some View {
        let summary = DaySummary.build(entries: entries, day: date, now: engine.now)

        Group {
            if summary.isEmpty {
                if isToday { EmptyStateView() } else { emptyDay }
            } else {
                ScrollView {
                    DayContent(summary: summary, date: date, onSelect: { editing = $0 })
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.contentBackground)
        .overlay(alignment: .bottom) { UndoBanner() }
        .sheet(item: $editing) { EntryEditorView(entry: $0) }
    }

    private var isToday: Bool { Calendar.current.isDate(date, inSameDayAs: engine.now) }

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
            Button("Add time for this day…") { ui.requestAddEntry() }
                .buttonStyle(.link)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The scrollable body of a day: headline, timeline, cards. Pure (takes a prebuilt summary)
/// so it can be rendered outside a ScrollView.
struct DayContent: View {
    let summary: DaySummary
    let date: Date
    var onSelect: (Entry) -> Void = { _ in }
    @Environment(TrackingEngine.self) private var engine
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            DayTimeline(summary: summary, date: date, onSelect: onSelect)
            ForEach(fullCards) { ProjectCard(project: $0, onSelect: onSelect) }
            ForEach(Array(compactRows.enumerated()), id: \.offset) { _, pair in
                HStack(alignment: .top, spacing: 14) {
                    ForEach(pair) { CompactProjectCard(project: $0, onSelect: onSelect) }
                    if pair.count == 1 { Color.clear.frame(maxWidth: .infinity) }
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text(Format.duration(summary.totalTracked))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .tracking(-0.5)
            Text("tracked")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            if let first = summary.blocks.first, let last = summary.blocks.last {
                Text("\(Format.clock(first.start)) – \(last.isRunning ? "now" : Format.clock(last.end))")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 4)
    }

    private var fullCards: [ProjectGroup] { summary.projects.filter { !$0.isCompact } }

    private var compactRows: [[ProjectGroup]] {
        let compact = summary.projects.filter(\.isCompact)
        return stride(from: 0, to: compact.count, by: 2).map { Array(compact[$0..<min($0 + 2, compact.count)]) }
    }
}

/// The day as a horizontal strip: colored blocks, an hour scale, and dashed gaps that open
/// "Add time" prefilled with that stretch.
struct DayTimeline: View {
    let summary: DaySummary
    let date: Date
    var onSelect: (Entry) -> Void
    @Environment(TrackingEngine.self) private var engine
    @Environment(AppSettings.self) private var settings
    @Environment(UICoordinator.self) private var ui
    @State private var hovered: String?

    private var isToday: Bool { Calendar.current.isDate(date, inSameDayAs: engine.now) }

    /// Work hours, widened to fit everything tracked, in whole hours.
    private var range: DateInterval {
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        var start = day.addingTimeInterval(TimeInterval(settings.workStartMinutes * 60))
        var end = day.addingTimeInterval(TimeInterval(settings.workEndMinutes * 60))
        if let first = summary.blocks.first?.start { start = min(start, first) }
        if let last = summary.blocks.map(\.end).max() { end = max(end, last) }
        if isToday { end = max(end, engine.now) }
        start = cal.dateInterval(of: .hour, for: start)?.start ?? start
        end = cal.dateInterval(of: .hour, for: end.addingTimeInterval(-1))?.end ?? end
        return DateInterval(start: start, end: max(end, start.addingTimeInterval(3600)))
    }

    private var gaps: [DateInterval] {
        let r = range
        let workStart = Calendar.current.startOfDay(for: date).addingTimeInterval(TimeInterval(settings.workStartMinutes * 60))
        let from = max(r.start, min(summary.blocks.first?.start ?? workStart, workStart))
        let to = isToday ? min(engine.now, r.end) : (summary.blocks.map(\.end).max() ?? r.end)
        return summary.gaps(from: from, to: to)
    }

    var body: some View {
        let r = range
        let untracked = gaps.reduce(0) { $0 + $1.duration }
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                let x = { (d: Date) -> CGFloat in CGFloat(d.timeIntervalSince(r.start) / r.duration) * geo.size.width }
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.fieldTint)
                    ForEach(gaps, id: \.start) { g in
                        let id = "gap-\(g.start.timeIntervalSince1970)"
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .foregroundStyle(hovered == id ? Theme.accent : Theme.textQuaternary.opacity(0.6))
                            .background(hovered == id ? Theme.accent.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 5))
                            .overlay { if x(g.end) - x(g.start) > 22 { Image(systemName: "plus").font(.system(size: 10, weight: .semibold)).foregroundStyle(hovered == id ? Theme.accent : Theme.textQuaternary) } }
                            .frame(width: max(4, x(g.end) - x(g.start) - 2), height: 26)
                            .offset(x: x(g.start) + 1, y: 3)
                            .onHover { hovered = $0 ? id : nil }
                            .onTapGesture { ui.requestAddEntry(start: g.start, end: g.end) }
                            .help("Untracked \(Format.timeRange(g.start, g.end)) (\(Format.duration(g.duration))) — click to fill")
                    }
                    ForEach(summary.blocks) { b in
                        let id = "\(b.id)"
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color(hex: b.colorHex).opacity(hovered == id ? 1 : 0.85))
                            .overlay(alignment: .trailing) {
                                if b.isRunning { PulsingDot(color: .white, size: 6).padding(.trailing, 4) }
                            }
                            .frame(width: max(3, x(b.end) - x(b.start) - 1), height: 26)
                            .offset(x: x(b.start), y: 3)
                            .onHover { hovered = $0 ? id : nil }
                            .onTapGesture { onSelect(b.entry) }
                            .help("\(b.entry.activity?.label.asDisplayLabel ?? b.name) · \(Format.timeRange(b.start, b.end)) · \(Format.duration(b.total))")
                    }
                    if isToday, engine.now < r.end {
                        Rectangle().fill(Theme.accent).frame(width: 1.5, height: 32).offset(x: x(engine.now))
                    }
                }
            }
            .frame(height: 32)

            GeometryReader { geo in
                let hours = Int((r.duration / 3600).rounded())
                let step = hours > 12 ? 3 : (hours > 7 ? 2 : 1)
                ForEach(Array(stride(from: 0, through: hours, by: step)), id: \.self) { h in
                    Text(Format.clock(r.start.addingTimeInterval(TimeInterval(h * 3600))))
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textQuaternary)
                        .monospacedDigit()
                        .fixedSize()
                        .position(x: CGFloat(h) / CGFloat(max(hours, 1)) * geo.size.width, y: 6)
                }
            }
            .frame(height: 12)
            .padding(.horizontal, 12)

            if untracked >= 15 * 60 {
                Text("\(Format.duration(untracked)) untracked\(isToday ? " so far" : "") · click a dashed gap to fill it")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, 2)
            }
        }
        .padding(12)
        .groupedCard()
    }
}

/// "Entry deleted · Undo", shown for a few seconds after a delete.
struct UndoBanner: View {
    @Environment(TrackingEngine.self) private var engine

    var body: some View {
        if let deleted = engine.recentlyDeleted {
            HStack(spacing: 12) {
                Image(systemName: "trash").foregroundStyle(Theme.textTertiary)
                Text("Deleted \(deleted.label.asDisplayLabel) (\(Format.duration(deleted.end.timeIntervalSince(deleted.start))))")
                    .lineLimit(1)
                Button("Undo") { engine.undoDelete() }
                    .buttonStyle(.link)
                    .keyboardShortcut("z", modifiers: .command)
            }
            .font(.system(size: 12.5))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .padding(.bottom, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .task(id: deleted) {
                try? await Task.sleep(for: .seconds(8))
                if engine.recentlyDeleted == deleted { withAnimation { engine.forgetDeleted() } }
            }
        }
    }
}
