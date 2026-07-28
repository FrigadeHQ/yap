import Foundation
import Testing
@testable import Yap

struct SpeechLocaleTests {
    private let english = [
        Locale(identifier: "en-AU"),
        Locale(identifier: "en-GB"),
        Locale(identifier: "en-US"),
        Locale(identifier: "es-ES"),
    ]

    @Test func exactTagWins() {
        #expect(SpeechLocale.bestMatch(for: Locale(identifier: "en-GB"), in: english)?
            .identifier(.bcp47) == "en-GB")
    }

    /// The case that broke dictation outright: system language English (US) with
    /// the region set to Spain. The regional override makes the BCP-47 tag
    /// `en-US-u-rg-eszzzz`, which matches no supported locale exactly.
    @Test func regionalOverrideResolvesToSpokenRegion() {
        let overridden = Locale(identifier: "en_US@rg=eszzzz")
        // Guard the fixture: the bug only exists because of this serialization.
        #expect(overridden.identifier(.bcp47) == "en-US-u-rg-eszzzz")

        #expect(SpeechLocale.bestMatch(for: overridden, in: english)?
            .identifier(.bcp47) == "en-US")
    }

    @Test func fallsBackToSameLanguageInAnotherRegion() {
        #expect(SpeechLocale.bestMatch(for: Locale(identifier: "en-ZA"), in: english)?
            .identifier(.bcp47) == "en-AU")
    }

    @Test func widenedMatchIsStableRegardlessOfCandidateOrder() {
        let forward = SpeechLocale.bestMatch(for: Locale(identifier: "en-ZA"), in: english)
        let reversed = SpeechLocale.bestMatch(for: Locale(identifier: "en-ZA"), in: english.reversed())
        #expect(forward?.identifier(.bcp47) == reversed?.identifier(.bcp47))
    }

    @Test func unsupportedLanguageHasNoMatch() {
        #expect(SpeechLocale.bestMatch(for: Locale(identifier: "ja-JP"), in: english) == nil)
    }

    @Test func emptyCandidatesHaveNoMatch() {
        #expect(SpeechLocale.bestMatch(for: Locale(identifier: "en-US"), in: [Locale]()) == nil)
    }
}
