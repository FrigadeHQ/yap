import Observation

/// Observable state backing the recording HUD view.
@MainActor
@Observable
final class HUDModel {
    var phase: HUDPhase = .listening
    var level: Float = 0
    var partial: String = ""
    var device: String?

    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?
}
