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
        NSApp.setActivationPolicy(.accessory)

        let app = AppState.shared
        app.bootstrap()

        // Show onboarding on first run or whenever a permission is missing.
        if !app.permissions.allGranted {
            WindowManager.shared.show(
                id: "onboarding",
                title: "Welcome to Yap",
                size: NSSize(width: 460, height: 560),
                resizable: false
            ) {
                OnboardingView().environment(app)
            }
        }
    }
}
