import Foundation

/// How the paste keystroke reaches the target app.
enum PasteMethod: String, CaseIterable, Identifiable {
    /// Synthesized ⌘V key events. Fast and needs no extra permission.
    case standard
    /// Driven through System Events. Slower and needs automation access, but
    /// works in some apps that ignore synthetic key events.
    case appleScript

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Standard"
        case .appleScript: return "AppleScript"
        }
    }

    var detail: String {
        switch self {
        case .standard: return "Synthesized ⌘V. Works in most apps."
        case .appleScript: return "Via System Events. Try this if pasting fails."
        }
    }
}
