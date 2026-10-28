import Foundation

/// Duration + time-of-day formatting used throughout the UI.
/// All times/durations use tabular (`.monospacedDigit()`) rendering at the view layer.
enum Format {

    // MARK: Durations

    /// Long form: `6h 40m`, `1h 30m`, `2h`, `40m`, `0m`.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(m)m"
    }

    /// Compact `h:mm` form used in the sidebar: `3:55`, `1:30`, `0:40`.
    static func durationCompact(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        return String(format: "%d:%02d", h, m)
    }

    // MARK: Running timers

    /// `mm:ss` under an hour, `h:mm:ss` after (toolbar pill, menu-bar row): `04:12`, `1:12:15`.
    static func stopwatch(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        if total >= 3600 { return String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60) }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// `m:ss` under an hour, `h:mm` after (menu-bar title, which should not jitter): `4:12`, `1:12`.
    static func stopwatchCompact(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        if total >= 3600 { return String(format: "%d:%02d", total / 3600, total % 3600 / 60) }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// `just now`, `12m ago`, `3h ago`, `yesterday`, `4d ago`, `Mar 2`.
    static func relative(_ date: Date, now: Date) -> String {
        let s = now.timeIntervalSince(date)
        if s < 60 { return "just now" }
        if s < 3600 { return "\(Int(s / 60))m ago" }
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) { return "\(Int(s / 3600))h ago" }
        if let y = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(date, inSameDayAs: y) { return "yesterday" }
        if s < 7 * 86400 { return "\(Int(ceil(s / 86400)))d ago" }
        return monthDay(date)
    }

    // MARK: Time of day

    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let longDateFormatter = formatter("EEEE, MMMM d")
    private static let weekdayFormatter = formatter("EEEE")
    private static let weekdayShortFormatter = formatter("EEE")
    private static let monthDayFormatter = formatter("MMM d")

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.dateFormat = format
        return f
    }

    /// `13:30`
    static func clock(_ date: Date) -> String { clockFormatter.string(from: date) }

    /// `13:30 – 15:40`
    static func timeRange(_ start: Date, _ end: Date) -> String {
        "\(clockFormatter.string(from: start)) – \(clockFormatter.string(from: end))"
    }

    /// `Monday, July 21`
    static func longDate(_ date: Date) -> String { longDateFormatter.string(from: date) }

    /// `Mon`
    static func weekdayShort(_ date: Date) -> String { weekdayShortFormatter.string(from: date) }

    /// `Jul 21`
    static func monthDay(_ date: Date) -> String { monthDayFormatter.string(from: date) }

    // MARK: Relative day / week titles

    /// `Today` / `Yesterday` / `Tomorrow` / weekday name.
    static func dayTitle(_ date: Date, now: Date) -> String {
        let cal = Calendar.current
        if cal.isDate(date, inSameDayAs: now) { return "Today" }
        if let y = cal.date(byAdding: .day, value: -1, to: now), cal.isDate(date, inSameDayAs: y) { return "Yesterday" }
        if let t = cal.date(byAdding: .day, value: 1, to: now), cal.isDate(date, inSameDayAs: t) { return "Tomorrow" }
        return weekdayFormatter.string(from: date)
    }

    /// The [start, end) interval of the week containing `date`.
    static func weekInterval(_ date: Date) -> DateInterval {
        Calendar.current.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, duration: 604_800)
    }

    /// `This Week` / `Last Week` / `Week of Jul 14`.
    static func weekTitle(_ date: Date, now: Date) -> String {
        let cal = Calendar.current
        if let cur = cal.dateInterval(of: .weekOfYear, for: now), cur.contains(date) { return "This Week" }
        if let last = cal.date(byAdding: .weekOfYear, value: -1, to: now),
           let li = cal.dateInterval(of: .weekOfYear, for: last), li.contains(date) { return "Last Week" }
        return "Week of \(monthDay(weekInterval(date).start))"
    }

    /// `Jul 21 – Jul 27`
    static func weekSubtitle(_ date: Date) -> String {
        let interval = weekInterval(date)
        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return "\(monthDay(interval.start)) – \(monthDay(lastDay))"
    }

    /// `JUL 15 – JUL 21` (inclusive last day of the interval).
    static func periodRange(_ interval: DateInterval) -> String {
        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: interval.end) ?? interval.end
        return "\(monthDay(interval.start)) – \(monthDay(lastDay))".uppercased()
    }
}
