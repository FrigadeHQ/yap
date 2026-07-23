import Speech
import AVFoundation

/// Fallback transcription using the older `SFSpeechRecognizer`, forced on-device.
/// Used when the modern `SpeechTranscriber` doesn't support the current locale or
/// its model asset can't be installed.
final class LegacyTranscriptionService: StreamingTranscriber {
    var onPartial: ((String) -> Void)?

    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latest = ""

    func begin(locale: Locale) async throws {
        latest = ""

        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer() else {
            throw TranscriptionError.setupFailed
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, let result else { return }
            self.latest = result.bestTranscription.formattedString
            self.onPartial?(self.latest)
        }
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    func finish() async throws -> String {
        request?.endAudio()
        // Give the recognizer a brief moment to emit the last result.
        try? await Task.sleep(nanoseconds: 300_000_000)
        task?.finish()

        let result = latest.trimmingCharacters(in: .whitespacesAndNewlines)
        request = nil
        task = nil
        recognizer = nil
        return result
    }
}
