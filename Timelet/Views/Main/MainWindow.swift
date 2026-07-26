import SwiftUI

/// Main window (2a): NavigationSplitView with the vibrancy sidebar and the Today detail.
struct MainWindow: View {
    @Environment(TrackingEngine.self) private var engine
    @Environment(UICoordinator.self) private var ui
    @Environment(\.openWindow) private var openWindow
    @State private var selection: SidebarItem = .today
    @State private var showingAdd = false

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 214, max: 260)
        } detail: {
            detail
                .toolbar { toolbar }
                .navigationTitle("")
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
            TodayView()
        case .week:
            ComingSoonView(
                title: "This Week",
                systemImage: "calendar.badge.clock",
                message: "Weekly calendar, list, and timesheet views are coming in a later version."
            )
        case .statistics:
            ComingSoonView(
                title: "Statistics",
                systemImage: "chart.bar.fill",
                message: "Charts and time breakdowns are coming in a later version."
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            TrackingPill()
            Button { showingAdd = true } label: {
                Image(systemName: "plus")
            }
            .help("Add entry manually")
        }
    }

    private var title: String {
        switch selection {
        case .today: "Today"
        case .week: "This Week"
        case .statistics: "Statistics"
        }
    }

    private var subtitle: String {
        selection == .today ? Format.longDate(engine.now) : ""
    }
}
