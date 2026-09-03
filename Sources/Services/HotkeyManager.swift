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
    ///
    /// Takes the combination the recorder reports rather than reading it back:
    /// the callback runs before the new value reaches defaults, so a read here
    /// would still see the old one.
    func claim(
        _ shortcut: KeyboardShortcuts.Shortcut?,
        for profile: DictationProfile,
        among profiles: [DictationProfile]
    ) {
        guard let shortcut else { return }
        let taken = Self.conflicts(with: shortcut, for: profile, among: profiles) {
            KeyboardShortcuts.getShortcut(for: $0.shortcutName)
        }
        for other in taken { KeyboardShortcuts.setShortcut(nil, for: other.shortcutName) }
    }

    /// The profiles holding a combination that someone else has just claimed.
    static func conflicts(
        with shortcut: KeyboardShortcuts.Shortcut,
        for profile: DictationProfile,
        among profiles: [DictationProfile],
        shortcutFor: (DictationProfile) -> KeyboardShortcuts.Shortcut?
    ) -> [DictationProfile] {
        profiles.filter { $0.id != profile.id && shortcutFor($0) == shortcut }
    }

    /// A registered combination is claimed system-wide: the OS routes it to the
    /// hotkey rather than delivering a key press to the app. So the recorder in
    /// Settings never sees the keys, stays empty, and saves nil — which looks
    /// exactly like typing a taken shortcut doing nothing. Pausing is not enough;
    /// the combinations have to come off the system while Settings has focus,
    /// which is also the one moment nobody wants them firing.
    func suspend() { KeyboardShortcuts.disable(bound) }

    func resume() { KeyboardShortcuts.enable(bound) }

    /// Forgets a removed profile's combination, so it does not linger in defaults
    /// waiting for a later profile to inherit a shortcut nobody set for it.
    func forget(_ profile: DictationProfile) {
        KeyboardShortcuts.removeHandler(for: profile.shortcutName)
        KeyboardShortcuts.setShortcut(nil, for: profile.shortcutName)
        bound.removeAll { $0 == profile.shortcutName }
    }
}
