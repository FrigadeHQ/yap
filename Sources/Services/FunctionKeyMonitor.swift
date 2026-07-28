import AppKit
import Carbon.HIToolbox

/// Function-row keys as dictation triggers: bare F1–F12, or the dictation
/// (microphone) key that sits in the F5 position on 2021+ MacBooks.
///
/// Carbon hotkeys and NSEvent monitors see these too late: with the default
/// "media keys" mode, the system claims the press first — F5 starts macOS
/// dictation before any hotkey fires. So this uses a CGEvent tap at the HID
/// level, inserted at the head of the chain, which sees the press before the
/// system does and consumes it so the built-in action never triggers.
enum FunctionKeyTrigger: String, CaseIterable, Identifiable {
    case none
    case dictation
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10, f11, f12

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Off"
        case .dictation: return "🎤 Dictation key"
        default: return rawValue.uppercased()
        }
    }

    /// The dictation key reports as F5's keycode on the built-in keyboard, with
    /// 176 as a media-keycode variant seen from some keyboards.
    var keyCodes: Set<Int64> {
        switch self {
        case .none: return []
        case .dictation: return [Int64(kVK_F5), 176]
        case .f1: return [Int64(kVK_F1)]
        case .f2: return [Int64(kVK_F2)]
        case .f3: return [Int64(kVK_F3)]
        case .f4: return [Int64(kVK_F4)]
        case .f5: return [Int64(kVK_F5)]
        case .f6: return [Int64(kVK_F6)]
        case .f7: return [Int64(kVK_F7)]
        case .f8: return [Int64(kVK_F8)]
        case .f9: return [Int64(kVK_F9)]
        case .f10: return [Int64(kVK_F10)]
        case .f11: return [Int64(kVK_F11)]
        case .f12: return [Int64(kVK_F12)]
        }
    }

    /// Fires only on a bare press. Command/option/control/shift combos pass
    /// through untouched — ⌘F5 is VoiceOver, and F-keys with modifiers are
    /// other apps' shortcuts. The fn flag is fine: holding fn is how these keys
    /// are typed at all when the row is in media mode. Auto-repeats are ignored
    /// so holding the key doesn't toggle recording over and over.
    static func shouldFire(
        trigger: FunctionKeyTrigger,
        keyCode: Int64,
        flags: CGEventFlags,
        isRepeat: Bool
    ) -> Bool {
        guard !isRepeat, trigger.keyCodes.contains(keyCode) else { return false }
        return flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift]).isEmpty
    }
}

@MainActor
final class FunctionKeyMonitor {
    var trigger: FunctionKeyTrigger = .none {
        didSet { sync() }
    }
    var onTap: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() { sync() }

    func stop() { uninstall() }

    /// The tap only exists while a trigger is configured. No key trigger, no
    /// keyboard tap — Yap should not be in the key event path at all unless
    /// the user asked for it.
    private func sync() {
        if trigger == .none {
            uninstall()
        } else {
            install()
        }
    }

    private func install() {
        guard tap == nil else { return }

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<FunctionKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return monitor.handle(type: type, event: event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            // Accessibility not granted (an active tap requires it). The picker
            // change is still saved; sync() runs again on the next launch or
            // trigger change, after the permission flow has done its thing.
            NSLog("Yap: could not create function-key event tap; is Accessibility granted?")
            return
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func uninstall() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
            self.tap = nil
        }
    }

    /// Runs on the main run loop (where the tap source is scheduled), but from
    /// a C callback the compiler can't tie to the actor — hence nonisolated
    /// with an async hop for the action. The decision itself must be
    /// synchronous: consuming the event means returning nil right here.
    private nonisolated func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // The system disables a tap it thinks is unresponsive; re-enable or
        // the trigger silently dies until relaunch.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            DispatchQueue.main.async { [weak self] in
                guard let self, let tap = self.tap else { return }
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
        // The tap's run-loop source is scheduled on the main loop, so this
        // callback is already on the main thread — assumeIsolated, don't sync.
        let shouldFire = MainActor.assumeIsolated {
            FunctionKeyTrigger.shouldFire(
                trigger: trigger, keyCode: keyCode, flags: event.flags, isRepeat: isRepeat
            )
        }

        guard shouldFire else { return Unmanaged.passUnretained(event) }

        DispatchQueue.main.async { [weak self] in self?.onTap?() }
        // Swallow it: for the dictation key this is what keeps macOS's own
        // dictation from popping up alongside Yap.
        return nil
    }
}
