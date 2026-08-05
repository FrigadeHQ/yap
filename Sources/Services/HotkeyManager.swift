import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording", default: .init(.d, modifiers: [.command, .shift]))
}

extension DictationProfile {
    /// The first profile keeps the name the shortcut has always been stored under,
    /// which is what carries both the recorded combination and the ⌘⇧D default
    /// across the upgrade. Later profiles get a name of their own.
    var shortcutName: KeyboardShortcuts.Name {
        shortcutKey == DictationProfile.legacyShortcutKey ? .toggleRecording : .init(shortcutKey)
    }
}

@MainActor
final class HotkeyManager {
    private var handler: ((UUID) -> Void)?
    private var bound: [KeyboardShortcuts.Name] = []

    /// Rebinds every profile's key combination. Handlers accumulate rather than
    /// replace, so the previous ones have to go first or a press would fire twice.
    func bind(_ profiles: [DictationProfile], onToggle: @escaping (UUID) -> Void) {
        handler = onToggle

        for name in bound { KeyboardShortcuts.removeHandler(for: name) }
        bound = []

        for profile in profiles {
            let id = profile.id
            KeyboardShortcuts.onKeyDown(for: profile.shortcutName) { [weak self] in
                self?.handler?(id)
            }
            bound.append(profile.shortcutName)
        }
    }

    /// The recorder writes straight to defaults and knows nothing about the other
    /// profiles, so two can end up on one combination — which would start and then
    /// instantly stop. Whoever recorded it last keeps it, as with the other
    /// triggers, and the rest are cleared.
    func claim(_ profile: DictationProfile, among profiles: [DictationProfile]) {
        guard let shortcut = KeyboardShortcuts.getShortcut(for: profile.shortcutName) else { return }
        for other in profiles where other.id != profile.id {
            if KeyboardShortcuts.getShortcut(for: other.shortcutName) == shortcut {
                KeyboardShortcuts.setShortcut(nil, for: other.shortcutName)
            }
        }
    }

    /// Forgets a removed profile's combination, so it does not linger in defaults
    /// waiting for a later profile to inherit a shortcut nobody set for it.
    func forget(_ profile: DictationProfile) {
        KeyboardShortcuts.removeHandler(for: profile.shortcutName)
        KeyboardShortcuts.setShortcut(nil, for: profile.shortcutName)
        bound.removeAll { $0 == profile.shortcutName }
    }
}
