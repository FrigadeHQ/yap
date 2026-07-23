import AppKit

/// Plays short feedback cues when recording starts and stops.
protocol SoundPlaying {
    func playStart()
    func playStop()
}

/// Uses built-in macOS system sounds. Cheap, native, no bundled assets.
final class SystemSoundPlayer: SoundPlaying {
    /// Evaluated at call time so the setting can be toggled live.
    var enabled: () -> Bool = { true }

    private let start = NSSound(named: NSSound.Name("Tink"))
    private let stop = NSSound(named: NSSound.Name("Pop"))

    func playStart() {
        guard enabled() else { return }
        start?.stop()
        start?.play()
    }

    func playStop() {
        guard enabled() else { return }
        stop?.stop()
        stop?.play()
    }
}
