import AppKit

/// A borderless, non-activating floating panel. The check-in (2b) can become key so its field
/// accepts typing; the gentle reminder card cannot, so it never takes the keyboard from the
/// app you are using.
final class FloatingPanel: NSPanel {
    private let acceptsKey: Bool

    init(acceptsKey: Bool = true) {
        self.acceptsKey = acceptsKey
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 300),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { acceptsKey }
    override var canBecomeMain: Bool { false }

    /// ⌘1…⌘9 pick a suggestion. Handled here, before the main menu, whose ⌘1–3 switch views.
    static let pickNotification = Notification.Name("TimeletCheckInPick")

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           let ch = event.charactersIgnoringModifiers, let digit = Int(ch), (1...9).contains(digit) {
            NotificationCenter.default.post(name: Self.pickNotification, object: self, userInfo: ["index": digit - 1])
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
