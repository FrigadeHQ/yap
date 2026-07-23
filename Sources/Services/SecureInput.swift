import AppKit
import Carbon
import IOKit

/// Detects Secure Event Input, which blocks synthetic keystrokes system-wide.
///
/// While any process holds it (a password field, a stuck login window), an
/// injected ⌘V silently vanishes. Worth naming the culprit rather than letting
/// the user think Yap is broken.
enum SecureInput {
    static var isEnabled: Bool {
        IsSecureEventInputEnabled()
    }

    /// The process currently holding secure input, if it can be determined.
    static func holderPID() -> pid_t? {
        guard isEnabled else { return nil }

        // The property lives on the registry root — not under IOResources, as
        // most write-ups claim.
        let root = IORegistryGetRootEntry(kIOMainPortDefault)
        guard root != 0 else { return nil }
        defer { IOObjectRelease(root) }

        guard let property = IORegistryEntryCreateCFProperty(
            root, "IOConsoleUsers" as CFString, kCFAllocatorDefault, 0
        )?.takeRetainedValue(), let sessions = property as? [[String: Any]] else {
            return nil
        }

        for session in sessions {
            if let pid = session["kCGSSessionSecureInputPID"] as? Int, pid != 0 {
                return pid_t(pid)
            }
        }
        return nil
    }

    /// Best-effort name of the blocking app. The reported pid can be wrong when
    /// secure input was enabled by a background process, so treat it as a hint.
    static func holderName() -> String? {
        guard let pid = holderPID() else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)"
    }
}
