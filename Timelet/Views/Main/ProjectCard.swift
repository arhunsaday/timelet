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

/// A tappable entry row that highlights on hover (affords editing).
private struct EntryRowButton<Content: View>: View {
    let action: () -> Void
    @ViewBuilder var content: Content
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            content
                .contentShape(Rectangle())
                .background(hovering ? Theme.accent.opacity(0.06) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Full-width project card: header + one row per entry (`HH:MM – HH:MM · name · duration`).
struct ProjectCard: View {
    let project: ProjectGroup
    var onSelect: (Entry) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            ProjectCardHeader(name: project.name, colorHex: project.colorHex, total: project.total)
            ForEach(Array(project.rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Hairline() }
                EntryRowButton { onSelect(row.entry) } content: {
                    rowContent(row)
                }
            }
        }
        .groupedCard()
    }

    private func rowContent(_ row: EntryRow) -> some View {
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
        }
        .padding(.leading, 34)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
    }
}

/// Compact card for minor projects: header + a single `name · duration` row (no time range).
struct CompactProjectCard: View {
    let project: ProjectGroup
    var onSelect: (Entry) -> Void = { _ in }

    var body: some View {
        VStack(spacing: 0) {
            ProjectCardHeader(name: project.name, colorHex: project.colorHex, total: project.total)
            if let row = project.rows.first {
                EntryRowButton { onSelect(row.entry) } content: {
                    HStack(spacing: 0) {
                        Text(row.name)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(Format.duration(row.total))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textTertiary)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                }
            }
        }
        .groupedCard()
    }
}
