import SwiftUI
import AppKit

/// Entry point. Under the test harness we run a bare, idle app so the full stack
/// (model container, services, windows) never initializes — unit tests bring
/// their own isolated containers.
@main
enum YapMain {
    static func main() {
        if RuntimeMode.isTesting {
            let app = NSApplication.shared
            app.setActivationPolicy(.prohibited)
            app.run()
        } else {
            YapApp.main()
        }
    }
}

struct YapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var app = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(app)
                .modelContainer(app.modelContainer)
        } label: {
            Image(systemName: app.coordinator.state == .idle ? "mic" : "mic.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // A relaunch briefly leaves the previous instance alive.
        AppRelauncher.terminateOtherInstances()

        let app = AppState.shared
        app.applyActivationPolicy()
        app.bootstrap()

        // Show onboarding on first run or whenever a permission is missing.
        if !app.permissions.allGranted {
            app.presentMainWindow()
        }
    }

    /// Yap has no Dock icon and no default window, so opening it from Finder
    /// would otherwise look like nothing happened.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppState.shared.presentMainWindow()
        return true
    }

    /// Yap is a background dictation tool — closing a window must not quit it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
