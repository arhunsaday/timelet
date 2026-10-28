import AppKit
import Foundation
import SwiftData
import Observation

/// The seam between UI and storage: views talk to tracking only through this protocol,
/// so a networked store could replace `TrackingEngine` later without UI changes.
@MainActor
protocol TrackingStore: AnyObject {
    var runningEntry: Entry? { get }
    var isPaused: Bool { get }
    var now: Date { get }
    var currentActivity: Activity? { get }
    var lastActivityLabel: String? { get }
    var elapsed: TimeInterval { get }

    func track(_ text: String, note: String?)
    func continuePrevious()
    func addEntry(text: String, start: Date, end: Date, note: String?)
    func updateEntry(_ entry: Entry, text: String, start: Date, end: Date, note: String?)
    func deleteEntry(_ entry: Entry)
    func togglePause()
    func stopTracking()
    func suggestions(matching query: String, limit: Int) -> [TaskSuggestion]
    func projectColorHex(named name: String) -> String?
}

@Observable
@MainActor
final class TrackingEngine: TrackingStore {

    private(set) var runningEntry: Entry?
    private(set) var isPaused = false
    private(set) var now: Date
    private(set) var lastActivityLabel: String?
    /// While set (and in the future), scheduled check-ins are suppressed.
    private(set) var snoozedUntil: Date?
    /// When the next scheduled check-in is due. Moves forward on every check-in.
    private(set) var nextAskAt: Date?
    /// An away period (idle, sleep, lock, app closed) waiting for the user to log or discard it.
    private(set) var pendingAway: DateInterval?

    /// UI hooks (wired to the check-in panel by the app).
    @ObservationIgnored var onAskDue: (() -> Void)?
    @ObservationIgnored var onAwayReturn: ((TimeInterval) -> Void)?
    /// Injectable for tests.
    @ObservationIgnored var idleSeconds: () -> TimeInterval = IdleMonitor.idleSeconds

    @ObservationIgnored let context: ModelContext
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var ticker: Timer?
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var awayStart: Date?
    /// The task that was running when the pending away period began.
    private(set) var pendingResumeLabel: String?
    @ObservationIgnored private var lastHeartbeat: Date = .distantPast
    @ObservationIgnored private var lastSlowTick: Date = .distantPast

    /// Gaps longer than this (or crossing midnight) end the task instead of offering to resume it.
    static let longAway: TimeInterval = 4 * 3600
    static let heartbeatKey = "lastHeartbeat"

    var isSnoozed: Bool { (snoozedUntil ?? .distantPast) > now }
    var currentActivity: Activity? { runningEntry?.activity }
    var elapsed: TimeInterval { runningEntry.map { max(0, now.timeIntervalSince($0.start)) } ?? 0 }
    var isTracking: Bool { runningEntry != nil && !isPaused }

    init(context: ModelContext, settings: AppSettings, clock: @escaping () -> Date = { .now },
         defaults: UserDefaults = .standard, startTimers: Bool = true) {
        self.context = context
        self.settings = settings
        self.clock = clock
        self.defaults = defaults
        self.now = clock()
        recoverOnLaunch()
        markCheckedIn()
        if startTimers {
            startTicker()
            observeSystem()
        }
    }

    // MARK: - Tracking

    /// Starts `text` (`Project:Activity`, optionally "20m ago" / "since 14:30"), ending whatever
    /// was running at that moment. The same task just keeps running (and takes the note).
    func track(_ text: String, note: String? = nil) {
        let t = clock()
        now = t
        let parsed = EntryParser.checkIn(text, now: t)
        let activity = findOrCreateActivity(named: parsed.activity, in: findOrCreateProject(named: parsed.project))
        let note = Self.cleaned(note)
        markCheckedIn()
        isPaused = false

        if let running = runningEntry, running.activity?.persistentModelID == activity.persistentModelID {
            if let note { running.note = note }
            save()
            return
        }

        var start = min(parsed.start ?? t, t)
        if let running = runningEntry {
            if start <= running.start.addingTimeInterval(30) {
                context.delete(running) // the backdated task replaces the one that barely started
            } else {
                running.end = start
            }
            runningEntry = nil
        }
        // Never overlap a completed block.
        if let floor = latestCompletedEnd(before: t), start < floor { start = floor }
        open(activity, at: start, note: note)
        save()
    }

    /// Keeps the current task, resumes after a pause, or restarts the last task.
    func continuePrevious() {
        markCheckedIn()
        if isPaused { resume(); return }
        if runningEntry == nil, let label = lastActivityLabel {
            track(label)
            return
        }
        save()
    }

