import ServiceManagement
import Observation
import Foundation

/// Wraps `SMAppService` to toggle launch-at-login.
@MainActor
@Observable
final class LaunchAtLoginService {
    var isEnabled: Bool = false

    init() {
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func set(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Yap: launch-at-login toggle failed: \(error.localizedDescription)")
        }
        refresh()
    }
}
