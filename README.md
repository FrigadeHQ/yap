<div align="center">

# Yap

**Voice dictation for macOS that runs entirely on your Mac.**

[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE)
[![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black.svg)](https://www.apple.com/macos/)
[![Swift 6](https://img.shields.io/badge/Swift-6-black.svg)](https://swift.org)

Press a shortcut, talk, press it again. Your words land in whatever text field you were
using. No account, no API key, no audio leaving your machine.

Built by [Frigade](https://frigade.com).

</div>

---

## What it does

Yap lives in your menu bar and waits for a shortcut. Trigger it and a small window appears
near the bottom of the screen with a live waveform and a running preview of what you have
said so far. Press the shortcut again and the text gets pasted into the app you were
already working in. Every transcript is saved locally, so you can go back and copy
something again later.

The default shortcut is `⌘⇧D`. You can rebind it, or set a single modifier key instead.
Tapping right shift on its own works nicely if you have a spare thumb.

## Install

### Homebrew

```bash
brew install --cask frigadehq/tap/yap
```

To update later:

```bash
brew upgrade --cask yap
```

### Direct download

Grab the latest `.dmg` from [Releases](https://github.com/FrigadeHQ/yap/releases) and drag
Yap into your Applications folder.

Released builds are signed and notarized, so macOS opens them without complaint.

### Build locally

You only need this if you want to hack on Yap. The build is generated from `project.yml`
rather than a committed Xcode project, so configuration changes stay readable in a diff.

```bash
brew install xcodegen                # one-time
git clone https://github.com/FrigadeHQ/yap.git
cd yap
xcodegen generate                    # writes Yap.xcodeproj
open Yap.xcodeproj                   # then run with ⌘R
```

Prefer the command line:

```bash
xcodebuild -project Yap.xcodeproj -scheme Yap -configuration Release build
```

Run the tests with:

```bash
xcodebuild -project Yap.xcodeproj -scheme Yap -destination 'platform=macOS' test
```

One thing to know about local builds. They are signed ad-hoc, which gives them no stable
identity, so macOS treats every rebuild as a brand new application and forgets the
Accessibility and Automation grants you gave the previous one. The symptom is confusing:
the checkbox still looks switched on in System Settings, but pasting quietly stops working.
There is a "Reset and re-grant" button in Settings for exactly this. Released builds are
properly signed and do not have the problem.

The app icon is generated too, if you want to change it:

```bash
swift Tools/GenerateIcon.swift /tmp/Yap.iconset
iconutil -c icns /tmp/Yap.iconset -o Sources/Yap.icns
```

## Why we built this

Apple made this problem a lot easier in macOS 26, and we think most people have not noticed
yet.

Until recently, building decent dictation meant one of two things. You could ship Whisper
weights inside your app, which means hundreds of megabytes, a slow cold start, and a fan
that spins up every time someone talks. Or you could call a hosted transcription API, which
means the audio leaves the machine, somebody needs to manage an API key, and there is a bill
attached to every minute of speech.

macOS 26 ships `SpeechAnalyzer` and `SpeechTranscriber`. They do streaming speech to text
on device, the OS manages the models, and the results come back fast enough to show partial
text while you are still talking. Nothing is uploaded. There is no key to configure and
nothing to pay per minute.

That changes what a dictation app has to be. It can be small, and it can be private without
asking you to trust anyone. Yap is roughly two thousand lines of Swift and calls no network
APIs at all.

We use it internally at [Frigade](https://frigade.com). Most of the team writes faster by
talking, particularly for the longer messages nobody wants to type twice.

## Features

- On-device transcription through Apple's Speech framework
- Global shortcut, fully rebindable, with optional single-modifier triggers like right shift
- Pastes straight into the focused field of whatever app you were in
- Local transcript history with search, copy, and delete
- Live waveform and partial transcript while you speak
- Press escape twice to discard a dictation in progress
- Follows your system default microphone, including when it changes mid-session
- Optional launch at login, off by default
- No account, no network calls, no telemetry

## Requirements

macOS 26 (Tahoe) or later. Yap depends on the speech models Apple ships with macOS 26, so
earlier versions will not work. Building from source additionally needs Xcode 26.

## Permissions

On first launch Yap asks for four things, and explains each one:

| Permission | Why |
| --- | --- |
| Microphone | To hear you |
| Speech Recognition | To transcribe on device |
| Accessibility | To see which app you are typing into |
| Automation | To paste the result into it |

Accessibility has to be switched on by hand in System Settings. macOS requires that of any
app that types on your behalf, and there is no way to grant it programmatically.

## How it works

Audio comes off the default input through `AVAudioEngine` and gets converted to whatever
format the analyzer asks for. Capture starts before the speech stack finishes initializing,
and buffers recorded in that window are held and flushed once the transcriber attaches, so
the first word of a sentence is never clipped.

Transcription runs through `SpeechAnalyzer` with volatile results turned on, which is what
gives you the live preview. `SFSpeechRecognizer` is wired up as a fallback for locales the
newer API does not cover.

Insertion is the awkward part. Yap writes the text to the clipboard, drives `⌘V` through
System Events, then restores your previous clipboard contents. It waits before restoring,
because Chromium-based apps read the pasteboard asynchronously and more than once, and
restoring too early hands the renderer stale data. That single detail is the difference
between working everywhere and working only in native apps.

State lives in one place. `RecordingCoordinator` is a small state machine whose dependencies
are all protocols, so the logic is covered by unit tests without needing a microphone.

## Why it is not sandboxed

Typing into another application requires driving System Events and reading the focused UI
element, both of which the macOS App Sandbox forbids. Yap therefore ships unsandboxed and is
distributed outside the Mac App Store. Every text expander, clipboard manager, and dictation
tool on macOS lands in the same place for the same reason.

## Roadmap

- Windows support. The interesting part is that this cannot be a shared codebase in any
  meaningful sense, because the value comes from each OS's built-in speech engine. Windows
  would need its own native implementation.
- A language picker. Yap currently follows your system locale.

## Contributing

Issues and pull requests are welcome. If you are fixing a paste failure in a specific app,
please say which app and which macOS version, since that class of bug is almost always
app-specific.

## License

MIT. See [LICENSE](LICENSE).

---

<div align="center">

Built by [Frigade](https://frigade.com), an AI assistant that lives inside your product,
learns it end to end, and takes actions on behalf of your users.

</div>
