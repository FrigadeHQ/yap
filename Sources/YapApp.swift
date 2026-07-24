import SwiftUI
import AppKit

/// Under the test harness, run a bare idle app so the full stack never boots —
/// unit tests bring their own isolated model containers.
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

    private var isRecording: Bool { app.coordinator.state != .idle }

    var body: some Scene {
        MenuBarExtra {
            Button(isRecording ? "Stop Dictation" : "Start Dictation") {
                app.toggleRecording()
            }
            Divider()
            Button("Open Yap…") { app.openMain(page: .settings) }
            Button("Recording History…") { app.openMain(page: .history) }
            Divider()
            Button("About Yap") { app.openAbout() }
            Button("Quit Yap") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(nsImage: MenuBarIcon.image(recording: isRecording))
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // A relaunch briefly leaves the previous instance alive.
        AppRelauncher.terminateOtherInstances()

        NSApp.setActivationPolicy(.regular)

        let app = AppState.shared
        app.bootstrap()

        if !app.permissions.allGranted {
            app.openOnboarding()
        }
    }

    /// Yap has no default window, so opening it from the Dock or Finder would
    /// otherwise look like nothing happened.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppState.shared.presentMainWindow()
        return true
    }

    /// Yap is a background dictation tool — closing a window must not quit it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
