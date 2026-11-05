import SwiftUI

/// The layout shared by the corner cards (focus and break announcements): an icon badge, a title,
/// a subtitle and a row of buttons.
struct CornerCard<Buttons: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    @ViewBuilder var buttons: Buttons

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Theme.iconGradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                    Text(subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) { buttons }
                .font(.system(size: 12))
        }
        .padding(14)
        .frame(width: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.1), lineWidth: 0.5))
    }
}

/// "Time for a break?" and "Break's over".
struct BreakCard: View {
    let event: BreakReminder.Event
    let reminder: BreakReminder
    let engine: TrackingEngine
    let breakMinutes: Int
    let onClose: () -> Void

    var body: some View {
        switch event {
        case .due(let worked):
            CornerCard(icon: "figure.walk", title: "Time for a break?",
                       subtitle: "\(Format.duration(worked)) of work without one") {
                Button("Later") { reminder.later(); onClose() }
                    .buttonStyle(SecondaryButtonStyle())
                Button("Take \(breakMinutes) min") { reminder.takeBreak(); onClose() }
                    .buttonStyle(PrimaryButtonStyle())
            }
        case .breakOver:
            CornerCard(icon: "figure.walk", title: "Break's over",
                       subtitle: engine.lastActivityLabel.map { "Back to \($0.asDisplayLabel)?" } ?? "Ready to start again?") {
                Button("Not yet", action: onClose)
                    .buttonStyle(SecondaryButtonStyle())
                Button("Resume") { reminder.resume(); onClose() }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(engine.lastActivityLabel == nil)
            }
        }
    }
}
