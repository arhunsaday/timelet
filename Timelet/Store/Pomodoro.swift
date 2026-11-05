import Foundation
import Observation

/// Focus sessions on top of tracking: focus → short break → … → long break, repeating.
///
/// A break pauses tracking, so it never appears in the day; when it ends the same task resumes.
/// Scheduled check-ins are held off while focusing. Stopping, pausing or walking away from the
/// task during focus ends the cycle.
@Observable
@MainActor
final class Pomodoro {
    enum Phase: Equatable {
        case focus, shortBreak, longBreak
        var isBreak: Bool { self != .focus }
    }

    /// Phase changes the UI announces.
    enum Event: Equatable {
        case focusEnded(next: Phase)
        case breakEnded
    }

    private(set) var phase: Phase?
    private(set) var phaseEnd: Date?
    /// Focus sessions finished in this cycle.
    private(set) var completed = 0
    /// Refreshed every second while a cycle runs, for countdowns.
    private(set) var now: Date

    @ObservationIgnored var onEvent: ((Event) -> Void)?
    @ObservationIgnored private let engine: TrackingEngine
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let usesTimer: Bool
    @ObservationIgnored private var timer: Timer?

    init(engine: TrackingEngine, settings: AppSettings, clock: @escaping () -> Date = { .now }, startTimer: Bool = true) {
        self.engine = engine
        self.settings = settings
        self.clock = clock
        self.usesTimer = startTimer
        now = clock()
    }

    var isActive: Bool { phase != nil }
    var isFocusing: Bool { phase == .focus }
    var isOnBreak: Bool { phase?.isBreak ?? false }
    var remaining: TimeInterval { max(0, (phaseEnd ?? now).timeIntervalSince(now)) }

    /// Starts a cycle on the running task, resuming the last one if nothing is running.
    func start() {
        if engine.runningEntry == nil { engine.continuePrevious() }
        guard engine.runningEntry != nil else { return }
        completed = 0
        begin(.focus)
    }

    func stop() {
        phase = nil
        phaseEnd = nil
        timer?.invalidate()
        timer = nil
    }

    /// Ends the break now and resumes the task.
    func skipBreak() {
        guard isOnBreak else { return }
        engine.resume()
        guard engine.runningEntry != nil else { stop(); return }
        begin(.focus)
    }

    func tick() {
        let t = clock()
        now = t
        guard let phase, let end = phaseEnd else { return }
        if phase == .focus {
            guard engine.runningEntry != nil else { stop(); return } // stopped, paused or away
            guard t >= end else { return }
            completed += 1
            let next: Phase = completed % max(1, settings.pomodoroLongBreakEvery) == 0 ? .longBreak : .shortBreak
            engine.pause()
            begin(next)
            onEvent?(.focusEnded(next: next))
        } else {
            if engine.runningEntry != nil { begin(.focus); return } // back to work early
            guard engine.isPaused else { stop(); return }           // tracking was stopped
            guard t >= end else { return }
            engine.resume()
            guard engine.runningEntry != nil else { stop(); return }
            begin(.focus)
            onEvent?(.breakEnded)
        }
    }

    private func begin(_ next: Phase) {
        let t = clock()
        now = t
        phase = next
        phaseEnd = t.addingTimeInterval(TimeInterval(minutes(for: next) * 60))
        if usesTimer, timer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            timer.tolerance = 0.2
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    func minutes(for phase: Phase) -> Int {
        switch phase {
        case .focus: settings.pomodoroFocusMinutes
        case .shortBreak: settings.pomodoroShortBreakMinutes
        case .longBreak: settings.pomodoroLongBreakMinutes
        }
    }
}
