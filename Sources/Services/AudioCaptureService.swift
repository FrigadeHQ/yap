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
    private var configObserver: NSObjectProtocol?

    func start() throws {
        installTap()

        // Switching the default input reconfigures the engine and invalidates the
        // installed tap. Handle it explicitly rather than letting a stale,
        // half-torn-down graph keep running.
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        if let configObserver {
            NotificationCenter.default.removeObserver(configObserver)
            self.configObserver = nil
        }
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func installTap() {
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let format = input.outputFormat(forBus: 0)

        // 2048 frames ≈ 23 level updates/sec, which the meter needs to look alive.
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.onBuffer?(buffer)
            self.onLevel?(AudioLevel.normalized(from: buffer))
        }
    }

    /// Re-point the tap at the (possibly new) input and restart the engine so
    /// recording continues on the new device. Delivered on the main queue.
    private func handleConfigurationChange() {
        guard isRunning else { return }
        installTap()
        if !engine.isRunning {
            try? engine.start()
        }
    }
}
