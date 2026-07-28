import AVFoundation

protocol StreamingTranscriber: AnyObject {
    var onPartial: ((String) -> Void)? { get set }
    func begin(locale: Locale) async throws
    func feed(_ buffer: AVAudioPCMBuffer)
    func finish() async throws -> String
}

enum TranscriptionError: Error {
    case setupFailed
    case invalidFormat
    case unsupportedLocale
}
