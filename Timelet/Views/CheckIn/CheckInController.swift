import SwiftUI
import AppKit

/// Owns the check-in floating panel (2b) and its presentation lifecycle.
/// The ask-timer, global shortcut, menu-bar "Change task…", and empty-state button all
/// route through `present()`.
@MainActor
@Observable
final class CheckInController {
    @ObservationIgnored private var panel: FloatingPanel?
    @ObservationIgnored private var resignObserver: NSObjectProtocol?
    @ObservationIgnored private weak var engine: TrackingEngine?
    @ObservationIgnored private var settings: AppSettings?

    private(set) var isPresented = false

    func configure(engine: TrackingEngine, settings: AppSettings) {
        self.engine = engine
        self.settings = settings
    }

    func present() {
        guard let engine, let settings else { return }
        let panel = panel ?? FloatingPanel()
        self.panel = panel

        // Rebuild content each time so the prefill / caret reset to the latest activity.
        let root = CheckInPanel(
            engine: engine,
            intervalMinutes: settings.askIntervalMinutes,
            onSave: { [weak self] text in
                engine.checkInSave(text: text)
                self?.dismiss()
            },
            onContinue: { [weak self] in
                engine.continuePrevious()
                self?.dismiss()
            }
        )
        let hosting = NSHostingView(rootView: root)
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)
        center(panel)

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        isPresented = true

        installResignObserver(for: panel)
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        removeResignObserver()
        panel?.orderOut(nil)
    }

    // MARK: - Helpers

    private func center(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2 + visible.height * 0.08 // sit slightly above center
        )
        panel.setFrameOrigin(origin)
    }

    /// Click-away / focus loss: dismiss and keep tracking the previous activity silently.
    private func installResignObserver(for panel: FloatingPanel) {
        removeResignObserver()
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.dismiss() }
        }
    }

    private func removeResignObserver() {
        if let resignObserver {
            NotificationCenter.default.removeObserver(resignObserver)
            self.resignObserver = nil
        }
    }
}
