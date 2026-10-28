import Foundation

/// A task the user can pick in the check-in, add-entry and edit sheets.
struct TaskSuggestion: Identifiable, Equatable {
    var id: String { label }
    let project: String
    let activity: String
    let colorHex: String
    let lastUsed: Date
    let uses: Int

    var label: String { "\(project):\(activity)" }
}

/// Orders suggestions for a query: whole-label prefix beats activity prefix beats
/// word prefix beats substring beats in-order letters ("tlref" → "Timelet:Electron refactor").
/// Ties go to the most recently used, then the most used.
enum Ranking {
    static func rank(_ candidates: [TaskSuggestion], query: String, now: Date = .now) -> [TaskSuggestion] {
        let q = normalize(query)
        guard !q.isEmpty else { return candidates.sorted(by: recency) }
        return candidates
            .compactMap { c -> (TaskSuggestion, Int)? in score(c, q).map { (c, $0) } }
            .sorted { a, b in a.1 != b.1 ? a.1 > b.1 : recency(a.0, b.0) }
            .map(\.0)
    }

    /// The typed text is the beginning of this task (label or activity), so ⏎ may pick it.
    static func isStrongMatch(_ c: TaskSuggestion, query: String) -> Bool {
        (score(c, normalize(query)) ?? 0) >= 950
    }

    private static func recency(_ a: TaskSuggestion, _ b: TaskSuggestion) -> Bool {
        a.lastUsed != b.lastUsed ? a.lastUsed > b.lastUsed : a.uses > b.uses
    }

    static func score(_ c: TaskSuggestion, _ q: String) -> Int? {
        let label = normalize(c.label)
        let activity = normalize(c.activity)
        let project = normalize(c.project)
        // A query written as "proj:act" matches each side separately.
        if let colon = q.firstIndex(of: ":") {
            let qp = String(q[..<colon]), qa = String(q[q.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
            guard project.hasPrefix(qp) || project.contains(qp) else { return nil }
            if qa.isEmpty { return 900 }
            if activity.hasPrefix(qa) { return 1000 }
            if activity.contains(qa) { return 700 }
            return isSubsequence(qa, of: activity) ? 300 : nil
        }
        if label.hasPrefix(q) { return 1000 }
        if activity.hasPrefix(q) { return 950 }
        let words = label.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
        if words.contains(where: { $0.hasPrefix(q) }) { return 800 }
        if label.contains(q) { return 600 }
        if isSubsequence(q, of: label) { return 200 }
        return nil
    }

    private static func normalize(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: ": ", with: ":")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func isSubsequence(_ needle: String, of haystack: String) -> Bool {
        var it = haystack.makeIterator()
        return needle.filter { !$0.isWhitespace }.allSatisfy { ch in
            while let h = it.next() { if h == ch { return true } }
            return false
        }
    }
}
