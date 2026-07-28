import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(AppState.self) private var app
    var onOpenHistory: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.s5) {
                historySection
                shortcutSection
                languageSection
                generalSection
                inputSection
                permissionsSection
                aboutSection
            }
            .padding(Theme.s5)
        }
        .onAppear { app.permissions.refresh(); app.launchAtLogin.refresh() }
    }

    private var historySection: some View {
        Button {
            onOpenHistory?()
        } label: {
            HStack(spacing: Theme.s3) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("View history").font(.system(size: 13, weight: .medium))
                    Text("Browse and copy past transcripts.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var shortcutSection: some View {
        @Bindable var app = app
        return VStack(alignment: .leading, spacing: Theme.s3) {
            SectionLabel("Shortcut")
            Card(padding: Theme.s2) {
                VStack(spacing: 0) {
                    HStack(spacing: Theme.s3) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Toggle dictation").font(.system(size: 13, weight: .medium))
                            Text("Press once to start, again to stop.")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: Theme.s3)
                        KeyboardShortcuts.Recorder(for: .toggleRecording)
                    }
                    .padding(.horizontal, Theme.s3)
                    .padding(.vertical, Theme.s2 + 2)

                    Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s3)

                    HStack(spacing: Theme.s3) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Single modifier key").font(.system(size: 13, weight: .medium))
                            Text("Tap a modifier on its own, like Right Shift.")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: Theme.s3)
                        Picker("", selection: $app.modifierTrigger) {
                            ForEach(ModifierTrigger.allCases) { trigger in
                                Text(trigger.title).tag(trigger)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 168)
                    }
                    .padding(.horizontal, Theme.s3)
                    .padding(.vertical, Theme.s2 + 2)
                }
            }
        }
    }

    private var languageSection: some View {
        @Bindable var app = app
        return VStack(alignment: .leading, spacing: Theme.s3) {
            SectionLabel("Language")
            Card(padding: Theme.s2) {
                HStack(spacing: Theme.s3) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Dictation language").font(.system(size: 13, weight: .medium))
                        Text("Dictate in a language other than your system's.")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: Theme.s3)
                    Picker("", selection: $app.dictationLanguage) {
                        Text("System default").tag(AppState.systemLanguage)
                        if !app.availableLocales.isEmpty {
                            Divider()
                            ForEach(app.availableLocales, id: \.identifier) { locale in
                                Text(AppState.languageName(for: locale))
                                    .tag(locale.identifier(.bcp47))
                            }
                        }
                    }
                    .labelsHidden()
                    .frame(width: 168)
                }
                .padding(.horizontal, Theme.s3)
                .padding(.vertical, Theme.s2 + 2)
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
                    Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s3)
                    SettingsToggleRow(
                        title: "Show in Dock",
                        subtitle: "Turn off to run from the menu bar only.",
                        isOn: $app.showInDock
                    )
                    Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s3)
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
                    Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s3)
                    PermissionRow(
                        title: "Speech Recognition",
                        granted: app.permissions.speech == .granted,
                        action: { Task { await app.permissions.requestSpeech() } }
                    )
                    Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s3)
                    PermissionRow(
                        title: "Accessibility",
                        granted: app.permissions.accessibility,
                        action: {
                            app.permissions.requestAccessibility()
                            app.permissions.openAccessibilitySettings()
                        }
                    )
                    Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s3)
                    PermissionRow(
                        title: "Automation",
                        granted: app.permissions.automation == .granted,
                        action: {
                            Task {
                                await app.permissions.requestAutomation()
                                if app.permissions.automation != .granted {
                                    app.permissions.openAutomationSettings()
                                }
                            }
                        }
                    )
                }
            }

            if !app.permissions.accessibility {
                HStack(spacing: Theme.s2) {
                    Button("Reset & re-grant") {
                        app.permissions.resetAccessibilityGrant()
                    }
                    .buttonStyle(GhostButtonStyle())
                    Button("Restart Yap") { app.restartApp() }
                        .buttonStyle(GhostButtonStyle())
                }

                Text("If Accessibility looks switched on but Yap still can't paste, the grant is stale after a rebuild — reset and grant it again.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
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

/// Label on the left, switch hard-right. Using `Toggle`'s own label would let
/// each row's text width push its switch to a different x, leaving the column ragged.
private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: Theme.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer(minLength: Theme.s3)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.horizontal, Theme.s3)
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
        .padding(.horizontal, Theme.s3)
        .padding(.vertical, Theme.s2 + 2)
    }
}
