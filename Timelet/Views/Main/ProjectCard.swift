import SwiftUI

private struct ProjectCardHeader: View {
    let name: String
    let colorHex: String
    let total: TimeInterval
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ColorSwatch(hex: colorHex, size: 10)
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer(minLength: 4)
                Text(Format.duration(total))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Theme.cardHeaderBackground)
            Hairline(color: Theme.stroke)
        }
    }
}

/// Full-width project card: header + one row per block, newest first.
struct ProjectCard: View {
    let project: ProjectGroup
    var onSelect: (Entry) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            ProjectCardHeader(name: project.name, colorHex: project.colorHex, total: project.total)
            ForEach(Array(project.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Hairline() }
                EntryRowView(row: row, compact: false, onEdit: { onSelect(row.entry) })
            }
        }
        .groupedCard()
    }
}

/// Compact card for minor projects: header + a single `name · duration` row.
struct CompactProjectCard: View {
    let project: ProjectGroup
    var onSelect: (Entry) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            ProjectCardHeader(name: project.name, colorHex: project.colorHex, total: project.total)
            if let row = project.rows.first {
                EntryRowView(row: row, compact: true, onEdit: { onSelect(row.entry) })
            }
        }
        .groupedCard()
    }
}

/// A block: time range, name, duration. Hover shows "track again"; right-click has every action.
/// A row with a note can be expanded to read it.
private struct EntryRowView: View {
    let row: EntryRow
    let compact: Bool
    let onEdit: () -> Void
    @Environment(TrackingEngine.self) private var engine
    @State private var expanded = false
    @State private var hovering = false

    var body: some View {
        let note = row.entry.trimmedNote
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if !compact {
                    Text(row.isRunning ? "\(Format.clock(row.start)) – now" : Format.timeRange(row.start, row.end))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                        .monospacedDigit()
                        .frame(width: 118, alignment: .leading)
                }
                HStack(spacing: 6) {
                    if row.isRunning { PulsingDot(size: 6) }
                    Text(row.name)
                        .font(.system(size: compact ? 12.5 : 13))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    if note != nil, !compact {
                        Image(systemName: "note.text").font(.system(size: 10)).foregroundStyle(Theme.textQuaternary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if hovering && !row.isRunning {
                    Button { engine.resume(row.entry) } label: {
                        Image(systemName: "play.fill").font(.system(size: 9))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.accent)
                    .help("Track this again now")
                    .padding(.trailing, 8)
                }
                Text(row.isRunning ? Format.stopwatch(row.total) : Format.duration(row.total))
                    .font(.system(size: compact ? 12.5 : 13, weight: row.isRunning ? .semibold : .medium))
                    .foregroundStyle(row.isRunning ? Theme.accent : (compact ? Theme.textTertiary : Theme.textPrimary))
                    .monospacedDigit()
                if note != nil { DisclosureChevron(expanded: $expanded).padding(.leading, 2) }
            }
            .padding(.leading, compact ? 14 : 34)
            .padding(.trailing, note != nil ? 8 : 14)
            .padding(.vertical, compact ? 11 : 10)
            .background(hovering ? Theme.accent.opacity(0.06) : .clear)
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }
            .onHover { hovering = $0 }
            .contextMenu {
                Button("Edit…", action: onEdit)
                if !row.isRunning {
                    Button("Track Again Now") { engine.resume(row.entry) }
                } else {
                    Button("Stop") { engine.stopTracking() }
                }
                Button("Copy") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("\(row.entry.activity?.label.asDisplayLabel ?? row.name) — \(Format.duration(row.total))", forType: .string)
                }
                Divider()
                Button("Delete", role: .destructive) { engine.deleteEntry(row.entry) }
            }

            if let note, expanded {
                EntryNoteView(note: note, leadingInset: compact ? 14 : 34)
            }
        }
    }
}
