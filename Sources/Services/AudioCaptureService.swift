import AVFoundation

/// macOS has no AVAudioSession — routing is handled by Core Audio, so we just
/// tap the input node.
final class AudioCaptureService {
    /// Called on the audio thread for each captured buffer.
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    /// Called on the audio thread with a normalized 0...1 level.
    var onLevel: ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private(set) var isRunning = false

    func start() throws {
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let format = input.outputFormat(forBus: 0)

        // 2048 frames ≈ 23 level updates/sec, which the meter needs to look alive.
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.onBuffer?(buffer)
            self.onLevel?(AudioLevel.normalized(from: buffer))
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }
}
