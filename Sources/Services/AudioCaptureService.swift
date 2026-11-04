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
        try restart()
        isRunning = true
    }

    /// Brings a fresh engine online, tearing down any existing graph first.
    ///
    /// A reused AVAudioEngine keeps the format of the device it last ran on, so
    /// installTap can be handed a 48 kHz format on a 16 kHz Bluetooth mic and
    /// throw an Objective-C exception. Swift cannot catch that, and the unwind
    /// corrupts task state enough to crash the app on the next UI event. A fresh
    /// engine always reads the current device's format, so both a cold start and
    /// a live device switch go through here.
    private func restart() throws {
        // An observer left over from an earlier start would otherwise stack a
        // second listener, so several handlers would race to rebuild the graph
        // on the next device change.
        removeConfigObserver()
        engine.stop()
        engine = AVAudioEngine()

        addConfigObserver()

        // installTap, prepare and start can raise Objective-C exceptions from
        // AVFoundation on a bad audio state (e.g. an input format that no longer
        // matches the hardware mid device-change). Swift try cannot catch those,
        // and unhandled they corrupt the runtime and crash the app on the next
        // UI event. Catch them here, plus any Swift error from start(), and fail
        // the start cleanly so the next attempt rebuilds from scratch.
        var startError: Error?
        let raised = YapRunCatchingExceptions { [self] in
            installTap()
            engine.prepare()
            do {
                try engine.start()
            } catch {
                startError = error
            }
        }

        if let failure = raised ?? startError {
            removeConfigObserver()
            engine.inputNode.removeTap(onBus: 0)
            throw failure
        }
    }

    func stop() {
        removeConfigObserver()
        if isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            isRunning = false
        }

        // Stopping the engine halts rendering but leaves the input node's HAL
        // unit instantiated, which keeps the microphone device open. That is
        // enough to hold Bluetooth headsets in their low-quality call/recording
        // mode, degrading all system audio for as long as Yap runs after the
        // first dictation. Drop the engine so the input unit is deallocated and
        // the device released; start() builds a fresh one for the next take.
        engine = AVAudioEngine()
    }

    private func installTap() {
        let input = engine.inputNode
        input.removeTap(onBus: 0)

        // Mid-switch the node can briefly report a degenerate format (0 Hz or
        // 0 channels). Skip then and let the next configuration change rebuild
        // the tap once the device has settled.
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { return }

        // Pass nil so the tap adopts the input node's own live format. Passing
        // an explicit format can disagree with the hardware the instant a device
        // changes, and installTap throws an ObjC exception on the mismatch; the
        // buffers are converted downstream anyway, so the exact format is moot.
        // 2048 frames is about 23 level updates a second, which the meter needs
        // to look alive.
        input.installTap(onBus: 0, bufferSize: 2048, format: nil) { [weak self] buffer, _ in
            guard let self else { return }
            // Another app's echo cancellation can flip the shared mic to a
            // layout-less multi-channel stream; collapse it to a defined mono
            // buffer so the downstream converter resamples it instead of
            // emitting silence.
            let mono = AudioDownmix.toMono(buffer)
            self.onBuffer?(mono)
            self.onLevel?(AudioLevel.normalized(from: mono))
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
    /// installed tap. Rebuild on a fresh engine so recording continues on the
    /// new device without inheriting the old device's format, which is what made
    /// installTap throw and crash the app. Delivered on the main queue.
    private func handleConfigurationChange() {
        // Rebuilding the graph can itself emit another configuration change.
        // Guard against re-entering while a rebuild is already in flight, and
        // ignore changes once we have stopped.
        guard isRunning, !handlingConfigChange else { return }
        handlingConfigChange = true
        defer { handlingConfigChange = false }

        do {
            try restart()
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
