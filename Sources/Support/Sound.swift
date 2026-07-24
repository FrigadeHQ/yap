import AppKit

protocol SoundPlaying {
    func playStart()
    func playStop()
}

final class SystemSoundPlayer: SoundPlaying {
    /// Evaluated at call time so the setting can be toggled live.
    var enabled: () -> Bool = { true }

    // "Purr" is warm and gentle; "Pop" is a crisp finish. Deliberately avoiding
    // Tink/Basso/Sosumi/Funk, which macOS uses for alerts and errors — they make
    // a normal start-of-dictation feel like something went wrong.
    private let start = NSSound(named: NSSound.Name("Purr"))
    private let stop = NSSound(named: NSSound.Name("Glass"))

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
