import AVFoundation

/// Pure audio-level math for the HUD meter. Kept free of state so it can be
/// unit-tested without an audio device.
enum AudioLevel {
    /// Normalized 0...1 level for a buffer, from RMS mapped to dBFS with a -60 dB floor.
    static func normalized(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }

        let samples = channelData[0]
        var sumSquares: Float = 0
        for i in 0..<frames {
            let sample = samples[i]
            sumSquares += sample * sample
        }
        let rms = (sumSquares / Float(frames)).squareRoot()
        return normalized(rms: rms)
    }

    /// Maps an RMS amplitude (0...1) to a 0...1 meter value via dBFS with a -60 dB floor.
    static func normalized(rms: Float) -> Float {
        let clampedRms = max(rms, 1e-7)
        let db = 20 * log10(clampedRms)
        let floored = max(-60, min(0, db))
        return (floored + 60) / 60
    }
}
