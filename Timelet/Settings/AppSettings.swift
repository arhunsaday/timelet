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

enum AppLanguage: String, CaseIterable, Identifiable {
    case english, french, pirate
    var id: String { rawValue }
    var label: String {
        switch self {
        case .english: "English"
        case .french: "Français"
        case .pirate: "Pirate"
        }
    }
}

/// User preferences, persisted to `UserDefaults` (the storage the handoff calls out as
/// `@AppStorage`). Exposed as an `@Observable` object so both SwiftUI views and the
/// non-view tracking engine can read/observe the same values.
@Observable
final class AppSettings {
    // Tracking
    var askIntervalMinutes: Int { didSet { d.set(askIntervalMinutes, forKey: Key.askInterval) } }
    var roundToMinutes: Int { didSet { d.set(roundToMinutes, forKey: Key.roundTo) } } // 0 == off
    var workHoursOnly: Bool { didSet { d.set(workHoursOnly, forKey: Key.workHoursOnly) } }
    var workStartMinutes: Int { didSet { d.set(workStartMinutes, forKey: Key.workStart) } } // from midnight
    var workEndMinutes: Int { didSet { d.set(workEndMinutes, forKey: Key.workEnd) } }
    var pauseInDoNotDisturb: Bool { didSet { d.set(pauseInDoNotDisturb, forKey: Key.pauseInDND) } }
    var idleDetectionEnabled: Bool { didSet { d.set(idleDetectionEnabled, forKey: Key.idleEnabled) } }
    var idleThresholdMinutes: Int { didSet { d.set(idleThresholdMinutes, forKey: Key.idleThreshold) } }

    // Appearance
    var appearance: AppearanceMode { didSet { d.set(appearance.rawValue, forKey: Key.appearance) } }
    var language: AppLanguage { didSet { d.set(language.rawValue, forKey: Key.language) } }

    // First-run marker for sample-data seeding.
    var hasSeeded: Bool { didSet { d.set(hasSeeded, forKey: Key.hasSeeded) } }

    static let intervalOptions = [5, 10, 15, 20, 30, 60]
    static let roundingOptions = [0, 1, 5, 10, 15]
    static let idleOptions = [5, 10, 15, 30]

    @ObservationIgnored private let d = UserDefaults.standard

    init() {
        askIntervalMinutes = d.object(forKey: Key.askInterval) as? Int ?? 15
        roundToMinutes = d.object(forKey: Key.roundTo) as? Int ?? 5
        workHoursOnly = d.object(forKey: Key.workHoursOnly) as? Bool ?? true
        workStartMinutes = d.object(forKey: Key.workStart) as? Int ?? (9 * 60)
        workEndMinutes = d.object(forKey: Key.workEnd) as? Int ?? (18 * 60)
        pauseInDoNotDisturb = d.object(forKey: Key.pauseInDND) as? Bool ?? false
        idleDetectionEnabled = d.object(forKey: Key.idleEnabled) as? Bool ?? true
        idleThresholdMinutes = d.object(forKey: Key.idleThreshold) as? Int ?? 10
        appearance = AppearanceMode(rawValue: d.string(forKey: Key.appearance) ?? "") ?? .light
        language = AppLanguage(rawValue: d.string(forKey: Key.language) ?? "") ?? .english
        hasSeeded = d.bool(forKey: Key.hasSeeded)
    }

    private enum Key {
        static let askInterval = "askIntervalMinutes"
        static let roundTo = "roundToMinutes"
        static let workHoursOnly = "workHoursOnly"
        static let workStart = "workStartMinutes"
        static let workEnd = "workEndMinutes"
        static let pauseInDND = "pauseInDoNotDisturb"
        static let idleEnabled = "idleDetectionEnabled"
        static let idleThreshold = "idleThresholdMinutes"
        static let appearance = "appearance"
        static let language = "language"
        static let hasSeeded = "hasSeeded"
    }
}

extension Int {
    /// Interpret a minutes-from-midnight value as a `Date` today (for time pickers).
    var asTimeOfDayToday: Date {
        Calendar.current.date(
            bySettingHour: self / 60, minute: self % 60, second: 0, of: .now
        ) ?? .now
    }
}
