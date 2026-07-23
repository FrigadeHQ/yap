import Testing
@testable import Yap

// MARK: - Fakes

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
    func deliver(_ text: String) -> InjectionOutcome {
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
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?

    func show(device: String?) { shown += 1 }
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
private func makeCoordinator(
    session: FakeSession? = nil,
    injector: FakeInjector? = nil,
    history: FakeHistory? = nil,
    hud: FakeHUD? = nil
) -> RecordingCoordinator {
    RecordingCoordinator(
        session: session ?? FakeSession(),
        injector: injector ?? FakeInjector(),
        history: history ?? FakeHistory(),
        hud: hud ?? FakeHUD(),
        sounds: FakeSounds(),
        deviceName: { "Test Mic" }
    )
}

// MARK: - Tests

@MainActor
struct RecordingCoordinatorTests {
    @Test func startsIdle() {
        let coordinator = makeCoordinator()
        #expect(coordinator.state == .idle)
    }

    @Test func toggleStartsRecording() async {
        let session = FakeSession()
        let coordinator = makeCoordinator(session: session)
        await coordinator.toggle()
        #expect(coordinator.state == .recording)
        #expect(session.startCalled == 1)
    }

    @Test func fullCycleInsertsAndSaves() async {
        let session = FakeSession()
        let injector = FakeInjector()
        let history = FakeHistory()
        let coordinator = makeCoordinator(session: session, injector: injector, history: history)

        await coordinator.toggle() // start
        await coordinator.toggle() // stop

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

        await coordinator.toggle() // start
        await coordinator.cancel()

        #expect(coordinator.state == .idle)
        #expect(session.stopCalled == 1) // capture is still torn down
        #expect(injector.delivered.isEmpty)
        #expect(history.saved.isEmpty)
    }

    @Test func cancelIsIgnoredWhenNotRecording() async {
        let session = FakeSession()
        let coordinator = makeCoordinator(session: session)

        await coordinator.cancel()

        #expect(coordinator.state == .idle)
        #expect(session.stopCalled == 0)
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
