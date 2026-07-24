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

    /// Which page the main window is showing.
    var mainPage: MainPage = .settings


    /// Optional single-modifier trigger (e.g. tap Right Shift), alongside the
    /// regular key combination.
    var modifierTrigger: ModifierTrigger {
        didSet {
            UserDefaults.standard.set(modifierTrigger.rawValue, forKey: "modifierTrigger")
            modifierHotkeys.trigger = modifierTrigger
        }
    }

    private(set) var coordinator: RecordingCoordinator!

    private let hotkeys = HotkeyManager()
    private let modifierHotkeys = ModifierHotkeyMonitor()
    private let escapeMonitor = EscapeMonitor()
    private let injector = TextInjector()
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
        modifierTrigger = ModifierTrigger(
            rawValue: UserDefaults.standard.string(forKey: "modifierTrigger") ?? ""
        ) ?? .none
        currentInputName = AudioDevices.defaultInputName()

        let history = HistoryStore(context: modelContainer.mainContext)
        self.history = history

        sounds.enabled = { [weak self] in self?.soundsEnabled ?? true }

        coordinator = RecordingCoordinator(
            session: DictationSession(locale: .current),
            injector: injector,
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

        modifierHotkeys.onTap = { [weak self] in
            guard let self else { return }
            Task { await self.coordinator.toggle() }
        }
        modifierHotkeys.trigger = modifierTrigger
        modifierHotkeys.start()

        escapeMonitor.onEscape = { [weak self] in
            self?.coordinator.handleEscape()
        }
        escapeMonitor.start()

        // Build the HUD window and resolve the speech model up front, so the
        // first press of the shortcut is immediate rather than paying setup cost.
        hud.prepare()
        Task.detached(priority: .utility) {
            await DictationSession.prewarm()
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
            openMain(page: mainPage)
        } else {
            openOnboarding()
        }
    }

    /// The one Yap window. Settings and History are pages within it rather than
    /// separate windows, so transcripts are always a click away.
    func openMain(page: MainPage = .settings) {
        mainPage = page
        WindowManager.shared.show(
            id: "main", title: "Yap · On-device dictation",
            size: NSSize(width: 460, height: 740)
        ) {
            MainWindowView()
                .environment(self)
                .modelContainer(self.modelContainer)
        }
    }

    func openAbout() {
        WindowManager.shared.show(
            id: "about", title: "About Yap",
            size: NSSize(width: 360, height: 440), resizable: false
        ) { AboutView() }
    }

    func openOnboarding() {
        WindowManager.shared.show(
            id: "onboarding", title: "Welcome to Yap",
            size: NSSize(width: 460, height: 560), resizable: false
        ) { OnboardingView().environment(self) }
    }
}
