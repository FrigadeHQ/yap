import Foundation
import Testing
@testable import Yap

struct DictationProfileTests {
    @Test func resolvesABCP47LanguageToItsLocale() {
        #expect(DictationProfile(language: "de-DE").locale == Locale(identifier: "de-DE"))
    }

    @Test func followsTheSystemLocaleLate() {
        // Resolved on read, so changing the OS language needs no edit to the profile.
        #expect(DictationProfile().locale == .current)
    }

    @Test func shortensTheLanguageToATagForTheRecordingWindow() {
        #expect(DictationProfile(language: "de-DE").languageTag == "DE")
        #expect(DictationProfile(language: "fr-CH").languageTag == "FR")
        #expect(DictationProfile(language: "en-US").languageTag == "EN")
    }
}
