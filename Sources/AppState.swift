import AppKit
import Foundation
import Observation
import SwiftData

/// The app's root object. Owns the model store and every service, wires the
/// coordinator together, and registers the global hotkey and device observer.
@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    let modelContainer: ModelContainer
    let permissions = PermissionsManager()
    let launchAtLogin = LaunchAtLoginService()

    var currentInputName: String?
    var soundsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundsEnabled, forKey: "soundsEnabled") }
    }

    private(set) var coordinator: RecordingCoordinator!

    private let hotkeys = HotkeyManager()
    private let hud = HUDController()
    private let sounds = SystemSoundPlayer()
    private let deviceObserver = DefaultInputObserver()
    private var history: HistoryStore!

    private init() {
        do {
            modelContainer = try ModelContainer(for: Transcript.self)
        } catch {
            fatalError("Yap: failed to create model container: \(error)")
        }

        soundsEnabled = (UserDefaults.standard.object(forKey: "soundsEnabled") as? Bool) ?? true
        currentInputName = AudioDevices.defaultInputName()

        let history = HistoryStore(context: modelContainer.mainContext)
        self.history = history

        sounds.enabled = { [weak self] in self?.soundsEnabled ?? true }

        coordinator = RecordingCoordinator(
            session: DictationSession(locale: .current),
            injector: TextInjector(),
            history: history,
            hud: hud,
            sounds: sounds,
            deviceName: { [weak self] in self?.currentInputName }
        )
    }

    /// Called once after launch to start observers and register the hotkey.
    func bootstrap() {
        permissions.refresh()
        launchAtLogin.refresh()

        permissions.onAccessibilityGranted = { [weak self] in
            guard let self, self.permissions.needsRestartForAccessibility else { return }
            self.restartForAccessibility()
        }
        permissions.startObserving()

        hotkeys.onToggle { [weak self] in
            guard let self else { return }
            Task { await self.coordinator.toggle() }
        }

        deviceObserver.start { [weak self] name in
            Task { @MainActor in self?.currentInputName = name }
        }
    }

    /// Toggles recording (used by the menu Start/Stop button).
    func toggleRecording() {
        Task { await coordinator.toggle() }
    }

    /// Relaunches so newly granted Accessibility rights take effect. Skipped
    /// while a dictation is in flight so the user is never cut off mid-sentence
    /// — the Settings and onboarding screens offer a manual restart in that case.
    func restartForAccessibility() {
        guard coordinator.state == .idle else { return }
        hud.show(device: nil)
        hud.setPhase(.restarting)
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            AppRelauncher.relaunch()
        }
    }
}
