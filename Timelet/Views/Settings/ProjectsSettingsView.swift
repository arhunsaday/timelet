import SwiftUI
import SwiftData

/// Projects tab (2d): color-coded project/activity list. v1 is read-only; editing,
/// recoloring, and archiving are deferred (see README scope).
struct ProjectsSettingsView: View {
    @Query(sort: \Project.order) private var projects: [Project]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                SettingsSectionLabel(text: "PROJECTS")
                if projects.isEmpty {
                    Text("No projects yet — they're created automatically as you track time.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .groupedCard()
                } else {
                    SettingsCard {
                        ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                            if index > 0 { Hairline() }
                            row(project)
                        }
                    }
                }
                Text("Editing, recoloring, and archiving are coming in a later version.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
        }
        .background(Theme.contentBackground)
    }

    private func row(_ project: Project) -> some View {
        HStack(spacing: 10) {
            ColorSwatch(hex: project.colorHex, size: 11)
            Text(project.name)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            Text("^[\(project.activities.count) activity](inflect: true)")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}
