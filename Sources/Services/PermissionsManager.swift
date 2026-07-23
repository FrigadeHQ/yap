import AppKit
import AVFoundation
import Speech
import ApplicationServices
import Observation

/// Tracks and requests the three permissions Yap needs: microphone, speech
/// recognition, and accessibility (for pasting into other apps).
@MainActor
@Observable
final class PermissionsManager {
    enum Status: Equatable {
        case granted, denied, notDetermined
    }

    var microphone: Status = .notDetermined
    var speech: Status = .notDetermined
    var accessibility: Bool = false

    /// Whether we were already trusted when this process started. Accessibility
    /// rights granted *after* launch don't reliably apply to the running
    /// process, so a grant that arrives later means we need to relaunch.
    private let trustedAtLaunch: Bool = AXIsProcessTrusted()

    /// True once Accessibility is granted but only after we launched untrusted.
    var needsRestartForAccessibility: Bool {
        accessibility && !trustedAtLaunch
    }

    /// Called when Accessibility flips from denied to granted while running.
    var onAccessibilityGranted: (() -> Void)?

    private var pollTimer: Timer?

    var allGranted: Bool {
        microphone == .granted && speech == .granted && accessibility
    }

    func refresh() {
        microphone = Self.map(AVCaptureDevice.authorizationStatus(for: .audio))
        speech = Self.map(SFSpeechRecognizer.authorizationStatus())
        accessibility = AXIsProcessTrusted()
    }

    /// Watches for Accessibility being granted in System Settings while we run.
    /// Uses the system's accessibility-change notification, backed by a slow
    /// poll because that notification is undocumented and can be missed.
    func startObserving() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // The notification can arrive marginally before the trust flips.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.refreshAndNotify()
            }
        }

        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshAndNotify() }
        }
    }

    private func refreshAndNotify() {
        let wasGranted = accessibility
        refresh()
        guard !wasGranted, accessibility else { return }
        pollTimer?.invalidate()
        pollTimer = nil
        onAccessibilityGranted?()
    }

    func requestMicrophone() async {
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        refresh()
    }

    func requestSpeech() async {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { _ in continuation.resume() }
        }
        refresh()
    }

    /// Prompts for Accessibility and deep-links to System Settings.
    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        refresh()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private static func map(_ status: AVAuthorizationStatus) -> Status {
        switch status {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    private static func map(_ status: SFSpeechRecognizerAuthorizationStatus) -> Status {
        switch status {
        case .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
}
