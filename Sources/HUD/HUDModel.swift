import Observation

/// Observable state backing the recording HUD view.
@MainActor
@Observable
final class HUDModel {
    static let waveformSampleCount = 32

    var phase: HUDPhase = .listening
    var level: Float = 0
    /// Rolling window of recent levels, oldest first. Drawn as a scrolling
    /// waveform so the meter reads as a timeline rather than a single bouncing bar.
    var levels: [Float] = Array(repeating: 0, count: HUDModel.waveformSampleCount)
    var partial: String = ""
    var device: String?

    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?
}
