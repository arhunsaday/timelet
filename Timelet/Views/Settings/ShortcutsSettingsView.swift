import SwiftUI
import AppKit

/// Shortcuts tab (2d): recordable global shortcuts, plus the in-app ones for reference.
struct ShortcutsSettingsView: View {
    @Environment(AppSettings.self) private var settingsEnv
    @Environment(AppModel.self) private var app
    @State private var refused: [String] = []

    private let inApp: [(String, String)] = [
        ("Check in", "⌘K"), ("Add time", "⌘N"), ("Pause / resume", "⇧⌘P"), ("Stop tracking", "⌘."),
        ("Today · Week · Statistics", "⌘1 ⌘2 ⌘3"), ("Previous / next day", "⌘[  ⌘]"), ("Go to today", "⌘T"),
        ("Export CSV", "⇧⌘E"),
    ]

    private let inCheckIn: [(String, String)] = [
        ("Save / switch", "⏎"), ("Keep going", "⎋"), ("Choose a suggestion", "↑ ↓"),
        ("Complete the highlighted task", "⇥"), ("Pick recent task 1–5", "⌘1 … ⌘5"), ("Add a note", "⌘N"),
    ]

    var body: some View {
        @Bindable var settings = settingsEnv
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                SettingsSectionLabel(text: "GLOBAL — WORK IN ANY APP")
                SettingsCard {
                    SettingsRow(label: "Check in") {
                        ShortcutRecorder(combo: $settings.checkInHotkey, defaultCombo: .checkInDefault)
                    }
                    Hairline()
                    SettingsRow(label: "Pause / resume") {
                        ShortcutRecorder(combo: $settings.pauseHotkey, defaultCombo: .pauseDefault)
                    }
                }
                ForEach(warnings, id: \.self) { w in
                    Label(w, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 4)
                }
                Text("Click a shortcut, then press the new keys. ⌫ clears it, ⎋ cancels.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 4)
                    .padding(.top, 2)

                SettingsSectionLabel(text: "IN TIMELET").padding(.top, 8)
                SettingsCard { list(inApp) }

                SettingsSectionLabel(text: "IN THE CHECK-IN").padding(.top, 8)
                SettingsCard { list(inCheckIn) }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
        }
        .background(Theme.contentBackground)
        .onChange(of: settings.checkInHotkey) { refused = app.registerHotkeys() }
        .onChange(of: settings.pauseHotkey) { refused = app.registerHotkeys() }
    }

    private var warnings: [String] {
        var out = refused.map { "macOS refused the \($0) shortcut — another app probably uses it." }
        for combo in [settingsEnv.checkInHotkey, settingsEnv.pauseHotkey].compactMap({ $0 }) {
            if let w = combo.conflictWarning { out.append(w) }
        }
        if let a = settingsEnv.checkInHotkey, a == settingsEnv.pauseHotkey { out.append("Both actions use \(a.display).") }
        return out
    }

    @ViewBuilder private func list(_ items: [(String, String)]) -> some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            if index > 0 { Hairline() }
            SettingsRow(label: item.0) { KeyCap(text: item.1) }
        }
    }
}

/// Click, then press a key combination. ⌫ clears, ⎋ cancels. Global shortcuts are suspended
/// while recording so the current combo can be typed again.
struct ShortcutRecorder: View {
    @Binding var combo: KeyCombo?
    let defaultCombo: KeyCombo
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggle) {
                Text(recording ? "Type shortcut…" : (combo?.display ?? "None"))
                    .font(.system(size: 12, weight: .medium))
                    .monospacedDigit()
                    .frame(minWidth: 96)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .foregroundStyle(recording ? Theme.accent : (combo == nil ? Theme.textTertiary : Theme.textPrimary))
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(recording ? Theme.accent.opacity(0.1) : Theme.fieldTint))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(recording ? Theme.accent : Theme.border, lineWidth: recording ? 1.5 : 0.5))
            }
            .buttonStyle(.plain)
            if combo != defaultCombo && !recording {
                Button { combo = defaultCombo } label: { Image(systemName: "arrow.uturn.backward") }
                    .buttonStyle(.borderless)
                    .help("Reset to \(defaultCombo.display)")
            }
        }
        .onDisappear(perform: stop)
    }

    private func toggle() { recording ? stop() : start() }

    private func start() {
        recording = true
        GlobalHotkeyManager.shared.setSuspended(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case 53: stop() // ⎋
            case 51, 117: combo = nil; stop() // ⌫ ⌦
            default:
                if let new = KeyCombo(event: event) {
                    combo = new
                    stop()
                } else {
                    NSSound.beep() // needs ⌘, ⌃ or ⌥
                }
            }
            return nil
        }
    }

    private func stop() {
        recording = false
        GlobalHotkeyManager.shared.setSuspended(false)
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
