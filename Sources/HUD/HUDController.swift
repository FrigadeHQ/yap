import AppKit

/// Owns the HUD panel and its model, implementing the coordinator's HUD contract.
@MainActor
final class HUDController: HUDControlling {
    private let model = HUDModel()
    private var panel: HUDPanel?
    private var hideTask: Task<Void, Never>?

    func show(device: String?) {
        hideTask?.cancel()
        model.device = device
        model.partial = ""
        model.level = 0
        model.phase = .listening

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
        model.level = level
    }

    func setPartial(_ text: String) {
        model.partial = text
    }

    func hide(after seconds: Double) {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.panel?.orderOut(nil)
        }
    }
}
