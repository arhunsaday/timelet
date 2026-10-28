import SwiftUI
import SwiftData
import SQLite3

/// Asks for "add an entry" (optionally prefilled, e.g. from a gap in the day timeline).
struct AddEntryRequest: Identifiable, Equatable {
    let id = UUID()
    var day: Date
    var start: Date?
    var end: Date?
    var text: String = ""
}

/// Routes menu-command actions that need to reach a specific window/sheet.
@MainActor
@Observable
final class UICoordinator {
    var selection: SidebarItem = .today
    var selectedDate: Date = .now
    var addEntry: AddEntryRequest?
    @ObservationIgnored var openMainWindow: (() -> Void)?

    func requestAddEntry(start: Date? = nil, end: Date? = nil, text: String = "") {
        openDashboard()
        addEntry = AddEntryRequest(day: start ?? selectedDate, start: start, end: end, text: text)
    }

    func openDashboard() {
        openMainWindow?()
        NSApp.activate()
    }

    func show(_ item: SidebarItem) {
        selection = item
        openDashboard()
    }

    func shiftDay(_ days: Int) {
        selectedDate = Calendar.current.date(byAdding: selection == .week ? .weekOfYear : .day, value: days, to: selectedDate) ?? selectedDate
    }
}

/// Owns the app-wide singletons: the SwiftData container, settings, tracking engine,
/// check-in controller, and global shortcuts.
@MainActor
@Observable
final class AppModel {
    let container: ModelContainer
    let settings: AppSettings
    let engine: TrackingEngine
    let checkIn: CheckInController
    let ui: UICoordinator

