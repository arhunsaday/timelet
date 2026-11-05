import SwiftData
import XCTest
@testable import Timelet

/// Walks `Pomodoro` through focus and break phases with a fake clock.
@MainActor
final class PomodoroTests: XCTestCase {
    final class Clock { var now: Date; init(_ d: Date) { now = d } }

    var container: ModelContainer!
    var settings: AppSettings!
    var clock: Clock!
    var engine: TrackingEngine!
    var pomodoro: Pomodoro!
    var events: [Pomodoro.Event] = []

    override func setUp() async throws {
        let schema = Schema([Project.self, Activity.self, Entry.self])
        container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let defaults = UserDefaults(suiteName: "timelet-pomodoro-\(UUID().uuidString)")!
        settings = AppSettings(defaults: defaults)
        settings.workHoursOnly = false
        settings.pomodoroFocusMinutes = 25
        settings.pomodoroShortBreakMinutes = 5
        settings.pomodoroLongBreakMinutes = 15
        settings.pomodoroLongBreakEvery = 2
        clock = Clock(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 28, hour: 10))!)
        engine = TrackingEngine(context: container.mainContext, settings: settings, clock: { [unowned self] in clock.now },
                                defaults: defaults, startTimers: false)
        engine.idleSeconds = { 0 }
        pomodoro = Pomodoro(engine: engine, settings: settings, clock: { [unowned self] in clock.now }, startTimer: false)
        engine.asksSuppressed = { [unowned self] in pomodoro.isFocusing }
        events = []
        pomodoro.onEvent = { [unowned self] in events.append($0) }
    }

    private func advance(_ minutes: Double) {
        clock.now = clock.now.addingTimeInterval(minutes * 60)
        pomodoro.tick()
    }

    private var entries: [Entry] {
        (try? container.mainContext.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.start)]))) ?? []
    }

    func testFocusEndsInAPausedBreakAndTheTaskResumesAfterIt() {
        engine.track("Timelet: Design")
        pomodoro.start()
        XCTAssertTrue(pomodoro.isFocusing)

        advance(25)
        XCTAssertEqual(pomodoro.phase, .shortBreak)
        XCTAssertTrue(engine.isPaused)
        XCTAssertNil(engine.runningEntry)
        XCTAssertEqual(events, [.focusEnded(next: .shortBreak)])

        advance(5)
        XCTAssertEqual(pomodoro.phase, .focus)
        XCTAssertEqual(engine.currentActivity?.label, "Timelet:Design")
        XCTAssertEqual(events.last, .breakEnded)
        // The break is not tracked: two blocks with a 5-minute hole between them.
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[1].start.timeIntervalSince(entries[0].end!), 5 * 60)
    }

    func testEveryNthSessionGetsALongBreak() {
        engine.track("Timelet: Design")
        pomodoro.start()
        advance(25)
        advance(5)
        advance(25)
        XCTAssertEqual(pomodoro.phase, .longBreak)
        XCTAssertEqual(pomodoro.remaining, 15 * 60)
    }

    func testStartResumesTheLastTaskWhenNothingRuns() {
        engine.track("Timelet: Design")
        engine.stopTracking()
        pomodoro.start()
        XCTAssertTrue(pomodoro.isFocusing)
        XCTAssertEqual(engine.currentActivity?.label, "Timelet:Design")
    }

    func testStoppingTheTaskEndsTheCycle() {
        engine.track("Timelet: Design")
        pomodoro.start()
        advance(3)
        engine.stopTracking()
        advance(1)
        XCTAssertFalse(pomodoro.isActive)
    }

    func testResumingDuringTheBreakStartsTheNextFocus() {
        engine.track("Timelet: Design")
        pomodoro.start()
        advance(25)
        engine.togglePause()
        advance(1)
        XCTAssertTrue(pomodoro.isFocusing)
        XCTAssertEqual(pomodoro.remaining, 25 * 60)
    }

    func testSkipBreakResumesTheTask() {
        engine.track("Timelet: Design")
        pomodoro.start()
        advance(25)
        pomodoro.skipBreak()
        XCTAssertTrue(pomodoro.isFocusing)
        XCTAssertNotNil(engine.runningEntry)
    }

    func testCheckInsWaitWhileFocusing() {
        engine.track("Timelet: Design")
        pomodoro.start()
        XCTAssertFalse(engine.canAsk)
        pomodoro.stop()
        XCTAssertTrue(engine.canAsk)
    }
}
