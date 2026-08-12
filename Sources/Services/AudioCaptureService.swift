import AVFoundation

/// macOS has no AVAudioSession, so routing is handled by Core Audio and we just
/// tap the input node.
final class AudioCaptureService {
    /// Called on the audio thread for each captured buffer.
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    /// Called on the audio thread with a normalized 0...1 level.
    var onLevel: ((Float) -> Void)?

    private var engine = AVAudioEngine()
    private(set) var isRunning = false
    private var configObserver: NSObjectProtocol?
    private var handlingConfigChange = false

    func start() throws {
        // Start from a clean slate. An observer left over from an earlier failed
        // start would otherwise stack a second listener on the same engine, so
        // several handlers would race to rebuild the graph on the next device
        // change.
        removeConfigObserver()

        // Build a new engine every time. A reused one keeps the format of the
        // device it last ran on, so installTap gets a 48 kHz format on a 16 kHz
        // Bluetooth mic and throws an Objective-C exception. Swift cannot catch
        // that, and the unwind corrupts the task state enough to crash the app.
        engine = AVAudioEngine()

        installTap()
        addConfigObserver()

        engine.prepare()
        do {
            try engine.start()
        } catch {
            // Do not leave the observer or tap behind if the engine will not run.
            removeConfigObserver()
            engine.inputNode.removeTap(onBus: 0)
            throw error
        }
        isRunning = true
    }

    func stop() {
        removeConfigObserver()
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private func installTap() {
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        let format = input.outputFormat(forBus: 0)

        // 2048 frames is about 23 level updates a second, which the meter needs
        // to look alive.
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.onBuffer?(buffer)
            self.onLevel?(AudioLevel.normalized(from: buffer))
        }
    }

    private func addConfigObserver() {
        configObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            self?.handleConfigurationChange()
        }
    }

    private func removeConfigObserver() {
        guard let configObserver else { return }
        NotificationCenter.default.removeObserver(configObserver)
        self.configObserver = nil
    }

    /// Switching the default input reconfigures the engine and invalidates the
    /// installed tap. Re-point the tap and restart so recording continues on the
    /// new device. Delivered on the main queue.
    private func handleConfigurationChange() {
        // Rebuilding the graph can itself emit another configuration change.
        // Guard against re-entering while a rebuild is already in flight, and
        // ignore changes once we have stopped.
        guard isRunning, !handlingConfigChange else { return }
        handlingConfigChange = true
        defer { handlingConfigChange = false }

        installTap()
        guard !engine.isRunning else { return }

        do {
            try engine.start()
        } catch {
            // The new device would not start. Tear down rather than leave a
            // half-running graph that looks alive but records nothing.
            NSLog("Yap: audio engine could not restart after a device change: \(error.localizedDescription)")
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isRunning = false
        }
    }
}
