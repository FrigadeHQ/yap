import AppKit
import Foundation

/// Relaunches the app in place.
///
/// Note: Yap does **not** need to restart when Accessibility is granted —
/// `AXIsProcessTrusted()` and `CGEvent.post` both take effect live, and Yap uses
/// a Carbon hotkey rather than a `CGEventTap` (a tap created while untrusted is
/// permanently inert and would need rebuilding). This exists purely as a manual
/// escape hatch, most usefully after a rebuild invalidates the TCC grant.
///
/// `createsNewApplicationInstance` is mandatory: without it, opening your own
/// bundle is a no-op because LaunchServices just reactivates the running
/// instance. Termination happens only inside the completion handler, once the
/// replacement process exists — ordering, not sleeping, is what avoids the race.
@MainActor
enum AppRelauncher {
    static func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = false // don't yank focus out of System Settings
        configuration.addsToRecentItems = false

        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { app, error in
            Task { @MainActor in
                guard error == nil, app != nil else {
                    NSLog("Yap: relaunch failed (\(error?.localizedDescription ?? "unknown")), falling back")
                    relaunchViaOpenTool()
                    return
                }
                NSApp.terminate(nil)
            }
        }
    }

    /// Fallback. `-n` is required while we're still alive, or `open` just
    /// reactivates this instance instead of starting a new one.
    private static func relaunchViaOpenTool() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }

    /// Both relaunch paths briefly leave two instances alive — two status items,
    /// two hotkey registrations. Run this early in the new instance.
    static func terminateOtherInstances() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let me = ProcessInfo.processInfo.processIdentifier
        for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        where app.processIdentifier != me {
            app.terminate()
        }
    }
}
