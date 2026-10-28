import Foundation
import SwiftData

enum SampleData {
    /// A believable week for demos and screenshots (`TIMELET_SAMPLE=1`): today matches the
    /// design handoff's screen 2a, earlier days vary, and a task is running.
    @MainActor
    static func seed(into context: ModelContext, now: Date = .now) {
        let cal = Calendar.current

        let timelet = Project(name: "Timelet", colorHex: Theme.palette[0], order: 0)
        let clientX = Project(name: "Client-X", colorHex: Theme.palette[1], order: 1)
        let learning = Project(name: "Learning", colorHex: Theme.palette[2], order: 2)
        let admin = Project(name: "Admin", colorHex: Theme.palette[3], order: 3)
        [timelet, clientX, learning, admin].forEach(context.insert)

        var activities: [String: Activity] = [:]
        func activity(_ name: String, _ project: Project) -> Activity {
            if let a = activities[name] { return a }
            let a = Activity(name: name, project: project)
            context.insert(a)
            activities[name] = a
            return a
        }

        func day(_ offset: Int, _ blocks: [(Int, Int, Int, Int, String, Project, String?)]) {
            guard let date = cal.date(byAdding: .day, value: -offset, to: now) else { return }
            for (h1, m1, h2, m2, name, project, note) in blocks {
                guard let s = cal.date(bySettingHour: h1, minute: m1, second: 0, of: date),
                      let e = cal.date(bySettingHour: h2, minute: m2, second: 0, of: date), e <= now else { continue }
                context.insert(Entry(start: s, end: e, activity: activity(name, project), note: note))
            }
        }

        day(0, [
            (9, 0, 9, 25, "Standup", admin, nil),
            (9, 25, 11, 0, "Design mockups", timelet, "Check-in panel, gentle reminder card, menu bar."),
            (11, 20, 12, 50, "Auth token bugfix", clientX, "Refresh token expired early on Safari. Fixed the clock skew."),
            (13, 30, 15, 40, "Electron refactor", timelet, nil),
            (15, 45, 16, 25, "Rust ownership", learning, nil),
        ])
        day(1, [
            (9, 0, 9, 20, "Standup", admin, nil), (9, 20, 12, 10, "Electron refactor", timelet, nil),
            (13, 0, 15, 30, "API pagination", clientX, nil), (15, 30, 17, 15, "Code review", clientX, nil),
        ])
        day(2, [
            (9, 0, 9, 15, "Standup", admin, nil), (9, 15, 11, 45, "Design mockups", timelet, nil),
            (12, 30, 14, 0, "Rust ownership", learning, nil), (14, 0, 17, 40, "Auth token bugfix", clientX, nil),
        ])
        day(3, [
            (9, 30, 12, 0, "Electron refactor", timelet, nil), (13, 0, 14, 30, "Invoices", admin, nil),
            (14, 30, 16, 50, "API pagination", clientX, nil),
        ])
        day(4, [
            (9, 0, 9, 20, "Standup", admin, nil), (9, 20, 12, 30, "Release 1.2", timelet, nil),
            (13, 30, 15, 0, "Code review", clientX, nil),
        ])

        // A task in progress, started a few minutes ago.
        if let last = cal.date(bySettingHour: 16, minute: 25, second: 0, of: now), last < now {
            context.insert(Entry(start: max(last, now.addingTimeInterval(-252)), end: nil, activity: activity("Electron refactor", timelet)))
        }
        try? context.save()
    }
}
