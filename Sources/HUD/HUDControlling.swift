import Foundation

/// What the recording HUD is currently showing.
enum HUDPhase: Equatable {
    case listening
    case transcribing
    /// Finished. `inserted` is true if text was pasted, false if left on the
    /// clipboard or nothing was captured.
    case done(inserted: Bool)
    /// Nothing was heard.
    case empty
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
}
