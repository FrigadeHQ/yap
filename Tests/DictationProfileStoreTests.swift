import Foundation
import Testing
@testable import Yap

@MainActor
struct DictationProfileStoreTests {
    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "yap.profiles.test.\(UUID().uuidString)")!
    }

    @Test func migratesTheOldSingleLanguageSettings() {
        let defaults = isolatedDefaults()
        defaults.set("de-DE", forKey: "dictationLanguage")
        defaults.set(ModifierTrigger.rightOption.rawValue, forKey: "modifierTrigger")
        defaults.set(FunctionKeyTrigger.f6.rawValue, forKey: "functionKeyTrigger")

        let store = DictationProfileStore(defaults: defaults)

        #expect(store.profiles.count == 1)
        #expect(store.profiles[0].language == "de-DE")
        #expect(store.profiles[0].modifierTrigger == .rightOption)
        #expect(store.profiles[0].functionKeyTrigger == .f6)
        // Keeping the old name is what carries the combo the user already recorded.
        #expect(store.profiles[0].shortcutKey == DictationProfile.legacyShortcutKey)
    }

    @Test func leavesTheOldKeysInPlaceForADowngrade() {
        let defaults = isolatedDefaults()
        defaults.set("de-DE", forKey: "dictationLanguage")

        _ = DictationProfileStore(defaults: defaults)

        #expect(defaults.string(forKey: "dictationLanguage") == "de-DE")
    }

    @Test func startsFromOneSystemLanguageProfileOnAFreshInstall() {
        let store = DictationProfileStore(defaults: isolatedDefaults())

        #expect(store.profiles.count == 1)
        #expect(store.profiles[0].language == DictationProfile.systemLanguage)
        #expect(store.profiles[0].modifierTrigger == .none)
        #expect(store.profiles[0].functionKeyTrigger == .none)
    }

    @Test func persistsAcrossReload() {
        let defaults = isolatedDefaults()
        let store = DictationProfileStore(defaults: defaults)
        store.add()
        var second = store.profiles[1]
        second.language = "fr-FR"
        store.update(second)

        let reloaded = DictationProfileStore(defaults: defaults)

        #expect(reloaded.profiles.map(\.language) == [DictationProfile.systemLanguage, "fr-FR"])
        #expect(reloaded.profiles[1].id == second.id)
    }

    @Test func claimingATriggerTakesItFromTheProfileThatHeldIt() {
        let store = DictationProfileStore(defaults: isolatedDefaults())
        var first = store.profiles[0]
        first.modifierTrigger = .rightOption
        first.functionKeyTrigger = .f6
        store.update(first)

        store.add()
        var second = store.profiles[1]
        second.modifierTrigger = .rightOption
        second.functionKeyTrigger = .f6
        store.update(second)

        #expect(store.profiles[0].modifierTrigger == .none)
        #expect(store.profiles[0].functionKeyTrigger == .none)
        #expect(store.profiles[1].modifierTrigger == .rightOption)
        #expect(store.profiles[1].functionKeyTrigger == .f6)
    }

    @Test func offIsUnsetSoEveryProfileMayHoldIt() {
        let store = DictationProfileStore(defaults: isolatedDefaults())
        var first = store.profiles[0]
        first.modifierTrigger = .rightOption
        store.update(first)

        store.add()
        store.update(store.profiles[1]) // both triggers still .none

        #expect(store.profiles[0].modifierTrigger == .rightOption)
    }

    @Test func refusesToRemoveTheLastProfile() {
        let store = DictationProfileStore(defaults: isolatedDefaults())

        store.remove(store.profiles[0].id)

        #expect(store.profiles.count == 1)
    }

    @Test func removesAnExtraProfile() {
        let store = DictationProfileStore(defaults: isolatedDefaults())
        store.add()
        let removed = store.profiles[1].id

        store.remove(removed)

        #expect(store.profiles.count == 1)
        #expect(!store.profiles.contains { $0.id == removed })
    }

    @Test func givesEveryNewProfileItsOwnShortcutName() {
        let store = DictationProfileStore(defaults: isolatedDefaults())
        store.add()
        store.add()

        let keys = store.profiles.map(\.shortcutKey)
        #expect(Set(keys).count == keys.count)
        // KeyboardShortcuts uses the name in a key path and rejects dots.
        #expect(!keys.contains { $0.contains(".") })
    }
}
