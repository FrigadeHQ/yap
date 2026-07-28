<div align="center">

<img src="assets/yap-icon.png" alt="Yap" width="128" height="128">

# Yap

**Blazing-fast voice dictation for macOS that works anywhere you can type.**

[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE) [![macOS 26+](https://img.shields.io/badge/macOS-26%2B-black.svg)](https://www.apple.com/macos/) [![Swift 6](https://img.shields.io/badge/Swift-6-black.svg)](https://swift.org)

Press a shortcut, talk, press it again. Your words land in whatever text field you were using. No account, no API key, no audio leaving your machine.

Built by [Frigade](https://frigade.com/?utm_source=yap&utm_medium=readme).

https://github.com/user-attachments/assets/9bd8dae6-49d6-4c06-98b9-878e24dd401f

</div>

---

## What it does

Yap lives in your menu bar and waits for a shortcut. Trigger it and a small window appears near the bottom of the screen with a live waveform and a running preview of what you have said so far. Press the shortcut again and the text gets pasted into the app you were already working in. Every transcript is saved locally, so you can go back and copy something again later.

The default shortcut is `⌘⇧D`. You can rebind it, or set a single modifier key instead. Tapping right shift on its own works nicely if you have a spare thumb.

## Install

The quickest way is from the website: [frigade.com/yap](https://frigade.com/yap). Or use Homebrew.

### Homebrew

```bash
brew install --cask frigadehq/tap/yap
```

To update later:

```bash
brew upgrade --cask yap
```

### Direct download

[**Download Yap**](https://frigade.com/yap) from the website, or grab the `.dmg` straight from [Releases](https://github.com/FrigadeHQ/yap/releases). Drag it into your Applications folder.

Yap runs on macOS 26 (Tahoe) on an Apple Silicon Mac. Intel Macs are not supported. Released builds are signed and notarized, so macOS opens them without complaint.

## Why we built this

There's no shortage of voice to text tools for macOS, and some of the open source ones are genuinely good. Most of them still run into some mix of the same problems:

- Some cost money, which is a lot to ask for something that's now built into your OS for free.
- Most make you download a heavy model. Whisper weights run to hundreds of megabytes, sit in your RAM, and only feel fast on a recent, high end Mac. On slower machines a single paragraph can take thirty seconds to a minute to come back.
- A lot are Electron or web-stack apps, so a whole browser engine idles in your memory just to run a menu bar icon and a settings window.
- Plenty are bloated with settings and modes you will never open.
- Some are closed source, so you are trusting that your audio and transcripts stay on your machine, with no way to check.

What changed recently is macOS 26. It added two APIs, `SpeechAnalyzer` and `SpeechTranscriber`, that do on-device streaming speech to text using models the OS ships and manages. The app carries no model of its own, loads nothing into memory before the first word, and needs no API key or per minute cost. Text comes back as you talk.

Is Apple's model actually any good? Better than the thing it replaces, as it turns out. A [recent benchmark](https://get-inscribe.com/blog/apple-speech-api-benchmark.html) put it at 2.12% word error rate on clean audio and 4.56% on noisy, against 3.74% and 7.95% for Whisper Small, and it ran about three times faster, across 5,559 LibriSpeech clips.

So Yap ships no model at all. It's roughly three thousand lines of native Swift in a 4 MB app, all of it open, with no browser engine anywhere in sight. It idles around 60 MB of memory and never touches the network. We use it all day at [Frigade](https://frigade.com/?utm_source=yap&utm_medium=readme), mostly for prompting coding agents, writing emails, and firing off Slack messages, basically anything that's quicker to say than type.

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

macOS 26 (Tahoe) or later, on an Apple Silicon Mac. Yap depends on the speech models Apple ships with macOS 26, and `SpeechAnalyzer` runs on device only on Apple Silicon. We dropped Intel support on purpose: the only way to transcribe on those machines was an API that sends audio to Apple, and that breaks the one promise Yap makes. Building from source needs Xcode 26.

## Permissions

On first launch Yap asks for four things, and explains each one:

| Permission         | Why                                  |
| ------------------ | ------------------------------------ |
| Microphone         | To hear you                          |
| Speech Recognition | To transcribe on device              |
| Accessibility      | To see which app you are typing into |
| Automation         | To paste the result into it          |

Accessibility has to be switched on by hand in System Settings. macOS requires that of any app that types on your behalf, and there is no way to grant it programmatically.

## How it works

Audio comes off the default input through `AVAudioEngine` and gets converted to whatever format the analyzer asks for. Capture starts before the speech stack finishes initializing, and buffers recorded in that window are held and flushed once the transcriber attaches, so the first word of a sentence is never clipped.

Transcription runs through `SpeechAnalyzer` with volatile results turned on, which is what gives you the live preview. There is no other path. Older APIs like `SFSpeechRecognizer` can fall back to Apple's servers when a locale has no on-device model, so Yap does not use them. If `SpeechAnalyzer` can't handle your language on device, dictation stops rather than sending your audio anywhere.

Insertion is the awkward part. Yap writes the text to the clipboard, drives `⌘V` through System Events, then restores your previous clipboard contents. It waits before restoring, because Chromium-based apps read the pasteboard asynchronously and more than once, and restoring too early hands the renderer stale data. That single detail is the difference between working everywhere and working only in native apps.

State lives in one place. `RecordingCoordinator` is a small state machine whose dependencies are all protocols, so the logic is covered by unit tests without needing a microphone.

## FAQ

**Why not just use the built-in macOS Dictation?**

Apple's built-in Dictation still does part of the work online, and even discloses that it "sends information like your voice input, contacts, and location to Apple." Yap talks to the on-device `SpeechAnalyzer` API directly and makes zero network calls, and because it is open source you can check that yourself. It also gives you press-to-stop with a live preview, so you can cancel a bad take before it inserts instead of watching it type as you talk (very useful in terminals / coding agents).

**Does any of my audio or text leave my Mac?**

No. There is no network code in the app at all. Transcription runs entirely on device, and your history is stored locally in SwiftData. Nothing is uploaded, and there is no account or telemetry.

**Why is it Apple Silicon only?**

`SpeechAnalyzer` runs on device only on Apple Silicon. The old way to cover Intel Macs was `SFSpeechRecognizer`, which can send your audio to Apple when a locale has no on-device model, so we removed it rather than ship something that quietly breaks the promise. If you are on an Intel Mac, stay on 0.1.4 or an earlier version (note: that Intel version _will_ send API calls to Apple).

## Roadmap

There is not much of one, and that is on purpose. Yap does a single thing, and keeping it small enough that you never have to think about it is the main design principle. Most feature ideas make an app like this worse.

We are not precious about it though. If something is missing that you would use every day, open an issue or send a pull request and we will give it a fair hearing. A language picker is the most likely next addition, since Yap follows your system locale today.

## Development

Build and install from source in one line. It clones, builds, drops Yap into `/Applications`, and launches it:

```bash
git clone https://github.com/FrigadeHQ/yap.git && cd yap && ./install.sh
```

The script installs XcodeGen if you do not have it, quits any running copy, and replaces it with the new build. Re-run `./install.sh` any time to rebuild after a change.

If you would rather work in Xcode:

```bash
xcodegen generate                    # writes Yap.xcodeproj from project.yml
open Yap.xcodeproj                   # then run with ⌘R
```

The Xcode project is generated rather than committed, so configuration changes stay readable in a diff.

Run the tests with:

```bash
xcodebuild -project Yap.xcodeproj -scheme Yap -destination 'platform=macOS' test
```

One thing to know about local builds. They are signed ad-hoc, which gives them no stable identity, so macOS treats every rebuild as a brand new application and forgets the permissions you granted the previous one. The symptom is confusing: the checkbox still looks switched on in System Settings, but pasting quietly stops working. There is a "Reset and re-grant" button in Settings for exactly this. Released builds are signed properly and do not have the problem.

The app icon is generated too, if you want to change it:

```bash
swift Tools/GenerateIcon.swift /tmp/Yap.iconset
iconutil -c icns /tmp/Yap.iconset -o Sources/Yap.icns
```

## Contributing

Issues and pull requests are welcome. If you are fixing a paste failure in a specific app, please say which app and which macOS version, since that class of bug is almost always app-specific.

## License

MIT. See [LICENSE](LICENSE).

---

<div align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/frigade-logo-dark.svg">
    <img src="assets/frigade-logo.svg" alt="Frigade" width="120">
  </picture>
</div>

<div align="center">

Built by Frigade. [Frigade Engage](https://frigade.com/engage?utm_source=yap&utm_medium=readme) makes it easy to build in-product onboarding (checklists, product tours, and more), and [Frigade Assistant](https://frigade.com/?utm_source=yap&utm_medium=readme) is an in-app AI assistant that learns your product by using it, then onboards, supports, and activates your customers.

</div>

<div align="center">
<a href="https://frigade.com/?utm_source=yap&utm_medium=readme">Website</a> · <a href="https://docs.frigade.com/?utm_source=yap&utm_medium=readme">Docs</a> · <a href="https://demo.frigade.com/?utm_source=yap&utm_medium=readme">Demo</a> · <a href="https://github.com/FrigadeHQ">GitHub</a>
</div>
