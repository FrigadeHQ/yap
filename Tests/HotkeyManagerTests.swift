import Foundation
import KeyboardShortcuts
import Testing
@testable import Yap

@MainActor
struct HotkeyManagerTests {
    private let english = DictationProfile(language: "en-US")
    private let german = DictationProfile(language: "de-DE")

    private let toggle = KeyboardShortcuts.Shortcut(.d, modifiers: [.command, .shift])
    private let other = KeyboardShortcuts.Shortcut(.e, modifiers: [.command, .shift])

    @Test func takesTheCombinationFromTheProfileThatHeldIt() {
        let taken = HotkeyManager.conflicts(
            with: toggle, for: german, among: [english, german]
        ) { $0.id == english.id ? toggle : nil }

        #expect(taken.map(\.id) == [english.id])
    }

    @Test func leavesProfilesOnAnotherCombinationAlone() {
        let taken = HotkeyManager.conflicts(
            with: toggle, for: german, among: [english, german]
        ) { $0.id == english.id ? other : nil }

        #expect(taken.isEmpty)
    }

    /// Drives the real library rather than a stub, so a change in how it stores
    /// shortcuts by name shows up here rather than as a dead picker.
    @Test func clearsTheOtherProfileHoldingTheSameCombination() {
        KeyboardShortcuts.setShortcut(toggle, for: english.shortcutName)
        KeyboardShortcuts.setShortcut(toggle, for: german.shortcutName)
        defer {
            KeyboardShortcuts.setShortcut(nil, for: english.shortcutName)
            KeyboardShortcuts.setShortcut(nil, for: german.shortcutName)
        }

        HotkeyManager().claim(toggle, for: german, among: [english, german])

        #expect(KeyboardShortcuts.getShortcut(for: english.shortcutName) == nil)
        #expect(KeyboardShortcuts.getShortcut(for: german.shortcutName) == toggle)
    }

    @Test func neverTakesACombinationFromItself() {
        // Re-recording the same combination on the same profile must not clear it.
        let taken = HotkeyManager.conflicts(
            with: toggle, for: english, among: [english, german]
        ) { _ in toggle }

        #expect(taken.map(\.id) == [german.id])
    }
}
