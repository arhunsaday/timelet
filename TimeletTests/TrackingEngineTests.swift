import SwiftData
import XCTest
@testable import Timelet

/// Drives `TrackingEngine` with an in-memory store, a fake clock and fake idle time.
@MainActor
final class TrackingEngineTests: XCTestCase {
    final class Clock { var now: Date; init(_ d: Date) { now = d } }

    var container: ModelContainer!
    var defaults: UserDefaults!
    var settings: AppSettings!
    var clock: Clock!
    var idle: TimeInterval = 0
    var engine: TrackingEngine!

    /// Wednesday 28 Oct 2026, 10:00.
    let start = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 10))!

    override func setUp() async throws {
        let schema = Schema([Project.self, Activity.self, Entry.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        defaults = UserDefaults(suiteName: "timelet-tests-\(UUID().uuidString)")
        settings = AppSettings(defaults: defaults)
        settings.workHoursOnly = false
        settings.askIntervalMinutes = 20
        settings.idleThresholdMinutes = 5
        clock = Clock(start)
        engine = makeEngine()
    }

    override func tearDown() {
        Entry.reportingStep = 0
    }

    private func makeEngine() -> TrackingEngine {
        let e = TrackingEngine(context: container.mainContext, settings: settings, clock: { [unowned self] in clock.now },
                               defaults: defaults, startTimers: false)
        e.idleSeconds = { [unowned self] in idle }
        return e
    }

    private func advance(_ minutes: Double) { clock.now = clock.now.addingTimeInterval(minutes * 60) }

    private var entries: [Entry] {
        (try? container.mainContext.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.start)]))) ?? []
    }

    // MARK: Tracking

    func testSwitchingClosesThePreviousBlock() {
        engine.track("Timelet: Design")
        advance(30)
        engine.track("Client-X: Bug")
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].end, clock.now)
        XCTAssertEqual(entries[0].activity?.label, "Timelet:Design")
        XCTAssertNil(entries[1].end)
        XCTAssertEqual(engine.currentActivity?.label, "Client-X:Bug")
    }

    func testSameTaskKeepsRunningAndTakesTheNote() {
        engine.track("Timelet: Design")
        advance(10)
        engine.track("timelet:design", note: "wireframes")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].note, "wireframes")
        XCTAssertEqual(engine.elapsed, 600)
    }

    func testBackdatedSwitchEndsThePreviousTaskAtTheStart() {
        engine.track("Timelet: Design")
        advance(60)
        engine.track("Client-X: Call 20m ago")
        XCTAssertEqual(entries[0].end, clock.now.addingTimeInterval(-1200))
        XCTAssertEqual(entries[1].start, clock.now.addingTimeInterval(-1200))
    }

    func testBackdatingNeverOverlapsCompletedBlocks() {
        engine.track("A: one")
        advance(10)
        engine.stopTracking()
        advance(5)
        engine.track("B: two 30m ago") // would start before A ended
        XCTAssertEqual(entries[1].start, entries[0].end)
    }

    func testBackdatingBeforeARunningTaskReplacesIt() {
        engine.track("A: misfire")
        advance(2)
        engine.track("B: real 10m ago")
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].activity?.label, "B:real")
    }

    func testPauseAndResumeMakeTwoBlocks() {
        engine.track("A: x")
        advance(15)
        engine.togglePause()
        XCTAssertTrue(engine.isPaused)
        XCTAssertNil(engine.runningEntry)
        advance(10)
        engine.togglePause()
        XCTAssertFalse(engine.isPaused)
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[1].start, clock.now)
    }

    func testContinueRestartsTheLastTaskAfterStop() {
        engine.track("A: x")
        advance(5)
        engine.stopTracking()
        advance(5)
        engine.continuePrevious()
        XCTAssertEqual(engine.currentActivity?.label, "A:x")
        XCTAssertEqual(entries.count, 2)
    }

    func testNewProjectsGetUnusedColors() {
        engine.track("A: x")
        engine.track("B: y")
        let colors = Set(((try? container.mainContext.fetch(FetchDescriptor<Project>())) ?? []).map(\.colorHex))
        XCTAssertEqual(colors.count, 2)
    }

    func testUsingAnArchivedProjectUnarchivesIt() throws {
        engine.track("A: x")
        let project = try XCTUnwrap(engine.currentActivity?.project)
        engine.setProjectArchived(project, true)
        engine.track("a: y")
        XCTAssertFalse(project.isArchived)
    }

    // MARK: Entries

    func testDeleteCanBeUndone() throws {
        engine.addEntry(text: "A: x", start: start, end: start.addingTimeInterval(1800), note: "n")
        engine.deleteEntry(try XCTUnwrap(entries.first))
        XCTAssertTrue(entries.isEmpty)
        engine.undoDelete()
        XCTAssertEqual(entries.first?.note, "n")
        XCTAssertEqual(entries.first?.end, start.addingTimeInterval(1800))
    }

    func testRoundingIsReportedNotStored() throws {
        Entry.reportingStep = 300
        engine.addEntry(text: "A: x", start: start, end: start.addingTimeInterval(7 * 60), note: nil)
        engine.addEntry(text: "A: y", start: start, end: start.addingTimeInterval(8 * 60), note: nil)
        engine.addEntry(text: "A: z", start: start, end: start.addingTimeInterval(60), note: nil)
        let d = entries.map { $0.duration() }.sorted()
        XCTAssertEqual(d, [300, 300, 600])
        XCTAssertEqual(entries.first { $0.activity?.name == "x" }?.end, start.addingTimeInterval(7 * 60))
    }

    // MARK: Check-in schedule

    func testAskIsDueOneIntervalAfterTheLastCheckIn() {
        var asked = 0
        engine.onAskDue = { asked += 1 }
        advance(10)
        engine.track("A: x") // a check-in resets the schedule
        advance(19)
        engine.checkAsk(at: clock.now)
        XCTAssertEqual(asked, 0)
        advance(1)
        engine.checkAsk(at: clock.now)
        XCTAssertEqual(asked, 1)
        engine.checkAsk(at: clock.now)
        XCTAssertEqual(asked, 1, "does not ask twice in a row")
    }

    func testNoAskOutsideWorkHoursOrWhileSnoozed() {
        var asked = 0
        engine.onAskDue = { asked += 1 }
        settings.workHoursOnly = true
        settings.workStartMinutes = 9 * 60
        settings.workEndMinutes = 9 * 60 + 30 // over at 9:30; it's 10:00
        advance(25)
        engine.tick()
        engine.checkAsk(at: clock.now)
        XCTAssertEqual(asked, 0)
        settings.workHoursOnly = false
        engine.snooze(for: 3600)
        advance(25)
        engine.tick()
        engine.checkAsk(at: clock.now)
        XCTAssertEqual(asked, 0)
    }

    func testDoneForTodayWaitsForTheNextWorkday() throws {
        settings.workHoursOnly = true
        settings.workDays = [2, 3, 4, 5, 6]
        engine.track("A: x")
        engine.doneForToday()
        let until = try XCTUnwrap(engine.snoozedUntil)
        let c = Calendar.current.dateComponents([.weekday, .hour], from: until)
        XCTAssertEqual(c.weekday, 5) // Thursday
        XCTAssertEqual(c.hour, 9)
        XCTAssertNil(engine.runningEntry)
    }

    // MARK: Away time

    func testIdleIsCarvedOutAndCanBeLogged() throws {
        var prompted: TimeInterval?
        engine.onAwayReturn = { prompted = $0 }
        engine.track("A: work")
        advance(30)
        idle = 12 * 60
        engine.checkIdle() // away since 12 minutes ago
        idle = 0
        engine.checkIdle() // back
        XCTAssertEqual(try XCTUnwrap(prompted), 12 * 60, accuracy: 1)
        XCTAssertEqual(entries[0].end, clock.now.addingTimeInterval(-12 * 60))
        XCTAssertNil(engine.runningEntry)

        engine.logAway(as: "Admin: Lunch", note: nil)
        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries[1].activity?.label, "Admin:Lunch")
        XCTAssertEqual(engine.currentActivity?.label, "A:work", "resumes the previous task")
    }

    func testSleepCountsAsAway() {
        var prompted = false
        engine.onAwayReturn = { _ in prompted = true }
        engine.track("A: work")
        advance(20)
        engine.noteAway()
        advance(40)
        engine.noteBack()
        XCTAssertTrue(prompted)
        XCTAssertEqual(entries[0].end, start.addingTimeInterval(20 * 60))
    }

    func testLongAwayStopsInsteadOfPrompting() {
        var prompted = false
        engine.onAwayReturn = { _ in prompted = true }
        engine.track("A: work")
        advance(30)
        engine.noteAway()
        advance(5 * 60)
        engine.noteBack()
        XCTAssertFalse(prompted)
        XCTAssertNil(engine.pendingAway)
        XCTAssertNil(engine.runningEntry)
        XCTAssertEqual(engine.lastActivityLabel, "A:work")
    }

    func testDiscardingAwayTimeResumes() {
        engine.track("A: work")
        advance(30)
        engine.noteAway()
        advance(15)
        engine.noteBack()
        engine.finishAway(resume: true)
        XCTAssertEqual(engine.currentActivity?.label, "A:work")
        XCTAssertEqual(entries.count, 2)
    }

    // MARK: Launch recovery

    func testTaskLeftRunningWhenTheAppQuitEndsAtTheLastHeartbeat() {
        engine.track("A: work")
        advance(45)
        engine.writeHeartbeat()
        let quitAt = clock.now
        advance(60) // app closed for an hour

        let relaunched = makeEngine()
        XCTAssertNil(relaunched.runningEntry)
        XCTAssertEqual(entries[0].end, quitAt)
        XCTAssertEqual(relaunched.pendingAway?.duration, 3600)
        XCTAssertEqual(relaunched.lastActivityLabel, "A:work")
    }

    func testRecentHeartbeatKeepsTheTaskRunning() {
        engine.track("A: work")
        advance(10)
        engine.writeHeartbeat()
        advance(1)
        let relaunched = makeEngine()
        XCTAssertEqual(relaunched.currentActivity?.label, "A:work")
    }

    // MARK: Suggestions

    func testSuggestionsRankRecentAndMatching() {
        engine.addEntry(text: "Timelet: Design", start: start.addingTimeInterval(-7200), end: start.addingTimeInterval(-3600), note: nil)
        engine.addEntry(text: "Client-X: Auth", start: start.addingTimeInterval(-3600), end: start, note: nil)
        XCTAssertEqual(engine.suggestions(matching: "", limit: 5).first?.label, "Client-X:Auth")
        XCTAssertEqual(engine.suggestions(matching: "des", limit: 5).first?.label, "Timelet:Design")
    }

    func testDeletingAProjectForgetsItsTask() throws {
        engine.track("A: x")
        let project = try XCTUnwrap(engine.currentActivity?.project)
        engine.deleteProject(project)
        XCTAssertNil(engine.runningEntry)
        XCTAssertNil(engine.lastActivityLabel)
        XCTAssertTrue(entries.isEmpty)
    }

    func testDaySummaryGaps() {
        engine.addEntry(text: "A: x", start: start, end: start.addingTimeInterval(3600), note: nil)
        engine.addEntry(text: "A: y", start: start.addingTimeInterval(5400), end: start.addingTimeInterval(7200), note: nil)
        let summary = DaySummary.build(entries: entries, day: start, now: start.addingTimeInterval(9000))
        let gaps = summary.gaps(from: start.addingTimeInterval(-1800), to: start.addingTimeInterval(9000))
        XCTAssertEqual(gaps.map(\.duration), [1800, 1800, 1800])
        XCTAssertEqual(summary.totalTracked, 5400)
    }
}
