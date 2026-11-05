import Foundation
import Observation

/// Suggests a break after a long stretch of continuous work, across task switches.
///
/// A stretch ends when nothing is tracked, or the user is idle, for `restThreshold`. Taking the
/// break pauses tracking; when it is over the user is offered to resume. Quiet while a focus
/// session runs, which has breaks of its own.
@Observable
@MainActor
final class BreakReminder {
    enum Event: Equatable {
        case due(worked: TimeInterval)
        case breakOver
    }

    /// Start of the current stretch of work.
    private(set) var workingSince: Date?
    /// End of the break being taken, if any.
    private(set) var breakEnd: Date?

    @ObservationIgnored var onEvent: ((Event) -> Void)?
    @ObservationIgnored private let engine: TrackingEngine
    @ObservationIgnored private let pomodoro: Pomodoro
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var lastWorking: Date?
    @ObservationIgnored private var nextReminder: Date?
    @ObservationIgnored private var timer: Timer?

    /// A pause at least this long counts as a break.
    static let restThreshold: TimeInterval = 5 * 60
    /// An unanswered reminder comes back after this long.
    static let repeatAfter: TimeInterval = 30 * 60
    /// "Later" asks again after this long.
    static let laterDelay: TimeInterval = 15 * 60

    init(engine: TrackingEngine, pomodoro: Pomodoro, settings: AppSettings,
         clock: @escaping () -> Date = { .now }, startTimer: Bool = true) {
        self.engine = engine
        self.pomodoro = pomodoro
        self.settings = settings
        self.clock = clock
        if startTimer {
            let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            timer.tolerance = 1
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    var isOnBreak: Bool { breakEnd != nil }

    func tick() {
        let t = clock()
        if let end = breakEnd {
            if engine.runningEntry != nil {
                breakEnd = nil // back to work early
            } else if t >= end {
                breakEnd = nil
                onEvent?(.breakOver)
            }
        }

        let working = engine.isTracking && !pomodoro.isActive && engine.idleSeconds() < 60
        guard working else { return }
        if workingSince == nil || t.timeIntervalSince(lastWorking ?? .distantPast) >= Self.restThreshold {
            workingSince = t
            nextReminder = nil
        }
        lastWorking = t

        guard settings.breakReminderMinutes > 0, let since = workingSince else { return }
        let due = nextReminder ?? since.addingTimeInterval(TimeInterval(settings.breakReminderMinutes * 60))
        guard t >= due else { return }
        nextReminder = t.addingTimeInterval(Self.repeatAfter)
        onEvent?(.due(worked: t.timeIntervalSince(since)))
    }

    func later() { nextReminder = clock().addingTimeInterval(Self.laterDelay) }

    /// Pauses tracking for the break length from Settings.
    func takeBreak() {
        engine.pause()
        breakEnd = clock().addingTimeInterval(TimeInterval(settings.pomodoroShortBreakMinutes * 60))
        workingSince = nil
        lastWorking = nil
        nextReminder = nil
    }

    func resume() {
        breakEnd = nil
        engine.resume()
    }
}
