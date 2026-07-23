import AVFoundation

/// A full dictation session: microphone capture wired to a streaming transcriber.
/// Behind a protocol so the coordinator can be tested with a fake.
@MainActor
protocol DictationSessioning: AnyObject {
    var onLevel: ((Float) -> Void)? { get set }
    var onPartial: ((String) -> Void)? { get set }
    func start() async throws
    /// Stops capture and returns the final transcript.
    func stop() async throws -> String
}

@MainActor
final class DictationSession: DictationSessioning {
    var onLevel: ((Float) -> Void)?
    var onPartial: ((String) -> Void)?

    private let capture = AudioCaptureService()
    private let relay = AudioBufferRelay()
    private var transcriber: StreamingTranscriber?
    private let locale: Locale

    /// Resolved once — querying supported locales is slow enough to be felt on
    /// the first keypress.
    private static var cachedModernSupport: Bool?

    init(locale: Locale = .current) {
        self.locale = locale
    }

    /// Resolves locale support and installs the speech model ahead of time, so
    /// the first dictation doesn't pay for it.
    static func prewarm(locale: Locale = .current) async {
        let supported = await TranscriptionService.isSupported(locale: locale)
        cachedModernSupport = supported
        guard supported else { return }
        await TranscriptionService.prepareModel(for: locale)
    }

    func start() async throws {
        // Open the microphone FIRST. Preparing the speech stack takes a moment,
        // and anything said during it would otherwise be lost — which is what
        // made the first press feel laggy.
        relay.reset()
        capture.onLevel = { [weak self] level in
            Task { @MainActor in self?.onLevel?(level) }
        }
        capture.onBuffer = { [weak self] buffer in
            self?.relay.receive(buffer)
        }
        try capture.start()

        // Now bring up the transcriber and flush everything captured meanwhile.
        let supportsModern: Bool
        if let cached = Self.cachedModernSupport {
            supportsModern = cached
        } else {
            supportsModern = await TranscriptionService.isSupported(locale: locale)
            Self.cachedModernSupport = supportsModern
        }

        let engine: StreamingTranscriber = supportsModern
            ? TranscriptionService()
            : LegacyTranscriptionService()

        engine.onPartial = { [weak self] text in
            Task { @MainActor in self?.onPartial?(text) }
        }
        transcriber = engine

        do {
            try await engine.begin(locale: locale)
        } catch {
            capture.stop()
            relay.reset()
            transcriber = nil
            throw error
        }

        relay.attach { buffer in engine.feed(buffer) }
    }

    func stop() async throws -> String {
        capture.stop()
        relay.reset()
        let text = try await transcriber?.finish() ?? ""
        transcriber = nil
        return text
    }
}
