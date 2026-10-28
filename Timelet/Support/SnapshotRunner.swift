import SwiftUI
import SwiftData
import AppKit

/// Dev-only visual verification: when launched with `TIMELET_SNAPSHOT=1`, the app renders
/// each screen to a PNG (via `ImageRenderer`, which needs no Screen Recording permission),
/// then quits. Content that lives inside a `ScrollView`/`TabView`/`List` is rendered via its
/// extracted, pure sub-view so `ImageRenderer` can lay it out.
enum SnapshotRunner {
    private static var didRun = false

    @MainActor
    static func runIfNeeded(app: AppModel) {
        // Dev: drive the real UI with key events posted to Timelet's own windows, logging the
        // engine after each step. `TIMELET_SCRIPT="show:checkin;type:elec;key:return;log"`.
        if !didRun, let script = ProcessInfo.processInfo.environment["TIMELET_SCRIPT"] {
            didRun = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                for step in script.split(separator: ";").map(String.init) {
                    let parts = step.split(separator: ":", maxSplits: 1).map(String.init)
                    let arg = parts.count > 1 ? parts[1] : ""
                    switch parts[0] {
                    case "show":
                        switch arg {
                        case "checkin": app.checkIn.present()
                        case "nudge": app.checkIn.ask()
                        case "away": app.checkIn.presentAway(seconds: 27 * 60)
                        case "settings": NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        case "week": app.ui.show(.week)
                        case "stats": app.ui.show(.statistics)
                        case "today": app.ui.show(.today)
                        default: break
                        }
                    case "size":
                        let wh = arg.split(separator: "x").compactMap { Double($0) }
                        let main = NSApp.windows.filter { $0.isVisible && !($0 is NSPanel) }.max { $0.frame.width < $1.frame.width }
                        if wh.count == 2, let w = main {
                            w.setFrame(NSRect(x: 200, y: 200, width: wh[0], height: wh[1]), display: true, animate: false)
                        }
                    case "type": for ch in arg { postKey(characters: String(ch), keyCode: 0) }
                    case "key": postNamedKey(arg)
                    case "wait": try? await Task.sleep(for: .seconds(Double(arg) ?? 1))
                    case "track": app.engine.track(arg)
                    case "log": logState(app, arg)
                    case "quit": NSApp.terminate(nil)
                    default: break
                    }
                    try? await Task.sleep(for: .milliseconds(350))
                }
            }
            return
        }
        // Dev: open one piece of UI at launch to check it on screen
        // (`TIMELET_SHOW=checkin|nudge|away|add`).
        if !didRun, let show = ProcessInfo.processInfo.environment["TIMELET_SHOW"] {
            didRun = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                switch show {
                case "checkin": app.checkIn.present()
                case "nudge": app.checkIn.ask()
                case "away": app.checkIn.presentAway(seconds: 27 * 60)
                case "add": app.ui.requestAddEntry()
                default: break
                }
            }
            return
        }
        guard !didRun,
              ProcessInfo.processInfo.environment["TIMELET_SNAPSHOT"] == "1" else { return }
        didRun = true

        let dir = URL(fileURLWithPath:
            ProcessInfo.processInfo.environment["TIMELET_SNAPSHOT_DIR"] ?? NSTemporaryDirectory())

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            // 2a — Today content (headline + cards), built from the real store.
            let entries = (try? app.container.mainContext.fetch(FetchDescriptor<Entry>())) ?? []
            let summary = DaySummary.build(entries: entries, day: app.engine.now, now: app.engine.now)
            renderApp(
                DayContent(summary: summary, date: app.engine.now)
                    .padding(.horizontal, 20).padding(.vertical, 18)
                    .frame(width: 672, alignment: .top)
                    .background(Theme.contentBackground),
                app: app, to: dir.appendingPathComponent("2a_today.png"))

            // 2a — sidebar (List can't be rendered; a faithful static stand-in).
            let projects = ((try? app.container.mainContext.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.order)]))) ?? [])
            let totals = DaySummary.projectTotals(entries: entries, day: app.engine.now, now: app.engine.now)
            renderApp(
                SidebarSnapshot(projects: projects.map {
                    ($0.name, $0.colorHex, totals[$0.persistentModelID] ?? 0)
                }),
                app: app, to: dir.appendingPathComponent("2a_sidebar.png"))

            // 2b — check-in panel.
            renderApp(
                CheckInPanel(engine: app.engine, mode: .regular, onDone: {}),
                app: app, to: dir.appendingPathComponent("2b_checkin.png"))

            // 2c — menu-bar popover.
            renderApp(
                MenuBarPanel().frame(width: 264).background(Color(hex: "F6F6F8")),
                app: app, to: dir.appendingPathComponent("2c_menubar.png"))

            // 2d — settings General tab content.
            renderApp(
                GeneralSettingsContent()
                    .frame(width: 500, alignment: .top)
                    .background(Theme.contentBackground),
                app: app, to: dir.appendingPathComponent("2d_settings.png"))

            // 2e — empty state.
            renderApp(
                EmptyStateView().frame(width: 440, height: 340),
                app: app, to: dir.appendingPathComponent("2e_empty.png"))

            // New screens.
            if let entry = (try? app.container.mainContext.fetch(
                FetchDescriptor<Entry>(predicate: #Predicate { $0.end != nil })))?.first {
                renderApp(EntryEditorView(entry: entry), app: app,
                          to: dir.appendingPathComponent("3a_entry_editor.png"))
            }
            if let project = (try? app.container.mainContext.fetch(FetchDescriptor<Project>()))?.first {
                renderApp(ProjectEditorView(project: project), app: app,
                          to: dir.appendingPathComponent("3b_project_editor.png"))
            }
            let weekModel = WeekModel.build(entries: entries, weekDate: app.engine.now, now: app.engine.now)
            renderApp(WeekContent(model: weekModel, now: app.engine.now)
                        .padding(20).frame(width: 700, alignment: .top).background(Theme.contentBackground),
                      app: app, to: dir.appendingPathComponent("3c_week.png"))
            renderApp(StatisticsContent()
                        .frame(width: 700, alignment: .top).background(Theme.contentBackground),
                      app: app, to: dir.appendingPathComponent("3d_stats.png"))
            renderApp(CheckInPanel(engine: app.engine, mode: .away(seconds: 12 * 60), onDone: {}),
                      app: app, to: dir.appendingPathComponent("3e_idle.png"))

            renderApp(AddEntryView(request: AddEntryRequest(day: app.engine.now)), app: app, to: dir.appendingPathComponent("3g_add.png"))

            // Note display demo (an expanded row) — the live store may have no notes yet.
            renderApp(
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("13:30 – 15:40").font(.system(size: 13)).foregroundStyle(Theme.textTertiary)
                            .monospacedDigit().frame(width: 118, alignment: .leading)
                        Text("Electron refactor").font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("2h 10m").font(.system(size: 13, weight: .medium)).monospacedDigit()
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Theme.textQuaternary).frame(width: 20, height: 20)
                    }
                    .padding(.leading, 34).padding(.trailing, 8).padding(.vertical, 10)
                    EntryNoteView(note: "Finished the IPC bridge. Tomorrow's daily: wire up error handling + add tests.",
                                  leadingInset: 34)
                }
                .groupedCard()
                .frame(width: 620)
                .padding(30).background(Theme.contentBackground),
                app: app, to: dir.appendingPathComponent("3f_note.png"))

            try? await Task.sleep(nanoseconds: 200_000_000)
            NSApp.terminate(nil)
        }
    }

    @MainActor
    private static func postKey(characters: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags = []) {
        guard let window = NSApp.keyWindow else { print("SCRIPT: no key window"); return }
        for type in [NSEvent.EventType.keyDown, .keyUp] {
            if let e = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: modifiers, timestamp: ProcessInfo.processInfo.systemUptime,
                                        windowNumber: window.windowNumber, context: nil, characters: characters,
                                        charactersIgnoringModifiers: characters, isARepeat: false, keyCode: keyCode) {
                NSApp.postEvent(e, atStart: false)
            }
        }
    }

    @MainActor
    private static func postNamedKey(_ name: String) {
        let cmd = name.hasPrefix("cmd")
        let key = cmd ? String(name.dropFirst(3)) : name
        let map: [String: (String, UInt16)] = [
            "return": ("\r", 36), "tab": ("\t", 48), "esc": ("\u{1b}", 53),
            "down": (String(UnicodeScalar(NSDownArrowFunctionKey)!), 125), "up": (String(UnicodeScalar(NSUpArrowFunctionKey)!), 126),
            "1": ("1", 18), "2": ("2", 19), "3": ("3", 20), "n": ("n", 45), "k": ("k", 40),
        ]
        guard let (chars, code) = map[key] else { return }
        var flags: NSEvent.ModifierFlags = cmd ? [.command] : []
        if key == "down" || key == "up" { flags.insert([.numericPad, .function]) }
        postKey(characters: chars, keyCode: code, modifiers: flags)
    }

    @MainActor
    private static func logState(_ app: AppModel, _ tag: String) {
        let e = app.engine
        let entries = (try? app.container.mainContext.fetch(FetchDescriptor<Entry>(sortBy: [SortDescriptor(\.start)]))) ?? []
        let today = entries.filter { Calendar.current.isDateInToday($0.start) }
        let blocks = today.suffix(4).map { "\($0.activity?.label ?? "?") \(Format.clock($0.start))-\($0.end.map(Format.clock) ?? "…")\($0.note.map { " [\($0)]" } ?? "")" }
        print("STATE[\(tag)] running=\(e.currentActivity?.label ?? "-") paused=\(e.isPaused) panel=\(app.checkIn.isPresented) nudge=\(app.checkIn.isNudging) away=\(e.pendingAway != nil) last4=\(blocks)")
        fflush(stdout)
    }

    @MainActor
    private static func renderApp(_ view: some View, app: AppModel, to url: URL) {
        let wrapped = view
            .environment(app)
            .environment(app.engine)
            .environment(app.settings)
            .environment(app.checkIn)
            .environment(app.ui)
            .modelContainer(app.container)
        let renderer = ImageRenderer(content: wrapped)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else {
            NSLog("SNAPSHOT: render failed for \(url.lastPathComponent)")
            return
        }
        try? data.write(to: url)
        NSLog("SNAPSHOT: wrote \(url.lastPathComponent)")
    }
}

