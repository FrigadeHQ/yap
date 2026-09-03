import Testing
@testable import Yap

@MainActor
final class FakeSession: DictationSessioning {
    var onLevel: ((Float) -> Void)?
    var onPartial: ((String) -> Void)?
    var textToReturn = "hello world"
    var startCalled = 0
    var stopCalled = 0

    func start() async throws { startCalled += 1 }
    func stop() async throws -> String { stopCalled += 1; return textToReturn }
}

@MainActor
final class FakeInjector: TextInjecting {
    var outcome: InjectionOutcome = .pasted
    var delivered: [String] = []
    var targetCaptures = 0

    func captureTarget() { targetCaptures += 1 }
    func deliver(_ text: String) async -> InjectionOutcome {
        delivered.append(text)
        return outcome
    }
}

@MainActor
final class FakeHistory: HistoryStoring {
    var saved: [String] = []
    func save(text: String, duration: Double?, device: String?) { saved.append(text) }
}

@MainActor
final class FakeHUD: HUDControlling {
    var phases: [HUDPhase] = []
    var shown = 0
    var hidden = 0
    var languages: [String?] = []
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?

    func show(device: String?, language: String?) {
        shown += 1
        languages.append(language)
    }
    func setPhase(_ phase: HUDPhase) { phases.append(phase) }
    func setLevel(_ level: Float) {}
    func setPartial(_ text: String) {}
    func hide(after seconds: Double) { hidden += 1 }
    func setActions(onConfirm: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.onConfirm = onConfirm
        self.onCancel = onCancel
    }
}

final class FakeSounds: SoundPlaying {
    func playStart() {}
    func playStop() {}
}

@MainActor
final class FakeCleaner: TranscriptCleaning {
    var isAvailable = true
    var transform: (String) -> String = { $0 }
    var cleaned: [String] = []

    func process(_ text: String, cleanup: Bool, vocabulary: [String]) async -> String {
        cleaned.append(text)
        return transform(text)
    }
}

@MainActor
private func makeCoordinator(
    session: FakeSession? = nil,
    injector: FakeInjector? = nil,
    history: FakeHistory? = nil,
    hud: FakeHUD? = nil,
    cleaner: FakeCleaner? = nil,
    cleanupEnabled: Bool = false,
    vocabulary: [String] = [],
    language: String? = nil
) -> RecordingCoordinator {
    RecordingCoordinator(
        session: session ?? FakeSession(),
        injector: injector ?? FakeInjector(),
        history: history ?? FakeHistory(),
        hud: hud ?? FakeHUD(),
        sounds: FakeSounds(),
        cleaner: cleaner ?? FakeCleaner(),
        cleanupEnabled: { cleanupEnabled },
        vocabulary: { vocabulary },
        deviceName: { "Test Mic" },
        language: { language }
    )
}

@MainActor
struct RecordingCoordinatorTests {
    @Test func startsIdle() {
        let coordinator = makeCoordinator()
        #expect(coordinator.state == .idle)
    }

    @Test func handsTheHUDTheLanguageItIsListeningIn() async {
        let hud = FakeHUD()
        let coordinator = makeCoordinator(hud: hud, language: "DE")
        await coordinator.toggle()
        #expect(hud.languages == ["DE"])
    }

    @Test func leavesTheLanguageOffTheHUDWhenItIsTurnedOff() async {
        let hud = FakeHUD()
        let coordinator = makeCoordinator(hud: hud, language: nil)
        await coordinator.toggle()
        #expect(hud.languages == [nil])
    }

    @Test func toggleStartsRecording() async {
        let session = FakeSession()
        let coordinator = makeCoordinator(session: session)
        await coordinator.toggle()
        #expect(coordinator.state == .recording)
        #expect(session.startCalled == 1)
    }

    @Test func capturesTargetAppBeforeShowingAnyUI() async {
        let injector = FakeInjector()
        let hud = FakeHUD()
        let coordinator = makeCoordinator(injector: injector, hud: hud)

        await coordinator.toggle()

        // Must happen on start, not at insert time, or the HUD could be mistaken
        // for the target.
        #expect(injector.targetCaptures == 1)
        #expect(hud.shown == 1)
    }

    @Test func fullCycleInsertsAndSaves() async {
        let session = FakeSession()
        let injector = FakeInjector()
        let history = FakeHistory()
        let coordinator = makeCoordinator(session: session, injector: injector, history: history)

        await coordinator.toggle()
        await coordinator.toggle()

        #expect(coordinator.state == .idle)
        #expect(session.stopCalled == 1)
        #expect(injector.delivered == ["hello world"])
        #expect(history.saved == ["hello world"])
        #expect(coordinator.lastOutcome == .pasted)
    }

    @Test func emptyTranscriptIsNotSavedOrInserted() async {
        let session = FakeSession()
        session.textToReturn = "   \n  "
        let injector = FakeInjector()
        let history = FakeHistory()
        let coordinator = makeCoordinator(session: session, injector: injector, history: history)

        await coordinator.toggle()
        await coordinator.toggle()

        #expect(history.saved.isEmpty)
        #expect(injector.delivered.isEmpty)
        #expect(coordinator.state == .idle)
    }

