import Foundation
import SwiftData
import Observation

/// The seam the handoff asks for: the UI talks to tracking only through this protocol,
/// so a networked store could replace `TrackingEngine` later without UI changes.
@MainActor
protocol TrackingStore: AnyObject {
    var runningEntry: Entry? { get }
    var isPaused: Bool { get }
    var now: Date { get }
    var currentActivity: Activity? { get }
    var lastActivityLabel: String? { get }
    var elapsed: TimeInterval { get }

    func checkInSave(text: String)
    func continuePrevious()
    func addManualEntry(text: String, duration: TimeInterval)
    func updateEntry(_ entry: Entry, text: String, start: Date, end: Date)
    func deleteEntry(_ entry: Entry)
    func togglePause()
    func stopTracking()
    func suggestions(matching prefix: String, limit: Int) -> [String]
    func projectColorHex(named name: String) -> String?
}

@Observable
@MainActor
final class TrackingEngine: TrackingStore {

    private(set) var runningEntry: Entry?
    private(set) var isPaused = false
    private(set) var now = Date.now
    private(set) var lastActivityLabel: String?
    /// While set (and in the future), the ask-timer and idle check-ins are suppressed.
    private(set) var snoozedUntil: Date?

    /// UI hooks (wired to the check-in panel by the app).
    @ObservationIgnored var onAskDue: (() -> Void)?
    @ObservationIgnored var onIdleReturn: ((TimeInterval) -> Void)?

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var tickTimer: Timer?
    @ObservationIgnored private var askTimer: Timer?
    @ObservationIgnored private var idleTimer: Timer?
    @ObservationIgnored private var idleFlagged = false
    @ObservationIgnored private var idleStart: Date?
    @ObservationIgnored private var pendingIdle: (interval: DateInterval, resumeLabel: String?)?

    var isSnoozed: Bool { (snoozedUntil ?? .distantPast) > .now }

    var currentActivity: Activity? { runningEntry?.activity }
    var elapsed: TimeInterval { runningEntry.map { now.timeIntervalSince($0.start) } ?? 0 }
    var isTracking: Bool { runningEntry != nil && !isPaused }

    init(context: ModelContext, settings: AppSettings) {
        self.context = context
        self.settings = settings
        resumeExistingRunningEntry()
        startTick()
        scheduleAskTimer()
        startIdleMonitor()
    }

    // MARK: - Public operations

    func checkInSave(text: String) {
        let stamp = Date.now
        let activity = resolveActivity(from: text)
        if let current = currentActivity, let activity,
           current.persistentModelID == activity.persistentModelID {
            continuePrevious()
            return
        }
        closeRunningEntry(at: stamp)
        if let activity { openRunningEntry(for: activity, at: stamp) }
        isPaused = false
        save()
        startTick()
    }

    func continuePrevious() {
        if isPaused { resume(); return }
        if runningEntry == nil {
            if let label = lastActivityLabel, let activity = resolveActivity(from: label) {
                openRunningEntry(for: activity)
                isPaused = false
                startTick()
            }
        }
        save()
    }

    func addManualEntry(text: String, duration: TimeInterval) {
        guard let activity = resolveActivity(from: text), duration > 0 else { return }
        let end = Date.now
        context.insert(Entry(start: end.addingTimeInterval(-duration), end: end, activity: activity))
        save()
    }

    /// Edit a completed block: reassign its activity/group and adjust its interval.
    func updateEntry(_ entry: Entry, text: String, start: Date, end: Date) {
        if let activity = resolveActivity(from: text) { entry.activity = activity }
        entry.start = start
        entry.end = max(start, end)
        save()
    }

    func deleteEntry(_ entry: Entry) {
        if entry.persistentModelID == runningEntry?.persistentModelID {
            runningEntry = nil
            tickTimer?.invalidate()
            tickTimer = nil
        }
        context.delete(entry)
        save()
    }

    // MARK: - Project management

    func renameProject(_ project: Project, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        project.name = trimmed
        if runningEntry?.activity?.project?.persistentModelID == project.persistentModelID {
            lastActivityLabel = runningEntry?.activity?.label
        }
        save()
    }

