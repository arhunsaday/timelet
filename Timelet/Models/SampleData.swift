import Foundation
import SwiftData

enum SampleData {
    /// Seed the handoff's verbatim sample data (screen 2a), dated to today, plus a
    /// currently-running "Electron refactor" segment started 4:12 ago (matches the pill).
    @MainActor
    static func seed(into context: ModelContext) {
        let cal = Calendar.current
        func today(_ h: Int, _ m: Int) -> Date {
            cal.date(bySettingHour: h, minute: m, second: 0, of: .now) ?? .now
        }

        let timelet = Project(name: "Timelet", colorHex: Theme.palette[0], order: 0)
        let clientX = Project(name: "Client-X", colorHex: Theme.palette[1], order: 1)
        let learning = Project(name: "Learning", colorHex: Theme.palette[2], order: 2)
        let admin = Project(name: "Admin", colorHex: Theme.palette[3], order: 3)
        [timelet, clientX, learning, admin].forEach(context.insert)

        func activity(_ name: String, _ project: Project) -> Activity {
            let a = Activity(name: name, project: project)
            context.insert(a)
            return a
        }
        let electron = activity("Electron refactor", timelet)
        let mockups = activity("Design mockups", timelet)
        let authBug = activity("Auth token bugfix", clientX)
        let rust = activity("Rust ownership", learning)
        let standup = activity("Standup", admin)

        func entry(_ a: Activity, _ start: Date, _ end: Date) {
            context.insert(Entry(start: start, end: end, activity: a))
        }
        entry(electron, today(13, 30), today(15, 40)) // 2h 10m
        entry(mockups, today(9, 15), today(11, 0))    // 1h 45m
        entry(authBug, today(11, 20), today(12, 50))  // 1h 30m
        entry(rust, today(15, 45), today(16, 25))     // 40m
        entry(standup, today(9, 0), today(9, 25))      // 25m

        // Currently running segment.
        context.insert(Entry(start: .now.addingTimeInterval(-252), end: nil, activity: electron))

        try? context.save()
    }
}
