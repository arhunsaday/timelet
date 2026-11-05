import SwiftUI

/// Edit sheet for a tracked block: rename / move project, adjust the interval, note, delete,
/// or start the same task again.
struct EntryEditorView: View {
    let entry: Entry
    @Environment(TrackingEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var start: Date
    @State private var end: Date
    @State private var note: String

    init(entry: Entry) {
        self.entry = entry
        _text = State(initialValue: entry.activity?.label.asDisplayLabel ?? "")
        _start = State(initialValue: entry.start)
        _end = State(initialValue: entry.end ?? .now)
        _note = State(initialValue: entry.note ?? "")
    }

    private var isRunning: Bool { entry.end == nil }
    private var duration: TimeInterval { max(0, (isRunning ? engine.now : end).timeIntervalSince(start)) }
    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && (isRunning || end > start)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(isRunning ? "Edit running task" : "Edit entry").font(.system(size: 15, weight: .semibold))
                Spacer()
                Text(Format.duration(duration))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .monospacedDigit()
            }

            labeled("Task") { TaskField(text: $text) }

            HStack(alignment: .top, spacing: 16) {
                labeled("Start") {
                    VStack(alignment: .leading, spacing: 6) {
                        DatePicker("", selection: $start, in: ...(isRunning ? engine.now : end), displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                        nudges { m in
                            let latest = (isRunning ? engine.now : end).addingTimeInterval(-60)
                            start = min(latest, start.addingTimeInterval(TimeInterval(m * 60)))
                        }
                    }
                }
                if !isRunning {
                    labeled("End") {
                        VStack(alignment: .leading, spacing: 6) {
                            DatePicker("", selection: $end, in: start..., displayedComponents: [.hourAndMinute])
                                .labelsHidden()
                            nudges { m in end = max(start.addingTimeInterval(60), end.addingTimeInterval(TimeInterval(m * 60))) }
                        }
                    }
                }
            }

            labeled("Note") {
                TextField("Optional — details, links, next steps…", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...6)
            }

            HStack {
                Button(role: .destructive) {
                    engine.deleteEntry(entry)
                    dismiss()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .keyboardShortcut(.delete, modifiers: .command)
                .help("Delete (⌘⌫) — you can undo it")
                if !isRunning {
                    Button {
                        engine.resume(entry)
                        dismiss()
                    } label: {
                        Label("Track again", systemImage: "play.fill")
                    }
                    .help("Start this task again now")
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
        .frame(width: 440)
    }

    /// −15 −5 +5 +15 minute steps for one end of the interval.
    private func nudges(_ apply: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 4) {
            ForEach([-15, -5, 5, 15], id: \.self) { m in
                Button(m > 0 ? "+\(m)" : "−\(-m)") { apply(m) }
                    .controlSize(.small)
                    .monospacedDigit()
                    .help("\(m > 0 ? "Later" : "Earlier") by \(abs(m)) minutes")
            }
        }
    }

    private func labeled(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            content().font(.system(size: 13))
        }
    }
}
