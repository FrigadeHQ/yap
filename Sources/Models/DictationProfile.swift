import Foundation

/// A dictation language paired with the triggers that start it. Yap keeps a list
/// of these rather than one global language, so moving between English and German
/// is a different key rather than a trip to Settings.
struct DictationProfile: Codable, Identifiable, Hashable {
    /// The name the original shortcut has always been persisted under. It predates
    /// profiles, so the first one has to keep using it or the ⌘⇧D people already
    /// recorded would be orphaned on upgrade.
    static let legacyShortcutKey = "toggleRecording"

    /// Follows the OS locale, whatever that turns out to be at the time.
    static let systemLanguage = "system"

    let id: UUID
    /// `systemLanguage`, or a BCP-47 identifier.
    var language: String
    /// KeyboardShortcuts persists combos by name, so the name has to survive edits
    /// to the profile — hence a stored key rather than one derived on the fly.
    let shortcutKey: String
    var modifierTrigger: ModifierTrigger
    var functionKeyTrigger: FunctionKeyTrigger

    init(
        id: UUID = UUID(),
        language: String = DictationProfile.systemLanguage,
        shortcutKey: String? = nil,
        modifierTrigger: ModifierTrigger = .none,
        functionKeyTrigger: FunctionKeyTrigger = .none
    ) {
        self.id = id
        self.language = language
        // KeyboardShortcuts reads the name as a key path, so it must not contain a
        // dot. UUIDs never do.
        self.shortcutKey = shortcutKey ?? "dictation-\(id.uuidString)"
        self.modifierTrigger = modifierTrigger
        self.functionKeyTrigger = functionKeyTrigger
    }
}
