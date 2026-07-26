import SwiftUI
import SwiftData

/// Projects tab (2d): color-coded project list with editing (#7). Click a row to rename /
/// recolor; right-click to archive or delete. Archived projects appear in their own section.
struct ProjectsSettingsView: View {
    @Environment(TrackingEngine.self) private var engine
    @Query(sort: \Project.order) private var projects: [Project]
    @State private var editingProject: Project?
    @State private var pendingDelete: Project?

    private var active: [Project] { projects.filter { !$0.isArchived } }
    private var archived: [Project] { projects.filter(\.isArchived) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                SettingsSectionLabel(text: "PROJECTS")
                if active.isEmpty {
                    Text("No projects yet — they're created automatically as you track time.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .groupedCard()
                } else {
                    SettingsCard {
                        ForEach(Array(active.enumerated()), id: \.element.id) { index, project in
                            if index > 0 { Hairline() }
                            row(project)
                        }
                    }
                }

                if !archived.isEmpty {
                    SettingsSectionLabel(text: "ARCHIVED").padding(.top, 8)
                    SettingsCard {
                        ForEach(Array(archived.enumerated()), id: \.element.id) { index, project in
                            if index > 0 { Hairline() }
                            row(project, isArchived: true)
                        }
                    }
                }

                Text("Click a project to rename or recolor it. Right-click to archive or delete.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
        }
        .background(Theme.contentBackground)
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

    private func row(_ project: Project, isArchived: Bool = false) -> some View {
        HStack(spacing: 10) {
            ColorSwatch(hex: project.colorHex, size: 11)
            Text(project.name)
                .font(.system(size: 13))
                .foregroundStyle(isArchived ? Theme.textTertiary : Theme.textPrimary)
            Spacer()
            Text("^[\(project.activities.count) activity](inflect: true)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textQuaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture { editingProject = project }
        .projectContextMenu(project, engine: engine,
                            onEdit: { editingProject = project },
                            onDelete: { pendingDelete = project })
    }
}
