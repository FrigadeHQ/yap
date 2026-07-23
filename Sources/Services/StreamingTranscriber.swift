import AVFoundation

/// A streaming speech-to-text engine: begin a session, feed audio buffers, then
/// finish and receive the final text. Two implementations exist — the modern
/// `SpeechAnalyzer`-based `TranscriptionService` and the `SFSpeechRecognizer`
/// fallback `LegacyTranscriptionService`.
protocol StreamingTranscriber: AnyObject {
    /// Called with the running transcript (final + in-progress) as it updates.
    var onPartial: ((String) -> Void)? { get set }
    func begin(locale: Locale) async throws
    func feed(_ buffer: AVAudioPCMBuffer)
    func finish() async throws -> String
}

enum TranscriptionError: Error {
    case setupFailed
    case invalidFormat
}