    /// Starts an earlier entry's task again, now.
    func resume(_ entry: Entry) {
        guard let label = entry.activity?.label else { return }
        track(label)
    }

    func togglePause() { isPaused ? resume() : pause() }

    func pause() {
        guard runningEntry != nil else { return }
        close(at: clock())
        isPaused = true
        save()
    }

    func resume() {
        isPaused = false
        markCheckedIn()
        if let label = lastActivityLabel { track(label) } else { save() }
    }

    func stopTracking() {
        close(at: clock())
        isPaused = false
        markCheckedIn()
        save()
    }

    /// Stops and stays quiet until the next working day.
    func doneForToday() {
        stopTracking()
        snoozedUntil = nextWorkStart(after: clock())
    }

    // MARK: - Entries

    func addEntry(text: String, start: Date, end: Date, note: String?) {
        guard end > start else { return }
        let (p, a) = EntryParser.splitLabel(text)
        let activity = findOrCreateActivity(named: a, in: findOrCreateProject(named: p))
        context.insert(Entry(start: start, end: end, activity: activity, note: Self.cleaned(note)))
        save()
    }

    /// Edit a block: reassign its activity/group, adjust its interval, and set its note.
    func updateEntry(_ entry: Entry, text: String, start: Date, end: Date, note: String?) {
        let (p, a) = EntryParser.splitLabel(text)
        entry.activity = findOrCreateActivity(named: a, in: findOrCreateProject(named: p))
        entry.start = start
        if entry.end != nil { entry.end = max(start, end) }
        entry.note = Self.cleaned(note)
        if entry.persistentModelID == runningEntry?.persistentModelID { lastActivityLabel = entry.activity?.label }
        save()
    }

    func deleteEntry(_ entry: Entry) {
        if entry.persistentModelID == runningEntry?.persistentModelID { runningEntry = nil }
        if let end = entry.end, let label = entry.activity?.label {
            recentlyDeleted = DeletedEntry(label: label, start: entry.start, end: end, note: entry.note)
        }
        context.delete(entry)
        save()
    }

    /// The last deleted block, kept briefly so the UI can offer Undo.
    struct DeletedEntry: Equatable {
        let label: String
        let start: Date
        let end: Date
        let note: String?
    }

    private(set) var recentlyDeleted: DeletedEntry?

    func undoDelete() {
        guard let d = recentlyDeleted else { return }
        recentlyDeleted = nil
        addEntry(text: d.label, start: d.start, end: d.end, note: d.note)
    }

    func forgetDeleted() { recentlyDeleted = nil }

    // MARK: - Projects

    func renameProject(_ project: Project, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        project.name = trimmed
        if let label = runningEntry?.activity?.label,
           runningEntry?.activity?.project?.persistentModelID == project.persistentModelID {
            lastActivityLabel = label
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
        }
        if let label = lastActivityLabel,
           EntryParser.splitLabel(label).project.caseInsensitiveCompare(project.name) == .orderedSame {
            lastActivityLabel = nil
        }
        context.delete(project) // cascades to activities + entries
        save()
    }

    // MARK: - Check-in schedule

    /// The user just answered (or the panel was dismissed): next ask is one interval away.
    func markCheckedIn() {
        nextAskAt = clock().addingTimeInterval(TimeInterval(max(1, settings.askIntervalMinutes) * 60))
    }

    /// Call when the interval setting changes.
    func rescheduleAskTimer() { markCheckedIn() }

    func snooze(for seconds: TimeInterval) { snoozedUntil = clock().addingTimeInterval(seconds) }

