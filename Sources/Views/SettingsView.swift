import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.s5) {
                shortcutSection
                generalSection
                inputSection
                permissionsSection
                aboutSection
            }
            .padding(Theme.s5)
        }
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { app.permissions.refresh(); app.launchAtLogin.refresh() }
    }

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            SectionLabel("Shortcut")
            Card {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Toggle dictation").font(.system(size: 13, weight: .medium))
                        Text("Press once to start, again to stop.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    KeyboardShortcuts.Recorder(for: .toggleRecording)
                }
            }
        }
    }

    private var generalSection: some View {
        @Bindable var app = app
        return VStack(alignment: .leading, spacing: Theme.s3) {
            SectionLabel("General")
            Card(padding: Theme.s2) {
                VStack(spacing: 0) {
                    SettingsToggleRow(
                        title: "Launch at login",
                        subtitle: "Start Yap automatically when you log in.",
                        isOn: Binding(
                            get: { app.launchAtLogin.isEnabled },
                            set: { app.launchAtLogin.set($0) }
                        )
                    )
                    Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s2)
                    SettingsToggleRow(
                        title: "Sound feedback",
                        subtitle: "Play a cue when recording starts and stops.",
                        isOn: $app.soundsEnabled
                    )
                }
            }
        }
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            SectionLabel("Microphone")
            Card {
                HStack(spacing: Theme.s3) {
                    Image(systemName: "waveform")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.currentInputName ?? "Default microphone")
                            .font(.system(size: 13, weight: .medium))
                        Text("Yap uses your system default input automatically.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            SectionLabel("Permissions")
            Card(padding: Theme.s2) {
                VStack(spacing: 0) {
                    PermissionRow(
                        title: "Microphone",
                        granted: app.permissions.microphone == .granted,
                        action: { Task { await app.permissions.requestMicrophone() } }
                    )
                    Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s2)
                    PermissionRow(
                        title: "Speech Recognition",
                        granted: app.permissions.speech == .granted,
                        action: { Task { await app.permissions.requestSpeech() } }
                    )
                    Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s2)
                    PermissionRow(
                        title: "Accessibility",
                        granted: app.permissions.accessibility,
                        action: {
                            app.permissions.requestAccessibility()
                            app.permissions.openAccessibilitySettings()
                        }
                    )
                }
            }

            if app.permissions.needsRestartForAccessibility {
                Button("Restart Yap to apply Accessibility") {
                    app.restartForAccessibility()
                }
                .buttonStyle(GhostButtonStyle())
            }
        }
    }

    private var aboutSection: some View {
        HStack {
            Text("Yap · on-device dictation")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
            Spacer()
            Text("MIT licensed")
                .font(.system(size: 11)).foregroundStyle(.tertiary)
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .padding(.horizontal, Theme.s2)
        .padding(.vertical, Theme.s2 + 2)
    }
}

private struct PermissionRow: View {
    let title: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: Theme.s3) {
            Text(title).font(.system(size: 13, weight: .medium))
            Spacer()
            if granted {
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.success)
                    Text("Granted").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            } else {
                Button("Grant", action: action)
                    .buttonStyle(.borderless)
                    .font(.system(size: 12, weight: .medium))
            }
        }
        .padding(.horizontal, Theme.s2)
        .padding(.vertical, Theme.s2 + 2)
    }
}
