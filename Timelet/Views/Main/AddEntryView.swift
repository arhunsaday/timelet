import SwiftUI

/// Manual entry sheet (toolbar `+`): `Group:Activity` + a natural-language duration.
struct AddEntryView: View {
    @Environment(TrackingEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var durationText = ""
    @FocusState private var focus: Field?

    private enum Field { case task, duration }

    private var parsed: TimeInterval? { DurationParser.seconds(from: durationText) }
    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && (parsed ?? 0) > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add entry")
                .font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 10) {
                labeled("Task") {
                    TextField("Group:Activity", text: $text)
                        .focused($focus, equals: .task)
                }
                labeled("Duration") {
                    HStack(spacing: 8) {
                        TextField("e.g. 45m, 1h30", text: $durationText)
                            .focused($focus, equals: .duration)
                        if let parsed {
                            Text(Format.duration(parsed))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.accent)
                                .monospacedDigit()
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { add() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear { focus = .task }
    }

    private func labeled(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            content()
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
        }
    }

    private func add() {
        guard let parsed else { return }
        engine.addManualEntry(text: text, duration: parsed)
        dismiss()
    }
}
