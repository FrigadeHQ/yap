import AppKit
import AVFoundation
import Speech
import ApplicationServices
import Carbon
import Observation

@MainActor
@Observable
final class PermissionsManager {
    enum Status: Equatable {
        case granted, denied, notDetermined
    }

    var microphone: Status = .notDetermined
    var speech: Status = .notDetermined
    var accessibility: Bool = false
    // Starts from the last grant we observed. System Events reports
    // "undetermined" while it isn't running, which it usually isn't at launch, so
    // without this every launch looked like a missing permission and reopened
    // the welcome window.
    var automation: Status = UserDefaults.standard.bool(forKey: automationGrantedKey) ? .granted : .notDetermined {
        didSet { UserDefaults.standard.set(automation == .granted, forKey: Self.automationGrantedKey) }
    }

    private static let automationGrantedKey = "automationGranted"
    private var pollTimer: Timer?
    private var automationCheck: Task<Void, Never>?

    var allGranted: Bool {
        essentialsGranted && automation == .granted
    }

    /// What dictation can't work without. Automation is optional: the AppleScript
    /// paste falls back to synthetic ⌘V when it's unavailable.
    var essentialsGranted: Bool {
        microphone == .granted && speech == .granted && accessibility
    }

    /// Cheap, local checks only. This runs on every app switch and on a timer,
    /// so anything that talks to another process belongs in `refreshAutomation`.
    func refresh() {
        microphone = Self.map(AVCaptureDevice.authorizationStatus(for: .audio))
        speech = Self.map(SFSpeechRecognizer.authorizationStatus())
        accessibility = AXIsProcessTrusted()
    }

    /// The Automation check sends an Apple Event to System Events and can launch
    /// it, so it runs off the main thread and only when a permissions screen is
    /// showing. It used to run on every app switch and every few seconds, on the
    /// main thread, where it could hold up the shortcut.
    func refreshAutomation() {
        guard automationCheck == nil else { return }
        automationCheck = Task { [weak self] in
            let latest = await Task.detached(priority: .utility) { () -> Status in
                Self.wakeSystemEvents()
                return Self.automationStatus(prompt: false)
            }.value
            guard let self else { return }
            self.automationCheck = nil
            // Never let a transient "undetermined" undo a grant already on file;
            // only an explicit denial should.
            if !(latest == .notDetermined && self.automation == .granted) {
                self.automation = latest
            }
        }
    }

    /// System Events launches on demand. Nudging it awake before checking keeps
    /// the reported status honest.
    private nonisolated static func wakeSystemEvents() {
        let bundleID = "com.apple.systemevents"
        guard NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        else { return }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    /// Runs off the main actor because the prompt call blocks until the user answers.
    func requestAutomation() async {
        let result = await Task.detached { () -> Status in
            // Without System Events running the call returns "not found" instead
            // of showing the prompt.
            Self.wakeSystemEvents()
            try? await Task.sleep(nanoseconds: 300_000_000)
            return Self.automationStatus(prompt: true)
        }.value
        automation = result
    }

    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    private nonisolated static func automationStatus(prompt: Bool) -> Status {
        let bundleID = "com.apple.systemevents"
        var target = AEAddressDesc()

        let created = bundleID.withCString { pointer in
            AECreateDesc(typeApplicationBundleID, pointer, strlen(pointer), &target)
        }
        guard created == noErr else { return .notDetermined }
        defer { AEDisposeDesc(&target) }

        switch AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, prompt) {
        case noErr:
            return .granted
        case OSStatus(errAEEventNotPermitted):
            return .denied
        case OSStatus(errAEEventWouldRequireUserConsent):
            return .notDetermined
        case OSStatus(procNotFound):
            // System Events isn't running yet; it launches on demand.
            return .notDetermined
        default:
            return .notDetermined
        }
    }

    /// Three signals, because none alone is dependable: the (undocumented)
    /// system accessibility-change notification for latency, app activation
    /// (Apple DTS's suggested mechanism), and a sparse poll as the backstop.
    func startObserving() {
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.accessibility.api"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // Fires slightly before the trust value actually flips.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                self?.refreshAndNotify()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshAndNotify() }
        }

        setPolling(interval: accessibility ? 5.0 : 1.0)
    }

    private func setPolling(interval: TimeInterval) {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshAndNotify() }
        }
        timer.tolerance = interval / 4
        // .common so it keeps firing while a menu is being tracked.
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func refreshAndNotify() {
        let wasGranted = accessibility
        refresh()
        guard wasGranted != accessibility else { return }
        // Back off once granted; poll attentively while we're still waiting.
        setPolling(interval: accessibility ? 5.0 : 1.0)
    }

    /// Ad-hoc signed builds have no stable designated requirement, so every
    /// rebuild looks like a different app to TCC. The tell-tale symptom is the
    /// checkbox appearing checked in System Settings while `AXIsProcessTrusted()`
    /// still returns false. Clearing the stale record lets the user re-grant.
    func resetAccessibilityGrant() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        task.arguments = ["reset", "Accessibility", bundleID]
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            NSLog("Yap: tccutil reset failed: \(error.localizedDescription)")
        }
        refresh()
        requestAccessibility()
        openAccessibilitySettings()
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
