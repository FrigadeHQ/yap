import CoreGraphics
import Carbon.HIToolbox
import Testing
@testable import Yap

struct FunctionKeyTriggerTests {
    @Test func firesOnBareMatchingKey() {
        #expect(FunctionKeyTrigger.shouldFire(
            trigger: .f6, keyCode: Int64(kVK_F6), flags: [], isRepeat: false
        ))
    }

    @Test func dictationMatchesBothItsKeycodes() {
        #expect(FunctionKeyTrigger.shouldFire(
            trigger: .dictation, keyCode: Int64(kVK_F5), flags: [], isRepeat: false
        ))
        #expect(FunctionKeyTrigger.shouldFire(
            trigger: .dictation, keyCode: 176, flags: [], isRepeat: false
        ))
    }

    @Test func ignoresOtherKeys() {
        #expect(!FunctionKeyTrigger.shouldFire(
            trigger: .dictation, keyCode: Int64(kVK_F6), flags: [], isRepeat: false
        ))
    }

    @Test func passesThroughModifierCombos() {
        // ⌘F5 is VoiceOver — a bound dictation key must not eat it.
        #expect(!FunctionKeyTrigger.shouldFire(
            trigger: .dictation, keyCode: Int64(kVK_F5), flags: .maskCommand, isRepeat: false
        ))
        #expect(!FunctionKeyTrigger.shouldFire(
            trigger: .f1, keyCode: Int64(kVK_F1), flags: .maskShift, isRepeat: false
        ))
    }

    @Test func allowsTheFnFlag() {
        // Holding fn is how F-keys are typed at all when the row is in media
        // mode; it must not disqualify the press.
        #expect(FunctionKeyTrigger.shouldFire(
            trigger: .f6, keyCode: Int64(kVK_F6), flags: .maskSecondaryFn, isRepeat: false
        ))
    }

    @Test func ignoresAutoRepeat() {
        #expect(!FunctionKeyTrigger.shouldFire(
            trigger: .f6, keyCode: Int64(kVK_F6), flags: [], isRepeat: true
        ))
    }

    @Test func offNeverFires() {
        #expect(!FunctionKeyTrigger.shouldFire(
            trigger: .none, keyCode: Int64(kVK_F5), flags: [], isRepeat: false
        ))
    }
}
