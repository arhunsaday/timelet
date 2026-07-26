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

    /// `mm:ss` with zero-padded minutes (toolbar pill, menu-bar row): `04:12`, `72:15`.
    static func stopwatch(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// `m:ss` with un-padded minutes (compact menu-bar title): `4:12`.
    static func stopwatchCompact(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: Time of day

    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let longDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    /// `13:30`
    static func clock(_ date: Date) -> String { clockFormatter.string(from: date) }

    /// `13:30 – 15:40`
    static func timeRange(_ start: Date, _ end: Date) -> String {
        "\(clockFormatter.string(from: start)) – \(clockFormatter.string(from: end))"
    }

    /// `Monday, July 21`
    static func longDate(_ date: Date) -> String { longDateFormatter.string(from: date) }
}
