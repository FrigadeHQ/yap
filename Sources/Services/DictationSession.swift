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
    private var locale: Locale

    /// The locale the on-device transcriber will actually run, resolved from the
    /// user's locale. `.unsupported` means no on-device model covers it. We stop
    /// there rather than fall back to anything that would leave the device.
    enum Resolution {
        case supported(Locale)
        case unsupported
    }

    /// Resolved once — querying supported locales is slow enough to be felt on
    /// the first keypress.
    private static var cachedResolution: Resolution?

    init(locale: Locale = .current) {
        self.locale = locale
    }

    /// Switch dictation language while idle. Clears the resolved cache so the
    /// next recording re-resolves for the new locale.
    func setLocale(_ newLocale: Locale) {
        locale = newLocale
        transcriber = nil
        Self.cachedResolution = nil
    }

    static func resolve(for locale: Locale) async -> Resolution {
        if let supported = await TranscriptionService.resolvedLocale(for: locale) {
            return .supported(supported)
        }
        return .unsupported
    }

    static func prewarm(locale: Locale = .current) async {
        let resolution = await resolve(for: locale)
        cachedResolution = resolution
        guard case .supported(let resolved) = resolution else { return }
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

        let resolution: Resolution
        if let cached = Self.cachedResolution {
            resolution = cached
        } else {
            resolution = await Self.resolve(for: locale)
            Self.cachedResolution = resolution
        }

        guard case .supported(let engineLocale) = resolution else {
            // No on-device model covers this locale. Refuse rather than hand the
            // audio to a service that would send it off the device.
            capture.stop()
            relay.reset()
            throw TranscriptionError.unsupportedLocale
        }

        let engine: StreamingTranscriber = TranscriptionService()
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
