import Testing
import SwiftData
@testable import Yap

/// Serialized around one shared in-memory container: SwiftData traps when multiple `ModelContainer`s for the same model are created concurrently.
@MainActor
@Suite(.serialized)
struct HistoryStoreTests {
    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: Transcript.self, configurations: config)
    }()

    private func makeStore() -> HistoryStore {
        let store = HistoryStore(context: Self.container.mainContext)
        store.clearAll()
        return store
    }

    @Test func savesAndFetchesNewestFirst() {
        let store = makeStore()
        store.save(text: "first", duration: 1, device: "Mic")
        store.save(text: "second", duration: 2, device: "Mic")

        let recent = store.recent()
        #expect(recent.count == 2)
        #expect(recent.first?.text == "second")
        #expect(recent.last?.text == "first")
    }

    @Test func deletesOne() throws {
        let store = makeStore()
        store.save(text: "keep", duration: nil, device: nil)
        store.save(text: "remove", duration: nil, device: nil)

        let toRemove = try #require(store.recent().first { $0.text == "remove" })
        store.delete(toRemove)

        let remaining = store.recent()
        #expect(remaining.count == 1)
        #expect(remaining.first?.text == "keep")
    }

    @Test func clearsAll() {
        let store = makeStore()
        store.save(text: "a", duration: nil, device: nil)
        store.save(text: "b", duration: nil, device: nil)
        store.clearAll()
        #expect(store.recent().isEmpty)
    }

    @Test func respectsFetchLimit() {
        let store = makeStore()
        for i in 0..<5 { store.save(text: "t\(i)", duration: nil, device: nil) }
        #expect(store.recent(limit: 3).count == 3)
    }
}