    func snoozeUntilEndOfDay() {
        snoozedUntil = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: clock())
    }

    func resumeAsking() {
        snoozedUntil = nil
        markCheckedIn()
    }

    /// Whether a scheduled check-in would show right now.
    var canAsk: Bool {
        !isPaused && !isSnoozed && pendingAway == nil && settings.isWorkTime(now)
    }

    // MARK: - Away periods (idle, sleep, lock, quit)

    /// Logs the away period as `text`, then resumes the task that was running before.
    func logAway(as text: String, note: String?) {
        if let away = pendingAway {
            addEntry(text: text, start: away.start, end: away.end, note: note)
        }
        finishAway(resume: true)
    }

    /// Leaves the away period untracked. `resume` restarts the previous task from now.
    func finishAway(resume: Bool) {
        let label = pendingResumeLabel
        pendingAway = nil
        pendingResumeLabel = nil
        if resume, let label { track(label) } else { markCheckedIn(); save() }
    }

    func checkIdle() {
        let t = clock()
        guard settings.idleDetectionEnabled, runningEntry != nil, !isPaused, pendingAway == nil else {
            awayStart = nil
            return
        }
        let idle = idleSeconds()
        if idle >= TimeInterval(settings.idleThresholdMinutes * 60) {
            if awayStart == nil { awayStart = t.addingTimeInterval(-idle) }
        } else if let start = awayStart {
            awayStart = nil
            returnFromAway(since: start, at: t)
        }
    }

    /// The machine went to sleep, the screen locked, or the display slept.
    func noteAway() {
        guard settings.idleDetectionEnabled, runningEntry != nil, awayStart == nil else { return }
        awayStart = clock()
    }

    /// Woke up / unlocked: the gap is handled like idle time if it was long enough.
    func noteBack() {
        guard let start = awayStart else { return }
        let t = clock()
        guard t.timeIntervalSince(start) >= TimeInterval(settings.idleThresholdMinutes * 60) else { return }
        awayStart = nil
        returnFromAway(since: start, at: t)
    }

    private func returnFromAway(since start: Date, at t: Date) {
        guard let entry = runningEntry else { return }
        let from = max(entry.start, start)
        let away = t.timeIntervalSince(from)
        guard away >= 60 else { return }
        let label = entry.activity?.label ?? lastActivityLabel

        // Carve the away period out of the running block.
        if from.timeIntervalSince(entry.start) < 60 { context.delete(entry) } else { entry.end = from }
        runningEntry = nil
        lastActivityLabel = label
        now = t
        save()

        if away >= Self.longAway || !Calendar.current.isDate(from, inSameDayAs: t) {
            // Overnight / long break: stay stopped; the next check-in asks fresh.
            nextAskAt = t
        } else if isSnoozed {
            if let label { track(label) }
        } else {
            pendingAway = DateInterval(start: from, end: t)
            pendingResumeLabel = label
            onAwayReturn?(away)
        }
    }

    /// Shows the "welcome back" prompt for an away period found at launch.
    func presentPendingAwayIfNeeded() {
        guard let away = pendingAway else { return }
        onAwayReturn?(away.duration)
    }

    // MARK: - Lookups

    /// Every non-archived task, with how recently and how often it was used.
    func allSuggestions() -> [TaskSuggestion] {
        let activities = (try? context.fetch(FetchDescriptor<Activity>())) ?? []
        var byLabel: [String: TaskSuggestion] = [:]
        for a in activities {
            guard let project = a.project, !project.isArchived else { continue }
            let last = a.entries.map(\.start).max() ?? project.createdAt
            let s = TaskSuggestion(project: project.name, activity: a.name, colorHex: project.colorHex,
                                   lastUsed: last, uses: a.entries.count)
            if let existing = byLabel[s.label], existing.lastUsed > s.lastUsed { continue }
            byLabel[s.label] = s
        }
        return Array(byLabel.values)
    }

    func suggestions(matching query: String, limit: Int = 6) -> [TaskSuggestion] {
        Array(Ranking.rank(allSuggestions(), query: query).prefix(limit))
    }

    func projectColorHex(named name: String) -> String? {
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        return projects.first { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }?.colorHex
    }

    /// Tracked time on `day`, including the running block.
    func total(on day: Date) -> TimeInterval {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? start
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.start >= start && $0.start < end })
        return ((try? context.fetch(descriptor)) ?? [])
            .filter { !($0.activity?.project?.isArchived ?? false) }
            .reduce(0) { $0 + $1.duration(asOf: now) }
    }

    /// The end of the latest completed block that ends at or before `date`.
    func latestCompletedEnd(before date: Date) -> Date? {
        var descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.end != nil },
                                                sortBy: [SortDescriptor(\.start, order: .reverse)])
        descriptor.fetchLimit = 20
        return ((try? context.fetch(descriptor)) ?? []).compactMap(\.end).filter { $0 <= date }.max()
    }

    func entries(in interval: DateInterval) -> [Entry] {
        let s = interval.start, e = interval.end
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.start >= s && $0.start < e },
                                                sortBy: [SortDescriptor(\.start)])
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Ticking

    private func startTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    func tick() {
        let t = clock()
        // Refresh every second while a timer is visible, else once a minute.
        if isTracking || !Calendar.current.isDate(now, equalTo: t, toGranularity: .minute) { now = t }
        if t.timeIntervalSince(lastHeartbeat) >= 30 { writeHeartbeat(t) }
        guard t.timeIntervalSince(lastSlowTick) >= 5 else { return }
        lastSlowTick = t
        checkIdle()
        checkAsk(at: t)
    }

    func checkAsk(at t: Date) {
        guard let next = nextAskAt, t >= next else { return }
        if canAsk {
            nextAskAt = t.addingTimeInterval(TimeInterval(max(1, settings.askIntervalMinutes) * 60))
            onAskDue?()
        } else {
            nextAskAt = t.addingTimeInterval(60)
        }
    }

    func writeHeartbeat(_ t: Date? = nil) {
        let t = t ?? clock()
        lastHeartbeat = t
        defaults.set(t, forKey: Self.heartbeatKey)
    }

    private func observeSystem() {
        let ws = NSWorkspace.shared.notificationCenter
        let dist = DistributedNotificationCenter.default()
        let awayNames: [(NotificationCenter, Notification.Name)] = [
            (ws, NSWorkspace.willSleepNotification), (ws, NSWorkspace.screensDidSleepNotification),
            (dist, Notification.Name("com.apple.screenIsLocked")),
        ]
        let backNames: [(NotificationCenter, Notification.Name)] = [
            (ws, NSWorkspace.screensDidWakeNotification), (dist, Notification.Name("com.apple.screenIsUnlocked")),
        ]
        for (center, name) in awayNames {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.noteAway()
                    self?.writeHeartbeat()
                }
            }
            observers.append((center, token))
        }
        for (center, name) in backNames {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.noteBack() }
            }
            observers.append((center, token))
        }
    }

    // MARK: - Private

    private func open(_ activity: Activity, at date: Date, note: String? = nil) {
        let entry = Entry(start: date, end: nil, activity: activity, note: note)
        context.insert(entry)
        runningEntry = entry
        lastActivityLabel = activity.label
        isPaused = false
    }

    private func close(at date: Date) {
        guard let entry = runningEntry else { return }
        if date.timeIntervalSince(entry.start) < 1 {
            context.delete(entry) // nothing to keep
        } else {
            entry.end = date
        }
        lastActivityLabel = entry.activity?.label ?? lastActivityLabel
        runningEntry = nil
        now = date
    }

    private func recoverOnLaunch() {
        let t = clock()
        let descriptor = FetchDescriptor<Entry>(predicate: #Predicate { $0.end == nil },
                                                sortBy: [SortDescriptor(\.start, order: .reverse)])
        let running = (try? context.fetch(descriptor)) ?? []
        // More than one open block can only come from a crash; close the older ones.
        for (older, newer) in zip(running.dropFirst(), running) { older.end = max(older.start, newer.start) }

        if let entry = running.first {
            lastActivityLabel = entry.activity?.label
            let beat = defaults.object(forKey: Self.heartbeatKey) as? Date ?? entry.start
            if t.timeIntervalSince(beat) > 180 {
                // The app was not running (quit, crash, reboot): end the block when we last saw it.
                let end = max(entry.start, beat)
                if end.timeIntervalSince(entry.start) < 60 { context.delete(entry) } else { entry.end = end }
                let away = t.timeIntervalSince(end)
                if away < Self.longAway, Calendar.current.isDate(end, inSameDayAs: t), settings.isWorkTime(t) {
                    pendingAway = DateInterval(start: end, end: t)
                    pendingResumeLabel = lastActivityLabel
                }
            } else {
                runningEntry = entry
            }
        } else {
            var recent = FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.start, order: .reverse)])
            recent.fetchLimit = 1
            lastActivityLabel = (try? context.fetch(recent))?.first?.activity?.label
        }
        save()
    }

    private func nextWorkStart(after date: Date) -> Date {
        let cal = Calendar.current
        for offset in 1...8 {
            guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: date)) else { continue }
            if !settings.workHoursOnly || settings.workDays.contains(cal.component(.weekday, from: day)) {
                return cal.date(byAdding: .minute, value: settings.workStartMinutes, to: day) ?? day
            }
        }
        return cal.date(byAdding: .day, value: 1, to: date) ?? date
    }

    private func findOrCreateProject(named name: String) -> Project {
        let all = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        if let existing = all.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            if existing.isArchived { existing.isArchived = false } // using it again brings it back
            return existing
        }
        let used = Set(all.map(\.colorHex))
        let color = Theme.palette.first { !used.contains($0) } ?? Theme.palette[all.count % Theme.palette.count]
        let project = Project(name: name, colorHex: color, order: (all.map(\.order).max() ?? -1) + 1)
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

    static func cleaned(_ note: String?) -> String? {
        guard let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty else { return nil }
        return note
    }

    private func save() { try? context.save() }
}
