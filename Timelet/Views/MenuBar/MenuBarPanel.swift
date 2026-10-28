import SwiftUI

/// Menu-bar popover (2c): what's running, today's total, one-click switching to recent tasks,
/// and quick actions.
struct MenuBarPanel: View {
    @Environment(TrackingEngine.self) private var engine
    @Environment(CheckInController.self) private var checkIn
    @Environment(UICoordinator.self) private var ui
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var recents: [TaskSuggestion] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("TODAY")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer()
                    Text(Format.duration(engine.total(on: engine.now)))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .monospacedDigit()
                }
                statusRow
                scheduleLine
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 8)

            if !recents.isEmpty {
                Text("SWITCH TO")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Theme.textQuaternary)
                    .padding(.horizontal, 22)
                    .padding(.top, 4)
                    .padding(.bottom, 2)
                VStack(spacing: 1) {
                    ForEach(recents) { s in
                        HoverRow {
                            engine.track(s.label)
                            dismiss()
                        } label: {
                            HStack(spacing: 9) {
                                ColorSwatch(hex: s.colorHex, size: 8).frame(width: 16)
                                Text(s.project).foregroundStyle(Theme.textTertiary)
                                Text(s.activity).foregroundStyle(Theme.textPrimary).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .font(.system(size: 12.5))
                        }
                    }
                }
                .padding(.horizontal, 8)
                Hairline().padding(.horizontal, 14).padding(.vertical, 6)
            }

            VStack(spacing: 1) {
                MenuActionRow(icon: "text.cursor", title: engine.runningEntry == nil ? "Start a task…" : "Switch task…") {
                    dismiss()
                    checkIn.present()
                }
                if engine.runningEntry != nil || engine.isPaused {
                    MenuActionRow(icon: engine.isPaused ? "play.fill" : "pause.fill",
                                  title: engine.isPaused ? "Resume" : "Pause") { engine.togglePause() }
                }
                if engine.runningEntry != nil {
                    MenuActionRow(icon: "stop.fill", title: "Stop") { engine.stopTracking() }
                }
                MenuActionRow(icon: "moon", title: "Done for today") {
                    engine.doneForToday()
                    dismiss()
                }
                snoozeControl
                Hairline().padding(.horizontal, 6).padding(.vertical, 4)
                MenuActionRow(icon: "square.grid.2x2", title: "Open Timelet") {
                    dismiss()
                    openWindow(id: "main")
                    NSApp.activate()
                }
                SettingsLink {
                    MenuActionRowLabel(icon: "gearshape", title: "Settings…")
                }
                .buttonStyle(.plain)
                MenuActionRow(icon: "power", title: "Quit Timelet") { NSApp.terminate(nil) }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 280)
        .onAppear { refreshRecents() }
        .onChange(of: engine.runningEntry?.persistentModelID) { refreshRecents() }
    }

    private func refreshRecents() {
        let current = engine.currentActivity?.label
        recents = Array(Ranking.rank(engine.allSuggestions(), query: "").filter { $0.label != current }.prefix(4))
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: 9) {
            if let activity = engine.currentActivity, let entry = engine.runningEntry {
                PulsingDot(size: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text(activity.label.asDisplayLabel)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("since \(Format.clock(entry.start))")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 4)
                Text(Format.stopwatch(engine.elapsed))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .monospacedDigit()
            } else if engine.isPaused {
                Image(systemName: "pause.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                Text((engine.lastActivityLabel ?? "Paused").asDisplayLabel)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("Paused")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Circle().fill(Theme.textQuaternary).frame(width: 8, height: 8)
                Text("Not tracking")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 4)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity)
        .background(Theme.insetRow, in: RoundedRectangle(cornerRadius: Radius.field, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.field, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 0.5))
    }

    @ViewBuilder private var scheduleLine: some View {
        HStack(spacing: 6) {
            if engine.isSnoozed, let until = engine.snoozedUntil {
                Image(systemName: "bell.slash.fill")
                Text(Calendar.current.isDate(until, inSameDayAs: engine.now)
                     ? "Not asking until \(Format.clock(until))" : "Not asking until \(Format.weekdayShort(until)) \(Format.clock(until))")
            } else if engine.canAsk, let next = engine.nextAskAt {
                Image(systemName: "bell")
                Text("Next check-in at \(Format.clock(next))")
            } else if !engine.isPaused {
                Image(systemName: "bell.slash")
                Text("Outside work hours — not asking")
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(Theme.textTertiary)
    }

    @ViewBuilder
    private var snoozeControl: some View {
        if engine.isSnoozed {
            MenuActionRow(icon: "bell.fill", title: "Resume asking") { engine.resumeAsking() }
        } else {
            Menu {
                Button("For 30 minutes") { engine.snooze(for: 30 * 60) }
                Button("For 1 hour") { engine.snooze(for: 3600) }
                Button("For 2 hours") { engine.snooze(for: 2 * 3600) }
                Button("Until tomorrow") { engine.snoozeUntilEndOfDay() }
            } label: {
                MenuActionRowLabel(icon: "bell.slash", title: "Stop asking…")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        }
    }
}

struct MenuActionRowLabel: View {
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private struct MenuActionRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        HoverRow(action: action) { MenuActionRowLabel(icon: icon, title: title).padding(.horizontal, -8) }
    }
}

/// A full-width plain button with the menu-style hover highlight.
struct HoverRow<Label: View>: View {
    let action: () -> Void
    @ViewBuilder var label: Label
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label
                .padding(.horizontal, 8)
                .padding(.vertical, 1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(hovering ? Theme.accent.opacity(0.12) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
