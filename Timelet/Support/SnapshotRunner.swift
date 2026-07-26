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
        guard !didRun,
              ProcessInfo.processInfo.environment["TIMELET_SNAPSHOT"] == "1" else { return }
        didRun = true

        let dir = URL(fileURLWithPath:
            ProcessInfo.processInfo.environment["TIMELET_SNAPSHOT_DIR"] ?? NSTemporaryDirectory())

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)

            // 2a — Today content (headline + cards), built from the real store.
            let entries = (try? app.container.mainContext.fetch(FetchDescriptor<Entry>())) ?? []
            let runningElapsed: TimeInterval = {
                if let r = app.engine.runningEntry,
                   Calendar.current.isDate(r.start, inSameDayAs: app.engine.now) { return app.engine.elapsed }
                return 0
            }()
            let summary = TodaySummary.build(entries: entries, runningElapsedToday: runningElapsed, now: app.engine.now)
            renderApp(
                TodayContent(summary: summary)
                    .padding(.horizontal, 20).padding(.vertical, 18)
                    .frame(width: 672, alignment: .top)
                    .background(Theme.contentBackground),
                app: app, to: dir.appendingPathComponent("2a_today.png"))

            // 2a — sidebar (List can't be rendered; a faithful static stand-in).
            let projects = ((try? app.container.mainContext.fetch(FetchDescriptor<Project>(sortBy: [SortDescriptor(\.order)]))) ?? [])
            let totals = TodaySummary.projectTotals(entries: entries, now: app.engine.now)
            renderApp(
                SidebarSnapshot(projects: projects.map {
                    ($0.name, $0.colorHex, totals[$0.persistentModelID] ?? 0)
                }),
                app: app, to: dir.appendingPathComponent("2a_sidebar.png"))

            // 2b — check-in panel.
            renderApp(
                CheckInPanel(engine: app.engine, intervalMinutes: app.settings.askIntervalMinutes,
                             onSave: { _ in }, onContinue: {}),
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

            try? await Task.sleep(nanoseconds: 200_000_000)
            NSApp.terminate(nil)
        }
    }

    @MainActor
    private static func renderApp(_ view: some View, app: AppModel, to url: URL) {
        let wrapped = view
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
            navRow("Today", "calendar", selected: true)
            navRow("This Week", "calendar.badge.clock", selected: false)
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
