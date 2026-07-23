# Yap — Design Spec

**Date:** 2026-07-23
**Status:** Approved, ready for implementation planning

## Summary

Yap is a tiny, native **macOS menu-bar app** for voice dictation. You set a global
hotkey, press it to start speaking, press it again to stop. Yap transcribes your
speech **fully on-device** using Apple's Speech framework and pastes the result into
whatever text field you're focused on. Every transcript is saved to a local history
you can re-copy from.

No account, no cloud, no API keys, no telemetry. MIT licensed. Open source.

Yap is an open-source spiritual successor to closed-source dictation tools like
VoiceInk — deliberately minimal, fast, and private.

## Goals

- Press-to-toggle global hotkey dictation from anywhere in the OS
- On-device transcription (private, offline, no keys)
- Paste transcribed text into the currently focused field, reliably
- Persistent, searchable-enough local transcript history to re-copy from
- Launch at login
- Auto-detect and use the default system audio input; display which one is in use
- Feel native and fast; tiny footprint

## Non-Goals (v1)

- Windows support (a stated *future* goal; the app is Mac-only in v1 because the
  core value comes from each OS's built-in speech engine, which is inherently
  per-platform). Noted in README.
- Language picker (v1 auto-follows the system locale)
- Accounts, cloud sync, or any network dependency
- Voice commands, text formatting, or post-processing
- Analytics / telemetry
- Multiple or configurable input device selection (auto-detect only; display only)

## Platform & Stack

- **OS:** macOS 26+ (Tahoe)
- **Language/UI:** Swift + SwiftUI
- **App type:** Menu-bar app (`LSUIElement` / agent app — no dock icon)
- **Persistence:** SwiftData
- **License:** MIT
- **Dependencies:** `KeyboardShortcuts` (Sindre Sorhus, MIT) for hotkey recording &
  registration. All other functionality uses first-party Apple frameworks.

## Key Product Decisions (locked)

| Decision | Choice |
|---|---|
| Tech stack | Native Swift/SwiftUI menu-bar app, Mac first |
| Hotkey behavior | **Toggle** — press to start, press again to stop |
| Text delivery | **Paste via clipboard** — set clipboard, simulate ⌘V, restore prior clipboard |
| Language | **Auto** — follow the system locale, no picker |
| Name | **Yap** |

## Architecture

The app is decomposed into small, single-responsibility, protocol-backed services
coordinated by a central state machine. Services that wrap system APIs sit behind
protocols so the coordinator can be unit-tested with fakes.

### The core flow (state machine)

Owned by `RecordingCoordinator`:

```
idle → recording → transcribing → inserting → idle
```

1. **Hotkey pressed** (from `idle`) → play start sound, show HUD, start audio capture
   + live transcription → state `recording`
2. **Hotkey pressed again** → stop capture, finalize transcript, play stop sound →
   state `transcribing` (brief; text may already be mostly final from streaming)
3. Deliver text via `TextInjector` → state `inserting`
4. Save transcript to `HistoryStore`, hide HUD → back to `idle`

### Components

| Module | Responsibility | Primary API |
|---|---|---|
| `HotkeyManager` | Register/record the global toggle shortcut; emit start/stop | `KeyboardShortcuts` |
| `AudioCaptureService` | Capture default input; expose audio buffers, level meter, device name | `AVAudioEngine` |
| `TranscriptionService` | Stream audio → partial/final text, on-device | `SpeechAnalyzer` / `SpeechTranscriber` (primary), `SFSpeechRecognizer` (fallback) |
| `TextInjector` | Clipboard save/restore + synthetic ⌘V; focused-field check | `NSPasteboard`, `CGEvent`, Accessibility (`AXUIElement`) |
| `HistoryStore` | Create/list/delete/clear transcripts | `SwiftData` |
| `PermissionsManager` | Mic / Speech / Accessibility status + prompts | `AVCaptureDevice`, `SFSpeechRecognizer`, `AXIsProcessTrusted` |
| `LaunchAtLoginService` | Start-at-login toggle | `SMAppService` |
| `RecordingCoordinator` | State machine wiring services together; drives HUD | — |

### UI surfaces

