import Foundation

/// Natural-language duration and time parsing for manual entries and check-ins.
/// Durations: `45m`, `1h30`, `1h30m`, `1h`, `1.5h`, `2h 10m`, `90 min`, or a bare `90` (minutes).
/// Times of day: `9`, `9:30`, `09h30`, `14h`, `2pm`, `2:30 pm`.
/// Ranges: `9-10:30`, `9:00 – 10:30`, `14h-15h30`, `2pm to 3pm`.
enum DurationParser {
    /// Duration in seconds, or `nil` if nothing parseable was found.
    static func seconds(from input: String) -> TimeInterval? {
        var s = input.lowercased()
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "hours", with: "h")
            .replacingOccurrences(of: "hour", with: "h")
            .replacingOccurrences(of: "hrs", with: "h")
            .replacingOccurrences(of: "hr", with: "h")
            .replacingOccurrences(of: "minutes", with: "m")
            .replacingOccurrences(of: "minute", with: "m")
            .replacingOccurrences(of: "mins", with: "m")
            .replacingOccurrences(of: "min", with: "m")
            .filter { !$0.isWhitespace }
        guard !s.isEmpty else { return nil }

        // Bare number → minutes ("90", "1.5").
        if let bare = Double(s) {
            return bare > 0 ? bare * 60 : nil
        }

        var hours = 0.0
        var minutes = 0.0
        var matched = false

        // Hours: the number preceding an "h".
        if let hRange = s.range(of: "h") {
            let head = String(s[s.startIndex..<hRange.lowerBound])
            guard let h = Double(head) else { return nil }
            hours = h
            matched = true
            // Everything after the "h" is the minutes part ("30", "30m", or "").
            s = String(s[hRange.upperBound...])
        }

        // Minutes: remaining digits, with or without a trailing "m".
        var minutesPart = s
        if minutesPart.hasSuffix("m") { minutesPart.removeLast() }
        if !minutesPart.isEmpty {
            guard let m = Double(minutesPart) else { return nil }
            minutes = m
            matched = true
        }

        guard matched else { return nil }
        let total = hours * 3600 + minutes * 60
        return total > 0 ? total : nil
    }

    /// Minutes from midnight for a time of day, or `nil`.
    static func timeOfDay(from input: String) -> Int? {
        let s = input.lowercased().trimmingCharacters(in: .whitespaces)
        guard let m = s.firstMatch(#"^(\d{1,2})(?:[:h.](\d{2}))?\s*(am|pm|h)?$"#) else { return nil }
        guard var hour = Int(m[0]) else { return nil }
        let minute = m[1].isEmpty ? 0 : (Int(m[1]) ?? 0)
        switch m[2] {
        case "pm" where hour < 12: hour += 12
        case "am" where hour == 12: hour = 0
        default: break
        }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        return hour * 60 + minute
    }

    /// A time range as minutes from midnight. A range crossing midnight (`23:00-1:00`)
    /// comes back with `end` past 24h.
    static func timeRange(from input: String) -> (start: Int, end: Int)? {
        let s = input.lowercased()
        let parts = s.components(separatedBy: CharacterSet(charactersIn: "-–—"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let pair: [String]
        if parts.count == 2 {
            pair = parts
        } else if let to = s.range(of: " to ") {
            pair = [String(s[..<to.lowerBound]), String(s[to.upperBound...])]
        } else {
            return nil
        }
        // "2-3pm" → both pm.
        var startText = pair[0]
        let endText = pair[1]
        if let suffix = ["am", "pm"].first(where: { endText.hasSuffix($0) }),
           !startText.hasSuffix("am"), !startText.hasSuffix("pm") {
            startText += suffix
        }
        guard let start = timeOfDay(from: startText), var end = timeOfDay(from: endText) else { return nil }
        if end <= start { end += 24 * 60 }
        guard end - start <= 16 * 60 else { return nil }
        return (start, end)
    }
}

extension String {
    /// Capture groups (empty string for a group that did not participate) of the first
    /// case-insensitive match of `pattern`, or `nil`.
    func firstMatch(_ pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let m = regex.firstMatch(in: self, range: NSRange(startIndex..., in: self)) else { return nil }
        return (1..<max(m.numberOfRanges, 1)).map { i in
            Range(m.range(at: i), in: self).map { String(self[$0]) } ?? ""
        }
    }
}
