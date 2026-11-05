import SwiftUI
import Observation

enum AppearanceMode: String, CaseIterable, Identifiable {
    case light, dark, auto
    var id: String { rawValue }
    var label: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .auto: "Auto"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .auto: nil
        }
    }
}

/// How the scheduled check-in shows up.
enum CheckInStyle: String, CaseIterable, Identifiable {
    /// A small card in the corner that never takes the keyboard; ignoring it keeps the current task.
    case gentle
    /// The full check-in, centered and focused, like pressing the shortcut.
    case focused
    var id: String { rawValue }
    var label: String {
        switch self {
        case .gentle: "Gentle reminder"
        case .focused: "Ask right away"
        }
    }
    var help: String {
        switch self {
        case .gentle: "A small card in the corner. It never steals your typing; ignoring it keeps the current task."
        case .focused: "The check-in opens in the middle of the screen, ready to type."
        }
    }
}

/// What the menu-bar item shows next to its icon.
enum MenuBarDisplay: String, CaseIterable, Identifiable {
    case timer, taskAndTimer, todayTotal, iconOnly
    var id: String { rawValue }
    var label: String {
        switch self {
        case .timer: "Timer"
        case .taskAndTimer: "Task and timer"
        case .todayTotal: "Today's total"
        case .iconOnly: "Icon only"
        }
    }
}

/// User preferences, persisted to `UserDefaults`. Exposed as an `@Observable` object so both
/// SwiftUI views and the non-view tracking engine can read/observe the same values.
@Observable
final class AppSettings {
    // Tracking
    var askIntervalMinutes: Int {
        didSet {
            d.set(askIntervalMinutes, forKey: Key.askInterval)
            onIntervalChanged?()
        }
    }
    /// Durations in totals and exports are rounded to this many minutes (0 == off). Stored
    /// start/end times are never changed, so rounding can be switched off losslessly.
    var roundToMinutes: Int {
        didSet {
            d.set(roundToMinutes, forKey: Key.roundTo)
            Entry.reportingStep = TimeInterval(roundToMinutes * 60)
        }
    }
    var workHoursOnly: Bool { didSet { d.set(workHoursOnly, forKey: Key.workHoursOnly) } }
    var workStartMinutes: Int { didSet { d.set(workStartMinutes, forKey: Key.workStart) } } // from midnight
    var workEndMinutes: Int { didSet { d.set(workEndMinutes, forKey: Key.workEnd) } }
    /// `Calendar` weekday numbers (1 = Sunday … 7 = Saturday).
    var workDays: Set<Int> { didSet { d.set(Array(workDays).sorted(), forKey: Key.workDays) } }
    var idleDetectionEnabled: Bool { didSet { d.set(idleDetectionEnabled, forKey: Key.idleEnabled) } }
    var idleThresholdMinutes: Int { didSet { d.set(idleThresholdMinutes, forKey: Key.idleThreshold) } }
    var checkInStyle: CheckInStyle { didSet { d.set(checkInStyle.rawValue, forKey: Key.checkInStyle) } }

    // Focus sessions (Pomodoro)
    var pomodoroFocusMinutes: Int { didSet { d.set(pomodoroFocusMinutes, forKey: Key.pomodoroFocus) } }
    var pomodoroShortBreakMinutes: Int { didSet { d.set(pomodoroShortBreakMinutes, forKey: Key.pomodoroShortBreak) } }
    var pomodoroLongBreakMinutes: Int { didSet { d.set(pomodoroLongBreakMinutes, forKey: Key.pomodoroLongBreak) } }
    /// A long break replaces the short one after this many focus sessions.
    var pomodoroLongBreakEvery: Int { didSet { d.set(pomodoroLongBreakEvery, forKey: Key.pomodoroLongBreakEvery) } }
    /// Suggest a break after this many minutes of continuous work (0 = off).
    var breakReminderMinutes: Int { didSet { d.set(breakReminderMinutes, forKey: Key.breakReminder) } }
    /// Chime when a focus session, a break or a work stretch ends.
    var playsSounds: Bool { didSet { d.set(playsSounds, forKey: Key.playsSounds) } }

    // Shortcuts (nil = none)
    var checkInHotkey: KeyCombo? {
        didSet {
            store(checkInHotkey, Key.checkInHotkey)
            onHotkeysChanged?()
        }
    }
    var pauseHotkey: KeyCombo? {
        didSet {
            store(pauseHotkey, Key.pauseHotkey)
            onHotkeysChanged?()
        }
    }

    // Appearance
    var appearance: AppearanceMode { didSet { d.set(appearance.rawValue, forKey: Key.appearance) } }
    var showDockIcon: Bool {
        didSet {
            d.set(showDockIcon, forKey: Key.showDockIcon)
            NSApp?.setActivationPolicy(showDockIcon ? .regular : .accessory)
            if !showDockIcon { DispatchQueue.main.async { NSApp?.activate() } } // keep the settings window in front
        }
    }
    var menuBarDisplay: MenuBarDisplay { didSet { d.set(menuBarDisplay.rawValue, forKey: Key.menuBarDisplay) } }

