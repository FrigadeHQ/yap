import Testing
import AppKit
@testable import Yap

@MainActor
struct PasteboardSnapshotTests {
    @Test func restoresPreviousStringContents() {
        // Use a private, named pasteboard so we don't disturb the user's clipboard.
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.frigade.yap.tests"))
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)

        let snapshot = PasteboardSnapshot.capture(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("temporary", forType: .string)
        #expect(pasteboard.string(forType: .string) == "temporary")

        PasteboardSnapshot.restore(snapshot, to: pasteboard)
        #expect(pasteboard.string(forType: .string) == "original")
    }
}
