import SwiftUI

/// First-run empty state (2e).
struct EmptyStateView: View {
    @Environment(CheckInController.self) private var checkIn
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(spacing: 0) {
            AppIconBadge(size: 66)
                .padding(.bottom, 20)
            Text("No time tracked yet")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .tracking(-0.2)
                .padding(.bottom, 8)
            bodyText
                .font(.system(size: 13))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 300)
                .padding(.bottom, 22)
            Button("Start tracking") { checkIn.present() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.bottom, 13)
            helper
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.contentBackground)
    }

    private var bodyText: Text {
        Text("Timelet checks in every ").foregroundColor(Theme.textSecondary)
        + Text("\(settings.askIntervalMinutes) minutes").fontWeight(.semibold).foregroundColor(Theme.textPrimary)
        + Text(" and asks what you're up to. Just answer in ").foregroundColor(Theme.textSecondary)
        + Text("Group:Activity").fontWeight(.semibold).foregroundColor(Theme.textPrimary)
        + Text(" form.").foregroundColor(Theme.textSecondary)
    }

    @ViewBuilder private var helper: some View {
        if let combo = settings.checkInHotkey {
            hotkeyHint(combo.display)
        } else {
            Text("Set a global shortcut in Settings › Shortcuts")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textQuaternary)
        }
    }

    private func hotkeyHint(_ keys: String) -> some View {
        HStack(spacing: 6) {
            Text("or press")
                .foregroundStyle(Theme.textQuaternary)
            Text(keys)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Theme.fieldTint, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(Theme.border, lineWidth: 0.5))
            Text("anytime")
                .foregroundStyle(Theme.textQuaternary)
        }
        .font(.system(size: 12))
    }
}
