import SwiftUI

/// A `Project: Activity` text field with ranked autocomplete, shared by the add and edit sheets.
/// ↑↓ choose, ⇥ or ⏎ accept, ⎋ (or typing on) ignores the list.
struct TaskField: View {
    @Binding var text: String
    var placeholder = "Project: what you did"
    var autofocus = false
    @Environment(TrackingEngine.self) private var engine
    @State private var all: [TaskSuggestion] = []
    @State private var selection: Int?
    @State private var dismissedFor: String?
    @FocusState private var focused: Bool

    private var matches: [TaskSuggestion] {
        let q = text.trimmingCharacters(in: .whitespaces)
        guard focused, dismissedFor != text else { return [] }
        let ranked = Array(Ranking.rank(all, query: q).prefix(5))
        if ranked.count == 1, ranked[0].label.caseInsensitiveCompare(EntryParser.splitLabel(q).project + ":" + EntryParser.splitLabel(q).activity) == .orderedSame {
            return []
        }
        return ranked
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                ColorSwatch(hex: engine.projectColorHex(named: EntryParser.splitLabel(text).project) ?? Theme.palette[0], size: 9)
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onKeyPress(.downArrow) { move(1) }
                    .onKeyPress(.upArrow) { move(-1) }
                    .onKeyPress(.tab) { accept() }
                    .onKeyPress(.return) { selection == nil ? .ignored : accept() }
                    .onKeyPress(.escape) {
                        guard !matches.isEmpty else { return .ignored }
                        dismissedFor = text
                        return .handled
                    }
                    .onChange(of: text) { selection = nil }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Theme.insetRow, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(focused ? Theme.accent.opacity(0.45) : Theme.border, lineWidth: focused ? 2 : 0.5))

            if !matches.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(matches.enumerated()), id: \.element.id) { i, s in
                        HStack(spacing: 7) {
                            ColorSwatch(hex: s.colorHex, size: 7)
                            Text(s.project).foregroundStyle(Theme.textTertiary)
                            Text(s.activity).foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(Format.relative(s.lastUsed, now: engine.now)).font(.system(size: 10.5)).foregroundStyle(Theme.textQuaternary)
                        }
                        .font(.system(size: 12))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 5).fill(selection == i ? Theme.accent.opacity(0.14) : .clear))
                        .contentShape(Rectangle())
                        .onTapGesture { choose(s) }
                        .onHover { if $0 { selection = i } }
                    }
                }
                .padding(3)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.5))
            }
        }
        .onAppear {
            all = engine.allSuggestions()
            if autofocus { DispatchQueue.main.async { focused = true } }
        }
    }

    private func move(_ delta: Int) -> KeyPress.Result {
        guard !matches.isEmpty else { return .ignored }
        selection = max(0, min((selection ?? -1) + delta, matches.count - 1))
        return .handled
    }

    private func accept() -> KeyPress.Result {
        let i = selection ?? 0
        guard matches.indices.contains(i) else { return .ignored }
        choose(matches[i])
        return .handled
    }

    private func choose(_ s: TaskSuggestion) {
        text = s.label.asDisplayLabel
        dismissedFor = text
        selection = nil
    }
}
