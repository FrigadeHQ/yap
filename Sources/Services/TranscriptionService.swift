import Speech
import AVFoundation

final class TranscriptionService: StreamingTranscriber {
    var onPartial: ((String) -> Void)?

    private var transcriber: SpeechTranscriber?
    private var analyzer: SpeechAnalyzer?
    private var inputBuilder: AsyncStream<AnalyzerInput>.Continuation?
    private var recognizerTask: Task<Void, Never>?
    private let converter = BufferConverter()
    private var analyzerFormat: AVAudioFormat?
    private var finalized = ""

    /// The supported locale to transcribe `locale` with, or nil if this engine
    /// covers none of it. The returned locale is what must be handed to
    /// `SpeechTranscriber` — `locale` itself may carry extensions it rejects.
    static func resolvedLocale(for locale: Locale) async -> Locale? {
        SpeechLocale.bestMatch(for: locale, in: await SpeechTranscriber.supportedLocales)
    }

    static func isSupported(locale: Locale) async -> Bool {
        await resolvedLocale(for: locale) != nil
    }

    func begin(locale: Locale) async throws {
        finalized = ""

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        self.transcriber = transcriber

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer

        try await Self.ensureModel(for: transcriber, locale: locale)

        guard let format = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [transcriber]) else {
            throw TranscriptionError.invalidFormat
        }
        analyzerFormat = format

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        inputBuilder = continuation

        recognizerTask = Task { [weak self] in
            guard let self, let transcriber = self.transcriber else { return }
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    if result.isFinal {
                        self.finalized += text
                        let snapshot = self.finalized
                        await MainActor.run { self.onPartial?(snapshot) }
                    } else {
                        let snapshot = self.finalized + text
                        await MainActor.run { self.onPartial?(snapshot) }
                    }
                }
            } catch {
            }
        }

        try await analyzer.start(inputSequence: stream)
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        guard let analyzerFormat, let inputBuilder else { return }
        do {
            let converted = try converter.convertBuffer(buffer, to: analyzerFormat)
            inputBuilder.yield(AnalyzerInput(buffer: converted))
        } catch {
            // Drop this buffer if conversion fails; the next one will try again.
        }
    }

    func finish() async throws -> String {
        inputBuilder?.finish()
        try? await analyzer?.finalizeAndFinishThroughEndOfInput()
        recognizerTask?.cancel()
        recognizerTask = nil

        let result = finalized.trimmingCharacters(in: .whitespacesAndNewlines)
        transcriber = nil
        analyzer = nil
        inputBuilder = nil
        analyzerFormat = nil
        return result
    }

    /// Reserve the model ahead of time at launch so the first dictation isn't held up by it.
    static func prepareModel(for locale: Locale) async {
        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        try? await ensureModel(for: transcriber, locale: locale)
    }

    private static func ensureModel(for transcriber: SpeechTranscriber, locale: Locale) async throws {
        let installedLocales = await SpeechTranscriber.installedLocales
        let installed = Set(installedLocales.map { $0.identifier(.bcp47) })

        if !installed.contains(locale.identifier(.bcp47)) {
            if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
                try await request.downloadAndInstall()
            }
        }

        let reserved = await AssetInventory.reservedLocales
        if !reserved.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
            do {
                try await AssetInventory.reserve(locale: locale)
            } catch {
                NSLog("Yap: could not reserve locale \(locale.identifier): \(error.localizedDescription)")
            }
        }
    }
}
