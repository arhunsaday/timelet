import Foundation
import SwiftData

/// One time block (a single `Entry`) for display + editing.
struct EntryRow: Identifiable {
    let id: PersistentIdentifier
    let entry: Entry
    let name: String
    let colorHex: String
    let start: Date
    let end: Date
    let total: TimeInterval
    let isRunning: Bool
}

/// A project's blocks for a given day.
struct ProjectGroup: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let colorHex: String
    let total: TimeInterval
    let rows: [EntryRow]

    /// Minor projects render as compact 2-up cards (name + duration only), matching the mock.
    var isCompact: Bool { total < 3600 && rows.count <= 1 && !(rows.first?.isRunning ?? false) }
}

/// Groups a day's entries (one row per block, the running one included) by project.
struct DaySummary {
    let projects: [ProjectGroup]
    /// Every block of the day in time order, for the timeline.
    let blocks: [EntryRow]
    let totalTracked: TimeInterval
    var isEmpty: Bool { projects.isEmpty }

    static func build(entries: [Entry], day: Date, now: Date) -> DaySummary {
        let cal = Calendar.current
        var buckets: [PersistentIdentifier: (project: Project, rows: [EntryRow])] = [:]
        var blocks: [EntryRow] = []
        for entry in entries where cal.isDate(entry.start, inSameDayAs: day) {
            guard let activity = entry.activity, let project = activity.project, !project.isArchived else { continue }
            let row = EntryRow(
                id: entry.persistentModelID, entry: entry, name: activity.name, colorHex: project.colorHex,
                start: entry.start, end: entry.end ?? now, total: entry.duration(asOf: now), isRunning: entry.end == nil
            )
            buckets[project.persistentModelID, default: (project, [])].rows.append(row)
            blocks.append(row)
        }

        let projects = buckets.values.map { bucket -> ProjectGroup in
            let rows = bucket.rows.sorted { $0.start > $1.start }
            return ProjectGroup(
                id: bucket.project.persistentModelID,
                name: bucket.project.name,
                colorHex: bucket.project.colorHex,
                total: rows.reduce(0) { $0 + $1.total },
                rows: rows
            )
        }
        .sorted { ($0.total, $1.name) > ($1.total, $0.name) }

        return DaySummary(projects: projects, blocks: blocks.sorted { $0.start < $1.start },
                          totalTracked: projects.reduce(0) { $0 + $1.total })
    }

    /// Untracked stretches between `from` and `to` (at least `minimum` long), for the timeline.
    func gaps(from: Date, to: Date, minimum: TimeInterval = 10 * 60) -> [DateInterval] {
        var out: [DateInterval] = []
        var cursor = from
        for b in blocks {
            if b.start.timeIntervalSince(cursor) >= minimum { out.append(DateInterval(start: cursor, end: b.start)) }
            cursor = max(cursor, b.end)
        }
        if to.timeIntervalSince(cursor) >= minimum { out.append(DateInterval(start: cursor, end: to)) }
        return out
    }

    /// Per-project totals for a given day (sidebar), keyed by project id.
    static func projectTotals(entries: [Entry], day: Date, now: Date) -> [PersistentIdentifier: TimeInterval] {
        let cal = Calendar.current
        var totals: [PersistentIdentifier: TimeInterval] = [:]
        for entry in entries where cal.isDate(entry.start, inSameDayAs: day) {
            guard let project = entry.activity?.project, !project.isArchived else { continue }
            totals[project.persistentModelID, default: 0] += entry.duration(asOf: now)
        }
        return totals
    }
}
