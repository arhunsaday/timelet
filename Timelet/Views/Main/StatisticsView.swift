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

struct DailyTotal: Identifiable {
    let id: Date
    let date: Date
    let hours: Double
}

struct ProjectTotal: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let colorHex: String
    let seconds: TimeInterval
    var hours: Double { seconds / 3600 }
}

struct StatsModel {
    let daily: [DailyTotal]
    let projects: [ProjectTotal]
    let total: TimeInterval

    static func build(entries: [Entry], interval: DateInterval, now: Date) -> StatsModel {
        let cal = Calendar.current
        let completed = entries.filter {
            $0.end != nil && interval.contains($0.start) && !($0.activity?.project?.isArchived ?? false)
        }

        var byDay: [Date: TimeInterval] = [:]
        var cursor = cal.startOfDay(for: interval.start)
        while cursor < interval.end {
            byDay[cursor] = 0
            cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? interval.end
        }
        for entry in completed {
            byDay[cal.startOfDay(for: entry.start), default: 0] += entry.duration(asOf: now)
        }
        let daily = byDay
            .map { DailyTotal(id: $0.key, date: $0.key, hours: $0.value / 3600) }
            .sorted { $0.date < $1.date }

        var byProject: [PersistentIdentifier: (name: String, color: String, total: TimeInterval)] = [:]
        for entry in completed {
            guard let project = entry.activity?.project else { continue }
            byProject[project.persistentModelID, default: (project.name, project.colorHex, 0)].total += entry.duration(asOf: now)
        }
        let projects = byProject
            .map { ProjectTotal(id: $0.key, name: $0.value.name, colorHex: $0.value.color, seconds: $0.value.total) }
            .sorted { $0.seconds > $1.seconds }

        return StatsModel(daily: daily, projects: projects, total: completed.reduce(0) { $0 + $1.duration(asOf: now) })
    }
}

/// Statistics (2a detail): time by day + by project for the selected period.
struct StatisticsView: View {
    var body: some View {
        ScrollView { StatisticsContent() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.contentBackground)
    }
}

/// The scrollable body of Statistics, extracted so it renders outside a ScrollView.
struct StatisticsContent: View {
    @Environment(TrackingEngine.self) private var engine
    @Query(sort: \Entry.start) private var entries: [Entry]
    @State private var period: StatsPeriod = .week

    var body: some View {
        let now = engine.now
        let model = StatsModel.build(entries: entries, interval: period.interval(now: now), now: now)

        VStack(alignment: .leading, spacing: 16) {
                Picker("", selection: $period) {
                    ForEach(StatsPeriod.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)

                HStack(alignment: .firstTextBaseline, spacing: 9) {
                    Text(Format.duration(model.total))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .monospacedDigit()
                        .tracking(-0.5)
                    Text("tracked")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 4)

                if model.total == 0 {
                    empty
                } else {
                    card("By day") { dailyChart(model.daily) }
                    card("By project") { projectChart(model.projects) }
                }
            }
            .padding(20)
    }

    private func dailyChart(_ daily: [DailyTotal]) -> some View {
        Chart(daily) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Hours", day.hours)
            )
            .foregroundStyle(Theme.accent.gradient)
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { _ in
                AxisGridLine()
                AxisValueLabel(
                    format: period == .week
                        ? .dateTime.weekday(.abbreviated)
                        : .dateTime.day()
                )
            }
        }
        .frame(height: 200)
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

    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 34))
                .foregroundStyle(Theme.textQuaternary)
            Text("No data for this period")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}