    func setProjectColor(_ project: Project, hex: String) {
        project.colorHex = hex
        save()
    }

    func setProjectArchived(_ project: Project, _ archived: Bool) {
        project.isArchived = archived
        save()
    }

    func deleteProject(_ project: Project) {
        if runningEntry?.activity?.project?.persistentModelID == project.persistentModelID {
            runningEntry = nil
            isPaused = false
            tickTimer?.invalidate()
            tickTimer = nil
            lastActivityLabel = nil
        }
        context.delete(project) // cascades to activities + entries
        save()
    }

    func togglePause() { isPaused ? resume() : pause() }

    func stopTracking() {
        closeRunningEntry(at: .now)
        isPaused = false
        save()
    }

    /// Restart the ask countdown from now (call when the interval setting changes).
    func rescheduleAskTimer() { scheduleAskTimer() }

    // MARK: - Suggestions / lookups

    func suggestions(matching prefix: String, limit: Int = 6) -> [String] {
        let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        let labels = activities.map(\.label)
        let query = prefix.trimmingCharacters(in: .whitespaces)
        let matches = query.isEmpty ? labels : labels.filter { $0.localizedCaseInsensitiveContains(query) }
        var seen = Set<String>()
        var result: [String] = []
        for label in matches where !seen.contains(label) {
            seen.insert(label)
            result.append(label)
        }
        return Array(result.prefix(limit))
    }

