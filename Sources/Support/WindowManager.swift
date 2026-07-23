import AppKit
import SwiftUI

/// Opens and reuses standalone SwiftUI windows for a menu-bar (agent) app, where
/// SwiftUI's `Window`/`Settings` scenes are awkward to drive programmatically.
@MainActor
final class WindowManager {
    static let shared = WindowManager()
    private var windows: [String: NSWindow] = [:]

    func show<Content: View>(
        id: String,
        title: String,
        size: NSSize,
        resizable: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hosting = NSHostingController(rootView: content())
        let window = NSWindow(contentViewController: hosting)
        window.title = title
        var style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
        if resizable { style.insert(.resizable) }
        window.styleMask = style
        window.setContentSize(size)
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.center()

        windows[id] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
