import SwiftUI

/// Main window (2a): NavigationSplitView with the vibrancy sidebar and the selected detail.
struct MainWindow: View {
    @Environment(TrackingEngine.self) private var engine
    @Environment(UICoordinator.self) private var ui
    @Environment(\.openWindow) private var openWindow
    @State private var selection: SidebarItem = .today
    @State private var selectedDate: Date = .now
    @State private var selectedWeek: Date = .now
    @State private var showingAdd = false

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 214, max: 260)
        } detail: {
            detail
                .navigationTitle(navTitle)
                .navigationSubtitle(navSubtitle)
                .toolbar { toolbar }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showingAdd) { AddEntryView() }
        .onChange(of: ui.addEntryTick) { showingAdd = true }
        .onAppear { ui.openMainWindow = { openWindow(id: "main") } }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .today:
            DayView(date: selectedDate)
        case .week:
            WeekView(weekDate: selectedWeek)
        case .statistics:
            StatisticsView()
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if selection == .today || selection == .week {
            ToolbarItemGroup(placement: .navigation) {
                Button { shift(-1) } label: { Image(systemName: "chevron.backward") }
                    .help(selection == .week ? "Previous week" : "Previous day")
                Button(jumpLabel) { resetPeriod() }
                    .disabled(isCurrentPeriod)
                Button { shift(1) } label: { Image(systemName: "chevron.forward") }
                    .help(selection == .week ? "Next week" : "Next day")
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            TrackingPill()
            Button { showingAdd = true } label: { Image(systemName: "plus") }
                .help("Add entry manually")
        }
    }

    private var jumpLabel: String { selection == .week ? "This Week" : "Today" }

    // MARK: Titles

    private var navTitle: String {
        switch selection {
        case .today: Format.dayTitle(selectedDate, now: engine.now)
        case .week: Format.weekTitle(selectedWeek, now: engine.now)
        case .statistics: "Statistics"
        }
    }

    private var navSubtitle: String {
        switch selection {
        case .today: Format.longDate(selectedDate)
        case .week: Format.weekSubtitle(selectedWeek)
        case .statistics: ""
        }
    }

    // MARK: Navigation

    private func shift(_ direction: Int) {
        let cal = Calendar.current
        switch selection {
        case .today:
            selectedDate = cal.date(byAdding: .day, value: direction, to: selectedDate) ?? selectedDate
        case .week:
            selectedWeek = cal.date(byAdding: .weekOfYear, value: direction, to: selectedWeek) ?? selectedWeek
        case .statistics:
            break
        }
    }

    private func resetPeriod() {
        switch selection {
        case .today: selectedDate = .now
        case .week: selectedWeek = .now
        case .statistics: break
        }
    }

    private var isCurrentPeriod: Bool {
        let cal = Calendar.current
        switch selection {
        case .today: return cal.isDateInToday(selectedDate)
        case .week: return cal.dateInterval(of: .weekOfYear, for: .now)?.contains(selectedWeek) ?? false
        case .statistics: return true
        }
    }
}
