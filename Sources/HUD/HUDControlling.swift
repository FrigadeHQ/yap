import Foundation

/// What the recording HUD is currently showing. Deliberately minimal: the HUD
/// appears while listening, briefly acknowledges that it's transcribing, then
/// disappears. There is no success/failure state — a result the user can see
/// land in their text field doesn't need announcing.
enum HUDPhase: Equatable {
    case listening
    case transcribing
    /// Relaunching to pick up newly granted Accessibility rights.
    case restarting
}

/// Drives the floating recording HUD. Behind a protocol so the coordinator can
/// be tested without a real window.
@MainActor
protocol HUDControlling: AnyObject {
    func show(device: String?)
    func setPhase(_ phase: HUDPhase)
    func setLevel(_ level: Float)
    func setPartial(_ text: String)
    func hide(after seconds: Double)
    /// Wires the HUD's confirm (✓) and cancel (✕) buttons.
    func setActions(onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void)
}
