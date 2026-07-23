import AppKit
import Carbon.HIToolbox
import CoreGraphics
import ApplicationServices

enum InjectionOutcome: Equatable {
    /// Text was pasted into the focused field.
    case pasted
    /// No editable target was found; text was left on the clipboard to paste manually.
    case leftOnClipboard
}

@MainActor
protocol TextInjecting {
    func deliver(_ text: String) -> InjectionOutcome
}

/// Delivers text by placing it on the clipboard and simulating ⌘V into the
/// focused field, then restoring the previous clipboard contents. If no editable
/// target is found, the text is left on the clipboard.
@MainActor
final class TextInjector: TextInjecting {
    /// How long to wait after ⌘V before putting the user's clipboard back.
    /// Long enough for slower targets (Electron apps, browsers) to consume the
    /// paste, short enough that the clipboard isn't visibly hijacked.
    private static let restoreDelay: TimeInterval = 0.25

    func deliver(_ text: String) -> InjectionOutcome {
        let saved = PasteboardSnapshot.capture()

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        let changeCountAfterWrite = pasteboard.changeCount

        // Only skip when nothing at all has focus. We deliberately do NOT require
        // the element to look editable: Electron and web content (Slack, VS Code,
        // browsers) routinely report a generic role with no settable AXValue even
        // when the caret is sitting in a perfectly good text box. Gating on that
        // made Yap silently refuse to paste into exactly the apps people use most.
        guard hasFocusedElement() else {
            // Leave the text on the clipboard for manual pasting — restoring
            // here would discard the transcript.
            return .leftOnClipboard
        }

        simulatePaste()
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.restoreDelay) {
            // If the user copied something else in the meantime, leave it alone.
            guard NSPasteboard.general.changeCount == changeCountAfterWrite else { return }
            PasteboardSnapshot.restore(saved)
        }
        return .pasted
    }

    /// `NX_DEVICELCMDKEYMASK` — "left command physically down". Electron and Java
    /// apps (Slack, VS Code, IntelliJ) ignore a synthetic ⌘V without this bit,
    /// which is a very common cause of "paste silently does nothing in app X".
    private static let deviceLeftCommand: UInt64 = 0x0000_0008

    private func simulatePaste() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let flags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | Self.deviceLeftCommand)
        let vKey = CGKeyCode(kVK_ANSI_V)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        else { return }

        keyDown.flags = flags
        keyUp.flags = flags
        keyDown.post(tap: .cgAnnotatedSessionEventTap)
        keyUp.post(tap: .cgAnnotatedSessionEventTap)
    }

    /// Whether anything at all currently has keyboard focus.
    ///
    /// This is intentionally a weak test. Determining *editability* across
    /// AppKit, Electron, Java and web content is not reliably possible, so the
    /// only question worth asking is whether there's somewhere for keystrokes to
    /// go. A stray ⌘V into a non-text context is harmless; refusing to paste
    /// into a real text box is not.
    private func hasFocusedElement() -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &focused
        )
        return result == .success && focused != nil
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
