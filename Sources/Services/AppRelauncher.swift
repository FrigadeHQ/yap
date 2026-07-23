import AppKit
import Foundation

/// Relaunches the app in place.
///
/// macOS caches a process's Accessibility trust at the point the process is
/// checked, and event-posting rights granted after launch don't reliably apply
/// to an already-running process. The dependable fix is a clean relaunch.
///
/// The spawned shell outlives this process: it waits for us to exit, then opens
/// a fresh instance. Doing it this way avoids the race where macOS refuses to
/// launch a second instance of the same bundle identifier while the old one is
/// still alive.
enum AppRelauncher {
    static func relaunch() {
        let bundlePath = Bundle.main.bundlePath
        let pid = ProcessInfo.processInfo.processIdentifier

        let script = """
        while /bin/kill -0 \(pid) >/dev/null 2>&1; do /bin/sleep 0.1; done
        /usr/bin/open -n "\(bundlePath)"
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", script]

        do {
            try task.run()
        } catch {
            NSLog("Yap: relaunch failed to spawn helper: \(error.localizedDescription)")
            return
        }

        NSApp.terminate(nil)
    }
}
