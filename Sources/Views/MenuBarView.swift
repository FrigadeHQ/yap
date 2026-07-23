import SwiftUI
import KeyboardShortcuts

/// The panel shown when clicking the menu-bar icon.
struct MenuBarView: View {
    @Environment(AppState.self) private var app

    private var isRecording: Bool {
        app.coordinator.state != .idle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s4) {
            header

            Button(action: { app.toggleRecording() }) {
                HStack(spacing: Theme.s2) {
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                    Text(isRecording ? "Stop" : "Start dictation")
                    if let hint = shortcutHint, !isRecording {
                        Spacer(minLength: Theme.s2)
                        Text(hint).foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            inputRow

            if !app.permissions.allGranted {
                permissionWarning
            }

            Divider().overlay(Theme.hairline)

            HStack(spacing: Theme.s2) {
                Button("History") { openHistory() }
                    .buttonStyle(GhostButtonStyle())
                Button("Settings") { openSettings() }
                    .buttonStyle(GhostButtonStyle())
            }

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Text("Quit Yap")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
            .padding(.top, Theme.s1)
        }
        .padding(Theme.s4)
        .frame(width: 300)
    }

    private var header: some View {
        HStack(spacing: Theme.s2) {
            Text("Yap")
                .font(.system(size: 16, weight: .bold))
            Spacer()
            HStack(spacing: 6) {
                Circle()
                    .fill(isRecording ? Theme.recording : Theme.success)
                    .frame(width: 7, height: 7)
                Text(isRecording ? "Recording" : "Ready")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inputRow: some View {
        HStack(spacing: Theme.s2) {
            Image(systemName: "waveform")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Text(app.currentInputName ?? "Default microphone")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, Theme.s3)
        .padding(.vertical, Theme.s2)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }

    private var permissionWarning: some View {
        Button(action: { openOnboarding() }) {
            HStack(spacing: Theme.s2) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Finish setup to enable dictation")
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Theme.s3)
            .padding(.vertical, Theme.s2 + 1)
            .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var shortcutHint: String? {
        KeyboardShortcuts.getShortcut(for: .toggleRecording)?.description
    }

    // MARK: - Window openers

    private func openHistory() {
        WindowManager.shared.show(id: "history", title: "History", size: NSSize(width: 480, height: 580)) {
            HistoryView()
                .environment(app)
                .modelContainer(app.modelContainer)
        }
    }

    private func openSettings() {
        WindowManager.shared.show(id: "settings", title: "Settings", size: NSSize(width: 460, height: 520), resizable: false) {
            SettingsView().environment(app)
        }
    }

    private func openOnboarding() {
        WindowManager.shared.show(id: "onboarding", title: "Welcome to Yap", size: NSSize(width: 460, height: 560), resizable: false) {
            OnboardingView().environment(app)
        }
    }
}
