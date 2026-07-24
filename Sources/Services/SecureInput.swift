import AppKit
import Carbon
import IOKit

/// Detects Secure Event Input, which blocks synthetic keystrokes system-wide —
/// while held, an injected ⌘V silently vanishes.
enum SecureInput {
    static var isEnabled: Bool {
        IsSecureEventInputEnabled()
    }

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

    /// The reported pid can be wrong when secure input was enabled by a
    /// background process, so treat the name as a hint.
    static func holderName() -> String? {
        guard let pid = holderPID() else { return nil }
        return NSRunningApplication(processIdentifier: pid)?.localizedName ?? "pid \(pid)"
    }
}