    @Test func nonEditableTargetLeavesTextOnClipboard() async {
        let session = FakeSession()
        let injector = FakeInjector()
        injector.outcome = .leftOnClipboard
        let history = FakeHistory()
        let coordinator = makeCoordinator(session: session, injector: injector, history: history)

        await coordinator.toggle()
        await coordinator.toggle()

        // Still saved to history even when it couldn't be pasted.
        #expect(history.saved == ["hello world"])
        #expect(coordinator.lastOutcome == .leftOnClipboard)
    }

    @Test func cancelDiscardsWithoutInsertingOrSaving() async {
        let session = FakeSession()
        let injector = FakeInjector()
        let history = FakeHistory()
        let coordinator = makeCoordinator(session: session, injector: injector, history: history)

        await coordinator.toggle()
        await coordinator.cancel()

        #expect(coordinator.state == .idle)
        #expect(session.stopCalled == 1) // capture is still torn down
        #expect(injector.delivered.isEmpty)
        #expect(history.saved.isEmpty)
    }

    @Test func firstEscapeArmsCancelButKeepsRecording() async {
        let session = FakeSession()
        let hud = FakeHUD()
        let coordinator = makeCoordinator(session: session, hud: hud)

        await coordinator.toggle()
        coordinator.handleEscape()

        #expect(coordinator.state == .recording)
        #expect(hud.phases.contains(.confirmCancel))
        #expect(session.stopCalled == 0)
    }

    @Test func secondEscapeDiscardsTheDictation() async {
        let session = FakeSession()
        let injector = FakeInjector()
        let history = FakeHistory()
        let coordinator = makeCoordinator(session: session, injector: injector, history: history)

        await coordinator.toggle()
        coordinator.handleEscape()
        coordinator.handleEscape()

        // handleEscape spawns the cancel, so let it settle.
        try? await Task.sleep(nanoseconds: 100_000_000)

        #expect(coordinator.state == .idle)
        #expect(injector.delivered.isEmpty)
        #expect(history.saved.isEmpty)
    }

    @Test func escapeIsIgnoredWhenNotRecording() async {
        let hud = FakeHUD()
        let coordinator = makeCoordinator(hud: hud)

        coordinator.handleEscape()

        #expect(coordinator.state == .idle)
        #expect(!hud.phases.contains(.confirmCancel))
    }

    @Test func cancelIsIgnoredWhenNotRecording() async {
        let session = FakeSession()
        let coordinator = makeCoordinator(session: session)

        await coordinator.cancel()

        #expect(coordinator.state == .idle)
        #expect(session.stopCalled == 0)
    }

    @Test func cleanedTextIsInsertedAndSaved() async {
        let session = FakeSession()
        session.textToReturn = "um so hello world"
        let injector = FakeInjector()
        let history = FakeHistory()
        let hud = FakeHUD()
        let cleaner = FakeCleaner()
        cleaner.transform = { _ in "Hello world." }
        let coordinator = makeCoordinator(
            session: session, injector: injector, history: history, hud: hud,
            cleaner: cleaner, cleanupEnabled: true
        )

        await coordinator.toggle()
        await coordinator.toggle()

        // Fillers are stripped deterministically before the model sees the text.
        #expect(cleaner.cleaned == ["So hello world"])
        #expect(injector.delivered == ["Hello world."])
        #expect(history.saved == ["Hello world."])
        #expect(hud.phases.contains(.cleaning))
    }

    @Test func cleanupIsSkippedWhenDisabled() async {
        let injector = FakeInjector()
        let hud = FakeHUD()
        let cleaner = FakeCleaner()
        cleaner.transform = { _ in "should not appear" }
        let coordinator = makeCoordinator(
            injector: injector, hud: hud, cleaner: cleaner, cleanupEnabled: false
        )

        await coordinator.toggle()
        await coordinator.toggle()

        #expect(cleaner.cleaned.isEmpty)
        #expect(injector.delivered == ["hello world"])
        #expect(!hud.phases.contains(.cleaning))
    }

    @Test func cleanupIsSkippedWhenModelUnavailable() async {
        let injector = FakeInjector()
        let hud = FakeHUD()
        let cleaner = FakeCleaner()
        cleaner.isAvailable = false
        cleaner.transform = { _ in "should not appear" }
        let coordinator = makeCoordinator(
            injector: injector, hud: hud, cleaner: cleaner, cleanupEnabled: true
        )

        await coordinator.toggle()
        await coordinator.toggle()

        #expect(cleaner.cleaned.isEmpty)
        #expect(injector.delivered == ["hello world"])
        #expect(!hud.phases.contains(.cleaning))
    }

    @Test func trimsWhitespaceBeforeInserting() async {
        let session = FakeSession()
        session.textToReturn = "  padded text  "
        let injector = FakeInjector()
        let coordinator = makeCoordinator(session: session, injector: injector)

        await coordinator.toggle()
        await coordinator.toggle()

        #expect(injector.delivered == ["padded text"])
    }
}
