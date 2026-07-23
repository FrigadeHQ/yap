import AppKit

/// Owns the HUD panel and its model, implementing the coordinator's HUD contract.
@MainActor
final class HUDController: HUDControlling {
    private let model = HUDModel()
    private var panel: HUDPanel?
    private var hideTask: Task<Void, Never>?

    /// Smoothed meter value. Fast attack so speech registers immediately, slower
    /// release so the bars glide back instead of snapping to zero between words.
    private var smoothedLevel: Float = 0

    func setActions(onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        model.onConfirm = onConfirm
        model.onCancel = onCancel
    }

    func show(device: String?) {
        hideTask?.cancel()
        model.device = device
        model.partial = ""
        model.level = 0
        model.phase = .listening
        smoothedLevel = 0

        if panel == nil {
            panel = HUDPanel(model: model)
        }
        panel?.reposition()
        panel?.orderFrontRegardless()
    }

    func setPhase(_ phase: HUDPhase) {
        model.phase = phase
    }

    func setLevel(_ level: Float) {
        let coefficient: Float = level > smoothedLevel ? 0.6 : 0.12
        smoothedLevel += (level - smoothedLevel) * coefficient
        model.level = smoothedLevel
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