    init() {
        let settings = AppSettings()
        let env = ProcessInfo.processInfo.environment
        let container: ModelContainer
        do {
            let schema = Schema([Project.self, Activity.self, Entry.self])
            let config = env["TIMELET_IN_MEMORY"] == "1"
                ? ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                : ModelConfiguration(schema: schema, url: Self.storeURL())
            container = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Timelet: failed to create ModelContainer: \(error)")
        }

        // Demo data only on request (screenshots, trying the app) — never mixed into real use.
        if env["TIMELET_SAMPLE"] == "1",
           ((try? container.mainContext.fetch(FetchDescriptor<Project>()))?.isEmpty) ?? true {
            SampleData.seed(into: container.mainContext)
        }

        let engine = TrackingEngine(context: container.mainContext, settings: settings)
        let checkIn = CheckInController()
        checkIn.configure(engine: engine, settings: settings)
        engine.onAskDue = { [weak checkIn] in checkIn?.ask() }
        engine.onAwayReturn = { [weak checkIn] away in checkIn?.presentAway(seconds: away) }

        self.settings = settings
        self.container = container
        self.engine = engine
        self.checkIn = checkIn
        self.ui = UICoordinator()

        registerHotkeys()
        settings.onHotkeysChanged = { [weak self] in self?.registerHotkeys() }
        settings.onIntervalChanged = { [weak engine] in engine?.rescheduleAskTimer() }

        // Away period found at launch (app was quit or crashed mid-task).
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak engine] in engine?.presentPendingAwayIfNeeded() }
    }

    /// Re-registers the global shortcuts from Settings. Returns the names macOS refused.
    @discardableResult
    func registerHotkeys() -> [String] {
        var failed: [String] = []
        let hk = GlobalHotkeyManager.shared
        if !hk.register("checkIn", combo: settings.checkInHotkey, action: { [weak checkIn] in checkIn?.toggle() }) {
            failed.append("check-in")
        }
        if !hk.register("pause", combo: settings.pauseHotkey, action: { [weak engine] in engine?.togglePause() }) {
            failed.append("pause")
        }
        return failed
    }

    /// `~/Library/Application Support/Timelet/Timelet.store` (or `$TIMELET_DATA_DIR`).
    /// Early builds used SwiftData's shared `default.store`, which other apps also use; it is
    /// adopted only if it really holds Timelet's tables.
    static func storeURL() -> URL {
        let fm = FileManager.default
        let dir: URL
        if let custom = ProcessInfo.processInfo.environment["TIMELET_DATA_DIR"] {
            dir = URL(fileURLWithPath: custom, isDirectory: true)
        } else {
            dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Timelet", isDirectory: true)
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("Timelet.store")

        let legacy = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("default.store")
        if !fm.fileExists(atPath: url.path), fm.fileExists(atPath: legacy.path), isTimeletStore(legacy) {
            for suffix in ["", "-shm", "-wal"] {
                try? fm.copyItem(atPath: legacy.path + suffix, toPath: url.path + suffix)
            }
        }
        return url
    }

    private static func isTimeletStore(_ url: URL) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return false }
        defer { sqlite3_close(db) }
        var stmt: OpaquePointer?
        let sql = "SELECT count(*) FROM sqlite_master WHERE type='table' AND name IN ('ZENTRY','ZACTIVITY','ZPROJECT')"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
        defer { sqlite3_finalize(stmt) }
        return sqlite3_step(stmt) == SQLITE_ROW && sqlite3_column_int(stmt, 0) == 3
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor static var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            if let settings = Self.model?.settings { NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory) }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MainActor.assumeIsolated { Self.model?.engine.writeHeartbeat() }
    }

    /// Timelet lives in the menu bar too; closing the window must not quit it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct TimeletApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var app: AppModel

    init() {
        let model = AppModel()
        _app = State(initialValue: model)
        AppDelegate.model = model
    }

    var body: some Scene {
        Window("Timelet", id: "main") {
            Root(app: app) {
                MainWindow()
                    .frame(minWidth: 760, minHeight: 500)
                    .task { SnapshotRunner.runIfNeeded(app: app) }
            }
        }
        .defaultSize(width: 940, height: 660)
        .commands { commands }

        MenuBarExtra {
            Root(app: app) { MenuBarPanel() }
        } label: {
            MenuBarLabel().environment(app.engine).environment(app.settings)
        }
        .menuBarExtraStyle(.window)

        Settings {
            Root(app: app) { SettingsView() }
        }
    }

    @CommandsBuilder
    private var commands: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Entry…") { app.ui.requestAddEntry() }
                .keyboardShortcut("n", modifiers: .command)
            Divider()
            Button("Export CSV…") { Exporter.exportInteractively(engine: app.engine) }
                .keyboardShortcut("e", modifiers: [.command, .shift])
        }
        CommandGroup(after: .sidebar) {
            Button("Today") { app.ui.show(.today) }.keyboardShortcut("1", modifiers: .command)
            Button("Week") { app.ui.show(.week) }.keyboardShortcut("2", modifiers: .command)
            Button("Statistics") { app.ui.show(.statistics) }.keyboardShortcut("3", modifiers: .command)
            Divider()
            Button("Previous Day") { app.ui.shiftDay(-1) }.keyboardShortcut("[", modifiers: .command)
            Button("Next Day") { app.ui.shiftDay(1) }.keyboardShortcut("]", modifiers: .command)
            Button("Go to Today") { app.ui.selectedDate = .now }.keyboardShortcut("t", modifiers: .command)
            Divider()
        }
        CommandMenu("Tracking") {
            Button("Check In…") { app.checkIn.present() }
                .keyboardShortcut("k", modifiers: .command)
            Button(app.engine.isPaused ? "Resume" : "Pause") { app.engine.togglePause() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(app.engine.runningEntry == nil && !app.engine.isPaused)
            Button("Stop Tracking") { app.engine.stopTracking() }
                .keyboardShortcut(".", modifiers: .command)
                .disabled(app.engine.runningEntry == nil)
            Button("Done for Today") { app.engine.doneForToday() }
            Divider()
            Menu("Stop Asking") {
                Button("For 30 Minutes") { app.engine.snooze(for: 30 * 60) }
                Button("For 1 Hour") { app.engine.snooze(for: 3600) }
                Button("For 2 Hours") { app.engine.snooze(for: 2 * 3600) }
                Button("Until Tomorrow") { app.engine.snoozeUntilEndOfDay() }
            }
            if app.engine.isSnoozed {
                Button("Resume Asking") { app.engine.resumeAsking() }
            }
        }
    }
}

/// Injects the shared environment objects + container and applies the appearance preference.
private struct Root<Content: View>: View {
    let app: AppModel
    @ViewBuilder var content: Content

    var body: some View {
        content
            .environment(app)
            .environment(app.engine)
            .environment(app.settings)
            .environment(app.checkIn)
            .environment(app.ui)
            .modelContainer(app.container)
            .preferredColorScheme(app.settings.appearance.colorScheme)
    }
}
