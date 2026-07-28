import AVFoundation

@MainActor
protocol DictationSessioning: AnyObject {
    var onLevel: ((Float) -> Void)? { get set }
    var onPartial: ((String) -> Void)? { get set }
    func start() async throws
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

    /// Which engine to use and the locale to run it with. The two engines
    /// support different locale sets and neither takes `Locale.current`
    /// verbatim, so they are resolved together.
    enum Engine {
        case modern(Locale)
        case legacy(Locale)
    }

    /// Resolved once — querying supported locales is slow enough to be felt on
    /// the first keypress.
    private static var cachedEngine: Engine?

    init(locale: Locale = .current) {
        self.locale = locale
    }

    static func resolveEngine(for locale: Locale) async -> Engine {
        if let modern = await TranscriptionService.resolvedLocale(for: locale) {
            return .modern(modern)
        }
        return .legacy(LegacyTranscriptionService.resolvedLocale(for: locale) ?? locale)
    }

    static func prewarm(locale: Locale = .current) async {
        let engine = await resolveEngine(for: locale)
        cachedEngine = engine
        guard case .modern(let resolved) = engine else { return }
        await TranscriptionService.prepareModel(for: resolved)
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

        let resolved: Engine
        if let cached = Self.cachedEngine {
            resolved = cached
        } else {
            resolved = await Self.resolveEngine(for: locale)
            Self.cachedEngine = resolved
        }

        let engine: StreamingTranscriber
        let engineLocale: Locale
        switch resolved {
        case .modern(let locale):
            engine = TranscriptionService()
            engineLocale = locale
        case .legacy(let locale):
            engine = LegacyTranscriptionService()
            engineLocale = locale
        }

        engine.onPartial = { [weak self] text in
            Task { @MainActor in self?.onPartial?(text) }
        }
        transcriber = engine

        do {
            try await engine.begin(locale: engineLocale)
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
