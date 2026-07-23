import Foundation
import Observation

/// The core state machine. Ties together the dictation session, text injection,
/// history, HUD, and sounds. All system dependencies are injected as protocols
/// so this logic can be unit-tested with fakes.
@MainActor
@Observable
final class RecordingCoordinator {
    enum State: Equatable {
        case idle, recording, transcribing, inserting
    }

    private(set) var state: State = .idle
    private(set) var lastOutcome: InjectionOutcome?

    private let session: DictationSessioning
    private let injector: TextInjecting
    private let history: HistoryStoring
    private let hud: HUDControlling
    private let sounds: SoundPlaying
    private let deviceName: () -> String?

    private var startedAt: Date?

    init(
        session: DictationSessioning,
        injector: TextInjecting,
        history: HistoryStoring,
        hud: HUDControlling,
        sounds: SoundPlaying,
        deviceName: @escaping () -> String?
    ) {
        self.session = session
        self.injector = injector
        self.history = history
        self.hud = hud
        self.sounds = sounds
        self.deviceName = deviceName

        session.onLevel = { [weak self] level in self?.hud.setLevel(level) }
        session.onPartial = { [weak self] text in self?.hud.setPartial(text) }

        hud.setActions(
            onConfirm: { [weak self] in Task { await self?.toggle() } },
            onCancel: { [weak self] in Task { await self?.cancel() } }
        )
    }

    /// Discards the in-flight dictation: nothing is inserted and nothing is saved.
    func cancel() async {
        guard state == .recording else { return }
        state = .transcribing
        sounds.playStop()
        hud.hide(after: 0)
        _ = try? await session.stop()
        state = .idle
    }

    /// Called by the global hotkey (and the menu Start/Stop button).
    func toggle() async {
        switch state {
        case .idle:
            await startRecording()
        case .recording:
            await stopRecording()
        case .transcribing, .inserting:
            break // busy — ignore
        }
    }

    private func startRecording() async {
        state = .recording
        startedAt = Date()
        sounds.playStart()
        hud.show(device: deviceName())
        hud.setPhase(.listening)

        do {
            try await session.start()
        } catch {
            NSLog("Yap: failed to start recording: \(error.localizedDescription)")
            hud.hide(after: 0)
            state = .idle
        }
    }

    private func stopRecording() async {
        state = .transcribing
        sounds.playStop()
        hud.setPhase(.transcribing)

        do {
            let raw = try await session.stop()
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !text.isEmpty else {
                hud.hide(after: 0)
                state = .idle
                return
            }

            state = .inserting
            let outcome = injector.deliver(text)
            lastOutcome = outcome

            let duration = startedAt.map { Date().timeIntervalSince($0) }
            history.save(text: text, duration: duration, device: deviceName())

            hud.hide(after: 0)
        } catch {
            NSLog("Yap: failed to finish recording: \(error.localizedDescription)")
            hud.hide(after: 0)
        }
        state = .idle
    }
}
