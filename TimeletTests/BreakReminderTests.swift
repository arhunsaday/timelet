import SwiftData
import XCTest
@testable import Timelet

/// Walks `BreakReminder` through a working day with a fake clock and fake idle time.
@MainActor
final class BreakReminderTests: XCTestCase {
    final class Clock { var now: Date; init(_ d: Date) { now = d } }

    var container: ModelContainer!
    var settings: AppSettings!
    var clock: Clock!
    var idle: TimeInterval = 0
    var engine: TrackingEngine!
    var pomodoro: Pomodoro!
    var reminder: BreakReminder!
    var events: [BreakReminder.Event] = []

    override func setUp() async throws {
        let schema = Schema([Project.self, Activity.self, Entry.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let defaults = UserDefaults(suiteName: "timelet-breaks-\(UUID().uuidString)")!
        settings = AppSettings(defaults: defaults)
        settings.workHoursOnly = false
        settings.idleDetectionEnabled = false
        settings.breakReminderMinutes = 60
        settings.pomodoroShortBreakMinutes = 5
        clock = Clock(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 9))!)
        idle = 0
        engine = TrackingEngine(context: container.mainContext, settings: settings, clock: { [unowned self] in clock.now },
                                defaults: defaults, startTimers: false)
        engine.idleSeconds = { [unowned self] in idle }
        pomodoro = Pomodoro(engine: engine, settings: settings, clock: { [unowned self] in clock.now }, startTimer: false)
        reminder = BreakReminder(engine: engine, pomodoro: pomodoro, settings: settings,
                                 clock: { [unowned self] in clock.now }, startTimer: false)
        events = []
        reminder.onEvent = { [unowned self] in events.append($0) }
    }

    /// Moves the clock in one-minute ticks, like the app's timer (but coarser).
    private func work(_ minutes: Int) {
        for _ in 0..<minutes {
            clock.now = clock.now.addingTimeInterval(60)
            reminder.tick()
        }
    }

    func testRemindsAfterTheLimitAcrossTaskSwitches() {
        engine.track("A: One")
        reminder.tick()
        work(30)
        engine.track("B: Two")
        work(29)
        XCTAssertTrue(events.isEmpty)
        work(1)
        XCTAssertEqual(events, [.due(worked: 60 * 60)])
    }

    func testAFiveMinuteStopResetsTheStretch() {
        engine.track("A: One")
        reminder.tick()
        work(40)
        engine.stopTracking()
        work(5)
        engine.track("A: One")
        work(40)
        XCTAssertTrue(events.isEmpty)
    }

    func testBeingIdleCountsAsABreak() {
        engine.track("A: One")
        reminder.tick()
        work(40)
        idle = 600
        work(6)
        idle = 0
        work(40)
        XCTAssertTrue(events.isEmpty)
    }

    func testLaterAsksAgainAfterFifteenMinutes() {
        engine.track("A: One")
        reminder.tick()
        work(60)
        reminder.later()
        work(14)
        XCTAssertEqual(events.count, 1)
        work(1)
        XCTAssertEqual(events.count, 2)
    }

    func testTakingABreakPausesThenOffersToResume() {
        engine.track("A: One")
        reminder.tick()
        work(60)
        reminder.takeBreak()
        XCTAssertTrue(engine.isPaused)
        XCTAssertTrue(reminder.isOnBreak)
        work(5)
        XCTAssertEqual(events.last, .breakOver)
        reminder.resume()
        XCTAssertEqual(engine.currentActivity?.label, "A:One")
    }

    func testResumingEarlyCancelsTheBreak() {
        engine.track("A: One")
        reminder.tick()
        work(60)
        reminder.takeBreak()
        engine.togglePause()
        work(10)
        XCTAssertFalse(reminder.isOnBreak)
        XCTAssertNotEqual(events.last, .breakOver)
    }

    func testQuietDuringAFocusSession() {
        engine.track("A: One")
        pomodoro.start()
        work(20)
        XCTAssertTrue(events.isEmpty)
    }

    func testOffWhenSetToNever() {
        settings.breakReminderMinutes = 0
        engine.track("A: One")
        reminder.tick()
        work(180)
        XCTAssertTrue(events.isEmpty)
    }
}
