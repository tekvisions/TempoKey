# TempoKey

Minimalist, fully client-side **BPM & musical-key detection** for audio files, on macOS.

Load a track → TempoKey analyzes the whole song offline and shows the overall tempo and key
plus how each varies across the song on a shared timeline. Nothing is uploaded; all analysis
runs on your machine.

## Build & Run (macOS, Xcode)

Requirements: macOS 14+, Xcode 15+ (built/tested on Xcode 26), and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate          # regenerates TempoKey.xcodeproj from project.yml
open TempoKey.xcodeproj     # then press Run in Xcode
```

Or from the command line:

```bash
xcodebuild -project TempoKey.xcodeproj -scheme TempoKey -destination 'platform=macOS' build
```

Drag an audio file (mp3, m4a/aac, wav, aiff, caf, flac…) onto the drop zone, or use
"Choose File…". After analysis you'll see:

- Large **BPM** (top-left), the detected **key**, and the file name + length.
- A **Tempo** timeline (how BPM drifts through the song).
- A **Key** ribbon (circle-of-fifths colored; fainter where the estimate is less certain).
- **Beat** tick marks.
- A Light/Dark toggle (Light "paper" is the default).

## Architecture

- `TempoKeyCore/` — UI-free Swift package: audio decoding (AVFoundation), beat/tempo
  detection (a Swift port of Beat-and-Tempo-Tracking, using Accelerate/vDSP for FFT), and
  musical key detection (chromagram + Krumhansl-Schmuckler). Run its tests with
  `cd TempoKeyCore && swift test`.
- `TempoKeyApp/` — SwiftUI front-end that consumes `AnalysisResult`.

## Credits

Beat/tempo detection is a Swift translation of
[Beat-and-Tempo-Tracking](https://github.com/michaelkrzyzaniak/Beat-and-Tempo-Tracking)
by Michael Krzyzaniak (MIT License). See `TempoKeyCore/NOTICE.md`. Musical key detection is
original to TempoKey.

## Roadmap

A Windows front-end is planned — see [docs/WINDOWS.md](docs/WINDOWS.md).
