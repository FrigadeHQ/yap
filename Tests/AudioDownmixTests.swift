import AVFoundation
import Testing
@testable import Yap

struct AudioDownmixTests {
    /// Builds a non-interleaved float buffer and fills each channel with a
    /// constant value so the average is easy to reason about.
    private func buffer(channelValues: [Float], frames: Int = 64, sampleRate: Double = 48000) -> AVAudioPCMBuffer {
        // A discrete layout, like the layout-less multi-channel stream the mic
        // delivers under another app's echo cancellation. The convenience
        // channels: initializer returns nil past 2 channels for this reason.
        let layout = AVAudioChannelLayout(
            layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | UInt32(channelValues.count)
        )!
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            interleaved: false,
            channelLayout: layout
        )
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        for (channel, value) in channelValues.enumerated() {
            let data = buffer.floatChannelData![channel]
            for frame in 0..<frames { data[frame] = value }
        }
        return buffer
    }

    private func rms(_ buffer: AVAudioPCMBuffer) -> Float {
        let data = buffer.floatChannelData![0]
        let frames = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<frames { sum += data[i] * data[i] }
        return (sum / Float(frames)).squareRoot()
    }

    @Test func monoBufferIsReturnedUnchanged() {
        let mono = buffer(channelValues: [0.3])
        let result = AudioDownmix.toMono(mono)
        #expect(result === mono)
    }

    @Test func multiChannelIsAveragedToMono() {
        // Mic audio sits only on the middle channel; the current converter path
        // zeroes a layout-less multi-channel stream, so the signal must survive
        // the downmix rather than vanish.
        let multi = buffer(channelValues: [0, 0.6, 0])
        let result = AudioDownmix.toMono(multi)

        #expect(result.format.channelCount == 1)
        #expect(result.frameLength == multi.frameLength)
        let sample = result.floatChannelData![0][0]
        #expect(abs(sample - 0.2) < 1e-6) // (0 + 0.6 + 0) / 3
        #expect(rms(result) > 0.01)       // not silent
    }

    @Test func averagesEveryChannel() {
        let multi = buffer(channelValues: [0.2, 0.4, 0.6, 0.8])
        let result = AudioDownmix.toMono(multi)
        let sample = result.floatChannelData![0][0]
        #expect(abs(sample - 0.5) < 1e-6) // mean of 0.2,0.4,0.6,0.8
    }
}