- `MenuBarView` — status line, current default input device name, links to History /
  Settings, Quit. Menu-bar icon reflects state (idle vs recording).
- `RecordingHUD` — a borderless, non-activating, floating `NSPanel` hosting a SwiftUI
  view: mic glyph + live audio level / waveform, and a live partial-transcript
  preview. Appears near the bottom-center of the active screen.
- `HistoryView` — list of transcripts, newest first; per-row copy and delete; a
  "Clear all" action.
- `SettingsView` — minimal settings (below).
- `OnboardingView` — first-run flow that requests Mic, Speech, and Accessibility
  permissions with clear explanations.

### Settings (deliberately minimal)

- The record hotkey (recorder control)
- Launch at login (toggle)
- HUD sounds on/off (toggle)
- Read-only display of the current default input device
- Permission status + re-request buttons (Mic, Speech, Accessibility)

## Data Model

`Transcript` (SwiftData):

- `id: UUID`
- `text: String`
- `createdAt: Date`
- `durationSeconds: Double?`
- `inputDeviceName: String?`

History is unlimited in v1 (transcripts are cheap text). Users manage size via
per-row delete and "Clear all". A retention cap can be added later if needed.

## Permissions

The app requires three macOS permissions, requested during first-run onboarding:

1. **Microphone** (`NSMicrophoneUsageDescription`) — to capture audio
2. **Speech Recognition** (`NSSpeechRecognitionUsageDescription`) — to transcribe
3. **Accessibility** (`AXIsProcessTrusted`, granted in System Settings) — to post the
   synthetic ⌘V into other apps

If any permission is missing or later revoked, the app degrades gracefully (see Error
Handling) rather than failing silently.

## Error Handling

- **Missing/revoked permission** → onboarding on first run; thereafter the HUD or a
  menu-bar alert points the user to the correct System Settings pane instead of
  silently failing.
- **Empty / no speech detected** → brief HUD message ("Didn't catch that"); nothing is
  pasted and nothing is saved to history.
- **Focused field not editable / unknown** (Accessibility can't confirm an editable
  target) → skip the synthetic paste, **leave the text on the clipboard**, and notify
  the user. The text is also always in History.
- **Speech model / locale asset not downloaded** → trigger download on first use and
  show progress in the HUD; proceed once available.
- **Input device disappears mid-recording** → stop the session gracefully and inform
  the user.

## Text Insertion Detail

On stop:

1. Save current `NSPasteboard` contents.
2. Write transcript text to the pasteboard.
3. If Accessibility confirms a focused, editable element: synthesize ⌘V via `CGEvent`,
   then restore the saved pasteboard contents after a short delay.
4. If no editable target is confirmed: leave the transcript on the pasteboard (do not
   restore), and notify the user that it's ready to paste manually.
5. Regardless of outcome, persist the transcript to `HistoryStore`.

## Testing Strategy

- **TDD** the `RecordingCoordinator` state machine using fake services — this is the
  real logic core (state transitions, HUD driving, save/insert ordering, error paths).
- **Unit-test** `HistoryStore` against an in-memory SwiftData container (create, list
  ordering, delete, clear).
- **Unit-test** `TextInjector`'s clipboard save/restore logic (the non-system parts).
- **Manual test checklist** for the system-dependent pieces:
  - Permission grant/deny/revoke flows
  - Real dictation accuracy and latency
  - Insertion into Notes, Chrome, Slack, Terminal, and a non-editable context
  - Launch-at-login on real reboot
  - HUD appearance, sounds, and live level meter
  - Default input device change detection & display

## Distribution & Signing

- Builds from source with **ad-hoc signing** for local development.
- Signed releases require an Apple **Developer ID** and **notarization** so that Mic /
  Speech / Accessibility permission grants persist across launches. This will be
  documented in the README; release automation is out of scope for the initial build.

## Open Questions / To Confirm During Implementation

- Confirm the exact macOS 26 `SpeechAnalyzer` / `SpeechTranscriber` streaming API
  surface and the locale-asset download flow (`AssetInventory`); wire the
  `SFSpeechRecognizer` fallback path.
- Confirm the cleanest way to read the current default input device name and observe
  changes (Core Audio property listener vs `AVCaptureDevice`).
- Final bundle identifier (placeholder until chosen).
