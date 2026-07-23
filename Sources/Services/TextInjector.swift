import AppKit
import Carbon.HIToolbox
import CoreGraphics
import ApplicationServices

enum InjectionOutcome: Equatable {
    /// Text was pasted into the focused field.
    case pasted
    /// Couldn't paste; text was left on the clipboard to paste manually.
    case leftOnClipboard
    /// Another app holds Secure Event Input, which blocks synthetic keystrokes.
    case blockedBySecureInput(String?)
}

@MainActor
protocol TextInjecting {
    /// Records which app to paste into. Called the moment recording starts,
    /// before any Yap UI appears, so the target can't be mistaken for our own HUD.
    func captureTarget()
    func deliver(_ text: String) async -> InjectionOutcome
}

/// Delivers text by placing it on the clipboard and synthesizing ⌘V into the
/// app that was frontmost when recording began, then restoring the clipboard.
@MainActor
final class TextInjector: TextInjecting {
    /// How long to wait after ⌘V before restoring the user's clipboard.
    ///
    /// This must be generous. Chromium-based apps (Slack, VS Code, Discord) read
    /// the pasteboard asynchronously and more than once — browser process, then
    /// renderer — so restoring quickly hands the renderer stale or empty data and
    /// the paste silently produces nothing. Native apps read synchronously on ⌘V
    /// and are unaffected, which is why terminals worked while Slack didn't.
    private static let restoreDelay: TimeInterval = 1.5

    /// Delay between writing the clipboard and posting ⌘V, for the pasteboard
    /// server round-trip.
    private static let prePasteDelay: TimeInterval = 0.03

    /// `NX_DEVICELCMDKEYMASK` — "left command physically down". Carbon-era, Qt
    /// and Java apps read the device-dependent bits and ignore a bare command flag.
    private static let deviceLeftCommand: UInt64 = 0x0000_0008

    private static let sessionType = NSPasteboard.PasteboardType("com.frigade.yap.session")
    private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private var targetApp: NSRunningApplication?

    func captureTarget() {
        targetApp = NSWorkspace.shared.frontmostApplication
    }

    func deliver(_ text: String) async -> InjectionOutcome {
        let saved = PasteboardSnapshot.capture()
        let sessionID = UUID().uuidString

        func placeOnClipboard() -> Int {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            pasteboard.setString(sessionID, forType: Self.sessionType)
            pasteboard.setString("", forType: Self.transientType)
            return pasteboard.changeCount
        }

        // Without Accessibility, synthetic events are dropped. Leave the text
        // where the user can still get at it.
        guard AXIsProcessTrusted() else {
            _ = placeOnClipboard()
            return .leftOnClipboard
        }

        if SecureInput.isEnabled {
            _ = placeOnClipboard()
            return .blockedBySecureInput(SecureInput.holderName())
        }

        // Make sure the app the user was in is frontmost again before we type.
        if let target = targetApp, !target.isActive {
            target.activate()
            try? await Task.sleep(nanoseconds: 120_000_000)
        }

        // Insurance rather than a fix: assigning flags explicitly already stops
        // held modifiers leaking into the event, but some apps track modifier
        // state from the raw event stream themselves.
        await waitForModifiersToClear()

        let changeCount = placeOnClipboard()
        try? await Task.sleep(nanoseconds: UInt64(Self.prePasteDelay * 1_000_000_000))

        // Deliberately no check for whether the focused element looks editable —
        // Electron and web apps report no focused element at all, so any such
        // gate silently refuses to paste into Slack, VS Code, Discord and friends.
        await postPaste()

        scheduleRestore(saved, changeCount: changeCount, sessionID: sessionID)
        return .pasted
    }

    // MARK: - Private

    /// AppleScript first: driving System Events goes through Apple Events rather
    /// than the synthetic event stream, and is the only route that proved
    /// reliable across native, Electron and web-based apps alike. Synthetic key
    /// events remain as an automatic fallback for when automation is unavailable.
    private func postPaste() async {
        if pasteViaAppleScript() { return }
        NSLog("Yap: AppleScript paste unavailable, falling back to synthetic key events")
        await postSyntheticPaste()
    }

    /// Posts a full ⌘V as four events: Command down, V down, V up, Command up.
    ///
    /// Posting only a V event with `.maskCommand` set is enough for native apps,
    /// which read `event.flags` directly — but NOT for Chromium/Electron (Slack,
    /// Cursor, VS Code, Discord), which rebuilds modifier state from the raw
    /// event stream. Without a genuine Command *keyDown* it never sees a ⌘V, and
    /// the paste silently does nothing. Hence the real modifier key events.
    private func postSyntheticPaste() async {
        // A private source has its own modifier state, so nothing ambient can
        // bleed into the events we create.
        guard let source = CGEventSource(stateID: .privateState) else { return }
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let commandFlags = CGEventFlags(
            rawValue: CGEventFlags.maskCommand.rawValue | Self.deviceLeftCommand
        )
        let commandKey = CGKeyCode(kVK_Command)
        let vKey = CGKeyCode(kVK_ANSI_V)

        func post(_ key: CGKeyCode, down: Bool, flags: CGEventFlags) {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)
            else { return }
            event.flags = flags
            // The HID tap is where hardware events enter the window server, so
            // Chromium treats the sequence as genuine typing.
            event.post(tap: .cghidEventTap)
        }

        let step: UInt64 = 10_000_000 // 10ms

        post(commandKey, down: true, flags: commandFlags)
        try? await Task.sleep(nanoseconds: step)
        post(vKey, down: true, flags: commandFlags)
        try? await Task.sleep(nanoseconds: step)
        post(vKey, down: false, flags: commandFlags)
        try? await Task.sleep(nanoseconds: step)
        post(commandKey, down: false, flags: [])
    }

    /// Pastes via System Events. Returns false if it didn't run — typically
    /// because automation access hasn't been granted.
    private func pasteViaAppleScript() -> Bool {
        let source = "tell application \"System Events\" to keystroke \"v\" using command down"
        guard let script = NSAppleScript(source: source) else { return false }
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error {
            NSLog("Yap: AppleScript paste failed: \(error)")
            return false
        }
        return true
    }

    private func scheduleRestore(
        _ saved: [[NSPasteboard.PasteboardType: Data]],
        changeCount: Int,
        sessionID: String
    ) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.restoreDelay) {
            let pasteboard = NSPasteboard.general
            // Only restore if the clipboard is still the one we wrote — the user
            // may have copied something in the meantime.
            guard pasteboard.changeCount == changeCount,
                  pasteboard.string(forType: Self.sessionType) == sessionID
            else { return }
            PasteboardSnapshot.restore(saved)
        }
    }

    /// Polls until no modifier keys are physically held, or the timeout expires.
    private func waitForModifiersToClear(timeout: TimeInterval = 0.6) async {
        let deadline = Date().addingTimeInterval(timeout)
        let watched: NSEvent.ModifierFlags = [.command, .shift, .option, .control, .function]

        while Date() < deadline {
            if NSEvent.modifierFlags.intersection(watched).isEmpty { return }
            try? await Task.sleep(nanoseconds: 15_000_000)
        }
    }
}

/// Snapshots and restores the general pasteboard across all items and types.
enum PasteboardSnapshot {
    static func capture(_ pasteboard: NSPasteboard = .general) -> [[NSPasteboard.PasteboardType: Data]] {
        (pasteboard.pasteboardItems ?? []).map { item in
            var representation: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    representation[type] = data
                }
            }
            return representation
        }
    }

    static func restore(_ saved: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        let items = saved.map { representation -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in representation {
                item.setData(data, forType: type)
            }
            return item
        }
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
