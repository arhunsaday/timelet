import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case today, week, statistics
}

/// Vibrancy sidebar (2a): nav rows, a Projects section with per-project day totals,
/// and a pinned Settings row.
struct Sidebar: View {
    @Binding var selection: SidebarItem
    @Environment(TrackingEngine.self) private var engine
    @Query(sort: \Project.order) private var projects: [Project]
    @Query private var entries: [Entry]

    var body: some View {
        let totals = TodaySummary.projectTotals(entries: entries, now: engine.now)
        List(selection: $selection) {
            Label("Today", systemImage: "calendar").tag(SidebarItem.today)
            Label("This Week", systemImage: "calendar.badge.clock").tag(SidebarItem.week)
            Label("Statistics", systemImage: "chart.bar").tag(SidebarItem.statistics)

            Section("Projects") {
                ForEach(projects.filter { !$0.isArchived }) { project in
                    projectRow(project, total: totals[project.persistentModelID] ?? 0)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom, spacing: 0) { settingsRow }
    }

    private func projectRow(_ project: Project, total: TimeInterval) -> some View {
        HStack(spacing: 9) {
            ColorSwatch(hex: project.colorHex, size: 10)
            Text(project.name)
                .font(.system(size: 13))
            Spacer(minLength: 4)
            Text(Format.durationCompact(total))
                .font(.system(size: 11))
                .foregroundStyle(Theme.textQuaternary)
                .monospacedDigit()
        }
    }

    private var settingsRow: some View {
        VStack(spacing: 0) {
            Divider()
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }
}
