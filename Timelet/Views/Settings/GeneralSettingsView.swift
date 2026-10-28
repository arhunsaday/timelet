import SwiftUI

/// General tab (2d): tracking, check-ins, appearance and data, in grouped inset cards.
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

    private static let weekdays = Calendar.current.veryShortStandaloneWeekdaySymbols

    var body: some View {
        @Bindable var settings = settingsEnv
        VStack(alignment: .leading, spacing: 6) {
            SettingsSectionLabel(text: "CHECK-INS")
            SettingsCard {
                SettingsRow(label: "Ask every") {
                    Picker("", selection: $settings.askIntervalMinutes) {
                        ForEach(AppSettings.intervalOptions, id: \.self) { Text("\($0) minutes").tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                }
                Hairline()
                SettingsRow(label: "Style") {
                    Picker("", selection: $settings.checkInStyle) {
                        ForEach(CheckInStyle.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                }
                SettingsFootnote(text: settings.checkInStyle.help)
                Hairline()
                SettingsRow(label: "Only during work hours") {
                    Toggle("", isOn: $settings.workHoursOnly)
                        .labelsHidden().toggleStyle(.switch).tint(Theme.toggleOn)
                }
                if settings.workHoursOnly {
                    Hairline()
                    SettingsRow(label: "Hours") {
                        HStack(spacing: 6) {
                            DatePicker("", selection: timeBinding(\.workStartMinutes), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                            Text("–").foregroundStyle(Theme.textTertiary)
                            DatePicker("", selection: timeBinding(\.workEndMinutes), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                    Hairline()
                    SettingsRow(label: "Days") {
                        HStack(spacing: 3) {
                            ForEach(orderedWeekdays, id: \.self) { day in
                                let on = settings.workDays.contains(day)
                                Button(Self.weekdays[day - 1]) {
                                    if on { settings.workDays.remove(day) } else { settings.workDays.insert(day) }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .semibold))
                                .frame(width: 22, height: 22)
                                .foregroundStyle(on ? .white : Theme.textSecondary)
                                .background(Circle().fill(on ? Theme.accent : Theme.fieldTint))
                            }
                        }
                    }
                }
            }

            SettingsSectionLabel(text: "TRACKING").padding(.top, 8)
            SettingsCard {
                SettingsRow(label: "Notice when I'm away") {
                    Toggle("", isOn: $settings.idleDetectionEnabled)
                        .labelsHidden().toggleStyle(.switch).tint(Theme.toggleOn)
                }
                if settings.idleDetectionEnabled {
                    Hairline()
                    SettingsRow(label: "After") {
                        Picker("", selection: $settings.idleThresholdMinutes) {
                            ForEach(AppSettings.idleOptions, id: \.self) { Text("\($0) minutes idle").tag($0) }
                        }
                        .labelsHidden().pickerStyle(.menu).fixedSize()
                    }
                    SettingsFootnote(text: "Idle time, sleep and a locked screen are taken out of the running task. When you're back, Timelet asks what you were doing.")
                }
                Hairline()
                SettingsRow(label: "Round durations to") {
                    Picker("", selection: $settings.roundToMinutes) {
                        ForEach(AppSettings.roundingOptions, id: \.self) { opt in
                            Text(opt == 0 ? "Exact" : "\(opt) minutes").tag(opt)
                        }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                }
                SettingsFootnote(text: "Affects totals and exports only; recorded times are kept exact.")
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
                SettingsRow(label: "Menu bar shows") {
                    Picker("", selection: $settings.menuBarDisplay) {
                        ForEach(MenuBarDisplay.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                }
                Hairline()
                SettingsRow(label: "Show in Dock") {
                    Toggle("", isOn: $settings.showDockIcon)
                        .labelsHidden().toggleStyle(.switch).tint(Theme.toggleOn)
                }
                Hairline()
                SettingsRow(label: "Launch at login") {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden().toggleStyle(.switch).tint(Theme.toggleOn)
                        .onChange(of: launchAtLogin) { LoginItem.set(launchAtLogin) }
                }
            }

            SettingsSectionLabel(text: "DATA").padding(.top, 8)
            SettingsCard {
                SettingsRow(label: "Export to CSV") {
                    Button("Export…") { Exporter.exportInteractively(engine: engine) }
                }
                Hairline()
                SettingsRow(label: "Data folder") {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([AppModel.storeURL()])
                    }
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
    }

    /// Weekdays in the user's calendar order (Monday first in most of Europe).
    private var orderedWeekdays: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
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

/// Explanatory text under a settings row.
struct SettingsFootnote: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(Theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 9)
            .padding(.top, -3)
    }
}
