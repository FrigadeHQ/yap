@preconcurrency import AVFoundation
import os

/// The mic's native tap format generally won't match the analyzer's required
/// format, so each buffer is converted.
final class BufferConverter {
    enum ConversionError: Error {
        case failedToCreateConverter
        case failedToCreateBuffer
        case conversionFailed(NSError?)
    }

    private var converter: AVAudioConverter?

    func convertBuffer(_ buffer: AVAudioPCMBuffer, to format: AVAudioFormat) throws -> AVAudioPCMBuffer {
        let inputFormat = buffer.format
        guard inputFormat != format else { return buffer }

        if converter == nil || converter?.outputFormat != format {
            converter = AVAudioConverter(from: inputFormat, to: format)
            converter?.primeMethod = .none
        }
        guard let converter else { throw ConversionError.failedToCreateConverter }

        let ratio = converter.outputFormat.sampleRate / converter.inputFormat.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up))
        guard let output = AVAudioPCMBuffer(pcmFormat: converter.outputFormat, frameCapacity: capacity) else {
            throw ConversionError.failedToCreateBuffer
        }

        var nsError: NSError?
        let consumed = OSAllocatedUnfairLock(initialState: false)
        let status = converter.convert(to: output, error: &nsError) { _, statusPtr in
            let alreadyConsumed = consumed.withLock { flag -> Bool in
                let previous = flag
                flag = true
                return previous
            }
            statusPtr.pointee = alreadyConsumed ? .noDataNow : .haveData
            return alreadyConsumed ? nil : buffer
        }

        guard status != .error else { throw ConversionError.conversionFailed(nsError) }
        return output
    }
}
