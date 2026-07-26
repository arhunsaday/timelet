import SwiftUI

/// Settings window (2d): toolbar-style TabView.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
            ShortcutsSettingsView()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            ProjectsSettingsView()
                .tabItem { Label("Projects", systemImage: "folder") }
        }
        .frame(width: 500, height: 470)
    }
}
