import Foundation

enum HUDPhase: Equatable {
    case listening
    case confirmCancel
    case transcribing
    // Running the transcript through the on-device cleanup model.
    case cleaning
    // Relaunching to pick up newly granted Accessibility rights.
    case restarting
}

// Behind a protocol so the coordinator can be tested without a real window.
@MainActor
protocol HUDControlling: AnyObject {
    func show(device: String?)
    func setPhase(_ phase: HUDPhase)
    func setLevel(_ level: Float)
    func setPartial(_ text: String)
    func hide(after seconds: Double)
    func setActions(onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void)
}
