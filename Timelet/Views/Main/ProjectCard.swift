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

/// Full-width project card: header + one row per activity (`HH:MM – HH:MM · name · duration`).
struct ProjectCard: View {
    let project: ProjectSummary

    var body: some View {
        VStack(spacing: 0) {
            ProjectCardHeader(name: project.name, colorHex: project.colorHex, total: project.total)
            ForEach(Array(project.activities.enumerated()), id: \.element.id) { index, activity in
                if index > 0 { Hairline() }
                row(activity)
            }
        }
        .groupedCard()
    }

    private func row(_ activity: ActivitySummary) -> some View {
        HStack(spacing: 0) {
            Text(Format.timeRange(activity.start, activity.end))
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary)
                .monospacedDigit()
                .frame(width: 118, alignment: .leading)
            Text(activity.name)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Format.duration(activity.total))
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
    let project: ProjectSummary

    var body: some View {
        VStack(spacing: 0) {
            ProjectCardHeader(name: project.name, colorHex: project.colorHex, total: project.total)
            if let activity = project.activities.first {
                HStack(spacing: 0) {
                    Text(activity.name)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(Format.duration(activity.total))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textTertiary)
                        .monospacedDigit()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
            }
        }
        .groupedCard()
    }
}
