import SwiftUI

/// Edit sheet for a tracked block (#1): rename / move group, adjust the interval, or delete.
struct EntryEditorView: View {
    let entry: Entry
    @Environment(TrackingEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var start: Date
    @State private var end: Date
    @State private var note: String
    @State private var confirmingDelete = false
    @FocusState private var taskFocused: Bool

    init(entry: Entry) {
        self.entry = entry
        _text = State(initialValue: entry.activity?.label ?? "")
        _start = State(initialValue: entry.start)
        _end = State(initialValue: entry.end ?? .now)
        _note = State(initialValue: entry.note ?? "")
    }

    private var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && end > start
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Edit entry").font(.system(size: 15, weight: .semibold))

            VStack(alignment: .leading, spacing: 10) {
                labeled("Task") {
                    TextField("Group:Activity", text: $text)
                        .textFieldStyle(.roundedBorder)
                        .focused($taskFocused)
                }
                labeled("Start") {
                    DatePicker("", selection: $start, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                }
                labeled("End") {
                    HStack(spacing: 8) {
                        DatePicker("", selection: $end, in: start..., displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                        Spacer()
                        Text(Format.duration(duration))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .monospacedDigit()
                    }
                }
                labeled("Notes") {
                    TextField("Optional — details, next-day plan…", text: $note, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...6)
                }
            }

            HStack {
                Button(role: .destructive) { confirmingDelete = true } label: {
                    Label("Delete", systemImage: "trash")
                }
                .confirmationDialog("Delete this entry?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("Delete", role: .destructive) {
                        engine.deleteEntry(entry)
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") {
                    engine.updateEntry(entry, text: text, start: start, end: end, note: note)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func labeled(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            content()
                .font(.system(size: 13))
        }
    }
}