    func projectColorHex(named name: String) -> String? {
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        return projects.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }?.colorHex
    }

    // MARK: - Running-entry lifecycle

    private func pause() {
        closeRunningEntry(at: .now)
        isPaused = true
        save()
    }

    private func resume() {
        guard isPaused else { return }
        isPaused = false
        if let label = lastActivityLabel, let activity = resolveActivity(from: label) {
            openRunningEntry(for: activity)
            startTick()
        }
        save()
    }

    private func openRunningEntry(for activity: Activity, at date: Date = .now) {
        let entry = Entry(start: date, end: nil, activity: activity)
        context.insert(entry)
        runningEntry = entry
        lastActivityLabel = activity.label
        now = .now
    }

    private func closeRunningEntry(at date: Date) {
        guard let entry = runningEntry else { return }
        entry.end = roundedEnd(start: entry.start, end: date)
        lastActivityLabel = entry.activity?.label
        runningEntry = nil
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func resumeExistingRunningEntry() {
        let descriptor = FetchDescriptor<Entry>(
            predicate: #Predicate { $0.end == nil },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        if let running = try? context.fetch(descriptor).first {
            runningEntry = running
            lastActivityLabel = running.activity?.label
        } else {
            // Remember the most recent completed activity so Continue/Resume have a target.
            let recent = FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.start, order: .reverse)])
            lastActivityLabel = (try? context.fetch(recent))?.first?.activity?.label
        }
    }

    // MARK: - Duration rounding

    private func roundedEnd(start: Date, end: Date) -> Date {
        let n = settings.roundToMinutes
        guard n > 0 else { return end }
        let step = TimeInterval(n * 60)
        let rounded = (end.timeIntervalSince(start) / step).rounded() * step
        return rounded > 0 ? start.addingTimeInterval(rounded) : end
    }

    // MARK: - Resolution (find-or-create project/activity)

    private func resolveActivity(from text: String) -> Activity? {
        let (projectName, activityName) = Self.parse(text)
        let project = findOrCreateProject(named: projectName)
        return findOrCreateActivity(named: activityName, in: project)
    }

    static func parse(_ text: String) -> (project: String, activity: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let colon = trimmed.firstIndex(of: ":") {
            let p = trimmed[..<colon].trimmingCharacters(in: .whitespaces)
            let a = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            return (p.isEmpty ? "General" : p, a.isEmpty ? "Untitled" : a)
        }
        return ("General", trimmed.isEmpty ? "Untitled" : trimmed)
    }

    private func findOrCreateProject(named name: String) -> Project {
        let all = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        if let existing = all.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let project = Project(name: name, colorHex: Theme.palette[all.count % Theme.palette.count], order: all.count)
        context.insert(project)
        return project
    }

    private func findOrCreateActivity(named name: String, in project: Project) -> Activity {
        if let existing = project.activities.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }
        let activity = Activity(name: name, project: project)
        context.insert(activity)
        project.activities.append(activity)
        return activity
    }

    // MARK: - Timers

    private func startTick() {
        tickTimer?.invalidate()
        guard runningEntry != nil, !isPaused else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.now = .now }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func scheduleAskTimer() {
        askTimer?.invalidate()
        let interval = TimeInterval(max(1, settings.askIntervalMinutes) * 60)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.fireAskIfAllowed()
                self?.scheduleAskTimer() // reschedule with the latest interval
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        askTimer = timer
    }

    private func fireAskIfAllowed() {
        guard !isPaused else { return }
        if let until = snoozedUntil {
            if Date.now < until { return }
            snoozedUntil = nil // expired
        }
        if settings.workHoursOnly && !isWithinWorkHours(.now) { return }
        if settings.pauseInDoNotDisturb && Self.isDoNotDisturbActive() { return }
        onAskDue?()
    }

    // MARK: - Snooze ("Stop asking for X")

    func snooze(for seconds: TimeInterval) { snoozedUntil = Date.now.addingTimeInterval(seconds) }

    func snoozeUntilEndOfDay() {
        snoozedUntil = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: .now)
            ?? Date.now.addingTimeInterval(8 * 3600)
    }

    func resumeAsking() { snoozedUntil = nil }

    // MARK: - Idle detection

    private func startIdleMonitor() {
        idleTimer?.invalidate()
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.checkIdle() }
        }
        RunLoop.main.add(timer, forMode: .common)
        idleTimer = timer
    }

    private func checkIdle() {
        guard settings.idleDetectionEnabled, !isPaused, !isSnoozed else {
            idleFlagged = false
            return
        }
        let idle = IdleMonitor.idleSeconds()
        let threshold = TimeInterval(max(1, settings.idleThresholdMinutes) * 60)
        if idle >= threshold {
            if !idleFlagged, runningEntry != nil {
                idleFlagged = true
                idleStart = Date.now.addingTimeInterval(-idle)
            }
        } else if idleFlagged {
            idleFlagged = false
            handleIdleReturn()
        }
    }

    private func handleIdleReturn() {
        guard let start = idleStart, let entry = runningEntry else { idleStart = nil; return }
        idleStart = nil
        let awayStart = max(entry.start, start)
        let resumeLabel = entry.activity?.label ?? lastActivityLabel

        // Carve the away period out of the running entry.
        if awayStart.timeIntervalSince(entry.start) < 60 {
            context.delete(entry) // the whole (tiny) block was idle
        } else {
            entry.end = awayStart
        }
        lastActivityLabel = resumeLabel
        runningEntry = nil
        tickTimer?.invalidate()
        tickTimer = nil
        save()

        pendingIdle = (DateInterval(start: awayStart, end: .now), resumeLabel)
        onIdleReturn?(awayStart.distance(to: .now))
    }

    /// Log the away period as `text`, then resume the previous task from now.
    func logIdle(text: String) {
        if let pending = pendingIdle, let activity = resolveActivity(from: text) {
            context.insert(Entry(start: pending.interval.start, end: pending.interval.end, activity: activity))
        }
        finishIdle()
    }

    /// Drop the away period (leave it untracked), then resume the previous task from now.
    func discardIdle() { finishIdle() }

    private func finishIdle() {
        let label = pendingIdle?.resumeLabel
        pendingIdle = nil
        if let label, let activity = resolveActivity(from: label) {
            openRunningEntry(for: activity)
            isPaused = false
            startTick()
        }
        save()
    }

    private func isWithinWorkHours(_ date: Date) -> Bool {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let minutes = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return minutes >= settings.workStartMinutes && minutes <= settings.workEndMinutes
    }

    /// No public API exists for Focus / Do Not Disturb state; v1 stubs this to `false`.
    static func isDoNotDisturbActive() -> Bool { false }

    private func save() { try? context.save() }
}
