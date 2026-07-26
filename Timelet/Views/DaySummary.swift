import Foundation
import SwiftData

/// One completed time block (a single `Entry`) for display + editing.
struct EntryRow: Identifiable {
    let id: PersistentIdentifier
    let entry: Entry
    let name: String
    let start: Date
    let end: Date
    let total: TimeInterval
}

/// A project's blocks for a given day.
struct ProjectGroup: Identifiable {
    let id: PersistentIdentifier
    let name: String
    let colorHex: String
    let total: TimeInterval
    let rows: [EntryRow]

    /// Minor projects render as compact 2-up cards (name + duration only), matching the mock.
    var isCompact: Bool { total < 3600 && rows.count <= 1 }
}

/// Groups a day's *completed* entries (one row per block) by project. The running entry is
/// shown only in the pill / menu bar; its elapsed time is folded into the headline total when
/// the day being viewed is today.
struct DaySummary {
    let projects: [ProjectGroup]
    let totalTracked: TimeInterval
    var isEmpty: Bool { projects.isEmpty }

    static func build(entries: [Entry], day: Date, runningElapsed: TimeInterval, now: Date) -> DaySummary {
        let cal = Calendar.current
        let completed = entries.filter { entry in
            entry.end != nil
                && cal.isDate(entry.start, inSameDayAs: day)
                && !(entry.activity?.project?.isArchived ?? false)
        }

        var buckets: [PersistentIdentifier: (project: Project, rows: [EntryRow])] = [:]
        for entry in completed {
            guard let activity = entry.activity, let project = activity.project, let end = entry.end else { continue }
            let row = EntryRow(
                id: entry.persistentModelID, entry: entry, name: activity.name,
                start: entry.start, end: end, total: entry.duration(asOf: now)
            )
            buckets[project.persistentModelID, default: (project, [])].rows.append(row)
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

        let completedTotal = projects.reduce(0) { $0 + $1.total }
        return DaySummary(projects: projects, totalTracked: completedTotal + runningElapsed)
    }

    /// Per-project completed totals for a given day (sidebar), keyed by project id.
    static func projectTotals(entries: [Entry], day: Date, now: Date) -> [PersistentIdentifier: TimeInterval] {
        let cal = Calendar.current
        var totals: [PersistentIdentifier: TimeInterval] = [:]
        for entry in entries where entry.end != nil && cal.isDate(entry.start, inSameDayAs: day) {
            guard let project = entry.activity?.project, !project.isArchived else { continue }
            totals[project.persistentModelID, default: 0] += entry.duration(asOf: now)
        }
        return totals
    }
}
