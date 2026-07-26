import SwiftUI
import SwiftData

enum SidebarItem: Hashable {
    case today, week, statistics
}

/// Vibrancy sidebar (2a): nav rows, a Projects section with per-project day totals + inline
/// editing (click to edit name/color, right-click to archive/delete), and a Settings row.
struct Sidebar: View {
    @Binding var selection: SidebarItem
    @Environment(TrackingEngine.self) private var engine
    @Query(sort: \Project.order) private var projects: [Project]
    @Query private var entries: [Entry]
    @State private var editingProject: Project?
    @State private var pendingDelete: Project?

    var body: some View {
        let totals = DaySummary.projectTotals(entries: entries, day: engine.now, now: engine.now)
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
        .sheet(item: $editingProject) { ProjectEditorView(project: $0) }
        .confirmationDialog(
            "Delete this project and all its entries?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible,
            presenting: pendingDelete
        ) { project in
            Button("Delete “\(project.name)”", role: .destructive) {
                engine.deleteProject(project)
                pendingDelete = nil
            }
        }
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
        .contentShape(Rectangle())
        .onTapGesture { editingProject = project }
        .projectContextMenu(project, engine: engine,
                            onEdit: { editingProject = project },
                            onDelete: { pendingDelete = project })
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
