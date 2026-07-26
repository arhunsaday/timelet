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

/// Full-width project card: header + one row per entry. A row with a note shows a disclosure
/// chevron to reveal it; tapping the row opens the editor.
struct ProjectCard: View {
    let project: ProjectGroup
    var onSelect: (Entry) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            ProjectCardHeader(name: project.name, colorHex: project.colorHex, total: project.total)
            ForEach(Array(project.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Hairline() }
                DayEntryRow(row: row, onEdit: { onSelect(row.entry) })
            }
        }
        .groupedCard()
    }
}

/// Compact card for minor projects: header + a single `name · duration` row (with note support).
struct CompactProjectCard: View {
    let project: ProjectGroup
    var onSelect: (Entry) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            ProjectCardHeader(name: project.name, colorHex: project.colorHex, total: project.total)
            if let row = project.rows.first {
                CompactEntryRow(row: row, onEdit: { onSelect(row.entry) })
            }
        }
        .groupedCard()
    }
}

private struct DayEntryRow: View {
    let row: EntryRow
    let onEdit: () -> Void
    @State private var expanded = false
    @State private var hovering = false

    var body: some View {
        let note = row.entry.trimmedNote
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(Format.timeRange(row.start, row.end))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
                    .frame(width: 118, alignment: .leading)
                Text(row.name)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Format.duration(row.total))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                if note != nil { DisclosureChevron(expanded: $expanded).padding(.leading, 2) }
            }
            .padding(.leading, 34)
            .padding(.trailing, note != nil ? 8 : 14)
            .padding(.vertical, 10)
            .background(hovering ? Theme.accent.opacity(0.06) : .clear)
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }
            .onHover { hovering = $0 }

            if let note, expanded {
                EntryNoteView(note: note, leadingInset: 34)
            }
        }
    }
}

private struct CompactEntryRow: View {
    let row: EntryRow
    let onEdit: () -> Void
    @State private var expanded = false
    @State private var hovering = false

    var body: some View {
        let note = row.entry.trimmedNote
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(row.name)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(Format.duration(row.total))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
                    .monospacedDigit()
                if note != nil { DisclosureChevron(expanded: $expanded).padding(.leading, 2) }
            }
            .padding(.leading, 14)
            .padding(.trailing, note != nil ? 8 : 14)
            .padding(.vertical, 11)
            .background(hovering ? Theme.accent.opacity(0.06) : .clear)
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }
            .onHover { hovering = $0 }

            if let note, expanded {
                EntryNoteView(note: note, leadingInset: 14)
            }
        }
    }
}
