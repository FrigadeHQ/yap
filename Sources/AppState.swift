import AppKit
import Foundation
import Observation
import SwiftData

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

    var mainPage: MainPage = .settings

    var modifierTrigger: ModifierTrigger {
        didSet {
            UserDefaults.standard.set(modifierTrigger.rawValue, forKey: "modifierTrigger")
            modifierHotkeys.trigger = modifierTrigger
        }
    }

    var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: "showInDock")
            applyDockVisibility()
        }
    }

    /// "system" follows the OS locale; otherwise a BCP-47 identifier.
    var dictationLanguage: String {
        didSet {
            UserDefaults.standard.set(dictationLanguage, forKey: "dictationLanguage")
            applyDictationLocale()
        }
    }

    private(set) var availableLocales: [Locale] = []

    var effectiveDictationLocale: Locale {
        dictationLanguage == Self.systemLanguage ? .current : Locale(identifier: dictationLanguage)
    }

    static let systemLanguage = "system"

    private(set) var coordinator: RecordingCoordinator!

    private let hotkeys = HotkeyManager()
    private let modifierHotkeys = ModifierHotkeyMonitor()
    private let escapeMonitor = EscapeMonitor()
    private let injector = TextInjector()
    private let hud = HUDController()
    private let sounds = SystemSoundPlayer()
    private let deviceObserver = DefaultInputObserver()
    private var history: HistoryStore!
    private let dictation: DictationSession

    private init() {
        do {
            modelContainer = try ModelContainer(for: Transcript.self)
        } catch {
            fatalError("Yap: failed to create model container: \(error)")
        }

        soundsEnabled = (UserDefaults.standard.object(forKey: "soundsEnabled") as? Bool) ?? true
        showInDock = (UserDefaults.standard.object(forKey: "showInDock") as? Bool) ?? true
        modifierTrigger = ModifierTrigger(
            rawValue: UserDefaults.standard.string(forKey: "modifierTrigger") ?? ""
        ) ?? .none
        currentInputName = AudioDevices.defaultInputName()

        let language = UserDefaults.standard.string(forKey: "dictationLanguage") ?? Self.systemLanguage
        let dictation = DictationSession(
            locale: language == Self.systemLanguage ? .current : Locale(identifier: language)
        )
        self.dictation = dictation
        dictationLanguage = language

        let history = HistoryStore(context: modelContainer.mainContext)
        self.history = history

        sounds.enabled = { [weak self] in self?.soundsEnabled ?? true }

        coordinator = RecordingCoordinator(
            session: dictation,
            injector: injector,
            history: history,
            hud: hud,
            sounds: sounds,
            deviceName: { [weak self] in self?.currentInputName }
        )
    }

    func bootstrap() {
        applyDockVisibility()
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
        let locale = effectiveDictationLocale
        Task.detached(priority: .utility) {
            await DictationSession.prewarm(locale: locale)
        }

        Task { [weak self] in
            let locales = await TranscriptionService.availableLocales()
            self?.availableLocales = locales.sorted {
                Self.languageName(for: $0).localizedCaseInsensitiveCompare(Self.languageName(for: $1)) == .orderedAscending
            }
        }

        // Delivered on the main queue by the observer, so assign directly.
        deviceObserver.start { [weak self] name in
            self?.currentInputName = name
        }
    }

    private func applyDockVisibility() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    private func applyDictationLocale() {
        let locale = effectiveDictationLocale
        dictation.setLocale(locale)
        Task.detached(priority: .utility) {
            await DictationSession.prewarm(locale: locale)
        }
    }

    static func languageName(for locale: Locale) -> String {
        Locale.current.localizedString(forIdentifier: locale.identifier(.bcp47))
            ?? locale.identifier(.bcp47)
    }

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

    /// Settings and History are pages within one window, not separate windows,
    /// so transcripts are always a click away.
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
