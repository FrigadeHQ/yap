import Foundation
import Observation

/// The user's dictation profiles, persisted as a small JSON array so they survive
/// launches without pulling in a database. There is always at least one — a Yap
/// with no way to start it is a Yap that does nothing.
@MainActor
@Observable
final class DictationProfileStore {
    private static let key = "dictationProfiles"

    private(set) var profiles: [DictationProfile]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([DictationProfile].self, from: data),
           !decoded.isEmpty {
            profiles = decoded
        } else {
            profiles = [Self.migrated(from: defaults)]
            persist()
        }
    }

    func add() {
        profiles.append(DictationProfile())
        persist()
    }

    func remove(_ id: UUID) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == id }
        persist()
    }

    /// Two profiles sharing a trigger would race for the same press, so claiming
    /// one takes it from whoever held it, the way the system's own shortcut
    /// pickers do. `.none` is "unset" rather than a trigger, so it is never taken.
    func update(_ profile: DictationProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }

        for other in profiles.indices where other != index {
            if profile.modifierTrigger != .none, profiles[other].modifierTrigger == profile.modifierTrigger {
                profiles[other].modifierTrigger = .none
            }
            if profile.functionKeyTrigger != .none, profiles[other].functionKeyTrigger == profile.functionKeyTrigger {
                profiles[other].functionKeyTrigger = .none
            }
        }

        profiles[index] = profile
        persist()
    }

    /// Yap used to have one language and one set of triggers, each in its own key.
    /// Fold them into the first profile so upgrading is invisible. The old keys are
    /// left where they are, so downgrading still finds them.
    private static func migrated(from defaults: UserDefaults) -> DictationProfile {
        DictationProfile(
            language: defaults.string(forKey: "dictationLanguage") ?? DictationProfile.systemLanguage,
            shortcutKey: DictationProfile.legacyShortcutKey,
            modifierTrigger: ModifierTrigger(
                rawValue: defaults.string(forKey: "modifierTrigger") ?? ""
            ) ?? .none,
            functionKeyTrigger: FunctionKeyTrigger(
                rawValue: defaults.string(forKey: "functionKeyTrigger") ?? ""
            ) ?? .none
        )
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
