import Foundation
import Testing
@testable import Yap

@MainActor
struct VocabularyStoreTests {
    private func isolatedDefaults() -> UserDefaults {
        UserDefaults(suiteName: "yap.vocab.test.\(UUID().uuidString)")!
    }

    @Test func addsNewestFirstTrimsAndDedupes() {
        let store = VocabularyStore(defaults: isolatedDefaults())
        store.add("Frigade")
        store.add("  Anthropic  ")
        store.add("frigade") // case-insensitive duplicate, ignored
        store.add("   ")      // blank, ignored
        #expect(store.terms == ["Anthropic", "Frigade"])
    }

    @Test func removesAndPersistsAcrossReload() {
        let defaults = isolatedDefaults()
        let store = VocabularyStore(defaults: defaults)
        store.add("Kubernetes")
        store.add("kubectl")
        store.remove("Kubernetes")
        #expect(store.terms == ["kubectl"])

        let reloaded = VocabularyStore(defaults: defaults)
        #expect(reloaded.terms == ["kubectl"])
    }
}
