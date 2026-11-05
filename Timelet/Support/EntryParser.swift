import Foundation

/// What a check-in line means: a `Project:Activity` label, optionally backdated.
///
///     Timelet: Electron refactor
///     Timelet: Electron refactor 20m ago
///     Client-X: Auth bugfix since 14:30
///     Standup @9:15
struct ParsedCheckIn: Equatable {
    var project: String
    var activity: String
    /// When the work actually started, if the text says so.
    var start: Date?

    var label: String { "\(project):\(activity)" }
}

enum EntryParser {
    static let defaultProject = "General"

    /// Splits `Project:Activity`. Text without a colon goes to the default project.
    static func splitLabel(_ text: String) -> (project: String, activity: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let colon = trimmed.firstIndex(of: ":") {
            let p = trimmed[..<colon].trimmingCharacters(in: .whitespaces)
            let a = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return (p.isEmpty ? defaultProject : p, a.isEmpty ? "Untitled" : a)
        }
        return (defaultProject, trimmed.isEmpty ? "Untitled" : trimmed)
    }

    /// Parses a check-in line, pulling a trailing time modifier off the label.
    /// A start time in the future (or more than 16 hours back) is ignored.
    static func checkIn(_ text: String, now: Date, calendar: Calendar = .current) -> ParsedCheckIn {
        var body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var start: Date?

        // "… 20m ago", "… 1h 15m ago", "… 90 min ago"
        if let m = body.firstMatch(#"^(.*?)\s+((?:\d+(?:[.,]\d+)?\s*(?:h|hr|hrs|hours?|m|min|mins|minutes?)\s*)+)ago$"#),
           let seconds = DurationParser.seconds(from: m[1]) {
            body = m[0]
            start = now.addingTimeInterval(-seconds)
        }
        // "… since 14:30", "… from 9", "… @ 9:15", "… started at 2pm"
        else if let m = body.firstMatch(#"^(.*?)\s*(?:since|from|started at|@)\s*(\d{1,2}(?:[:h.]\d{2})?\s*(?:am|pm)?)$"#),
                let minutes = DurationParser.timeOfDay(from: m[1]) {
            body = m[0]
            start = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: now)
        }

        if let s = start, s > now || now.timeIntervalSince(s) > 16 * 3600 { start = nil }
        let (project, activity) = splitLabel(body)
        return ParsedCheckIn(project: project, activity: activity, start: start)
    }

    /// A leading day in an "Add time" line: `yesterday 9-10`, `mon 2pm to 3pm`, `today 45m`.
    /// A weekday means its latest occurrence up to today. Returns the day and the rest.
    static func leadingDay(_ text: String, now: Date, calendar: Calendar = .current) -> (day: Date, rest: String)? {
        guard let m = text.trimmingCharacters(in: .whitespaces).firstMatch(#"^([a-z]+)\.?(?:\s+(.*))?$"#) else { return nil }
        let word = m[0].lowercased()
        let rest = m[1].trimmingCharacters(in: .whitespaces)
        let today = calendar.startOfDay(for: now)
        switch word {
        case "today": return (today, rest)
        case "yesterday": return calendar.date(byAdding: .day, value: -1, to: today).map { ($0, rest) }
        default:
            let names = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
            guard word.count >= 3, let index = names.firstIndex(where: { $0.hasPrefix(word) }) else { return nil }
            let back = (calendar.component(.weekday, from: today) - (index + 1) + 7) % 7
            return calendar.date(byAdding: .day, value: -back, to: today).map { ($0, rest) }
        }
    }
}
