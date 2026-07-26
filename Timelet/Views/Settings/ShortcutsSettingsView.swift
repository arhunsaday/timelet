import SwiftUI

/// Shortcuts tab (2d): recorder-style rows showing each binding.
/// v1 displays the fixed bindings; custom recording is deferred (see README scope).
struct ShortcutsSettingsView: View {
    private struct Shortcut: Identifiable {
        let id = UUID()
        let name: String
        let keys: String
    }

    private let shortcuts: [Shortcut] = [
        .init(name: "Show check-in (global)", keys: "⌘⇧T"),
        .init(name: "Open dashboard", keys: "⌘0"),
        .init(name: "Add entry manually", keys: "⌘N"),
        .init(name: "Toggle tracking", keys: "⌘T"),
        .init(name: "Track silently", keys: "⌥⌘T"),
        .init(name: "Focus / close the check-in", keys: "⎋"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                SettingsSectionLabel(text: "KEYBOARD SHORTCUTS")
                SettingsCard {
                    ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                        if index > 0 { Hairline() }
                        SettingsRow(label: shortcut.name) { KeyCap(text: shortcut.keys) }
                    }
                }
                Text("Custom shortcut recording is coming in a later version.")
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
}
