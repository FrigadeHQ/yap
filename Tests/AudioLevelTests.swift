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

    @Test func flooredBelowMinus60dB() {
        // -60 dB ≈ rms 0.001; anything quieter floors at 0.
        #expect(AudioLevel.normalized(rms: 0.0001) == 0)
    }
}
