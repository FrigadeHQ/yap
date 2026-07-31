import Foundation

/// Strips common filler words ("um", "uh", ...) from a transcript with a plain
/// regex. Deterministic and on device, so it costs nothing and can be on by
/// default. The heavier Apple Intelligence cleanup does this too, but this runs
/// even when that is off.
enum FillerRemoval {
    /// The default filler set. Whole-word and case-insensitive, so real words
    /// that merely contain these letters ("human", "summary") are left alone.
    static let words = ["uhhh", "uhh", "uhm", "umm", "mmm", "hmm", "ehh", "uh", "um", "hm", "mm", "mh"]

    static func strip(_ text: String) -> String {
        let alternation = words
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")

        // Remove each filler token as a whole word, taking a trailing comma with it.
        var out = text.replacingOccurrences(
            of: "\\b(?:\(alternation))\\b,?",
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )

        // Nothing matched: leave the transcript exactly as it was, so filler-free
        // dictations aren't re-spaced or re-capitalized.
        guard out != text else { return text }

        // Tidy the gaps the removals leave behind.
        out = out.replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)
        out = out.replacingOccurrences(of: ",\\s*,", with: ",", options: .regularExpression)
        out = out.replacingOccurrences(of: "\\s+([,.!?;:])", with: "$1", options: .regularExpression)
        out = out.replacingOccurrences(of: "([,.!?;:])\\1+", with: "$1", options: .regularExpression)
        out = out.replacingOccurrences(of: "^[\\s,]+", with: "", options: .regularExpression)
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)

        return capitalizeSentences(out)
    }

    /// Uppercase the first letter, and the first letter after each sentence end,
    /// so removing a leading "Um" doesn't leave the sentence starting lowercase.
    /// Never lowercases anything that was already capital.
    private static func capitalizeSentences(_ text: String) -> String {
        var chars = Array(text)
        var capitalizeNext = true
        for i in chars.indices {
            let c = chars[i]
            if capitalizeNext, c.isLetter {
                chars[i] = Character(c.uppercased())
                capitalizeNext = false
            } else if ".!?".contains(c) {
                capitalizeNext = true
            } else if !c.isWhitespace {
                capitalizeNext = false
            }
        }
        return String(chars)
    }
}
