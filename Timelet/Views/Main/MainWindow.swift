import SwiftUI

/// Main window (2a): NavigationSplitView with the vibrancy sidebar and the selected detail.
struct MainWindow: View {
    @Environment(TrackingEngine.self) private var engine
    @Environment(UICoordinator.self) private var ui
    @Environment(CheckInController.self) private var checkIn
    @Environment(\.openWindow) private var openWindow
    @State private var pickingDate = false

    var body: some View {
        @Bindable var ui = ui
        NavigationSplitView {
            Sidebar(selection: $ui.selection, today: engine.now)
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
        .onChange(of: ui.pickDateRequest) { pickingDate = true }
    }

    @ViewBuilder
    private var detail: some View {
        switch ui.selection {
        case .today: DayView(date: ui.selectedDate)
        case .week: WeekView(weekDate: ui.selectedDate)
        case .statistics: StatisticsView(period: ui.statsPeriod, date: ui.selectedDate)
        }
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        @Bindable var ui = ui
        ToolbarItemGroup(placement: .navigation) {
            Button { ui.shiftDay(-1) } label: { Image(systemName: "chevron.backward") }
                .help("Previous \(ui.pagingName.lowercased()) (⌘[)")
            Button { ui.shiftDay(1) } label: { Image(systemName: "chevron.forward") }
                .help("Next \(ui.pagingName.lowercased()) (⌘])")
                .disabled(isCurrentPeriod)
            Button { pickingDate.toggle() } label: { Image(systemName: "calendar") }
                .help("Go to date… (⇧⌘T)")
                .popover(isPresented: $pickingDate, arrowEdge: .bottom) { datePicker }
            if !isCurrentPeriod {
                Button(currentPeriodTitle) { ui.selectedDate = .now }
                    .help("⌘T")
            }
        }
        if ui.selection == .statistics {
            ToolbarItem(placement: .navigation) {
                Picker("Period", selection: $ui.statsPeriod) {
                    ForEach(StatsPeriod.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            TrackingPill()
            Button { checkIn.present() } label: { Label("Check in", systemImage: "timer") }
                .help("Check in — switch or start a task (⌘K)")
            Button { ui.requestAddEntry() } label: { Label("Add time", systemImage: "plus") }
                .help("Add time manually (⌘N)")
        }
    }

    private var datePicker: some View {
        DatePicker("Go to date", selection: Binding(
            get: { ui.selectedDate },
            set: { ui.selectedDate = $0; pickingDate = false }
        ), in: ...engine.now, displayedComponents: .date)
        .datePickerStyle(.graphical)
        .labelsHidden()
        .padding(12)
    }

    private var currentPeriodTitle: String {
        switch ui.pagingUnit {
        case .weekOfYear: "This Week"
        case .month: "This Month"
        default: "Today"
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
        case .statistics: ui.statsPeriod.title(ui.selectedDate, now: engine.now)
        }
    }

    private var isCurrentPeriod: Bool {
        Calendar.current.isDate(ui.selectedDate, equalTo: engine.now, toGranularity: ui.pagingUnit)
    }
}
