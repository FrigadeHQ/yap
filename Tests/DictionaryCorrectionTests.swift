import Testing
@testable import Yap

struct DictionaryCorrectionTests {
    private func fix(_ text: String, _ terms: [String]) -> String {
        DictionaryCorrection.correctFirstLetterMisses(in: text, terms: terms)
    }

    @Test func replacesFirstLetterMiss() {
        #expect(fix("I work at brigade now", ["Frigade"]) == "I work at Frigade now")
    }

    @Test func matchesCaseInsensitivelyAndKeepsTermCasing() {
        #expect(fix("call it BRIGADE", ["Frigade"]) == "call it Frigade")
    }

    @Test func leavesTheCorrectWordAlone() {
        #expect(fix("welcome to Frigade", ["Frigade"]) == "welcome to Frigade")
    }

    @Test func ignoresWordsThatDifferByMoreThanTheFirstLetter() {
        // "brigades" differs in length; "friends" differs in more than one spot.
        #expect(fix("the brigades and friends", ["Frigade"]) == "the brigades and friends")
    }

    @Test func ignoresShortWords() {
        // Terms under four letters are skipped so common words don't collide.
        #expect(fix("a bat sat", ["cat"]) == "a bat sat")
    }

    @Test func preservesPunctuationAndSpacing() {
        #expect(fix("(brigade)", ["Frigade"]) == "(Frigade)")
    }

    @Test func noTermsIsANoOp() {
        #expect(fix("brigade", []) == "brigade")
    }
}
