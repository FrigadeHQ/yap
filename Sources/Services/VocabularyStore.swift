import Foundation
import Observation

/// The user's custom dictionary: names and words the transcriber should lean
/// toward. Fed to the recognizer as contextual strings at the start of each
/// dictation, never used to blindly replace text. Persisted as a small JSON
/// array so it survives launches without pulling in a database.
@MainActor
@Observable
final class VocabularyStore {
    private static let key = "dictionaryTerms"

    private(set) var terms: [String]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            terms = decoded
        } else {
            terms = []
        }
    }

    /// Adds a term, newest first. Ignores blanks and case-insensitive duplicates
    /// so the list stays clean.
    func add(_ raw: String) {
        let term = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty,
              !terms.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame })
        else { return }
        terms.insert(term, at: 0)
        persist()
    }

    func remove(_ term: String) {
        terms.removeAll { $0 == term }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(terms) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
