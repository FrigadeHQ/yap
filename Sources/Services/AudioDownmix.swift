import AVFoundation

/// Collapses a multi-channel microphone buffer to a single defined mono channel.
///
/// When another app turns on voice processing (echo cancellation) on the shared
/// input — meeting recorders do this — the microphone starts delivering a
/// multi-channel buffer with no channel layout attached. Handing that straight
/// to AVAudioConverter for the analyzer's mono format makes it emit pure silence
/// (it has no layout to downmix from), so dictation records nothing while that
/// other app runs. Averaging the channels ourselves produces a defined mono
/// buffer the converter can resample normally.
enum AudioDownmix {
    /// Returns `buffer` unchanged when it is already mono; otherwise a new
    /// float32 mono buffer that is the per-sample average of every channel. Falls
    /// back to the original buffer if it isn't float data we can read.
    static func toMono(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer {
        let channels = Int(buffer.format.channelCount)
        guard channels > 1 else { return buffer }

        let frames = Int(buffer.frameLength)
        guard frames > 0,
              let source = buffer.floatChannelData,
              let monoFormat = AVAudioFormat(
                  commonFormat: .pcmFormatFloat32,
                  sampleRate: buffer.format.sampleRate,
                  channels: 1,
                  interleaved: false
              ),
              let output = AVAudioPCMBuffer(pcmFormat: monoFormat, frameCapacity: AVAudioFrameCount(frames))
        else { return buffer }

        output.frameLength = AVAudioFrameCount(frames)
        let destination = output.floatChannelData![0]

        // Non-interleaved buffers give one pointer per channel; interleaved pack
        // every channel into channel 0 with a stride, so read accordingly.
        let interleaved = buffer.format.isInterleaved
        let stride = buffer.stride
        for frame in 0..<frames {
            var sum: Float = 0
            for channel in 0..<channels {
                sum += interleaved ? source[0][frame * stride + channel] : source[channel][frame]
            }
            destination[frame] = sum / Float(channels)
        }
        return output
    }
}
