# TempoKey

Offline BPM and musical-key analysis for macOS 14+. Import music, compare a batch of
tracks, inspect tempo/key/energy timelines, listen and correct estimates, then export results.
Analysis runs fully privately on your Mac; audio is never uploaded. The optional update check contacts GitHub, without sending audio.

## Build and test

Requires Xcode with the macOS 14+ SDK and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
**0.7.0 (4)** is available from [GitHub Releases](https://github.com/tekvisions/TempoKey/releases/tag/v0.7.0).
The downloadable DMG supports Apple Silicon and Intel Macs.

```sh
xcodegen generate
open TempoKey.xcodeproj
swift test --package-path TempoKeyCore
xcodebuild -project TempoKey.xcodeproj -scheme TempoKey -destination 'platform=macOS' test
xcodebuild -project TempoKey.xcodeproj -scheme TempoKey -configuration Release -destination 'platform=macOS' build
```

Debug disables App Sandbox for hosted XCTest injection; Release enables sandboxing,
user-selected read/write access, app-scoped bookmarks, microphone input and update networking.
Microphone access is requested only when **Start listening** is selected.

## Workflows

- **Import:** ⌘O, drag audio files, or choose a folder. MP3, M4A/AAC, WAV, AIFF, CAF,
  FLAC and audio-bearing MP4 are accepted where AVFoundation can decode them. One file
  is analyzed at a time; individual failures stay visible without discarding successes.
- **Library:** sort file/BPM/key/Camelot/duration columns; open or double-click a report;
  export the displayed order as CSV. Recent import bookmarks persist across launches.
- **Correct:** tap a tempo, enter a BPM and press Return, halve/double the estimate, or
  choose a key. Corrections belong to each track in the current session. Raw timelines
  remain unchanged. A dash means there is insufficient evidence for tempo.
- **Listen:** Space plays/pauses; ⌘←/⌘→ seek five seconds. Click the timeline to seek,
  pinch/scroll to zoom, drag to pan, double-click to reset. **Loop region** repeats the
  visible window. The metronome follows detected beats, not a corrected summary BPM.
- **Export:** JSON includes detected analysis plus corrections; PNG renders a shareable
  report. Tagged copies support common MP3 ID3v2.3/v2.4 tags and M4A (native BPM, key and
  Camelot in a comment). Original audio is preserved; unsupported tag variants fail safely.
- **Live input:** select the system default or an audio device, then start listening.
  Six seconds warms up the estimate; the latest twelve seconds are analyzed. No recording
  is saved. Stop or navigate away to end capture.

Meter and section boundaries are estimates. Meter currently distinguishes strong repeated
triple/quadruple accents and otherwise stays unknown. Sections use neutral labels; semantic
“intro/build/drop” classification is not claimed. Check results by ear.

## Architecture

- `TempoKeyCore/`: UI-free Swift package, Apple decoder/resampler/FFT adapters, onset/tempo/
  beat/key detectors, energy/section/meter analysis and Codable results. Analysis normalizes
  PCM to 44.1 kHz and checks cancellation through long operations.
- `TempoKeyApp/`: main-actor library orchestration with stale-task protection, per-track
  corrections, security-scoped recents, export services, playback and bounded live capture.
- `TempoKeyAppTests/`: hosted tests for app logic, batch/lifecycle behavior, CSV/JSON/PNG,
  metadata round trips, recent bookmarks and transport bounds.

See [the current roadmap](docs/ROADMAP.md) for implemented scope, limitations and outstanding
hardware/sandbox/release gates. Windows is deferred; see [WINDOWS.md](docs/WINDOWS.md).

## Credits

Beat/tempo detection is a Swift translation of
[Beat-and-Tempo-Tracking](https://github.com/michaelkrzyzaniak/Beat-and-Tempo-Tracking)
by Michael Krzyzaniak (MIT). See `TempoKeyCore/NOTICE.md`. Musical key detection is original
to TempoKey.
