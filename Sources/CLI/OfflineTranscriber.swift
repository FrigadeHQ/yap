import AVFoundation
import Foundation
import Speech

enum OfflineTranscriptionError: LocalizedError {
    case unavailable
    case unsupportedLocale(String)
    case modelNotInstalled(String)
    case modelReservationFailed(String, Error)
    case invalidAudioFormat
    case microphonePermissionDenied

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Apple's on-device SpeechTranscriber is unavailable on this Mac"
        case .unsupportedLocale(let identifier):
            return "SpeechTranscriber does not support locale '\(identifier)'"
        case .modelNotInstalled(let identifier):
            return """
            the on-device model for '\(identifier)' is not installed; install that \
            dictation language in macOS first, then run 'yap locales'
            """
        case .modelReservationFailed(let identifier, let error):
            return "could not reserve the installed '\(identifier)' model: \(error.localizedDescription)"
        case .invalidAudioFormat:
            return "the installed speech model does not accept the microphone's audio format"
        case .microphonePermissionDenied:
            return "microphone access was denied; allow access in System Settings > Privacy & Security > Microphone"
        }
    }
}

enum OfflineTranscriber {
    static func installedLocaleIdentifiers() async -> [String] {
        guard SpeechTranscriber.isAvailable else { return [] }
        return await SpeechTranscriber.installedLocales
            .map(bcp47Identifier)
            .sorted()
    }

    static func transcribeFile(
        at url: URL,
        localeIdentifier: String?
    ) async throws -> String {
        let locale = try await resolveInstalledLocale(localeIdentifier)
        let audioFile = try AVAudioFile(forReading: url)
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let resultsTask = collectResults(from: transcriber)

        do {
            let lastSampleTime = try await analyzer.analyzeSequence(from: audioFile)
            if let lastSampleTime {
                try await analyzer.finalizeAndFinish(through: lastSampleTime)
            } else {
                await analyzer.cancelAndFinishNow()
            }
            return try await resultsTask.value
        } catch {
            await analyzer.cancelAndFinishNow()
            resultsTask.cancel()
            _ = try? await resultsTask.value
            throw error
        }
    }

    static func record(
        localeIdentifier: String?,
        onReady: (String) -> Void,
        waitUntilStop: () async -> Void
    ) async throws -> String {
        try await requireMicrophoneAccess()

        let locale = try await resolveInstalledLocale(localeIdentifier)
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        guard let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(
            compatibleWith: [transcriber]
        ) else {
            throw OfflineTranscriptionError.invalidAudioFormat
        }

        let (inputs, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        let resultsTask = collectResults(from: transcriber)
        try await analyzer.start(inputSequence: inputs)

        let converter = BufferConverter()
        let capture = AudioCaptureService()
        capture.onBuffer = { buffer in
            guard let converted = try? converter.convertBuffer(buffer, to: analyzerFormat) else {
                return
            }
            continuation.yield(AnalyzerInput(buffer: converted))
        }

        do {
            try capture.start()
        } catch {
            continuation.finish()
            await analyzer.cancelAndFinishNow()
            resultsTask.cancel()
            _ = try? await resultsTask.value
            throw error
        }

        onReady(bcp47Identifier(locale))
        await waitUntilStop()

        capture.stop()
        continuation.finish()

        do {
            try await analyzer.finalizeAndFinishThroughEndOfInput()
            return try await resultsTask.value
        } catch {
            await analyzer.cancelAndFinishNow()
            resultsTask.cancel()
            _ = try? await resultsTask.value
            throw error
        }
    }

    private static func resolveInstalledLocale(_ identifier: String?) async throws -> Locale {
        guard SpeechTranscriber.isAvailable else {
            throw OfflineTranscriptionError.unavailable
        }

        let requested = identifier.map(Locale.init(identifier:)) ?? .current
        guard let supported = await SpeechTranscriber.supportedLocale(equivalentTo: requested) else {
            throw OfflineTranscriptionError.unsupportedLocale(
                identifier ?? bcp47Identifier(requested)
            )
        }

        let supportedIdentifier = bcp47Identifier(supported)
        let installed = await SpeechTranscriber.installedLocales
        guard let locale = installed.first(where: {
            bcp47Identifier($0).caseInsensitiveCompare(supportedIdentifier) == .orderedSame
        }) else {
            throw OfflineTranscriptionError.modelNotInstalled(supportedIdentifier)
        }

        let reserved = await AssetInventory.reservedLocales
        if !reserved.contains(where: {
            bcp47Identifier($0).caseInsensitiveCompare(supportedIdentifier) == .orderedSame
        }) {
            do {
                try await AssetInventory.reserve(locale: locale)
            } catch {
                throw OfflineTranscriptionError.modelReservationFailed(
                    supportedIdentifier,
                    error
                )
            }
        }

        let probe = SpeechTranscriber(locale: locale, preset: .transcription)
        guard await AssetInventory.status(forModules: [probe]) == .installed else {
            throw OfflineTranscriptionError.modelNotInstalled(supportedIdentifier)
        }

        return locale
    }

    private static func collectResults(
        from transcriber: SpeechTranscriber
    ) -> Task<String, Error> {
        Task {
            var finalized = ""
            var volatile = ""

            for try await result in transcriber.results {
                let text = String(result.text.characters)
                if result.isFinal {
                    finalized += text
                    volatile = ""
                } else {
                    volatile = text
                }
            }

            return (finalized + volatile)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private static func requireMicrophoneAccess() async throws {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return
        case .notDetermined:
            guard await AVCaptureDevice.requestAccess(for: .audio) else {
                throw OfflineTranscriptionError.microphonePermissionDenied
            }
        default:
            throw OfflineTranscriptionError.microphonePermissionDenied
        }
    }

    private static func bcp47Identifier(_ locale: Locale) -> String {
        locale.identifier(.bcp47)
    }
}
