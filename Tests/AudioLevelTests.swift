import Testing
@testable import Yap

struct AudioLevelTests {
    @Test func silenceIsZero() {
        #expect(AudioLevel.normalized(rms: 0) == 0)
    }

    @Test func fullScaleIsOne() {
        #expect(AudioLevel.normalized(rms: 1) == 1)
    }

    @Test func isMonotonicAndBounded() {
        let quiet = AudioLevel.normalized(rms: 0.01)
        let mid = AudioLevel.normalized(rms: 0.1)
        let loud = AudioLevel.normalized(rms: 0.5)
        #expect(quiet < mid)
        #expect(mid < loud)
        for value in [quiet, mid, loud] {
            #expect(value >= 0 && value <= 1)
        }
    }

    @Test func flooredBelowNoiseFloor() {
        // Anything below the -45 dB floor reads as silence.
        #expect(AudioLevel.normalized(rms: 0.0001) == 0)
    }

    @Test func speechRangeUsesMostOfTheTravel() {
        // Quiet speech (~-30 dB) and loud speech (~-14 dB) should be far apart,
        // otherwise the meter looks static while talking.
        let quietSpeech = AudioLevel.normalized(rms: 0.0316) // -30 dB
        let loudSpeech = AudioLevel.normalized(rms: 0.2)     // -14 dB
        #expect(loudSpeech - quietSpeech > 0.3)
    }
}
