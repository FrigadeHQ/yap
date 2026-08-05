import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @Environment(AppState.self) private var app
    var onOpenHistory: (() -> Void)?
    var onOpenDictionary: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.s5) {
                historySection
                dictionarySection
                dictationSection
                generalSection
                inputSection
                if !app.permissions.allGranted {
                    permissionsBanner
                }
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

    private var dictionarySection: some View {
        Button {
            onOpenDictionary?()
        } label: {
            HStack(spacing: Theme.s3) {
                Image(systemName: "character.book.closed")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dictionary").font(.system(size: 13, weight: .medium))
                    Text("Teach Yap names and words it often gets wrong.")
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

    /// One card per language. Only the first carries the explanatory subtitles —
    /// repeating them on every card buries the settings they describe.
    private var dictationSection: some View {
        VStack(alignment: .leading, spacing: Theme.s3) {
            SectionLabel("Dictation")
            ForEach(Array(app.profiles.enumerated()), id: \.element.id) { index, profile in
                profileCard(profile, isFirst: index == 0)
            }
            Button {
                app.addProfile()
            } label: {
                HStack(spacing: Theme.s2) {
                    Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                    Text("Add a language")
                }
            }
            .buttonStyle(GhostButtonStyle())
            Text("Each language gets its own triggers, so a different key dictates in a different language. Two languages cannot share one trigger.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func profileCard(_ profile: DictationProfile, isFirst: Bool) -> some View {
        Card(padding: Theme.s2) {
            VStack(spacing: 0) {
                DictationRow(
                    title: "Language",
                    subtitle: isFirst ? "Dictate in a language other than your system's." : nil
                ) {
                    Picker("", selection: binding(profile, \.language)) {
                        Text("System default").tag(DictationProfile.systemLanguage)
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
                    // The first card is the one Yap falls back to, so it stays.
                    removeSlot(isFirst ? nil : profile)
                }

                Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s3)

                DictationRow(
                    title: "Toggle dictation",
                    subtitle: isFirst ? "Press once to start, again to stop." : nil
                ) {
                    KeyboardShortcuts.Recorder(for: profile.shortcutName) { _ in
                        app.shortcutChanged(for: profile)
                    }
                    removeSlot(nil)
                }

                Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s3)

                DictationRow(
                    title: "Single modifier key",
                    subtitle: isFirst ? "Tap a modifier on its own, like Right Shift." : nil
                ) {
                    Picker("", selection: binding(profile, \.modifierTrigger)) {
                        ForEach(ModifierTrigger.allCases) { trigger in
                            Text(trigger.title).tag(trigger)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 168)
                    removeSlot(nil)
                }

                Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s3)

                DictationRow(
                    title: "Function-row key",
                    subtitle: isFirst ? "Press an F-key, or the mic key, on its own." : nil
                ) {
                    Picker("", selection: binding(profile, \.functionKeyTrigger)) {
                        ForEach(FunctionKeyTrigger.allCases) { trigger in
                            Text(trigger.title).tag(trigger)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 168)
                    removeSlot(nil)
                }
            }
        }
    }

    /// Reserved on every row, filled on one, so the controls stay in a single
    /// column whether or not the card can be removed.
    private func removeSlot(_ profile: DictationProfile?) -> some View {
        Group {
            if let profile {
                Button {
                    app.removeProfile(profile.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove this language")
            } else {
                Color.clear
            }
        }
        .frame(width: 12)
    }

    /// Profiles are edited through the store rather than in place, so each control
    /// writes its one field back into a copy.
    private func binding<Value>(
        _ profile: DictationProfile,
        _ field: WritableKeyPath<DictationProfile, Value>
    ) -> Binding<Value> {
        Binding(
            get: { profile[keyPath: field] },
            set: { newValue in
                var updated = profile
                updated[keyPath: field] = newValue
                app.updateProfile(updated)
            }
        )
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
                    Divider().overlay(Theme.hairline).padding(.horizontal, Theme.s3)
                    SettingsToggleRow(
                        title: "Clean up transcripts",
                        subtitle: app.cleanup.isAvailable
                            ? "Fix punctuation, format lists, and apply spoken corrections with Apple Intelligence, on-device."
                            : "Requires Apple Intelligence, enabled in System Settings.",
                        isOn: $app.cleanupEnabled
                    )
                    .disabled(!app.cleanup.isAvailable)
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

    // Shown only when something is missing. Tapping it reopens onboarding, which
    // is where permissions are actually granted, so Settings stays uncluttered
    // once everything is in place.
    private var permissionsBanner: some View {
        Button {
            app.openOnboarding()
        } label: {
            HStack(spacing: Theme.s3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(Self.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Some permissions are missing")
                        .font(.system(size: 13, weight: .medium))
                    Text("Yap needs them to hear you and paste into other apps. Review permissions.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Theme.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Self.warning.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .strokeBorder(Self.warning.opacity(0.35), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static let warning = Color(red: 0.95, green: 0.64, blue: 0.16)

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

/// Same hand-rolled label as `SettingsToggleRow`, for the rows whose control is a
/// picker or a shortcut recorder rather than a switch.
private struct DictationRow<Control: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .center, spacing: Theme.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: Theme.s3)
            control
        }
        .padding(.horizontal, Theme.s3)
        .padding(.vertical, Theme.s2 + 2)
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
