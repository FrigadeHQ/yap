import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The global toggle shortcut. Defaults to ⌘⇧D ("dictate").
    static let toggleRecording = Self("toggleRecording", default: .init(.d, modifiers: [.command, .shift]))
}

/// Registers the global toggle hotkey and forwards presses to a handler.
@MainActor
final class HotkeyManager {
    private var handler: (() -> Void)?

    func onToggle(_ action: @escaping () -> Void) {
        handler = action
        KeyboardShortcuts.onKeyDown(for: .toggleRecording) { [weak self] in
            self?.handler?()
        }
    }
}
