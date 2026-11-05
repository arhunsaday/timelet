import SwiftUI
import SwiftData
import Charts

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week, month
    var id: String { rawValue }
    var label: String { self == .week ? "Week" : "Month" }
    var component: Calendar.Component { self == .week ? .weekOfYear : .month }

    /// The week or month containing `date`.
    func interval(containing date: Date) -> DateInterval {
        Calendar.current.dateInterval(of: component, for: date) ?? DateInterval(start: date, duration: 604_800)
    }

    /// `This Week` / `Last Week` / `Week of Jul 14`, or `This Month` / `Last Month` / `March 2026`.
    func title(_ date: Date, now: Date) -> String {
        if self == .week { return Format.weekTitle(date, now: now) }
        let cal = Calendar.current
        if cal.isDate(date, equalTo: now, toGranularity: .month) { return "This Month" }
        if let last = cal.date(byAdding: .month, value: -1, to: now), cal.isDate(date, equalTo: last, toGranularity: .month) {
            return "Last Month"
        }
        return Format.monthYear(date)
    }
}

/// One project's colored slice of a day's stacked bar.
struct DaySegment: Identifiable {
    let id: String
    let colorHex: String
    let hours: Double
}

/// One day's stacked bar (all its project segments).
struct DayBar: Identifiable {
    let id: Date
    let date: Date
    let total: TimeInterval
    let segments: [DaySegment]
    var isEmpty: Bool { total <= 0 }
}

struct ProjectTotal: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let colorHex: String
    let seconds: TimeInterval
    var hours: Double { seconds / 3600 }
}

struct StatsModel {
    let days: [DayBar]
    let projects: [ProjectTotal]
    let total: TimeInterval
    let elapsedDays: Int
    let maxDayHours: Double

    /// Average over calendar days elapsed in the period (so zero days count).
    var avgPerDay: TimeInterval { elapsedDays > 0 ? total / Double(elapsedDays) : 0 }

    static func build(entries: [Entry], interval: DateInterval, now: Date) -> StatsModel {
        let cal = Calendar.current
        let completed = entries.filter {
            interval.contains($0.start) && !($0.activity?.project?.isArchived ?? false)
        }

        // Per-project totals (also drives a consistent stacking order across days).
        var byProject: [PersistentIdentifier: (name: String, color: String, total: TimeInterval)] = [:]
        for entry in completed {
            guard let project = entry.activity?.project else { continue }
            byProject[project.persistentModelID, default: (project.name, project.colorHex, 0)].total += entry.duration(asOf: now)
        }
        let projects = byProject
            .map { ProjectTotal(id: $0.key, name: $0.value.name, colorHex: $0.value.color, seconds: $0.value.total) }
            .sorted { $0.seconds > $1.seconds }
        let order = Dictionary(uniqueKeysWithValues: projects.enumerated().map { ($0.element.id, $0.offset) })

        var days: [DayBar] = []
        var cursor = cal.startOfDay(for: interval.start)
        while cursor < interval.end {
            var perProject: [PersistentIdentifier: (color: String, seconds: TimeInterval)] = [:]
            for entry in completed where cal.isDate(entry.start, inSameDayAs: cursor) {
                guard let project = entry.activity?.project else { continue }
                perProject[project.persistentModelID, default: (project.colorHex, 0)].seconds += entry.duration(asOf: now)
            }
            let total = perProject.values.reduce(0) { $0 + $1.seconds }
            // Emit smallest-ranked project first (bottom) so the biggest sits on top.
            let segments = perProject
                .sorted { (order[$0.key] ?? .max) > (order[$1.key] ?? .max) }
                .map { DaySegment(id: "\(cursor.timeIntervalSince1970)-\($0.key.hashValue)",
                                  colorHex: $0.value.color, hours: $0.value.seconds / 3600) }
            days.append(DayBar(id: cursor, date: cursor, total: total, segments: segments))
            cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? interval.end
        }

        let today = cal.startOfDay(for: now)
        return StatsModel(
            days: days,
            projects: projects,
            total: completed.reduce(0) { $0 + $1.duration(asOf: now) },
            elapsedDays: max(1, days.filter { $0.date <= today }.count),
            maxDayHours: days.map { $0.total / 3600 }.max() ?? 0
        )
    }
}

/// Statistics (2a detail): a stacked-by-project bar chart for the selected week or month, with
/// total + average. The period and paging live in the toolbar.
struct StatisticsView: View {
    let period: StatsPeriod
    let date: Date

    var body: some View {
        ScrollView { StatisticsContent(period: period, date: date) }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.contentBackground)
    }
}

struct StatisticsContent: View {
    let period: StatsPeriod
    let interval: DateInterval
    @Environment(TrackingEngine.self) private var engine
    @Query private var entries: [Entry]

    init(period: StatsPeriod, date: Date) {
        self.period = period
        interval = period.interval(containing: date)
        _entries = Query(filter: Entry.starting(in: interval), sort: \Entry.start)
    }

    var body: some View {
        let model = StatsModel.build(entries: entries, interval: interval, now: engine.now)

        VStack(alignment: .leading, spacing: 18) {
            header(model)
            dailyChart(model)

            if !model.projects.isEmpty {
                card("By project") { projectChart(model.projects) }
            }
        }
        .padding(20)
    }

    // MARK: Header (range · total · avg/day)

    private func header(_ model: StatsModel) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Format.periodRange(interval))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .tracking(0.5)
                Text(Format.duration(model.total))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                    .tracking(-0.5)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("avg / day")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                Text(Format.duration(model.avgPerDay))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .monospacedDigit()
            }
        }
    }

    // MARK: Charts

    private func dailyChart(_ model: StatsModel) -> some View {
        let stub = max(0.18, model.maxDayHours * 0.04)
        return Chart {
            ForEach(model.days) { day in
                if day.isEmpty {
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("Hours", stub))
                        .foregroundStyle(Theme.textQuaternary.opacity(0.22))
                        .cornerRadius(5)
                } else {
                    ForEach(day.segments) { segment in
                        BarMark(x: .value("Day", day.date, unit: .day), y: .value("Hours", segment.hours))
                            .foregroundStyle(Color(hex: segment.colorHex))
                            .cornerRadius(5)
                            .annotation(position: .top, spacing: 4) {
                                if period == .week, segment.id == day.segments.last?.id {
                                    Text(Format.duration(day.total))
                                        .font(.system(size: 10.5, weight: .medium))
                                        .foregroundStyle(Theme.textTertiary)
                                        .monospacedDigit()
                                }
                            }
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { _ in
                AxisValueLabel(
                    format: period == .week ? .dateTime.weekday(.abbreviated) : .dateTime.day()
                )
            }
        }
        .frame(height: 240)
    }

    private func projectChart(_ projects: [ProjectTotal]) -> some View {
        Chart(projects) { project in
            BarMark(
                x: .value("Hours", project.hours),
                y: .value("Project", project.name)
            )
            .foregroundStyle(Color(hex: project.colorHex))
            .cornerRadius(4)
            .annotation(position: .trailing, alignment: .leading) {
                Text(Format.duration(project.seconds))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
            }
        }
        .chartXAxis(.hidden)
        .frame(height: CGFloat(max(1, projects.count)) * 40 + 12)
    }

    private func card(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .groupedCard()
    }
}
