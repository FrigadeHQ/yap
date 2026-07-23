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

        // Accessibility takes effect live — no restart needed. Observing simply
        // keeps the UI honest the moment the user grants it.
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

    /// Manual restart escape hatch. Never runs mid-dictation — that would throw
    /// away audio the user already spoke.
    func restartApp() {
        guard coordinator.state == .idle else { return }
        hud.show(device: nil)
        hud.setPhase(.restarting)
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            AppRelauncher.relaunch()
        }
    }

    /// Surfaces a window when the user opens Yap from Finder/Dock. Without this,
    /// launching an already-running agent app appears to do nothing at all.
    func presentMainWindow() {
        if permissions.allGranted {
            WindowManager.shared.show(
                id: "settings", title: "Settings",
                size: NSSize(width: 460, height: 520), resizable: false
            ) { SettingsView().environment(self) }
        } else {
            WindowManager.shared.show(
                id: "onboarding", title: "Welcome to Yap",
                size: NSSize(width: 460, height: 560), resizable: false
            ) { OnboardingView().environment(self) }
        }
    }
}
