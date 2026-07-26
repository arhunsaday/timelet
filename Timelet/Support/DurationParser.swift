import Foundation

/// Natural-language duration parsing for manual entries.
/// Accepts phrases like `45m`, `1h30`, `1h30m`, `1h`, `1.5h`, `2h 10m`, or a bare `90` (minutes).
/// Returns the duration in seconds, or `nil` if nothing parseable was found.
enum DurationParser {
    static func seconds(from input: String) -> TimeInterval? {
        var s = input.lowercased()
            .replacingOccurrences(of: ",", with: ".")
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
            if let h = Double(head) {
                hours = h
                matched = true
            }
            // Everything after the "h" is the minutes part ("30", "30m", or "").
            s = String(s[hRange.upperBound...])
        }

        // Minutes: remaining digits, with or without a trailing "m".
        var minutesPart = s
        if minutesPart.hasSuffix("m") { minutesPart.removeLast() }
        if !minutesPart.isEmpty, let m = Double(minutesPart) {
            minutes = m
            matched = true
        }

        guard matched else { return nil }
        let total = hours * 3600 + minutes * 60
        return total > 0 ? total : nil
    }
}
