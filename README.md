<div align="center">

# 💬 Yap

**Free, open-source, on-device voice dictation for macOS.**

Press a key, speak, press again — your words land in whatever you're typing into.
No account. No cloud. No API keys. Nothing ever leaves your Mac.

MIT licensed.

</div>

---

Yap is a tiny menu-bar app. Set a global hotkey, press it to start dictating, press
it again to stop. Yap transcribes your speech **entirely on-device** using Apple's
Speech framework and pastes the result into the currently focused text field. Every
transcript is saved to a local history you can re-copy from.

It's an open, minimal alternative to closed-source dictation tools — deliberately
simple, fast, and private.

## Features

- 🎙️ **On-device transcription** — Apple's `SpeechAnalyzer` (macOS 26), no network
- ⌨️ **Global toggle hotkey** — press to start, press again to stop (fully rebindable)
- 📋 **Pastes into the focused field** — via the clipboard, then restores it
- 🕘 **Transcript history** — everything is saved locally so you can re-copy
- 🎧 **Auto-detects your input** — uses and displays the current default microphone
- 🚀 **Launch at login** — optional, off by default
- 🔒 **Private by design** — no telemetry, no account, no cloud

## Requirements

- macOS 26 (Tahoe) or later
- Xcode 26+ (to build from source)

## Build & run

```bash
brew install xcodegen        # one-time
xcodegen generate            # generates Yap.xcodeproj from project.yml
open Yap.xcodeproj           # then Run (⌘R) — or build from the CLI:

xcodebuild -project Yap.xcodeproj -scheme Yap -destination 'platform=macOS' build
```

On first launch Yap asks for three permissions:

1. **Microphone** — to hear you
2. **Speech Recognition** — to transcribe on-device
3. **Accessibility** — to paste into other apps

## Why not sandboxed?

Pasting into other apps requires posting synthetic keystrokes and reading the focused
UI element, which the macOS App Sandbox blocks. Yap therefore ships **non-sandboxed**
and is distributed as a Developer ID–signed, notarized build (not via the Mac App
Store). For local development it builds with ad-hoc signing.

## Roadmap

- Windows support (a separate native effort — the core value is each OS's built-in
  speech engine, which is inherently per-platform)
- Optional language picker (v1 follows the system locale automatically)

## License

MIT — see [LICENSE](LICENSE).
