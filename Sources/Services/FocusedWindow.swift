import AppKit
import ApplicationServices

/// The screen showing the frontmost app's focused window.
///
/// The recording HUD used to anchor to whichever screen held the mouse cursor,
/// so on a multi-monitor setup it often appeared on a display the user was not
/// looking at while they typed into an app on another one. Anchoring to the
/// focused window's screen puts the widget where the dictation is actually
/// going. Yap already holds Accessibility permission for pasting, which is what
/// these queries need.
enum FocusedWindow {
    static func screen() -> NSScreen? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        guard let window = element(axApp, kAXFocusedWindowAttribute)
            ?? element(axApp, kAXMainWindowAttribute) else { return nil }

        guard let position = point(window, kAXPositionAttribute),
              let size = size(window, kAXSizeAttribute),
              size.width > 0, size.height > 0,
              let primaryHeight = primaryScreenHeight() else { return nil }

        // AX reports a top-left origin with y growing downward from the primary
        // display's top; NSScreen uses a bottom-left origin. Flip the window's
        // center around the primary screen's height to compare it against frames.
        let center = CGPoint(
            x: position.x + size.width / 2,
            y: primaryHeight - (position.y + size.height / 2)
        )
        return NSScreen.screens.first { $0.frame.contains(center) }
    }

    /// The primary display (the one with the menu bar) sits at AppKit origin
    /// (0, 0); its height is the flip reference for the global coordinate space.
    private static func primaryScreenHeight() -> CGFloat? {
        (NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main)?.frame.height
    }

    private static func element(_ parent: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(parent, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private static func point(_ element: AXUIElement, _ attribute: String) -> CGPoint? {
        guard let axValue = axValue(element, attribute, expecting: .cgPoint) else { return nil }
        var result = CGPoint.zero
        guard AXValueGetValue(axValue, .cgPoint, &result) else { return nil }
        return result
    }

    private static func size(_ element: AXUIElement, _ attribute: String) -> CGSize? {
        guard let axValue = axValue(element, attribute, expecting: .cgSize) else { return nil }
        var result = CGSize.zero
        guard AXValueGetValue(axValue, .cgSize, &result) else { return nil }
        return result
    }

    private static func axValue(_ element: AXUIElement, _ attribute: String, expecting: AXValueType) -> AXValue? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == expecting else { return nil }
        return axValue
    }
}