    static let intervalOptions = [5, 10, 15, 20, 30, 45, 60, 90]
    static let roundingOptions = [0, 1, 5, 6, 10, 15, 30]
    static let idleOptions = [3, 5, 10, 15, 30]
    static let focusOptions = [15, 20, 25, 30, 45, 50, 60, 90]
    static let shortBreakOptions = [3, 5, 10, 15]
    static let longBreakOptions = [10, 15, 20, 30]
    static let longBreakEveryOptions = [2, 3, 4, 5, 6]
    static let breakReminderOptions = [0, 45, 60, 75, 90, 120]

    @ObservationIgnored private let d: UserDefaults
    @ObservationIgnored var onHotkeysChanged: (() -> Void)?
    @ObservationIgnored var onIntervalChanged: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        d = defaults
        askIntervalMinutes = d.object(forKey: Key.askInterval) as? Int ?? 20
        roundToMinutes = d.object(forKey: Key.roundTo) as? Int ?? 0
        workHoursOnly = d.object(forKey: Key.workHoursOnly) as? Bool ?? true
        workStartMinutes = d.object(forKey: Key.workStart) as? Int ?? (9 * 60)
        workEndMinutes = d.object(forKey: Key.workEnd) as? Int ?? (18 * 60)
        workDays = Set(d.array(forKey: Key.workDays) as? [Int] ?? [2, 3, 4, 5, 6])
        idleDetectionEnabled = d.object(forKey: Key.idleEnabled) as? Bool ?? true
        idleThresholdMinutes = d.object(forKey: Key.idleThreshold) as? Int ?? 5
        checkInStyle = CheckInStyle(rawValue: d.string(forKey: Key.checkInStyle) ?? "") ?? .gentle
        pomodoroFocusMinutes = d.object(forKey: Key.pomodoroFocus) as? Int ?? 25
        pomodoroShortBreakMinutes = d.object(forKey: Key.pomodoroShortBreak) as? Int ?? 5
        pomodoroLongBreakMinutes = d.object(forKey: Key.pomodoroLongBreak) as? Int ?? 15
        pomodoroLongBreakEvery = d.object(forKey: Key.pomodoroLongBreakEvery) as? Int ?? 4
        breakReminderMinutes = d.object(forKey: Key.breakReminder) as? Int ?? 90
        playsSounds = d.object(forKey: Key.playsSounds) as? Bool ?? true
        checkInHotkey = Self.load(d, Key.checkInHotkey, default: .checkInDefault)
        pauseHotkey = Self.load(d, Key.pauseHotkey, default: .pauseDefault)
        appearance = AppearanceMode(rawValue: d.string(forKey: Key.appearance) ?? "") ?? .auto
        showDockIcon = d.object(forKey: Key.showDockIcon) as? Bool ?? true
        menuBarDisplay = MenuBarDisplay(rawValue: d.string(forKey: Key.menuBarDisplay) ?? "") ?? .timer
        Entry.reportingStep = TimeInterval(roundToMinutes * 60)
    }

    func isWorkTime(_ date: Date, calendar: Calendar = .current) -> Bool {
        guard workHoursOnly else { return true }
        let c = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        guard workDays.contains(c.weekday ?? 0) else { return false }
        let minutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return minutes >= workStartMinutes && minutes < workEndMinutes
    }

    // A stored `Data()` means "explicitly cleared", which differs from "never set".
    private func store(_ combo: KeyCombo?, _ key: String) {
        d.set(combo.flatMap { try? JSONEncoder().encode($0) } ?? Data(), forKey: key)
    }

    private static func load(_ d: UserDefaults, _ key: String, default value: KeyCombo) -> KeyCombo? {
        guard let data = d.data(forKey: key) else { return value }
        return try? JSONDecoder().decode(KeyCombo.self, from: data)
    }

    private enum Key {
        static let askInterval = "askIntervalMinutes"
        static let roundTo = "roundToMinutes"
        static let workHoursOnly = "workHoursOnly"
        static let workStart = "workStartMinutes"
        static let workEnd = "workEndMinutes"
        static let workDays = "workDays"
        static let idleEnabled = "idleDetectionEnabled"
        static let idleThreshold = "idleThresholdMinutes"
        static let checkInStyle = "checkInStyle"
        static let pomodoroFocus = "pomodoroFocusMinutes"
        static let pomodoroShortBreak = "pomodoroShortBreakMinutes"
        static let pomodoroLongBreak = "pomodoroLongBreakMinutes"
        static let pomodoroLongBreakEvery = "pomodoroLongBreakEvery"
        static let breakReminder = "breakReminderMinutes"
        static let playsSounds = "playsSounds"
        static let checkInHotkey = "checkInHotkey"
        static let pauseHotkey = "pauseHotkey"
        static let appearance = "appearance"
        static let showDockIcon = "showDockIcon"
        static let menuBarDisplay = "menuBarDisplay"
    }
}

extension Int {
    /// Interpret a minutes-from-midnight value as a `Date` today (for time pickers).
    var asTimeOfDayToday: Date {
        Calendar.current.date(bySettingHour: self / 60, minute: self % 60, second: 0, of: .now) ?? .now
    }
}
