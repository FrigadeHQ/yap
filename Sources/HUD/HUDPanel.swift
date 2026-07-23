import AppKit
import SwiftUI

/// A borderless, non-activating, floating panel that hosts the recording HUD.
/// It appears on top without stealing focus from the app the user is typing into.
final class HUDPanel: NSPanel {
    init(model: HUDModel) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 386, height: 76),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false // the SwiftUI view draws its own soft shadow

        let hosting = NSHostingView(rootView: RecordingHUDView(model: model))
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Positions the panel near the bottom-center of the screen with the cursor.
    ///
    /// Layout is forced before measuring: reading `fittingSize` while SwiftUI
    /// still has a stale layout returns the wrong size, so the panel would appear
    /// at one size and visibly snap to another.
    func reposition() {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main else { return }
        let visible = screen.visibleFrame

        contentView?.layoutSubtreeIfNeeded()
        let size = contentView?.fittingSize ?? NSSize(width: 386, height: 76)
        guard size.width > 0, size.height > 0 else { return }
        setContentSize(size)

        // The window includes a transparent shadow margin, so offset by it to
        // keep the visible card where it looks right.
        let x = visible.midX - size.width / 2
        let y = visible.minY + 96 - RecordingHUDView.shadowMargin
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
