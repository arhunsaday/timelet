import XCTest
@testable import Timelet

final class DurationParserTests: XCTestCase {
    func testDurations() {
        let cases: [(String, TimeInterval?)] = [
            ("45m", 2700), ("1h30", 5400), ("1h30m", 5400), ("1h", 3600), ("1.5h", 5400), ("1,5h", 5400),
            ("2h 10m", 7800), ("90", 5400), ("90 min", 5400), ("2 hours", 7200), ("", nil), ("abc", nil),
            ("0", nil), ("h", nil), ("1hx", nil),
        ]
        for (input, expected) in cases {
            XCTAssertEqual(DurationParser.seconds(from: input), expected, input)
        }
    }

    func testTimesOfDay() {
        XCTAssertEqual(DurationParser.timeOfDay(from: "9"), 540)
        XCTAssertEqual(DurationParser.timeOfDay(from: "9:30"), 570)
        XCTAssertEqual(DurationParser.timeOfDay(from: "14h"), 840)
        XCTAssertEqual(DurationParser.timeOfDay(from: "09h15"), 555)
        XCTAssertEqual(DurationParser.timeOfDay(from: "2pm"), 840)
        XCTAssertEqual(DurationParser.timeOfDay(from: "12am"), 0)
        XCTAssertEqual(DurationParser.timeOfDay(from: "12pm"), 720)
        XCTAssertNil(DurationParser.timeOfDay(from: "25:00"))
        XCTAssertNil(DurationParser.timeOfDay(from: "9:75"))
    }

    func testRanges() {
        XCTAssertEqual(DurationParser.timeRange(from: "9-10:30")?.start, 540)
        XCTAssertEqual(DurationParser.timeRange(from: "9-10:30")?.end, 630)
        XCTAssertEqual(DurationParser.timeRange(from: "9:00 – 10:30")?.end, 630)
        XCTAssertEqual(DurationParser.timeRange(from: "14h-15h30")?.end, 930)
        XCTAssertEqual(DurationParser.timeRange(from: "2-3pm")?.start, 840) // pm carries over
        XCTAssertEqual(DurationParser.timeRange(from: "2pm to 3:15pm")?.end, 915)
        XCTAssertEqual(DurationParser.timeRange(from: "23:00-1:00")?.end, 25 * 60) // crosses midnight
        XCTAssertNil(DurationParser.timeRange(from: "45m"))
        XCTAssertNil(DurationParser.timeRange(from: "1-23")) // 22h is not a work block
    }
}

final class EntryParserTests: XCTestCase {
    let now = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 15, minute: 0))!

    func testLabels() {
        XCTAssertEqual(EntryParser.splitLabel("Timelet: Electron refactor").project, "Timelet")
        XCTAssertEqual(EntryParser.splitLabel("Timelet:Electron refactor").activity, "Electron refactor")
        XCTAssertEqual(EntryParser.splitLabel("Lunch").project, EntryParser.defaultProject)
        XCTAssertEqual(EntryParser.splitLabel(":x").project, EntryParser.defaultProject)
        XCTAssertEqual(EntryParser.splitLabel("A:").activity, "Untitled")
        XCTAssertEqual(EntryParser.splitLabel("A: b: c").activity, "b: c")
    }

    func testAgo() {
        let p = EntryParser.checkIn("Timelet: Review 20m ago", now: now)
        XCTAssertEqual(p.label, "Timelet:Review")
        XCTAssertEqual(p.start, now.addingTimeInterval(-1200))
        XCTAssertEqual(EntryParser.checkIn("Standup 1h 15m ago", now: now).start, now.addingTimeInterval(-4500))
    }

    func testSince() {
        let p = EntryParser.checkIn("Client-X: Bug since 14:30", now: now)
        XCTAssertEqual(p.activity, "Bug")
        XCTAssertEqual(p.start, now.addingTimeInterval(-1800))
        XCTAssertEqual(EntryParser.checkIn("Standup @9", now: now).start, now.addingTimeInterval(-6 * 3600))
    }

    func testRejectsFutureAndTooOld() {
        XCTAssertNil(EntryParser.checkIn("Plan since 16:00", now: now).start)
        XCTAssertNil(EntryParser.checkIn("Plan 20h ago", now: now).start)
        // Not a modifier, just part of the name.
        XCTAssertEqual(EntryParser.checkIn("Meeting with 2 people", now: now).activity, "Meeting with 2 people")
    }
}

final class RankingTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    lazy var tasks = [
        TaskSuggestion(project: "Timelet", activity: "Electron refactor", colorHex: "", lastUsed: now.addingTimeInterval(-60), uses: 10),
        TaskSuggestion(project: "Timelet", activity: "Design mockups", colorHex: "", lastUsed: now.addingTimeInterval(-7200), uses: 3),
        TaskSuggestion(project: "Client-X", activity: "Auth token bugfix", colorHex: "", lastUsed: now.addingTimeInterval(-3600), uses: 2),
        TaskSuggestion(project: "Learning", activity: "Rust ownership", colorHex: "", lastUsed: now.addingTimeInterval(-86400), uses: 1),
    ]

    func testEmptyQueryIsMostRecentFirst() {
        XCTAssertEqual(Ranking.rank(tasks, query: "").map(\.activity), ["Electron refactor", "Auth token bugfix", "Design mockups", "Rust ownership"])
    }

    func testPrefixBeatsSubstringBeatsFuzzy() {
        XCTAssertEqual(Ranking.rank(tasks, query: "des").first?.activity, "Design mockups")
        XCTAssertEqual(Ranking.rank(tasks, query: "auth").first?.activity, "Auth token bugfix")
        XCTAssertEqual(Ranking.rank(tasks, query: "token").first?.activity, "Auth token bugfix") // word prefix
        XCTAssertEqual(Ranking.rank(tasks, query: "tlelec").first?.activity, "Electron refactor") // fuzzy
        XCTAssertTrue(Ranking.rank(tasks, query: "zzz").isEmpty)
    }

    func testProjectScopedQuery() {
        XCTAssertEqual(Ranking.rank(tasks, query: "timelet: d").map(\.activity), ["Design mockups"])
        XCTAssertEqual(Ranking.rank(tasks, query: "Timelet:").count, 2)
    }

    func testStrongMatchOnlyForPrefixes() {
        XCTAssertTrue(Ranking.isStrongMatch(tasks[0], query: "Timelet: Ele"))
        XCTAssertTrue(Ranking.isStrongMatch(tasks[0], query: "elec"))
        XCTAssertFalse(Ranking.isStrongMatch(tasks[0], query: "Timelet: New feature"))
        XCTAssertFalse(Ranking.isStrongMatch(tasks[0], query: "refactor"))
    }

    func testFormats() {
        XCTAssertEqual(Format.stopwatch(252), "04:12")
        XCTAssertEqual(Format.stopwatch(4335), "1:12:15")
        XCTAssertEqual(Format.stopwatchCompact(4335), "1:12")
        XCTAssertEqual(Format.duration(5400), "1h 30m")
        XCTAssertEqual(Format.relative(now.addingTimeInterval(-30), now: now), "just now")
        XCTAssertEqual(Format.relative(now.addingTimeInterval(-600), now: now), "10m ago")
    }
}
