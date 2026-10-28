import SwiftUI
import SwiftData
import Charts

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week, month
    var id: String { rawValue }
    var label: String { self == .week ? "This Week" : "This Month" }

    func interval(now: Date) -> DateInterval {
        let cal = Calendar.current
        let component: Calendar.Component = self == .week ? .weekOfYear : .month
        return cal.dateInterval(of: component, for: now) ?? DateInterval(start: now, duration: 604_800)
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

/// Statistics (2a detail): a stacked-by-project weekly bar chart with total + average.
struct StatisticsView: View {
    var body: some View {
        ScrollView { StatisticsContent() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.contentBackground)
    }
}

struct StatisticsContent: View {
    @Environment(TrackingEngine.self) private var engine
    @Query(sort: \Entry.start) private var entries: [Entry]
    @State private var period: StatsPeriod = .week

    var body: some View {
        let now = engine.now
        let model = StatsModel.build(entries: entries, interval: period.interval(now: now), now: now)

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
                Text(Format.periodRange(period.interval(now: engine.now)))
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
