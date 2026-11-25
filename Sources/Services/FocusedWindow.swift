import AppKit
import CoreGraphics

/// The screen showing the frontmost app's front window.
///
/// The recording HUD used to anchor to whichever screen held the mouse cursor,
/// so on a multi-monitor setup it often appeared on a display the user was not
/// looking at while they typed into an app on another one. Anchoring to the
/// front window's screen puts the widget where the dictation is actually going.
///
/// This asks the window server, not the app. An earlier version used
/// Accessibility queries, which are synchronous messages to the target app:
/// when that app was busy (a Chromium or Electron app mid-render, say), each
/// query blocked the main thread for up to the system's 6-second AX timeout,
/// and the HUD could not draw until they returned. The window list answers
/// from the window server in well under a millisecond and needs no permission
/// for window bounds.
enum FocusedWindow {
    static func screen() -> NSScreen? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              let frame = frontWindowFrame(of: pid),
              let primaryHeight = primaryScreenHeight() else { return nil }

        // The window list reports a top-left origin with y growing downward
        // from the primary display's top; NSScreen uses a bottom-left origin.
        // Flip the window's center around the primary screen's height.
        let center = CGPoint(x: frame.midX, y: primaryHeight - frame.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
    }

    /// The list is ordered front to back, so the first normal-level window the
    /// app owns is its frontmost one.
    private static func frontWindowFrame(of pid: pid_t) -> CGRect? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == pid,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict),
                  // Skip slivers such as invisible helper windows.
                  bounds.width > 40, bounds.height > 40 else { continue }
            return bounds
        }
        return nil
    }

    /// The primary display (the one with the menu bar) sits at AppKit origin
    /// (0, 0); its height is the flip reference for the global coordinate space.
    private static func primaryScreenHeight() -> CGFloat? {
        (NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.main)?.frame.height
    }
}
