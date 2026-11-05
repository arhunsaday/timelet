import SwiftUI
import AppKit

/// Owns the check-in panel (2b), the gentle reminder card, and their presentation lifecycle.
/// The schedule calls `ask()`; the global shortcut calls `toggle()`; menus and buttons call `present()`.
@MainActor
@Observable
final class CheckInController {
    @ObservationIgnored private var panel: FloatingPanel?
    @ObservationIgnored private var nudgePanel: FloatingPanel?
    @ObservationIgnored private var resignObserver: NSObjectProtocol?
    @ObservationIgnored private var previousApp: NSRunningApplication?
    @ObservationIgnored private var nudgeTimeout: Task<Void, Never>?
    @ObservationIgnored private weak var engine: TrackingEngine?
    @ObservationIgnored private var settings: AppSettings?
    @ObservationIgnored weak var pomodoro: Pomodoro?

    private(set) var isPresented = false
    private(set) var isNudging = false

    /// How long the reminder card stays before it quietly counts as "keep going".
    static let nudgeLifetime: TimeInterval = 90

    func configure(engine: TrackingEngine, settings: AppSettings) {
        self.engine = engine
        self.settings = settings
    }

    /// Scheduled check-in: a gentle card or the full panel, per Settings.
    func ask() {
        guard !isPresented, !isNudging else { return }
        if settings?.checkInStyle == .focused { present() } else { showNudge() }
    }

    /// The global shortcut: open the check-in, or close it if it is already open.
    func toggle() {
        if isPresented {
            engine?.markCheckedIn()
            dismiss()
        } else {
            present()
        }
    }

    func present() {
        guard let engine else { return }
        hideNudge()
        show(CheckInPanel(
            engine: engine,
            pomodoro: pomodoro,
            mode: .regular,
            onDone: { [weak self] in self?.dismiss() }
        ))
    }

    /// The "Welcome back" prompt for an away period (idle, sleep, lock, app closed).
    func presentAway(seconds: TimeInterval) {
        guard let engine else { return }
        hideNudge()
        show(CheckInPanel(
            engine: engine,
            pomodoro: nil,
            mode: .away(seconds: seconds),
            onDone: { [weak self] in self?.dismiss() }
        ))
    }

    func dismiss(restoreFocus: Bool = true) {
        guard isPresented else { return }
        isPresented = false
        removeResignObserver()
        panel?.orderOut(nil)
        if restoreFocus, let app = previousApp, app != NSRunningApplication.current {
            app.activate()
        }
        previousApp = nil
    }

    // MARK: - Reminder card

    private func showNudge() {
        guard let engine else { return }
        showCard(NudgeView(
            engine: engine,
            lifetime: Self.nudgeLifetime,
            onKeepGoing: { [weak self] in
                self?.engine?.continuePrevious()
                self?.hideNudge()
            },
            onChange: { [weak self] in self?.present() },
            onSnooze: { [weak self] seconds in
                self?.engine?.snooze(for: seconds)
                self?.hideNudge()
            }
        ), lifetime: Self.nudgeLifetime) { [weak self] in
            // Ignored: the current task simply keeps running.
            self?.engine?.markCheckedIn()
        }
    }

    /// Announces the end of a focus session or a break in the corner card slot.
    func announce(_ event: Pomodoro.Event, pomodoro: Pomodoro) {
        guard let engine, !isPresented else { return }
        if settings?.playsSounds ?? true { NSSound(named: event == .breakEnded ? "Hero" : "Glass")?.play() }
        showCard(PomodoroCard(
            event: event, pomodoro: pomodoro, engine: engine,
            onSwitch: { [weak self] in self?.present() },
            onClose: { [weak self] in self?.hideNudge() }
        ), lifetime: 30) {}
    }

    /// Suggests a break, or says the break is over.
    func announce(_ event: BreakReminder.Event, reminder: BreakReminder) {
        guard let engine, let settings, !isPresented else { return }
        if settings.playsSounds { NSSound(named: event == .breakOver ? "Hero" : "Purr")?.play() }
        showCard(BreakCard(event: event, reminder: reminder, engine: engine,
                           breakMinutes: settings.pomodoroShortBreakMinutes,
                           onClose: { [weak self] in self?.hideNudge() }),
                 lifetime: event == .breakOver ? 10 * 60 : 60) {}
    }

    /// Shows `view` as the corner card; after `lifetime` it hides and `onTimeout` runs.
    private func showCard(_ view: some View, lifetime: TimeInterval, onTimeout: @escaping () -> Void) {
        let panel = nudgePanel ?? FloatingPanel(acceptsKey: false)
        nudgePanel = panel
        let hosting = NSHostingView(rootView: view)
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        if let screen = NSScreen.main {
            let v = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: v.maxX - panel.frame.width - 14, y: v.maxY - panel.frame.height - 10))
        }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            panel.animator().alphaValue = 1
        }
        isNudging = true
        nudgeTimeout?.cancel()
        nudgeTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(lifetime))
            guard !Task.isCancelled else { return }
            onTimeout()
            self?.hideNudge()
        }
    }

    private func hideNudge() {
        nudgeTimeout?.cancel()
        nudgeTimeout = nil
        guard isNudging, let panel = nudgePanel else { return }
        isNudging = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated { if !self.isNudging { panel.orderOut(nil) } }
        })
    }

    // MARK: - Helpers

    /// Rebuild content each presentation so the field, selection and caret start fresh.
    private func show<Content: View>(_ root: Content) {
        if !isPresented {
            let front = NSWorkspace.shared.frontmostApplication
            previousApp = front == NSRunningApplication.current ? nil : front
        }
        let panel = panel ?? FloatingPanel()
        self.panel = panel
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = [.preferredContentSize]
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        center(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()
        isPresented = true
        installResignObserver(for: panel)
    }

    private func center(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameTopLeftPoint(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY + size.height / 2 + visible.height * 0.1 // sit above center, like Spotlight
        ))
    }

    /// Clicking away keeps the current task running, like pressing Escape.
    private func installResignObserver(for panel: FloatingPanel) {
        removeResignObserver()
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.isPresented else { return }
                // Like Escape: keep the task; an unanswered away period is left untracked.
                if self.engine?.pendingAway != nil {
                    self.engine?.finishAway(resume: true)
                } else {
                    self.engine?.markCheckedIn()
                }
                self.dismiss(restoreFocus: false)
            }
        }
    }

    private func removeResignObserver() {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }
}
