import SwiftUI

/// General tab (2d): tracking + appearance preferences in grouped inset cards.
struct GeneralSettingsView: View {
    var body: some View {
        ScrollView { GeneralSettingsContent() }
            .background(Theme.contentBackground)
    }
}

/// The card content of the General tab, extracted so it can render outside a ScrollView.
struct GeneralSettingsContent: View {
    @Environment(TrackingEngine.self) private var engine
    @Environment(AppSettings.self) private var settingsEnv
    @State private var launchAtLogin = LoginItem.isEnabled

    var body: some View {
        @Bindable var settings = settingsEnv
        VStack(alignment: .leading, spacing: 6) {
                SettingsSectionLabel(text: "TRACKING")
                SettingsCard {
                    SettingsRow(label: "Ask interval") {
                        Picker("", selection: $settings.askIntervalMinutes) {
                            ForEach(AppSettings.intervalOptions, id: \.self) { Text("\($0) minutes").tag($0) }
                        }
                        .labelsHidden().pickerStyle(.menu).fixedSize()
                        .onChange(of: settings.askIntervalMinutes) { engine.rescheduleAskTimer() }
                    }
                    Hairline()
                    SettingsRow(label: "Round durations to") {
                        Picker("", selection: $settings.roundToMinutes) {
                            ForEach(AppSettings.roundingOptions, id: \.self) { opt in
                                Text(opt == 0 ? "Off" : "\(opt) minutes").tag(opt)
                            }
                        }
                        .labelsHidden().pickerStyle(.menu).fixedSize()
                    }
                    Hairline()
                    SettingsRow(label: "Track during work hours only") {
                        Toggle("", isOn: $settings.workHoursOnly)
                            .labelsHidden().toggleStyle(.switch).tint(Theme.toggleOn)
                    }
                    if settings.workHoursOnly {
                        Hairline()
                        SettingsRow(label: "Work hours") {
                            HStack(spacing: 6) {
                                DatePicker("", selection: timeBinding(\.workStartMinutes), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                Text("–").foregroundStyle(Theme.textTertiary)
                                DatePicker("", selection: timeBinding(\.workEndMinutes), displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                    }
                    Hairline()
                    SettingsRow(label: "Pause in Do Not Disturb") {
                        Toggle("", isOn: $settings.pauseInDoNotDisturb)
                            .labelsHidden().toggleStyle(.switch).tint(Theme.toggleOn)
                    }
                }

                SettingsSectionLabel(text: "APPEARANCE").padding(.top, 8)
                SettingsCard {
                    SettingsRow(label: "Appearance") {
                        Picker("", selection: $settings.appearance) {
                            ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden().pickerStyle(.segmented).fixedSize()
                    }
                    Hairline()
                    SettingsRow(label: "Language") {
                        Picker("", selection: $settings.language) {
                            ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden().pickerStyle(.menu).fixedSize()
                    }
                    Hairline()
                    SettingsRow(label: "Launch at login") {
                        Toggle("", isOn: $launchAtLogin)
                            .labelsHidden().toggleStyle(.switch).tint(Theme.toggleOn)
                            .onChange(of: launchAtLogin) { LoginItem.set(launchAtLogin) }
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
    }

    /// Binds a minutes-from-midnight setting to a `Date` for the time pickers.
    private func timeBinding(_ keyPath: ReferenceWritableKeyPath<AppSettings, Int>) -> Binding<Date> {
        Binding(
            get: { settingsEnv[keyPath: keyPath].asTimeOfDayToday },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                settingsEnv[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }
}
