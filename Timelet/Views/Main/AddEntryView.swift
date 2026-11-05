import SwiftUI

/// Manual entry sheet: task + one smart "when" field (`45m`, `1h30`, `9-10:30`, `2pm to 3:15pm`,
/// optionally led by a day: `yesterday 9-10`, `mon 2pm to 3pm`) on the day being viewed. Shows
/// exactly what will be saved, and warns about overlaps. Add & Next (⌥⏎) keeps the sheet open to
/// backfill the next stretch.
struct AddEntryView: View {
    let request: AddEntryRequest
    @Environment(TrackingEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var text: String
    @State private var day: Date
    @State private var when: String
    @State private var note = ""
    /// Bumped by Add & Next to rebuild (and refocus) the task field.
    @State private var round = 0
    @State private var lastAdded: String?

    init(request: AddEntryRequest) {
        self.request = request
        _text = State(initialValue: request.text)
        _day = State(initialValue: request.start ?? request.day)
        if let s = request.start, let e = request.end {
            _when = State(initialValue: "\(Format.clock(s)) – \(Format.clock(e))")
        } else {
            _when = State(initialValue: "")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add time").font(.system(size: 15, weight: .semibold))

            labeled("Task") {
                TaskField(text: $text, autofocus: true, preferred: request.suggested)
                    .id(round)
            }

            HStack(alignment: .top, spacing: 10) {
                labeled("Day") {
                    DatePicker("", selection: $day, in: ...engine.now, displayedComponents: .date)
                        .labelsHidden()
                        .fixedSize()
                }
                labeled("When") {
                    TextField("45m · 9-10:30 · yesterday 2pm to 3pm", text: $when)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: when) { if let d = dayInWhen?.day { day = d } }
                }
            }
            interpretation

            labeled("Note") {
                TextField("Optional", text: $note, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...5)
            }

            HStack {
                if let lastAdded {
                    Label(lastAdded, systemImage: "checkmark.circle.fill")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add & Next") { add(next: true) }
                    .keyboardShortcut(.return, modifiers: .option)
                    .disabled(!canSave)
                    .help("Add, then fill the next stretch (⌥⏎)")
                Button("Add") { add() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    // MARK: Interpretation

    /// A day typed at the start of When (`yesterday 9-10`).
    private var dayInWhen: (day: Date, rest: String)? { EntryParser.leadingDay(when, now: engine.now) }

    private var interval: DateInterval? {
        let cal = Calendar.current
        let day = dayInWhen?.day ?? self.day
        let when = dayInWhen?.rest ?? self.when
        let dayStart = cal.startOfDay(for: day)
        if let range = DurationParser.timeRange(from: when) {
            let s = dayStart.addingTimeInterval(TimeInterval(range.start * 60))
            let e = dayStart.addingTimeInterval(TimeInterval(range.end * 60))
            return DateInterval(start: s, end: e)
        }
        guard let seconds = DurationParser.seconds(from: when) else { return nil }
        if cal.isDateInToday(day) {
            // Today: it just ended (or ends where the gap that opened this sheet ends).
            let end = request.end ?? engine.runningEntry?.start ?? engine.now
            return DateInterval(start: end.addingTimeInterval(-seconds), end: end)
        }
        // Another day: right after the last block that day, or at the start of work.
        let blocks = engine.entries(in: DateInterval(start: dayStart, duration: 86400))
        let start = request.start ?? blocks.compactMap(\.end).max() ?? dayStart.addingTimeInterval(9 * 3600)
        return DateInterval(start: start, duration: seconds)
    }

    private var overlap: Entry? {
        guard let i = interval else { return nil }
        return engine.entries(in: DateInterval(start: i.start.addingTimeInterval(-86400), end: i.end))
            .first { e in
                let end = e.end ?? engine.now
                return e.start < i.end && end > i.start
            }
    }

    @ViewBuilder private var interpretation: some View {
        if let i = interval {
            VStack(alignment: .leading, spacing: 3) {
                Label("\(dayPrefix(i.start))\(Format.timeRange(i.start, i.end)) · \(Format.duration(i.duration))", systemImage: "clock")
                    .foregroundStyle(Theme.accent)
                if let o = overlap, let label = o.activity?.label {
                    Label("Overlaps \(label.asDisplayLabel) (\(Format.timeRange(o.start, o.end ?? engine.now)))",
                          systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                if i.end > engine.now {
                    Label("Ends in the future", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
            .font(.system(size: 12, weight: .medium))
        } else if !(dayInWhen?.rest ?? when).isEmpty {
            Text("Try a duration (45m, 1h30) or a range (9-10:30, 2pm to 3pm).")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private var canSave: Bool {
        !text.trimmingCharacters(in: .whitespaces).isEmpty && (interval?.duration ?? 0) > 0
    }

    private func labeled(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            content().font(.system(size: 13))
        }
    }

    /// `Wed Nov 4 · ` for a day other than today.
    private func dayPrefix(_ date: Date) -> String {
        Calendar.current.isDate(date, inSameDayAs: engine.now) ? "" : "\(Format.weekdayShort(date)) \(Format.monthDay(date)) · "
    }

    private func add(next: Bool = false) {
        guard let i = interval, canSave else { return }
        engine.addEntry(text: text, start: i.start, end: i.end, note: note)
        guard next else { dismiss(); return }
        lastAdded = "Added \(EntryParser.splitLabel(text).project): \(EntryParser.splitLabel(text).activity) · \(Format.timeRange(i.start, i.end))"
        text = ""
        note = ""
        day = i.start
        // Continue from where this one ended, up to the end of the gap the sheet was opened for.
        if let gapEnd = request.end, i.end < gapEnd {
            when = "\(Format.clock(i.end)) – \(Format.clock(gapEnd))"
        } else {
            when = "\(Format.clock(i.end)) – "
        }
        round += 1
    }
}
