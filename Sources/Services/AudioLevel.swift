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

    /// Maps an RMS amplitude (0...1) to a 0...1 meter value.
    ///
    /// Speech typically sits between -45 dB (room tone) and -10 dB (talking), so
    /// the window is tightened to that range rather than a full -60 dB sweep —
    /// otherwise everything bunches into the middle and the meter barely moves.
    /// The exponent then expands the quiet end so normal speech uses the full
    /// travel instead of hovering around half height.
    static func normalized(rms: Float) -> Float {
        let clampedRms = max(rms, 1e-7)
        let db = 20 * log10(clampedRms)
        let floor: Float = -45
        let ceiling: Float = -10
        let clamped = max(floor, min(ceiling, db))
        let linear = (clamped - floor) / (ceiling - floor)
        return pow(linear, 0.7)
    }
}
