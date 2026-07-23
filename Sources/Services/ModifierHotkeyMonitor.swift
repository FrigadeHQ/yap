import AppKit
import Carbon.HIToolbox

/// A single modifier key used on its own as the dictation trigger.
///
/// Carbon hotkeys (what the KeyboardShortcuts package registers) always require
/// a real key alongside the modifiers, so a bare "Right Shift" can't be
/// expressed that way. Instead we watch `flagsChanged` events and treat a clean
/// tap of the chosen modifier as the trigger.
enum ModifierTrigger: String, CaseIterable, Identifiable {
    case none
    case rightShift, leftShift
    case rightCommand, leftCommand
    case rightOption, leftOption
    case rightControl, leftControl
    case function

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Off"
        case .rightShift: return "Right ⇧ Shift"
        case .leftShift: return "Left ⇧ Shift"
        case .rightCommand: return "Right ⌘ Command"
        case .leftCommand: return "Left ⌘ Command"
        case .rightOption: return "Right ⌥ Option"
        case .leftOption: return "Left ⌥ Option"
        case .rightControl: return "Right ⌃ Control"
        case .leftControl: return "Left ⌃ Control"
        case .function: return "fn"
        }
    }

    /// The physical key's virtual keycode. `flagsChanged` reports which key
    /// changed, which is the only way to tell left from right reliably.
    var keyCode: UInt16? {
        switch self {
        case .none: return nil
        case .leftShift: return UInt16(kVK_Shift)
        case .rightShift: return UInt16(kVK_RightShift)
        case .leftCommand: return UInt16(kVK_Command)
        case .rightCommand: return UInt16(kVK_RightCommand)
        case .leftOption: return UInt16(kVK_Option)
        case .rightOption: return UInt16(kVK_RightOption)
        case .leftControl: return UInt16(kVK_Control)
        case .rightControl: return UInt16(kVK_RightControl)
        case .function: return UInt16(kVK_Function)
        }
    }

    var flag: NSEvent.ModifierFlags? {
        switch self {
        case .none: return nil
        case .leftShift, .rightShift: return .shift
        case .leftCommand, .rightCommand: return .command
        case .leftOption, .rightOption: return .option
        case .leftControl, .rightControl: return .control
        case .function: return .function
        }
    }
}

/// Watches for a clean tap of a single modifier key and reports it.
///
/// "Clean" means: pressed and released on its own, quickly, with no other key or
/// modifier involved — so holding Right Shift to type a capital letter never
/// fires the trigger.
@MainActor
final class ModifierHotkeyMonitor {
    var trigger: ModifierTrigger = .none {
        didSet { reset() }
    }
    var onTap: (() -> Void)?

    /// Longer than this and it was a hold, not a tap.
    private let maximumTapDuration: TimeInterval = 0.6

    private var monitors: [Any] = []
    private var isHolding = false
    private var usedInCombination = false
    private var pressedAt: Date?

    func start() {
        stop()

        // Global monitors observe other apps; local ones cover Yap's own windows.
        addGlobal(matching: .flagsChanged) { [weak self] event in self?.handleFlags(event) }
        addGlobal(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.usedInCombination = true
        }
        addLocal(matching: .flagsChanged) { [weak self] event in self?.handleFlags(event) }
        addLocal(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.usedInCombination = true
        }
    }

    func stop() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
        reset()
    }

    // MARK: - Private

    private func addGlobal(matching mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { event in
            Task { @MainActor in handler(event) }
        }) {
            monitors.append(monitor)
        }
    }

    private func addLocal(matching mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            Task { @MainActor in handler(event) }
            return event
        }) {
            monitors.append(monitor)
        }
    }

    private func reset() {
        isHolding = false
        usedInCombination = false
        pressedAt = nil
    }

    private func handleFlags(_ event: NSEvent) {
        guard let keyCode = trigger.keyCode, let flag = trigger.flag else { return }

        guard event.keyCode == keyCode else {
            // A different modifier moved while ours was held — that's a combo.
            if isHolding { usedInCombination = true }
            return
        }

        let isDown = event.modifierFlags.contains(flag)
        if isDown {
            isHolding = true
            usedInCombination = false
            pressedAt = Date()
            return
        }

        guard isHolding else { return }
        isHolding = false
        let heldFor = pressedAt.map { Date().timeIntervalSince($0) } ?? .greatestFiniteMagnitude
        pressedAt = nil

        // Nothing else pressed, released quickly, and no modifiers left down.
        let noModifiersRemain = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .isEmpty

        if !usedInCombination, heldFor < maximumTapDuration, noModifiersRemain {
            onTap?()
        }
    }
}
