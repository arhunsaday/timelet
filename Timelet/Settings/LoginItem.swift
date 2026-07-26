import Foundation
import ServiceManagement

/// Launch-at-login via `SMAppService` (README "Launch at login").
/// Registration is a persistent system change, so it happens only when the user toggles it.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func set(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Timelet: failed to update login item: \(error.localizedDescription)")
        }
    }
}
