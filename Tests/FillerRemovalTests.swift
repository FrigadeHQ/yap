import Testing
@testable import Yap

struct FillerRemovalTests {
    private func strip(_ text: String) -> String { FillerRemoval.strip(text) }

    @Test func removesLeadingFillerAndCapitalizes() {
        #expect(strip("um so I think") == "So I think")
    }

    @Test func removesMidSentenceFiller() {
        #expect(strip("I think um we should go") == "I think we should go")
    }

    @Test func removesFillerWithCommas() {
        #expect(strip("so, um, yeah") == "So, yeah")
    }

    @Test func removesSeveralDifferentFillers() {
        #expect(strip("uh hello uhh there hmm") == "Hello there")
    }

    @Test func isCaseInsensitive() {
        #expect(strip("Um okay UH sure") == "Okay sure")
    }

    @Test func leavesRealWordsThatContainFillerLetters() {
        // "human" contains "um", "summary" contains "umm" — both must survive, and
        // with no filler removed the text is returned untouched (not re-capitalized).
        #expect(strip("the human summary") == "the human summary")
    }

    @Test func capitalizesAfterSentenceEnd() {
        #expect(strip("yeah. um okay") == "Yeah. Okay")
    }

    @Test func doesNotLowercaseExistingCapitals() {
        #expect(strip("um I met Anna today") == "I met Anna today")
    }

    @Test func allFillerBecomesEmpty() {
        #expect(strip("um uh hmm") == "")
    }
}
