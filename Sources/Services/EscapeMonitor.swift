import AppKit
import Carbon.HIToolbox

/// Watches for the Escape key so a dictation can be cancelled from anywhere.
/// Observes only — Escape still reaches whatever app the user is in.
@MainActor
final class EscapeMonitor {
    var onEscape: (() -> Void)?

    private var monitors: [Any] = []

    func start() {
        stop()

        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { event in
            guard event.keyCode == UInt16(kVK_Escape) else { return }
            Task { @MainActor in EscapeMonitor.deliver(event) }
        }) {
            monitors.append(global)
        }

        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            guard event.keyCode == UInt16(kVK_Escape) else { return event }
            Task { @MainActor in EscapeMonitor.deliver(event) }
            return event
        }) {
            monitors.append(local)
        }

        EscapeMonitor.current = self
    }

    func stop() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors.removeAll()
        if EscapeMonitor.current === self { EscapeMonitor.current = nil }
    }

    // The monitor closures are non-isolated, so route through a main-actor hop.
    private static weak var current: EscapeMonitor?

    private static func deliver(_ event: NSEvent) {
        current?.onEscape?()
    }
}
