import AppKit
import Foundation
import Testing
@testable import Yap

struct ModifierTapRecognizerTests {
    private let english = UUID()
    private let german = UUID()

    private func recognizer(
        _ bindings: [(id: UUID, trigger: ModifierTrigger)]
    ) -> ModifierTapRecognizer {
        var recognizer = ModifierTapRecognizer()
        recognizer.bindings = bindings
        return recognizer
    }

    private func code(_ trigger: ModifierTrigger) -> UInt16 { trigger.keyCode! }

    private let start = Date(timeIntervalSinceReferenceDate: 0)
    private func later(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: seconds)
    }

    @Test func aCleanTapFiresItsProfile() {
        var recognizer = recognizer([(english, .rightOption)])

        #expect(recognizer.flagsChanged(keyCode: code(.rightOption), flags: .option, at: start) == nil)
        #expect(recognizer.flagsChanged(
            keyCode: code(.rightOption), flags: [], at: later(0.1)
        ) == english)
    }

    @Test func holdingPastTheTapWindowDoesNotFire() {
        // A long hold is someone typing a capital letter, not reaching for Yap.
        var recognizer = recognizer([(english, .rightShift)])

        _ = recognizer.flagsChanged(keyCode: code(.rightShift), flags: .shift, at: start)
        #expect(recognizer.flagsChanged(
            keyCode: code(.rightShift), flags: [], at: later(0.9)
        ) == nil)
    }

    @Test func aKeyPressDuringTheHoldDoesNotFire() {
        var recognizer = recognizer([(english, .rightShift)])

        _ = recognizer.flagsChanged(keyCode: code(.rightShift), flags: .shift, at: start)
        recognizer.interrupted()
        #expect(recognizer.flagsChanged(
            keyCode: code(.rightShift), flags: [], at: later(0.1)
        ) == nil)
    }

    @Test func anotherModifierMovingDuringTheHoldDoesNotFire() {
        var recognizer = recognizer([(english, .rightOption)])

        _ = recognizer.flagsChanged(keyCode: code(.rightOption), flags: .option, at: start)
        _ = recognizer.flagsChanged(
            keyCode: code(.leftCommand), flags: [.option, .command], at: later(0.05)
        )
        #expect(recognizer.flagsChanged(
            keyCode: code(.rightOption), flags: .command, at: later(0.1)
        ) == nil)
    }

    @Test func eachProfileFiresOnItsOwnModifier() {
        var recognizer = recognizer([(english, .rightOption), (german, .leftOption)])

        _ = recognizer.flagsChanged(keyCode: code(.rightOption), flags: .option, at: start)
        #expect(recognizer.flagsChanged(
            keyCode: code(.rightOption), flags: [], at: later(0.1)
        ) == english)

        _ = recognizer.flagsChanged(keyCode: code(.leftOption), flags: .option, at: later(1))
        #expect(recognizer.flagsChanged(
            keyCode: code(.leftOption), flags: [], at: later(1.1)
        ) == german)
    }

    @Test func holdingBothBoundModifiersFiresNeither() {
        // Left and right Option share the .option flag, so releasing one leaves the
        // flag set — the tap is not clean and neither profile should start.
        var recognizer = recognizer([(english, .rightOption), (german, .leftOption)])

        _ = recognizer.flagsChanged(keyCode: code(.rightOption), flags: .option, at: start)
        _ = recognizer.flagsChanged(keyCode: code(.leftOption), flags: .option, at: later(0.05))
        #expect(recognizer.flagsChanged(
            keyCode: code(.leftOption), flags: .option, at: later(0.1)
        ) == nil)
        #expect(recognizer.flagsChanged(
            keyCode: code(.rightOption), flags: [], at: later(0.15)
        ) == nil)
    }

    @Test func unboundModifiersNeverFire() {
        var recognizer = recognizer([(english, .rightOption)])

        _ = recognizer.flagsChanged(keyCode: code(.leftControl), flags: .control, at: start)
        #expect(recognizer.flagsChanged(
            keyCode: code(.leftControl), flags: [], at: later(0.1)
        ) == nil)
    }

    @Test func offNeverFires() {
        var recognizer = recognizer([(english, .none)])

        #expect(recognizer.flagsChanged(keyCode: 0, flags: [], at: start) == nil)
    }
}
