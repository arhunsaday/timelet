import SwiftUI
import SwiftData

/// One task of a project, with all-time totals.
struct ProjectTask: Identifiable {
    let id: PersistentIdentifier
    let label: String
    let name: String
    let total: TimeInterval
    let lastUsed: Date
}

/// A project's history: totals for this week, this month and all time, its tasks, and the
/// latest blocks.
struct ProjectModel {
    let week: TimeInterval
    let month: TimeInterval
    let allTime: TimeInterval
    let tasks: [ProjectTask]
    let recent: [Entry]

    static func build(project: Project, now: Date, recentLimit: Int = 30) -> ProjectModel {
        let cal = Calendar.current
        let week = cal.dateInterval(of: .weekOfYear, for: now)
        let month = cal.dateInterval(of: .month, for: now)
        var w: TimeInterval = 0, m: TimeInterval = 0, all: TimeInterval = 0
        var tasks: [ProjectTask] = []
        var entries: [Entry] = []
        for activity in project.activities {
            var total: TimeInterval = 0
            var last = Date.distantPast
            for entry in activity.entries {
                let d = entry.duration(asOf: now)
                total += d
                last = max(last, entry.start)
                if week?.contains(entry.start) ?? false { w += d }
                if month?.contains(entry.start) ?? false { m += d }
                entries.append(entry)
            }
            all += total
            if !activity.entries.isEmpty {
                tasks.append(ProjectTask(id: activity.persistentModelID, label: activity.label, name: activity.name,
                                         total: total, lastUsed: last))
            }
        }
        let recent = entries.sorted { $0.start > $1.start }.prefix(recentLimit)
        return ProjectModel(week: w, month: m, allTime: all, tasks: tasks.sorted { $0.total > $1.total }, recent: Array(recent))
    }
}

struct ProjectDetailView: View {
    let project: Project
    @Environment(TrackingEngine.self) private var engine
    @State private var editing: Entry?

    var body: some View {
        ScrollView {
            ProjectDetailContent(project: project, now: engine.now, onSelect: { editing = $0 })
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.contentBackground)
        .overlay(alignment: .bottom) { UndoBanner() }
        .sheet(item: $editing) { EntryEditorView(entry: $0) }
    }
}

/// The scrollable body of a project, extracted so it renders outside a ScrollView.
struct ProjectDetailContent: View {
    let project: Project
    let now: Date
    var onSelect: (Entry) -> Void = { _ in }
    @Environment(TrackingEngine.self) private var engine

    var body: some View {
        let model = ProjectModel.build(project: project, now: now)
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                stat("This week", model.week)
                stat("This month", model.month)
                stat("All time", model.allTime)
            }

            if model.tasks.isEmpty {
                Text("Nothing tracked on \(project.name) yet")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else {
                section("Tasks") {
                    ForEach(Array(model.tasks.enumerated()), id: \.element.id) { index, task in
                        if index > 0 { Hairline() }
                        TaskRow(task: task, share: task.total / max(model.allTime, 1), colorHex: project.colorHex, now: now)
                    }
                }
                section("Latest") {
                    ForEach(Array(model.recent.enumerated()), id: \.element.persistentModelID) { index, entry in
                        if index > 0 { Hairline() }
                        RecentRow(entry: entry, now: now, onEdit: { onSelect(entry) })
                    }
                }
            }
        }
    }

    private func stat(_ title: String, _ value: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            Text(Format.duration(value))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .groupedCard()
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Theme.cardHeaderBackground)
            Hairline(color: Theme.stroke)
            content()
        }
        .groupedCard()
    }
}

private struct TaskRow: View {
    let task: ProjectTask
    let share: Double
    let colorHex: String
    let now: Date
    @Environment(TrackingEngine.self) private var engine
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Text(task.name)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Format.relative(task.lastUsed, now: now))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textQuaternary)
            Capsule()
                .fill(Theme.fieldTint)
                .frame(width: 80, height: 5)
                .overlay(alignment: .leading) {
                    Capsule().fill(Color(hex: colorHex)).frame(width: max(3, 80 * share), height: 5)
                }
            Text(Format.duration(task.total))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
            Button { engine.track(task.label) } label: {
                Image(systemName: "play.fill").font(.system(size: 9))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Theme.accent)
            .opacity(hovering && engine.currentActivity?.label != task.label ? 1 : 0)
            .help("Track this now")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(hovering ? Theme.accent.opacity(0.06) : .clear)
        .onHover { hovering = $0 }
    }
}

private struct RecentRow: View {
    let entry: Entry
    let now: Date
    let onEdit: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Text("\(Format.weekdayShort(entry.start)) \(Format.monthDay(entry.start))")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 84, alignment: .leading)
            Text(entry.isRunning ? "\(Format.clock(entry.start)) – now" : Format.timeRange(entry.start, entry.end ?? now))
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textTertiary)
                .monospacedDigit()
                .frame(width: 108, alignment: .leading)
            Text(entry.activity?.name ?? "")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            if entry.trimmedNote != nil {
                Image(systemName: "note.text").font(.system(size: 10)).foregroundStyle(Theme.textQuaternary)
            }
            Spacer(minLength: 6)
            Text(Format.duration(entry.duration(asOf: now)))
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(entry.isRunning ? Theme.accent : Theme.textPrimary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(hovering ? Theme.accent.opacity(0.06) : .clear)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .onHover { hovering = $0 }
        .help(entry.trimmedNote ?? "Edit")
    }
}
