import os

/// Latency logging for the press-to-HUD path. Read it with:
/// log stream --predicate 'subsystem == "com.frigade.Yap" AND category == "timing"'
enum Timing {
    static let log = Logger(subsystem: "com.frigade.Yap", category: "timing")

    static func ms(_ duration: Duration) -> Int {
        let (seconds, attoseconds) = duration.components
        return Int(seconds * 1000 + attoseconds / 1_000_000_000_000_000)
    }
}
