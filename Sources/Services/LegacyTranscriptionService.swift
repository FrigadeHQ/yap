import Speech
import AVFoundation

/// Fallback transcriber used when the modern `SpeechTranscriber` can't run
/// (Intel Macs, or a locale with no installed model). Forced on-device.
///
/// `SFSpeechRecognizer` is built for short utterances. For long continuous
/// audio its hypothesis "slides" — it keeps only a bounded window of recent
/// speech and drops earlier words — and it stops after roughly a minute.
/// Reading the latest hypothesis alone therefore loses the beginning of a long
/// dictation. Instead we accumulate finalized text and start a fresh
/// recognition request whenever the current one finalizes or nears the limit,
/// stitching the segments into one transcript.
///
/// All mutable state is confined to `queue`; the recognition callback, audio
/// feed, and finish all hop onto it, so there is a single owner of the state.
final class LegacyTranscriptionService: StreamingTranscriber {
    var onPartial: ((String) -> Void)?

    private let queue = DispatchQueue(label: "com.frigade.yap.legacy-transcriber")
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private var committed = ""
    private var current = ""
    private var finished = false
    private var segmentFrames: AVAudioFrameCount = 0

    /// Roll to a new request before SFSpeechRecognizer's ~1 minute ceiling, so a
    /// long dictation is never dropped or slid away.
    private let segmentSeconds: Double = 40

    func begin(locale: Locale) async throws {
        guard let recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer() else {
            throw TranscriptionError.setupFailed
        }
        queue.sync {
            self.recognizer = recognizer
            self.committed = ""
            self.current = ""
            self.finished = false
        }
        queue.async { self.startSegment() }
    }

    func feed(_ buffer: AVAudioPCMBuffer) {
        queue.async {
            guard !self.finished, let request = self.request else { return }
            request.append(buffer)
            self.segmentFrames += buffer.frameLength
            let rate = buffer.format.sampleRate
            if rate > 0, Double(self.segmentFrames) / rate >= self.segmentSeconds {
                self.rollSegment()
            }
        }
    }

    func finish() async throws -> String {
        queue.sync {
            finished = true
            request?.endAudio()
        }
        // Give the recognizer a moment to emit its last result.
        try? await Task.sleep(nanoseconds: 400_000_000)
        return queue.sync {
            task?.finish()
            let text = join(committed, current).trimmingCharacters(in: .whitespacesAndNewlines)
            request = nil
            task = nil
            recognizer = nil
            return text
        }
    }

    // MARK: - Private (all invoked on `queue`)

    private func startSegment() {
        guard let recognizer, !finished else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request
        current = ""
        segmentFrames = 0

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            self.queue.async {
                if let result {
                    self.current = result.bestTranscription.formattedString
                    self.onPartial?(self.join(self.committed, self.current))
                    if result.isFinal { self.commitAndContinue() }
                } else if error != nil {
                    // The segment ended (limit reached, or an error). Keep what we
                    // have and roll into a fresh request.
                    self.commitAndContinue()
                }
            }
        }
    }

    /// Finalize the current request. Its final result triggers `commitAndContinue`.
    private func rollSegment() {
        guard !finished else { return }
        request?.endAudio()
    }

    private func commitAndContinue() {
        let segment = current.trimmingCharacters(in: .whitespacesAndNewlines)
        if !segment.isEmpty {
            committed = join(committed, segment)
        }
        current = ""
        if !finished {
            startSegment()
        }
    }

    private func join(_ a: String, _ b: String) -> String {
        if a.isEmpty { return b }
        if b.isEmpty { return a }
        return a + " " + b
    }
}
