import SwiftUI

/// What the check-in is asking about.
enum CheckInMode {
    case regular(intervalMinutes: Int)
    case idle(awaySeconds: TimeInterval)

    var title: String {
        switch self {
        case .regular: "What are you working on?"
        case .idle: "Welcome back"
        }
    }
    var subtitle: String {
        switch self {
        case .regular(let minutes): "Tracking the last \(minutes) minutes"
        case .idle(let seconds): "You were away for \(Format.duration(seconds)). What were you doing?"
        }
    }
    var primaryTitle: String {
        switch self {
        case .regular: "Save"
        case .idle: "Log"
        }
    }
    var secondaryTitle: String {
        switch self {
        case .regular: "Continue previous"
        case .idle: "Discard"
        }
    }
}

/// The recurring "What are you working on?" check-in (screen 2b), also reused for the idle
/// "Welcome back" prompt. Small centered floating panel with a combobox entry field.
struct CheckInPanel: View {
    let engine: TrackingEngine
    let mode: CheckInMode
    let onPrimary: (String) -> Void
    let onSecondary: () -> Void

    @State private var text: String
    @State private var hasEdited = false
    @State private var selection: Int?
    @FocusState private var focused: Bool

    init(engine: TrackingEngine, mode: CheckInMode,
         onPrimary: @escaping (String) -> Void, onSecondary: @escaping () -> Void) {
        self.engine = engine
        self.mode = mode
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
        _text = State(initialValue: engine.lastActivityLabel ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            field
            if !suggestions.isEmpty { suggestionList }
            buttons
        }
        .frame(width: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.panel, style: .continuous)
                .strokeBorder(.black.opacity(0.10), lineWidth: 0.5)
        )
        .onExitCommand { onSecondary() } // Escape → Continue previous / Discard
        .onAppear { focused = true }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 3) {
            AppIconBadge(size: 46)
                .padding(.bottom, 9)
            Text(mode.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            Text(mode.subtitle)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 22)
        .padding(.horizontal, 22)
        .padding(.bottom, 4)
    }

    // MARK: Field

    private var field: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Color(hex: swatchHex))
                .frame(width: 8, height: 8)
            TextField("Group:Activity", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.textPrimary)
                .focused($focused)
                .onSubmit(primary)
                .onChange(of: text) {
                    hasEdited = true
                    selection = nil
                }
                .onMoveCommand { moveSelection($0) }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.insetRow, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                .strokeBorder(focused ? Theme.accent.opacity(0.35) : Theme.border,
                              lineWidth: focused ? 3 : 0.5)
        )
        .padding(.horizontal, 22)
        .padding(.top, 16)
    }

    // MARK: Suggestions (combobox autocomplete)

    private var suggestions: [String] {
        guard hasEdited, !text.isEmpty else { return [] }
        let matches = engine.suggestions(matching: text, limit: 5)
        if matches.count == 1, matches[0].caseInsensitiveCompare(text) == .orderedSame { return [] }
        return matches
    }

    private var suggestionList: some View {
        VStack(spacing: 1) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                let (project, activity) = TrackingEngine.parse(suggestion)
                Button {
                    onPrimary(suggestion)
                } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(Color(hex: engine.projectColorHex(named: project) ?? Theme.palette[0]))
                            .frame(width: 7, height: 7)
                        Text(project).foregroundStyle(Theme.textTertiary)
                        Text(activity).foregroundStyle(Theme.textPrimary)
                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 12.5))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(selection == index ? Theme.accent.opacity(0.12) : .clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
    }

    // MARK: Buttons

    private var buttons: some View {
        HStack(spacing: 8) {
            Button { onSecondary() } label: {
                Text(mode.secondaryTitle).frame(maxWidth: .infinity)
            }
            .buttonStyle(SecondaryButtonStyle())
            Button(action: primary) {
                HStack(spacing: 5) {
                    Text(mode.primaryTitle)
                    Text("⏎").opacity(0.85)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    // MARK: Logic

    private var swatchHex: String {
        let (project, _) = TrackingEngine.parse(text)
        return engine.projectColorHex(named: project) ?? Theme.palette[0]
    }

    private func primary() {
        if let selection, suggestions.indices.contains(selection) {
            onPrimary(suggestions[selection])
        } else {
            onPrimary(text)
        }
    }

    private func moveSelection(_ direction: MoveCommandDirection) {
        let count = suggestions.count
        guard count > 0 else { return }
        switch direction {
        case .down: selection = min((selection ?? -1) + 1, count - 1)
        case .up: selection = max((selection ?? count) - 1, 0)
        default: break
        }
    }
}
