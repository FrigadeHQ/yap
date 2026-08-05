import AppKit
import Foundation
import KeyboardShortcuts
import Observation
import SwiftData

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    let modelContainer: ModelContainer
    let permissions = PermissionsManager()
    let launchAtLogin = LaunchAtLoginService()
    let vocabulary = VocabularyStore()

    var currentInputName: String?
    var soundsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundsEnabled, forKey: "soundsEnabled") }
    }

    var cleanupEnabled: Bool {
        didSet {
            UserDefaults.standard.set(cleanupEnabled, forKey: "cleanupEnabled")
            if cleanupEnabled { cleanup.prewarm() }
        }
    }

    var mainPage: MainPage = .settings

    var showLanguageInHUD: Bool {
        didSet { UserDefaults.standard.set(showLanguageInHUD, forKey: "showLanguageInHUD") }
    }

    var showInDock: Bool {
        didSet {
            UserDefaults.standard.set(showInDock, forKey: "showInDock")
            applyDockVisibility()
        }
    }

    private(set) var availableLocales: [Locale] = []

    /// Each profile is a language and the triggers that start dictation in it, so
    /// switching from English to German is a different key rather than a visit
    /// here. There is always at least one.
    var profiles: [DictationProfile] { profileStore.profiles }

    /// What onboarding should tell the user to press: the first profile's key
    /// combination, or whichever key it uses instead. Nil when nothing is bound.
    var firstTriggerDescription: String? {
        let profile = profiles[0]
        if let shortcut = KeyboardShortcuts.getShortcut(for: profile.shortcutName) {
            return "\(shortcut)"
        }
        if profile.modifierTrigger != .none { return profile.modifierTrigger.title }
        if profile.functionKeyTrigger != .none { return profile.functionKeyTrigger.title }
        return nil
    }

    private(set) var coordinator: RecordingCoordinator!

    private let profileStore = DictationProfileStore()
    private let hotkeys = HotkeyManager()
    private let modifierHotkeys = ModifierHotkeyMonitor()
    private let functionKeys = FunctionKeyMonitor()
    private let escapeMonitor = EscapeMonitor()
    private let injector = TextInjector()
    private let hud = HUDController()
    private let sounds = SystemSoundPlayer()
    let cleanup = TranscriptCleanupService()
    private let deviceObserver = DefaultInputObserver()
    private var history: HistoryStore!
    private var windowCloseObserver: NSObjectProtocol?
    private let dictation: DictationSession
    /// The profile the current dictation started in, which is what the HUD names.
    private var activeProfile: DictationProfile

    private init() {
        do {
            modelContainer = try ModelContainer(for: Transcript.self)
        } catch {
            fatalError("Yap: failed to create model container: \(error)")
        }

        soundsEnabled = (UserDefaults.standard.object(forKey: "soundsEnabled") as? Bool) ?? true
        showInDock = (UserDefaults.standard.object(forKey: "showInDock") as? Bool) ?? true
        showLanguageInHUD = (UserDefaults.standard.object(forKey: "showLanguageInHUD") as? Bool) ?? false
        cleanupEnabled = (UserDefaults.standard.object(forKey: "cleanupEnabled") as? Bool) ?? false
        currentInputName = AudioDevices.defaultInputName()

        // Whichever trigger fires picks the language, but something has to be
        // loaded before the first press — the first profile is the safe guess.
        activeProfile = profileStore.profiles[0]
        let dictation = DictationSession(locale: profileStore.profiles[0].locale)
        self.dictation = dictation

        let history = HistoryStore(context: modelContainer.mainContext)
        self.history = history

        sounds.enabled = { [weak self] in self?.soundsEnabled ?? true }

        coordinator = RecordingCoordinator(
            session: dictation,
            injector: injector,
            history: history,
            hud: hud,
            sounds: sounds,
            cleaner: cleanup,
            cleanupEnabled: { [weak self] in self?.cleanupEnabled ?? false },
            vocabulary: { [weak self] in self?.vocabulary.terms ?? [] },
            deviceName: { [weak self] in self?.currentInputName },
            language: { [weak self] in
                guard let self, self.showLanguageInHUD else { return nil }
                return self.activeProfile.languageTag
            }
        )

        dictation.contextualStrings = { [weak self] in self?.vocabulary.terms ?? [] }
    }

    func bootstrap() {
        applyDockVisibility()
        observeWindowClosesForDockVisibility()
        permissions.refresh()
        launchAtLogin.refresh()

        // Accessibility takes effect live — no restart needed. Observing simply
        // keeps the UI honest the moment the user grants it.
        permissions.startObserving()

        modifierHotkeys.onTap = { [weak self] id in self?.start(profile: id) }
        functionKeys.onTap = { [weak self] id in self?.start(profile: id) }
        applyProfiles()
        modifierHotkeys.start()
        functionKeys.start()

        escapeMonitor.onEscape = { [weak self] in
            self?.coordinator.handleEscape()
        }
        escapeMonitor.start()

        // Build the HUD window up front, so the first press of the shortcut is
        // immediate rather than paying setup cost.
        hud.prepare()

        Task { [weak self] in
            let locales = await TranscriptionService.availableLocales()
            self?.availableLocales = locales.sorted {
                Self.languageName(for: $0).localizedCaseInsensitiveCompare(Self.languageName(for: $1)) == .orderedAscending
            }
        }
        if cleanupEnabled { cleanup.prewarm() }

        // Delivered on the main queue by the observer, so assign directly.
        deviceObserver.start { [weak self] name in
            self?.currentInputName = name
        }
    }

    private func applyDockVisibility() {
        NSApp.setActivationPolicy(showInDock ? .regular : .accessory)
    }

    /// Flipping the policy to `.accessory` does not drop the Dock icon while a
    /// window is still on screen, so turning off "Show in Dock" from Settings
    /// leaves the icon until the window closes. Re-assert the policy once a window
    /// closes so closing Settings actually hides it.
    private func observeWindowClosesForDockVisibility() {
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.showInDock else { return }
                self.applyDockVisibility()
            }
        }
    }

    func addProfile() {
        profileStore.add()
        applyProfiles()
    }

    func removeProfile(_ id: UUID) {
        guard let profile = profiles.first(where: { $0.id == id }) else { return }
        profileStore.remove(id)
        // Only once the store agreed to drop it — it keeps the last profile.
        if !profiles.contains(where: { $0.id == id }) { hotkeys.forget(profile) }
        applyProfiles()
    }

    func updateProfile(_ profile: DictationProfile) {
        profileStore.update(profile)
        applyProfiles()
    }

    /// The shortcut recorder saves itself, so this is only about the effect that
    /// has on the other profiles.
    func shortcutChanged(for profile: DictationProfile) {
        hotkeys.claim(profile, among: profiles)
    }

    /// Points every monitor at the current profiles and gets each language ready.
    /// Cheap enough to re-run on any edit, which keeps it the single path.
    private func applyProfiles() {
        let profiles = self.profiles
        hotkeys.bind(profiles) { [weak self] id in self?.start(profile: id) }
        modifierHotkeys.bindings = profiles.map { ($0.id, $0.modifierTrigger) }
        functionKeys.bindings = profiles.map { ($0.id, $0.functionKeyTrigger) }

        // Resolving a locale and staging its model is slow enough to be felt on the
        // first press, so every language a trigger could ask for is warmed now.
        for locale in Set(profiles.map(\.locale)) {
            Task.detached(priority: .utility) {
                await DictationSession.prewarm(locale: locale)
            }
        }
    }

    /// Starts, or stops, dictation in the profile's language. The language is only
    /// swapped when a dictation is beginning: a second press is a stop, and moving
    /// the locale mid-flight would drop the transcriber holding the audio.
    private func start(profile id: UUID) {
        guard let profile = profiles.first(where: { $0.id == id }) else { return }
        if coordinator.state == .idle {
            activeProfile = profile
            dictation.setLocale(profile.locale)
        }
        Task { await coordinator.toggle() }
    }

    static func languageName(for locale: Locale) -> String {
        Locale.current.localizedString(forIdentifier: locale.identifier(.bcp47))
            ?? locale.identifier(.bcp47)
    }

    /// The menu bar has no language of its own, so it uses the first profile's.
    func toggleRecording() {
        start(profile: profiles[0].id)
    }

    /// Manual restart escape hatch. Never runs mid-dictation — that would throw
    /// away audio the user already spoke.
    func restartApp() {
        guard coordinator.state == .idle else { return }
        hud.show(device: nil, language: nil)
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
