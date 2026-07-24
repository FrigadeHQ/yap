import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.d, modifiers: [.command, .shift]))
}

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
