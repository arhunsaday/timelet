import SwiftUI

/// Edit a project's name + color (#7). Reached by clicking a project in the sidebar or the
/// Projects settings tab. Delete lives here too; archive is on the context menu.
struct ProjectEditorView: View {
    let project: Project
    @Environment(TrackingEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var colorHex: String
    @State private var confirmingDelete = false

    init(project: Project) {
        self.project = project
        _name = State(initialValue: project.name)
        _colorHex = State(initialValue: project.colorHex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit project").font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13))
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Color")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 30), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        ForEach(Theme.palette, id: \.self) { hex in
                            swatch(hex)
                        }
                    }
                }
            }

            HStack {
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Label("Delete", systemImage: "trash")
                }
                .confirmationDialog("Delete “\(project.name)” and all its entries?",
                                    isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) { engine.deleteProject(project); dismiss() }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func swatch(_ hex: String) -> some View {
        let selected = colorHex.caseInsensitiveCompare(hex) == .orderedSame
        return Button { colorHex = hex } label: {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(.white, lineWidth: selected ? 2 : 0))
                .overlay(Circle().strokeBorder(Theme.border, lineWidth: 0.5))
                .scaleEffect(selected ? 1.15 : 1)
                .shadow(color: .black.opacity(selected ? 0.22 : 0), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.2), value: selected)
    }

    private func save() {
        engine.renameProject(project, to: name)
        engine.setProjectColor(project, hex: colorHex)
        dismiss()
    }
}

extension View {
    /// Shared right-click menu for a project (edit / archive / delete).
    func projectContextMenu(
        _ project: Project,
        engine: TrackingEngine,
        onEdit: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        contextMenu {
            Button("Edit…", action: onEdit)
            Button(project.isArchived ? "Unarchive" : "Archive") {
                engine.setProjectArchived(project, !project.isArchived)
            }
            Divider()
            Button("Delete…", role: .destructive, action: onDelete)
        }
    }
}
