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

    /// Elapsed time; for a running entry this grows relative to `now`.
    func duration(asOf now: Date = .now) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }

    /// The note if it has non-whitespace content, else `nil`.
    var trimmedNote: String? {
        guard let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else { return nil }
        return note
    }
}
