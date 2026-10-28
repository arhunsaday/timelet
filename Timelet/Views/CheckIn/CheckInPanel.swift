import SwiftUI

/// What the check-in is asking about.
enum CheckInMode {
    case regular
    case away(seconds: TimeInterval)

    var isAway: Bool { if case .away = self { true } else { false } }
}

/// The "What are you working on?" check-in (screen 2b), also used for "Welcome back".
///
/// Keyboard first: type to filter, ↑↓ to choose, ⇥ to complete, ⏎ to save, ⌘1–5 to pick a
/// recent task, ⎋ to keep going. An empty field with ⏎ keeps the current task.
struct CheckInPanel: View {
    let engine: TrackingEngine
    let mode: CheckInMode
    let onDone: () -> Void

    @State private var text = ""
    @State private var note = ""
    @State private var showsNote = false
    @State private var selection: Int?
    @State private var all: [TaskSuggestion] = []
    @FocusState private var focus: Field?

    private enum Field { case task, note }

    init(engine: TrackingEngine, mode: CheckInMode, onDone: @escaping () -> Void) {
        self.engine = engine
        self.mode = mode
        self.onDone = onDone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            field
            parsedHint
            suggestionList
            if showsNote { noteField }
            buttons
            footer
        }
        .frame(width: 400)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                .strokeBorder(.primary.opacity(0.10), lineWidth: 0.5)
        )
        .onAppear {
            all = engine.allSuggestions()
            if !isTracking && !mode.isAway && !suggestions.isEmpty { selection = 0 }
            focus = .task
            DispatchQueue.main.async { focus = .task } // lands after the panel becomes key
        }
        .background(shortcutButtons)
    }

    // MARK: Derived state

    private var isTracking: Bool { engine.runningEntry != nil }
    private var currentLabel: String? { engine.currentActivity?.label }
    private var trimmed: String { text.trimmingCharacters(in: .whitespaces) }
    private var parsed: ParsedCheckIn { EntryParser.checkIn(text, now: engine.now) }

    /// Recent tasks when the field is empty, ranked matches otherwise. The typed text's own
    /// time modifier ("20m ago") is ignored for matching.
    private var suggestions: [TaskSuggestion] {
        let query = trimmed.isEmpty ? "" : (parsed.start != nil ? parsed.label : trimmed)
        let ranked = Ranking.rank(all, query: query)
        let exact = ranked.first.map { $0.label.caseInsensitiveCompare(parsed.label) == .orderedSame && !trimmed.isEmpty } ?? false
        return Array(ranked.prefix(exact && ranked.count == 1 ? 0 : 5))
    }

    /// What ⏎ would do, for the button title, the hint and the field's color dot.
    private enum Intent: Equatable { case keep, start(String), logAway(String) }

    private var chosenLabel: String? {
        selection.flatMap { suggestions.indices.contains($0) ? suggestions[$0].label : nil }
    }

    private var intent: Intent {
        if mode.isAway {
            return .logAway(chosenLabel ?? (trimmed.isEmpty ? engine.pendingResumeLabel ?? "Break" : trimmed))
        }
        if let chosen = chosenLabel {
            if chosen == currentLabel, parsed.start == nil { return .keep }
            // A picked suggestion keeps the typed time modifier: "elec 20m ago" → "Timelet:Electron… since 14:10".
            return .start(parsed.start != nil ? chosen + " " + timeSuffix : chosen)
        }
        if trimmed.isEmpty { return .keep }
        if let current = currentLabel, parsed.start == nil,
           parsed.label.caseInsensitiveCompare(EntryParser.splitLabel(current).project + ":" + EntryParser.splitLabel(current).activity) == .orderedSame {
            return .keep
        }
        return .start(trimmed)
    }

    /// Selection after an edit: the top match only when it clearly completes what was typed,
    /// so typing a new task name never silently picks an old one.
    private func autoSelection() -> Int? {
        if trimmed.isEmpty { return isTracking || mode.isAway || suggestions.isEmpty ? nil : 0 }
        guard let top = suggestions.first else { return nil }
        return Ranking.isStrongMatch(top, query: parsed.start != nil ? parsed.label : trimmed) ? 0 : nil
    }

    private var timeSuffix: String {
        guard let start = parsed.start else { return "" }
        return "since \(Format.clock(start))"
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            AppIconBadge(size: 38)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                subtitle
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var title: String {
        switch mode {
        case .regular: "What are you working on?"
        case .away: "Welcome back"
        }
    }

    @ViewBuilder private var subtitle: some View {
        switch mode {
        case .away(let seconds):
            if let away = engine.pendingAway {
                Text("You were away \(Format.timeRange(away.start, away.end)) (\(Format.duration(seconds))). What were you doing?")
            } else {
                Text("You were away for \(Format.duration(seconds)). What were you doing?")
            }
        case .regular:
            if let label = currentLabel, let entry = engine.runningEntry {
                Text("\(label.asDisplayLabel) · \(Format.duration(engine.elapsed)) since \(Format.clock(entry.start))")
            } else if engine.isPaused, let label = engine.lastActivityLabel {
                Text("Paused · last on \(label.asDisplayLabel)")
            } else {
                Text("Not tracking right now")
            }
        }
    }

    // MARK: Field

    private var field: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(Color(hex: swatchHex))
                .frame(width: 9, height: 9)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textPrimary)
                .focused($focus, equals: .task)
                .onSubmit(primary)
                .onChange(of: text) { selection = autoSelection() }
                .onKeyPress(.tab) { complete() }
                .onKeyPress(.downArrow) { move(1) }
                .onKeyPress(.upArrow) { move(-1) }
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textQuaternary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.insetRow, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                .strokeBorder(focus == .task ? Theme.accent.opacity(0.4) : Theme.border, lineWidth: focus == .task ? 2.5 : 0.5)
        )
        .padding(.horizontal, 18)
    }

    private var placeholder: String {
        if mode.isAway { return engine.pendingResumeLabel.map { "\($0.asDisplayLabel) — or Lunch, Meeting…" } ?? "Lunch, Meeting:Standup…" }
        if let current = currentLabel { return current.asDisplayLabel }
        return "Project: what you're doing"
    }

    @ViewBuilder private var parsedHint: some View {
        if let start = parsed.start, !mode.isAway {
            Label("Started at \(Format.clock(start)) · \(Format.duration(engine.now.timeIntervalSince(start))) ago",
                  systemImage: "clock.arrow.circlepath")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 22)
                .padding(.top, 7)
        } else if case .start(let label) = intent, chosenLabel == nil, !mode.isAway {
            let (project, activity) = EntryParser.splitLabel(label)
            let isNewProject = engine.projectColorHex(named: project) == nil
            (Text("⏎ starts ") + Text("\(project): \(activity)").fontWeight(.semibold)
             + Text(isNewProject ? " — new project" : "")
             + Text(trimmed.contains(":") ? "" : " · use Project: Activity to file it"))
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .padding(.horizontal, 22)
                .padding(.top, 7)
        }
    }

    // MARK: Suggestions

    @ViewBuilder private var suggestionList: some View {
        if !suggestions.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                Text(trimmed.isEmpty ? "RECENT" : "MATCHES")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.textQuaternary)
                    .tracking(0.4)
                    .padding(.horizontal, 9)
                    .padding(.bottom, 3)
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, s in
                    SuggestionRow(suggestion: s, index: index, isSelected: selection == index,
                                  isCurrent: s.label == currentLabel, now: engine.now)
                        .onTapGesture { selection = index; primary() }
                        .onHover { if $0 { selection = index } }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
        }
    }

    // MARK: Note

    private var noteField: some View {
        TextField("Note — what exactly, links, next steps…", text: $note, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 12.5))
            .foregroundStyle(Theme.textPrimary)
            .lineLimit(1...4)
            .focused($focus, equals: .note)
            .onSubmit(primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.insetRow.opacity(0.6), in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .strokeBorder(focus == .note ? Theme.accent.opacity(0.35) : Theme.border, lineWidth: focus == .note ? 2 : 0.5)
            )
            .padding(.horizontal, 18)
            .padding(.top, 10)
    }

    // MARK: Buttons

    private var buttons: some View {
        HStack(spacing: 8) {
            if mode.isAway {
                Button("I'm done for now") {
                    engine.finishAway(resume: false)
                    onDone()
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
            } else if !showsNote {
                Button {
                    showsNote = true
                    DispatchQueue.main.async { focus = .note }
                } label: { Label("Note", systemImage: "note.text.badge.plus") }
                    .buttonStyle(.borderless)
                    .font(.system(size: 12))
                    .keyboardShortcut("n", modifiers: .command)
                    .help("Add a note (⌘N)")
            }
            Spacer(minLength: 4)
            Button(action: secondary) {
                HStack(spacing: 5) {
                    Text(secondaryTitle)
                    Text("⎋").opacity(0.55)
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .keyboardShortcut(.cancelAction)
            Button(action: primary) {
                HStack(spacing: 5) {
                    Text(primaryTitle)
                    Text("⏎").opacity(0.8)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
    }

    private var primaryTitle: String {
        switch intent {
        case .keep: isTracking ? "Keep going" : "Resume"
        case .start: isTracking ? "Switch" : "Start"
        case .logAway: "Log it"
        }
    }

    private var secondaryTitle: String {
        if mode.isAway { return "Don't log" }
        return isTracking || engine.isPaused ? "Keep going" : "Not now"
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("↑↓ choose · ⇥ complete · ⌘1–5 pick")
            Spacer()
            if !mode.isAway {
                Menu {
                    if isTracking {
                        Button("Pause") { engine.pause(); onDone() }
                        Button("Stop tracking") { engine.stopTracking(); onDone() }
                    }
                    Button("Done for today") { engine.doneForToday(); onDone() }
                    Divider()
                    Button("Don't ask for 1 hour") { engine.snooze(for: 3600); engine.markCheckedIn(); onDone() }
                    Button("Don't ask until tomorrow") { engine.snoozeUntilEndOfDay(); engine.markCheckedIn(); onDone() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Pause, stop, or stop asking")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.textQuaternary)
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    /// Invisible buttons that carry ⌘1…⌘5.
    private var shortcutButtons: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Button("") { pick(i) }
                    .keyboardShortcut(KeyEquivalent(Character("\(i + 1)")), modifiers: .command)
            }
        }
        .opacity(0)
        .allowsHitTesting(false)
    }

    // MARK: Actions

    private var swatchHex: String {
        let label: String = switch intent {
        case .keep: currentLabel ?? trimmed
        case .start(let l), .logAway(let l): l
        }
        let (project, _) = EntryParser.splitLabel(label)
        return engine.projectColorHex(named: project) ?? Theme.palette[0]
    }

    private func primary() {
        switch intent {
        case .keep:
            if let current = currentLabel, !note.isEmpty { engine.track(current, note: note) } else { engine.continuePrevious() }
        case .start(let label): engine.track(label, note: note)
        case .logAway(let label): engine.logAway(as: label, note: note)
        }
        onDone()
    }

    private func secondary() {
        if mode.isAway { engine.finishAway(resume: true) } else { engine.continuePrevious() }
        onDone()
    }

    private func pick(_ index: Int) {
        guard suggestions.indices.contains(index) else { return }
        selection = index
        primary()
    }

    private func move(_ delta: Int) -> KeyPress.Result {
        let count = suggestions.count
        guard count > 0 else { return .ignored }
        if let s = selection {
            let next = s + delta
            selection = next < 0 ? nil : min(next, count - 1)
        } else {
            selection = delta > 0 ? 0 : nil
        }
        return .handled
    }

    /// Tab: put the highlighted (or top) suggestion in the field to keep editing it.
    private func complete() -> KeyPress.Result {
        let index = selection ?? 0
        guard suggestions.indices.contains(index) else { return .ignored }
        text = suggestions[index].label.asDisplayLabel + (parsed.start != nil ? " " + timeSuffix : "")
        DispatchQueue.main.async { selection = nil }
        return .handled
    }
}

private struct SuggestionRow: View {
    let suggestion: TaskSuggestion
    let index: Int
    let isSelected: Bool
    let isCurrent: Bool
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: suggestion.colorHex))
                .frame(width: 8, height: 8)
            Text(suggestion.project).foregroundStyle(Theme.textTertiary)
            Text(suggestion.activity).foregroundStyle(Theme.textPrimary).lineLimit(1)
            Spacer(minLength: 6)
            Text(isCurrent ? "now" : Format.relative(suggestion.lastUsed, now: now))
                .font(.system(size: 11))
                .foregroundStyle(isCurrent ? Theme.accent : Theme.textQuaternary)
            Text("⌘\(index + 1)")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Theme.textQuaternary)
                .frame(width: 24, alignment: .trailing)
        }
        .font(.system(size: 13))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.14) : .clear)
        )
        .contentShape(Rectangle())
    }
}
