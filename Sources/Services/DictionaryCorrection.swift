import Foundation

/// Deterministic first pass over a transcript using the user's dictionary.
enum DictionaryCorrection {
    /// Replaces any word that differs from a learned term only in its first
    /// letter, e.g. "brigade" -> "Frigade". A swapped first consonant is the
    /// most common way dictation mangles a name, and requiring everything after
    /// the first letter to match keeps this from touching unrelated words. Runs
    /// on device with no model, so it costs nothing.
    static func correctFirstLetterMisses(in text: String, terms: [String]) -> String {
        // Single words only (phrases are handled by biasing and the AI pass), and
        // at least four letters so short common words don't collide.
        let candidates = terms.filter { !$0.contains(" ") && $0.count >= 4 }
        guard !candidates.isEmpty else { return text }

        let regex = try? NSRegularExpression(pattern: "\\p{L}{4,}")
        guard let regex else { return text }

        let ns = text as NSString
        var result = ""
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let range = match.range
            result += ns.substring(with: NSRange(location: cursor, length: range.location - cursor))
            let word = ns.substring(with: range)
            result += replacement(for: word, in: candidates) ?? word
            cursor = range.location + range.length
        }
        result += ns.substring(with: NSRange(location: cursor, length: ns.length - cursor))
        return result
    }

    private static func replacement(for word: String, in terms: [String]) -> String? {
        let lowerWord = word.lowercased()
        for term in terms where term.count == word.count {
            let lowerTerm = term.lowercased()
            guard lowerTerm != lowerWord else { return nil } // already the term (any case)
            if lowerTerm.first != lowerWord.first, lowerTerm.dropFirst() == lowerWord.dropFirst() {
                return term
            }
        }
        return nil
    }
}
