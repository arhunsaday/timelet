import SwiftUI

/// Menu-bar popover (2c): current-tracking status + quick actions.
struct MenuBarPanel: View {
    @Environment(TrackingEngine.self) private var engine
    @Environment(CheckInController.self) private var checkIn
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("CURRENTLY TRACKING")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                statusRow
                if engine.isSnoozed, let until = engine.snoozedUntil {
                    HStack(spacing: 6) {
                        Image(systemName: "bell.slash.fill")
                            .font(.system(size: 10))
                        Text("Not asking until \(Format.clock(until))")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 13)
            .padding(.bottom, 10)

            VStack(spacing: 1) {
                MenuActionRow(icon: "pencil", title: "Change task…") { checkIn.present() }
                if engine.runningEntry != nil || engine.isPaused {
                    MenuActionRow(
                        icon: engine.isPaused ? "play.fill" : "pause.fill",
                        title: engine.isPaused ? "Resume tracking" : "Pause tracking"
                    ) { engine.togglePause() }
                }
                snoozeControl
                MenuActionRow(icon: "square.grid.2x2", title: "Open dashboard") { openDashboard() }
                Hairline().padding(.horizontal, 6).padding(.vertical, 4)
                SettingsLink {
                    MenuActionRowLabel(icon: "gearshape", title: "Settings…")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .frame(width: 264)
    }

    @ViewBuilder
    private var statusRow: some View {
        HStack(spacing: 9) {
            if engine.runningEntry != nil {
                PulsingDot(size: 8)
                Text((engine.currentActivity?.label ?? "").asDisplayLabel)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(Format.stopwatch(engine.elapsed))
                    .font(.system(size: 12.5, weight: .semibold))
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
        .overlay(
            RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var snoozeControl: some View {
        if engine.isSnoozed {
            MenuActionRow(icon: "bell.slash.fill", title: "Resume asking") { engine.resumeAsking() }
        } else {
            Menu {
                Button("For 30 minutes") { engine.snooze(for: 30 * 60) }
                Button("For 1 hour") { engine.snooze(for: 3600) }
                Button("For 2 hours") { engine.snooze(for: 2 * 3600) }
                Button("Until end of day") { engine.snoozeUntilEndOfDay() }
            } label: {
                MenuActionRowLabel(icon: "bell.slash", title: "Stop asking…")
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
        }
    }

    private func openDashboard() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct MenuActionRowLabel: View {
    let icon: String
    let title: String
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}

private struct MenuActionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            MenuActionRowLabel(icon: icon, title: title)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(hovering ? Theme.accent.opacity(0.12) : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