/// A static stand-in for the sidebar (the real one is a `List`, which `ImageRenderer` can't lay out).
private struct SidebarSnapshot: View {
    let projects: [(name: String, colorHex: String, total: TimeInterval)]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            navRow("Today", "smallcircle.circle", selected: true)
            navRow("This Week", "calendar", selected: false)
            navRow("Statistics", "chart.bar", selected: false)

            Text("Projects")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 9).padding(.top, 16).padding(.bottom, 5)

            ForEach(projects, id: \.name) { project in
                HStack(spacing: 9) {
                    ColorSwatch(hex: project.colorHex, size: 10)
                    Text(project.name).font(.system(size: 13)).foregroundStyle(Theme.textSecondary)
                    Spacer(minLength: 4)
                    Text(Format.durationCompact(project.total))
                        .font(.system(size: 11)).foregroundStyle(Theme.textQuaternary).monospacedDigit()
                }
                .padding(.horizontal, 9).padding(.vertical, 6)
            }
            Spacer()
        }
        .padding(.horizontal, 12).padding(.top, 12)
        .frame(width: 214, height: 600, alignment: .top)
        .background(Color(hex: "F0F0F2"))
    }

    private func navRow(_ title: String, _ symbol: String, selected: Bool) -> some View {
        HStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(selected ? .white : Theme.textTertiary)
                .frame(width: 16)
            Text(title)
                .font(.system(size: 13, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? .white : Theme.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 9).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: Radius.navRow, style: .continuous)
                .fill(selected ? Theme.accent : .clear)
        )
    }
}
