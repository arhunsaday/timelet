import Foundation
import SwiftData

// The local data model. Persistence is SwiftData in v1; the app talks to it only
// through `TrackingStore`, so a networked backend could replace the storage later
// without touching the UI.

@Model
final class Project {
    var name: String = ""
    var colorHex: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date.now
    /// Palette assignment order — also used as a stable sort key.
    var order: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \Activity.project)
    var activities: [Activity] = []

    init(name: String, colorHex: String, order: Int = 0, createdAt: Date = .now) {
        self.name = name
        self.colorHex = colorHex
        self.order = order
        self.createdAt = createdAt
    }
}

@Model
final class Activity {
    var name: String = ""
    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \Entry.activity)
    var entries: [Entry] = []

    init(name: String, project: Project? = nil) {
        self.name = name
        self.project = project
    }

    /// `Group:Activity` — the canonical entry-text form.
    var label: String { "\(project?.name ?? "General"):\(name)" }
}

@Model
final class Entry {
    var start: Date = Date.now
    /// `nil` while the entry is still running.
    var end: Date?
    var activity: Activity?
    var note: String?

    init(start: Date = .now, end: Date? = nil, activity: Activity? = nil, note: String? = nil) {
        self.start = start
        self.end = end
        self.activity = activity
        self.note = note
    }

    var isRunning: Bool { end == nil }

    /// Rounding step for reported durations (Settings › Round durations), in seconds; 0 = exact.
    /// Applied when reading, never written back, so stored blocks never overlap.
    nonisolated(unsafe) static var reportingStep: TimeInterval = 0

    /// Elapsed time; for a running entry this grows relative to `now` and is never rounded.
    /// Completed entries are rounded to the nearest `reportingStep` (at least one step).
    func duration(asOf now: Date = .now) -> TimeInterval {
        let exact = max(0, (end ?? now).timeIntervalSince(start))
        let step = Self.reportingStep
        guard end != nil, step > 0, exact > 0 else { return exact }
        return max(step, (exact / step).rounded() * step)
    }

    /// The note if it has non-whitespace content, else `nil`.
    var trimmedNote: String? {
        guard let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else { return nil }
        return note
    }
}
