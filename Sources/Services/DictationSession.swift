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
    private var transcriber: StreamingTranscriber?
    private let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func start() async throws {
        // Pick the modern engine if it supports this locale; otherwise fall back.
        let engine: StreamingTranscriber
        if await TranscriptionService.isSupported(locale: locale) {
            engine = TranscriptionService()
        } else {
            engine = LegacyTranscriptionService()
        }

        engine.onPartial = { [weak self] text in
            Task { @MainActor in self?.onPartial?(text) }
        }
        transcriber = engine
        try await engine.begin(locale: locale)

        // Capture callbacks fire on the audio thread. Level hops to main for UI;
        // buffers go straight to the (thread-safe) transcriber input.
        capture.onLevel = { [weak self] level in
            Task { @MainActor in self?.onLevel?(level) }
        }
        capture.onBuffer = { buffer in
            engine.feed(buffer)
        }
        try capture.start()
    }

    func stop() async throws -> String {
        capture.stop()
        let text = try await transcriber?.finish() ?? ""
        transcriber = nil
        return text
    }
}
