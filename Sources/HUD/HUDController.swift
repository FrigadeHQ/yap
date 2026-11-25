import AppKit

@MainActor
final class HUDController: HUDControlling {
    private let model = HUDModel()
    private var panel: HUDPanel?
    private var hideTask: Task<Void, Never>?

    // Fast attack so speech registers immediately, slower release so bars glide back instead of snapping to zero between words.
    private var smoothedLevel: Float = 0

    func setActions(onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        model.onConfirm = onConfirm
        model.onCancel = onCancel
    }

    // Built ahead of time: creating it on first use rendered an unlaid-out window for a frame — a flicker before "Listening" appeared.
    func prepare() {
        guard panel == nil else { return }
        let panel = HUDPanel(model: model)
        panel.alphaValue = 0
        panel.reposition()
        self.panel = panel
    }

    func show(device: String?) {
        hideTask?.cancel()

        // Reset state BEFORE the panel is on screen, so no stale frame from the previous session is ever visible.
        model.device = device
        model.partial = ""
        model.level = 0
        model.levels = Array(repeating: 0, count: HUDModel.waveformSampleCount)
        model.phase = .listening
        smoothedLevel = 0

        prepare()
        guard let panel else { return }

        panel.reposition()
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        // Short fade covers any residual first-frame layout settling. It runs as
        // a Core Animation layer animation, which the render server plays on its
        // own; animating the window's alpha instead is driven from the main
        // thread, so it stalled whenever the main thread did.
        if let layer = panel.contentView?.layer {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = 0.12
            layer.add(fade, forKey: "fadeIn")
        }

        // Commit now. Starting the microphone comes next and blocks the main
        // thread for a moment; without an explicit flush the HUD would not reach
        // the screen until that finished, so it appeared late.
        panel.displayIfNeeded()
        CATransaction.flush()
    }

    func setPhase(_ phase: HUDPhase) {
        model.phase = phase
    }

    func setLevel(_ level: Float) {
        // Very fast attack keeps transients visible; gentler release lets the trace fall away instead of collapsing between syllables.
        let coefficient: Float = level > smoothedLevel ? 0.75 : 0.22
        smoothedLevel += (level - smoothedLevel) * coefficient
        model.level = smoothedLevel

        var samples = model.levels
        samples.removeFirst()
        samples.append(smoothedLevel)
        model.levels = samples
    }

    func setPartial(_ text: String) {
        model.partial = text
    }

    func hide(after seconds: Double) {
        hideTask?.cancel()
        guard seconds > 0 else {
            panel?.orderOut(nil)
            return
        }
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.panel?.orderOut(nil)
        }
    }
}
