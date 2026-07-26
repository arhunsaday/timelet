import SwiftUI
import SwiftData
import Carbon.HIToolbox

/// Routes menu-command actions that need to reach a specific window/sheet.
@MainActor
@Observable
final class UICoordinator {
    var addEntryTick = 0
    @ObservationIgnored var openMainWindow: (() -> Void)?

    func requestAddEntry() { addEntryTick += 1 }
    func openDashboard() {
        openMainWindow?()
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// Owns the app-wide singletons: the SwiftData container, settings, tracking engine,
/// and check-in controller. Also performs first-run seeding and registers the global hotkey.
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
        let container: ModelContainer
        do {
            let schema = Schema([Project.self, Activity.self, Entry.self])
            container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)]
            )
        } catch {
            fatalError("Timelet: failed to create ModelContainer: \(error)")
        }

        // Seed the handoff's sample data on first launch (so the app matches screen 2a).
        if !settings.hasSeeded {
            let isEmpty = ((try? container.mainContext.fetch(FetchDescriptor<Project>()))?.isEmpty) ?? true
            if isEmpty { SampleData.seed(into: container.mainContext) }
            settings.hasSeeded = true
        }

        let engine = TrackingEngine(context: container.mainContext, settings: settings)
        let checkIn = CheckInController()
        checkIn.configure(engine: engine, settings: settings)
        engine.onAskDue = { [weak checkIn] in checkIn?.present() }
        engine.onIdleReturn = { [weak checkIn] away in checkIn?.presentIdle(awaySeconds: away) }

        self.settings = settings
        self.container = container
        self.engine = engine
        self.checkIn = checkIn
        self.ui = UICoordinator()

        // Global ⌘⇧T → check-in, from anywhere.
        GlobalHotkeyManager.shared.register(
            keyCode: UInt32(kVK_ANSI_T),
            modifiers: UInt32(cmdKey | shiftKey)
        ) { [weak checkIn] in
            checkIn?.present()
        }
    }
}

@main
struct TimeletApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup(id: "main") {
            Root(app: app) {
                MainWindow()
                    .frame(minWidth: 720, minHeight: 480)
                    .task { SnapshotRunner.runIfNeeded(app: app) }
            }
        }
        .defaultSize(width: 880, height: 620)
        .commands { commands }

        MenuBarExtra {
            Root(app: app) { MenuBarPanel() }
        } label: {
            MenuBarLabel().environment(app.engine)
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
        }
        CommandGroup(after: .sidebar) {
            Button("Open Dashboard") { app.ui.openDashboard() }
                .keyboardShortcut("0", modifiers: .command)
        }
        CommandMenu("Tracking") {
            Button("Show Check-in") { app.checkIn.present() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Divider()
            Button("Pause / Resume Tracking") { app.engine.togglePause() }
                .keyboardShortcut("t", modifiers: .command)
            Button("Continue Previous") { app.engine.continuePrevious() }
                .keyboardShortcut("t", modifiers: [.command, .option])
        }
    }
}

/// Injects the shared environment objects + container and applies the appearance preference.
private struct Root<Content: View>: View {
    let app: AppModel
    @ViewBuilder var content: Content

    var body: some View {
        content
            .environment(app.engine)
            .environment(app.settings)
            .environment(app.checkIn)
            .environment(app.ui)
            .modelContainer(app.container)
            .preferredColorScheme(app.settings.appearance.colorScheme)
    }
}
