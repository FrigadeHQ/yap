import AppKit
import KeyboardShortcuts
import Testing
@testable import Yap

@MainActor
struct RecorderFocusTests {
    /// Yap takes its key combinations off the system while a recorder has focus:
    /// a registered combination is claimed system-wide, so it never reaches the
    /// field and the field clears itself instead. That hangs off a notification
    /// KeyboardShortcuts posts but does not declare public, so pin it here. If a
    /// dependency bump renames it, this fails rather than the feature going quiet.
    @Test func theLibraryStillAnnouncesRecorderFocus() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 44),
            styleMask: [.titled], backing: .buffered, defer: false
        )
        let recorder = KeyboardShortcuts.RecorderCocoa(for: .init("yapRecorderFocusTest"))
        window.contentView?.addSubview(recorder)

        var announced: [Bool] = []
        let observer = NotificationCenter.default.addObserver(
            forName: AppState.recorderFocusDidChange, object: nil, queue: nil
        ) { notification in
            announced.append(notification.userInfo?["isActive"] as? Bool ?? false)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        // Taking focus resets before it activates, so it is the latest value that
        // matters — which is all the observer in AppState reads too.
        #expect(window.makeFirstResponder(recorder))
        #expect(announced.last == true)

        #expect(window.makeFirstResponder(nil))
        #expect(announced.last == false)
    }
}
