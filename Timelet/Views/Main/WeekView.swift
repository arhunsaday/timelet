import SwiftUI
import SwiftData

struct WeekRow: Identifiable {
    let id: PersistentIdentifier
    let entry: Entry
    let label: String
    let colorHex: String
    let start: Date
    let end: Date
    let total: TimeInterval
}

struct WeekDay: Identifiable {
    let id: Date
    let date: Date
    let total: TimeInterval
    let rows: [WeekRow]
}

struct WeekModel {
    let days: [WeekDay]
    /// Per-project totals for the week, largest first.
    let projects: [ProjectTotal]
    let total: TimeInterval
    var isEmpty: Bool { days.isEmpty }

    static func build(entries: [Entry], weekDate: Date, now: Date) -> WeekModel {
        let cal = Calendar.current
        let interval = Format.weekInterval(weekDate)
        let completed = entries.filter { entry in
            return interval.contains(entry.start) && !(entry.activity?.project?.isArchived ?? false)
        }

        var byDay: [Date: [WeekRow]] = [:]
        var byProject: [PersistentIdentifier: ProjectTotal] = [:]
        for entry in completed {
            guard let activity = entry.activity, let project = activity.project else { continue }
            let end = entry.end ?? now
            let dayStart = cal.startOfDay(for: entry.start)
            let row = WeekRow(
                id: entry.persistentModelID, entry: entry, label: activity.label,
                colorHex: project.colorHex, start: entry.start, end: end,
                total: entry.duration(asOf: now)
            )
            byDay[dayStart, default: []].append(row)
            let id = project.persistentModelID
            byProject[id] = ProjectTotal(id: id, name: project.name, colorHex: project.colorHex,
                                         seconds: (byProject[id]?.seconds ?? 0) + row.total)
        }

        let days = byDay.map { dayStart, rows -> WeekDay in
            let sorted = rows.sorted { $0.start < $1.start }
            return WeekDay(id: dayStart, date: dayStart, total: sorted.reduce(0) { $0 + $1.total }, rows: sorted)
        }
        .sorted { $0.date < $1.date }

        return WeekModel(days: days, projects: byProject.values.sorted { $0.seconds > $1.seconds },
                         total: days.reduce(0) { $0 + $1.total })
    }
}

/// This Week (2a detail): the selected week grouped by day. Navigation lives in the toolbar.
struct WeekView: View {
    let weekDate: Date
    @Environment(TrackingEngine.self) private var engine
    @Environment(UICoordinator.self) private var ui
    @Query private var entries: [Entry]
    @State private var editing: Entry?

    init(weekDate: Date) {
        self.weekDate = weekDate
        _entries = Query(filter: Entry.starting(in: Format.weekInterval(weekDate)), sort: \Entry.start)
    }

    var body: some View {
        let model = WeekModel.build(entries: entries, weekDate: weekDate, now: engine.now)
        Group {
            if model.isEmpty {
                empty
            } else {
                ScrollView {
                    WeekContent(model: model, now: engine.now, onSelect: { editing = $0 },
                                onOpenDay: { day in
                                    ui.selectedDate = day
                                    ui.selection = .today
                                })
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.contentBackground)
        .sheet(item: $editing) { EntryEditorView(entry: $0) }
    }

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 34))
                .foregroundStyle(Theme.textQuaternary)
            Text("No time tracked this week")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(Format.weekSubtitle(weekDate))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The scrollable body of This Week, extracted so it renders outside a ScrollView.
struct WeekContent: View {
    let model: WeekModel
    let now: Date
    var onSelect: (Entry) -> Void = { _ in }
    var onOpenDay: (Date) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Text(Format.duration(model.total))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .tracking(-0.5)
                Text("this week")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, 4)

            if model.projects.count > 1 { WeekProjectsCard(projects: model.projects, total: model.total) }

            ForEach(model.days) { day in
                DayCard(day: day, now: now, onSelect: onSelect, onOpen: { onOpenDay(day.date) })
            }
        }
    }
}

/// The week split by project: one proportional bar and a total per project.
private struct WeekProjectsCard: View {
    let projects: [ProjectTotal]
    let total: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(projects) { p in
                        Rectangle()
                            .fill(Color(hex: p.colorHex))
                            .frame(width: max(2, (geo.size.width - CGFloat(projects.count - 1) * 2) * p.seconds / max(total, 1)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .frame(height: 8)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16, alignment: .leading)], alignment: .leading, spacing: 8) {
                ForEach(projects) { p in
                    HStack(spacing: 7) {
                        ColorSwatch(hex: p.colorHex, size: 9)
                        Text(p.name)
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                        Text(Format.duration(p.seconds))
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.textPrimary)
                            .monospacedDigit()
                    }
                    .font(.system(size: 12))
                }
            }
        }
        .padding(14)
        .groupedCard()
    }
}

private struct DayCard: View {
    let day: WeekDay
    let now: Date
    var onSelect: (Entry) -> Void
    var onOpen: () -> Void
    @State private var hoveringHeader = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(Format.weekdayShort(day.date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(Format.monthDay(day.date))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                Spacer()
                if Calendar.current.isDate(day.date, inSameDayAs: now) {
                    Text("Today")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.accentTint, in: Capsule())
                }
                Text(Format.duration(day.total))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .opacity(hoveringHeader ? 1 : 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(hoveringHeader ? Theme.accent.opacity(0.06) : Theme.cardHeaderBackground)
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)
            .onHover { hoveringHeader = $0 }
            .help("Open \(Format.longDate(day.date))")
            Hairline(color: Theme.stroke)

            ForEach(Array(day.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Hairline() }
                WeekEntryRow(row: row, onEdit: { onSelect(row.entry) })
            }
        }
        .groupedCard()
    }
}

private struct WeekEntryRow: View {
    let row: WeekRow
    let onEdit: () -> Void
    @State private var expanded = false
    @State private var hovering = false

    var body: some View {
        let note = row.entry.trimmedNote
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ColorSwatch(hex: row.colorHex, size: 9)
                Text(row.entry.isRunning ? "\(Format.clock(row.start)) – now" : Format.timeRange(row.start, row.end))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
                    .frame(width: 108, alignment: .leading)
                Text(row.label.asDisplayLabel)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if row.entry.isRunning { PulsingDot(size: 6) }
                Text(Format.duration(row.total))
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(row.entry.isRunning ? Theme.accent : Theme.textPrimary)
                    .monospacedDigit()
                if note != nil { DisclosureChevron(expanded: $expanded) }
            }
            .padding(.leading, 14)
            .padding(.trailing, note != nil ? 8 : 14)
            .padding(.vertical, 9)
            .background(hovering ? Theme.accent.opacity(0.06) : .clear)
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }
            .onHover { hovering = $0 }

            if let note, expanded {
                EntryNoteView(note: note, leadingInset: 33)
            }
        }
    }
}
