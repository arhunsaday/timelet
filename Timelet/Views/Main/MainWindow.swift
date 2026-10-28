import SwiftUI

/// Main window (2a): NavigationSplitView with the vibrancy sidebar and the selected detail.
struct MainWindow: View {
    @Environment(TrackingEngine.self) private var engine
    @Environment(UICoordinator.self) private var ui
    @Environment(CheckInController.self) private var checkIn
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var ui = ui
        NavigationSplitView {
            Sidebar(selection: $ui.selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
        } detail: {
            detail
                .navigationTitle(navTitle)
                .navigationSubtitle(navSubtitle)
                .toolbar { toolbar }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $ui.addEntry) { AddEntryView(request: $0) }
        .onAppear { ui.openMainWindow = { openWindow(id: "main") } }
    }

    @ViewBuilder
    private var detail: some View {
        switch ui.selection {
        case .today: DayView(date: ui.selectedDate)
        case .week: WeekView(weekDate: ui.selectedDate)
        case .statistics: StatisticsView()
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if ui.selection != .statistics {
            ToolbarItemGroup(placement: .navigation) {
                Button { ui.shiftDay(-1) } label: { Image(systemName: "chevron.backward") }
                    .help(ui.selection == .week ? "Previous week (⌘[)" : "Previous day (⌘[)")
                Button { ui.shiftDay(1) } label: { Image(systemName: "chevron.forward") }
                    .help(ui.selection == .week ? "Next week (⌘])" : "Next day (⌘])")
                    .disabled(isCurrentPeriod)
                if !isCurrentPeriod {
                    Button(ui.selection == .week ? "This Week" : "Today") { ui.selectedDate = .now }
                        .help("⌘T")
                }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            TrackingPill()
            Button { checkIn.present() } label: { Label("Check in", systemImage: "text.cursor") }
                .help("Check in — switch or start a task (⌘K)")
            Button { ui.requestAddEntry() } label: { Label("Add time", systemImage: "plus") }
                .help("Add time manually (⌘N)")
        }
    }

    // MARK: Titles

    private var navTitle: String {
        switch ui.selection {
        case .today: Format.dayTitle(ui.selectedDate, now: engine.now)
        case .week: Format.weekTitle(ui.selectedDate, now: engine.now)
        case .statistics: "Statistics"
        }
    }

    private var navSubtitle: String {
        switch ui.selection {
        case .today: Format.longDate(ui.selectedDate)
        case .week: Format.weekSubtitle(ui.selectedDate)
        case .statistics: ""
        }
    }

    private var isCurrentPeriod: Bool {
        let cal = Calendar.current
        switch ui.selection {
        case .today: return cal.isDate(ui.selectedDate, inSameDayAs: engine.now)
        case .week: return cal.dateInterval(of: .weekOfYear, for: engine.now)?.contains(ui.selectedDate) ?? false
        case .statistics: return true
        }
    }
}
