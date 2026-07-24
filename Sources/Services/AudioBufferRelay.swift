import AVFoundation
import Foundation

/// Capture starts instantly, but preparing the speech analyzer takes a moment,
/// so buffers captured before a sink attaches are held here and flushed on
/// attach — otherwise the first words of a sentence are lost.
///
/// Receives on the audio thread, so all access is lock-protected.
final class AudioBufferRelay {
    private let lock = NSLock()
    private var pending: [AVAudioPCMBuffer] = []
    private var sink: ((AVAudioPCMBuffer) -> Void)?

    /// ~2048 frames each; 250 is roughly 10 seconds. A ceiling in case the
    /// transcriber never becomes ready, so we don't grow without bound.
    private let maximumPending = 250

    func receive(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        if let sink {
            lock.unlock()
            sink(buffer)
            return
        }
        if pending.count < maximumPending {
            pending.append(buffer)
        }
        lock.unlock()
    }

    func attach(_ sink: @escaping (AVAudioPCMBuffer) -> Void) {
        lock.lock()
        let buffered = pending
        pending.removeAll()
        self.sink = sink
        lock.unlock()

        for buffer in buffered {
            sink(buffer)
        }
    }

    func reset() {
        lock.lock()
        sink = nil
        pending.removeAll()
        lock.unlock()
    }
}
