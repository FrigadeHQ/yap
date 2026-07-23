import SwiftUI

/// First-run welcome that requests the three required permissions.
struct OnboardingView: View {
    @Environment(AppState.self) private var app

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.s5) {
            VStack(alignment: .leading, spacing: Theme.s2) {
                Text("💬")
                    .font(.system(size: 40))
                Text("Welcome to Yap")
                    .font(.system(size: 22, weight: .bold))
                Text("On-device voice dictation. Press a key, speak, and your words land wherever you're typing. Nothing leaves your Mac.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: Theme.s2) {
                PermissionStep(
                    icon: "mic.fill",
                    title: "Microphone",
                    detail: "To hear you.",
                    granted: app.permissions.microphone == .granted,
                    action: { Task { await app.permissions.requestMicrophone() } }
                )
                PermissionStep(
                    icon: "waveform",
                    title: "Speech Recognition",
                    detail: "To transcribe on-device.",
                    granted: app.permissions.speech == .granted,
                    action: { Task { await app.permissions.requestSpeech() } }
                )
                PermissionStep(
                    icon: "accessibility",
                    title: "Accessibility",
                    detail: "To paste into other apps.",
                    granted: app.permissions.accessibility,
                    action: {
                        app.permissions.requestAccessibility()
                        app.permissions.openAccessibilitySettings()
                    }
                )
            }

            Spacer(minLength: 0)

            if !app.permissions.accessibility {
                Button("Already switched on? Reset and re-grant") {
                    app.permissions.resetAccessibilityGrant()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            // Hands off to Settings so the user lands somewhere they can set
            // their shortcut, rather than on an empty desktop.
            Button(app.permissions.allGranted ? "Continue to Settings" : "Continue") {
                NSApp.keyWindow?.close()
                app.openSettings()
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!app.permissions.allGranted)
            .opacity(app.permissions.allGranted ? 1 : 0.5)

            Text(footnote)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(Theme.s6)
        .frame(width: 460, height: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { app.permissions.refresh() }
    }

    private var footnote: String {
        app.permissions.allGranted
            ? "You're all set. Press ⌘⇧D to start."
            : "Grant all three to start dictating. No restart needed."
    }
}

private struct PermissionStep: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: Theme.s3) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.radiusSmall, style: .continuous)
                    .fill(Theme.surface)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.success)
            } else {
                Button("Grant", action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .padding(Theme.s3)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                .strokeBorder(Theme.hairline, lineWidth: 1)
        )
    }
}
