import AppKit
import Carbon.HIToolbox

/// Carbon hotkeys always require a real key alongside modifiers, so a bare
/// modifier can't be one — we watch `flagsChanged` for a clean tap instead.
enum ModifierTrigger: String, Codable, CaseIterable, Identifiable {
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

    /// `flagsChanged` reports which key changed — the only way to tell left from right.
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

/// "Clean tap" means pressed and released quickly on its own — so holding
/// Right Shift to type a capital letter never fires the trigger.
///
/// Kept apart from the monitor below so the rules can be tested without
/// synthesizing NSEvents. State is per key: two profiles can bind Left and Right
/// Option, and both can be down at once.
struct ModifierTapRecognizer {
    var bindings: [(id: UUID, trigger: ModifierTrigger)] = []

    /// Longer than this and it was a hold, not a tap.
    private let maximumTapDuration: TimeInterval = 0.6

    private var held: [UInt16: (pressedAt: Date, dirty: Bool)] = [:]

    /// Returns the profile whose modifier was just tapped cleanly, if any.
    mutating func flagsChanged(
        keyCode: UInt16, flags: NSEvent.ModifierFlags, at now: Date
    ) -> UUID? {
        // Another modifier moved while ours was held — that's a combo, not a tap.
        for key in held.keys where key != keyCode { held[key]?.dirty = true }

        guard let binding = bindings.first(where: { $0.trigger.keyCode == keyCode }),
              let flag = binding.trigger.flag
        else { return nil }

        if flags.contains(flag) {
            held[keyCode] = (pressedAt: now, dirty: false)
            return nil
        }

        guard let press = held.removeValue(forKey: keyCode), !press.dirty else { return nil }
        guard now.timeIntervalSince(press.pressedAt) < maximumTapDuration else { return nil }

        // Anything still held means the user was building a combination. Left and
        // Right Option share a flag, so this also covers releasing one of a pair.
        guard flags.intersection(.deviceIndependentFlagsMask).isEmpty else { return nil }
        return binding.id
    }

    /// A key or mouse press arrived, so nothing currently held is a bare tap.
    mutating func interrupted() {
        for key in held.keys { held[key]?.dirty = true }
    }

    mutating func reset() {
        held.removeAll()
    }
}

@MainActor
final class ModifierHotkeyMonitor {
    var bindings: [(id: UUID, trigger: ModifierTrigger)] = [] {
        didSet {
            recognizer.bindings = bindings
            recognizer.reset()
        }
    }
    var onTap: ((UUID) -> Void)?

    private var recognizer = ModifierTapRecognizer()
    private var monitors: [Any] = []

    func start() {
        stop()

        // Global monitors observe other apps; local ones cover Yap's own windows.
        addGlobal(matching: .flagsChanged) { [weak self] event in self?.handleFlags(event) }
        addGlobal(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.recognizer.interrupted()
        }
        addLocal(matching: .flagsChanged) { [weak self] event in self?.handleFlags(event) }
        addLocal(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.recognizer.interrupted()
        }
    }

    func stop() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
        recognizer.reset()
    }

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

    private func handleFlags(_ event: NSEvent) {
        let tapped = recognizer.flagsChanged(
            keyCode: event.keyCode, flags: event.modifierFlags, at: Date()
        )
        if let tapped { onTap?(tapped) }
    }
}
