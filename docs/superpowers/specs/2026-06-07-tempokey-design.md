# TempoKey — Design Spec

**Date:** 2026-06-07
**Status:** Approved (pending written-spec review)

## Summary

TempoKey is a fully client-side macOS application for **BPM (tempo) and musical key
detection** of audio files. The user loads a music file; the app analyzes the entire
song offline and presents a minimalist report showing the overall BPM and key, plus how
both **vary throughout the song**, on a shared time axis.

The tempo/beat engine is a Swift translation of the MIT-licensed
[Beat-and-Tempo-Tracking](https://github.com/michaelkrzyzaniak/Beat-and-Tempo-Tracking)
C library by Michael Krzyzaniak. Musical key detection is net-new (the source library
does not detect key).

## Goals

- Translate the BTT C library's tempo/beat logic into readable, native Swift.
- Add musical key detection (per-section + overall).
- Present a minimalist, single-window report of tempo and key variation over time.
- Run in Xcode as a macOS app, fully client-side (no network, nothing leaves the machine).
- Leave a clean, documented seam for a future Windows front-end.

## Non-Goals (this iteration)

- No audio playback / synced playhead (offline analysis only).
- No real-time / live-input analysis.
- No export of results (documented as possible future work).
- No Windows implementation now — only a documented porting seam.

## Key Decisions (from brainstorming)

| Decision | Choice |
|---|---|
| Key detection | Build it (chromagram + Krumhansl-Schmuckler), alongside the BTT port |
| Port strategy | **Hybrid** — port BTT high-level logic to Swift; use Apple **Accelerate/vDSP** for FFT/DSP instead of porting `DFT.c`/`fastsin.c`. No C in the build. |
| Analysis mode | Offline whole-file analysis, no playback |
| Layout | Stacked timelines sharing one time axis (Tempo / Key / Beats) |
| Header | Large **BPM** top-left → **Key** → **file name + length** side by side |
| Aesthetic | **Light "paper"** as default, with a **Dark mode** toggle |
| Key colors | Mapped by circle of fifths |

## Architecture

Two layers, separated so the analysis core is testable without any UI.

```
TempoKey/                      (Xcode project, macOS)
├── TempoKeyCore/              Swift Package — pure logic, no UI/AppKit
│   ├── Audio/                 AudioDecoder: file → mono Float32 @ fixed rate
│   ├── BeatTracking/          Swift port of BTT
│   │   ├── OnsetDetector      spectral-flux onset signal (OSS)
│   │   ├── TempoTracker       autocorrelation + decaying tempo histogram
│   │   ├── BeatTracker        CBSS beat prediction
│   │   ├── Statistics         running mean/variance/std helpers
│   │   └── DSP                FFT/STFT via vDSP (replaces DFT.c/fastsin.c)
│   ├── KeyDetection/          Chromagram (vDSP) + Krumhansl-Schmuckler
│   └── Analysis/              AnalysisEngine → AnalysisResult
└── TempoKeyApp/               macOS app target (SwiftUI)
    ├── Import                 ImportView (drop zone)
    ├── Report                 ReportView (header + stacked timelines)
    ├── Charts                 reusable timeline views
    └── Theme                  Light (default) + Dark
```

**Rationale:** `TempoKeyCore` is a Swift Package with its own unit tests, verified against
the original C behavior and known-tempo/known-key synthetic signals before any UI exists.
The app target only consumes `AnalysisResult`. This concentrates portable algorithm logic
in one place for the future Windows effort.

## Analysis Core

### A. Audio decoding — `AudioDecoder`
- Uses AVFoundation (`AVAudioFile`) to read supported formats (mp3, m4a/aac, wav, aiff,
  caf, flac).
- Down-mixes to mono, resamples to a fixed analysis rate of **22,050 Hz**.
- Output: `[Float]` PCM buffer + `duration`.

### B. Beat & tempo — the BTT port (hop-based over the signal)
- **OnsetDetector**: STFT via vDSP FFT (~1024-sample window) → spectral flux (sum of
  positive bin-to-bin energy increases) → low-pass filter → adaptive threshold using
  running mean/std (`Statistics`). Produces the onset signal (OSS).
- **TempoTracker**: autocorrelate the OSS; take several highest peaks as candidate
  tempos; feed a **decaying histogram** with Gaussian weighting favoring moderate tempos.
  Default tempo range **50–200 BPM** (configurable; matches the library).
- **BeatTracker**: cumulative beat-strength signal (CBSS, Stark approach) → beat
  position predictions.
- Outputs: tempo sampled per hop → **tempo-over-time series**; histogram peak → **overall
  BPM**; beat predictions → **beat markers**; histogram strength → **bpmConfidence**.

### C. Key detection — net-new (independent windowed pass)
- **Chromagram**: FFT magnitude per window (~4 s window, ~1 s hop) folded into **12 pitch
  classes** via log-frequency mapping.
- **Krumhansl-Schmuckler**: correlate each window's 12-bin chroma against all **24** major
  and minor key profiles; highest correlation → that window's key + confidence.
- Smooth across windows to reduce jitter → **key-over-time series** (`KeySegment`s); the
  dominant key → **overall key**. Each key is colored by the circle of fifths.

### Numerics note
Because vDSP's FFT replaces the C `DFT.c`/`fastsin.c`, results are not bit-identical to the
original. Tempo/beat outcomes are driven by spectral *magnitude* and peak structure, which
match. Tests assert correct BPM/key on synthetic signals within tolerance, not bit-equality.

## Data Model

```swift
struct AnalysisResult {
    let fileName: String
    let duration: TimeInterval
    let overallBPM: Double
    let overallKey: MusicalKey            // tonic + mode (major/minor)
    let tempoSeries: [TempoPoint]         // (time, bpm)
    let keySeries:   [KeySegment]         // (startTime, endTime, key, confidence)
    let beats:       [TimeInterval]       // beat onset times
    let bpmConfidence: Double
}
```

## UI

SwiftUI, single window.

1. **ImportView** — minimalist drop zone ("Drop an audio file" + Open button). On drop,
   shows a progress indicator while `AnalysisEngine` runs off the main thread.
2. **ReportView** — Light-paper layout:
   - **Header**: large **BPM** top-left → **Key** → **file name + length** side by side (right).
   - **Stacked timelines** sharing one time axis:
     - **Tempo**: line graph of BPM over time.
     - **Key**: circle-of-fifths colored ribbon with key labels.
     - **Beats**: tick markers.
     - Hover shows the value at that time.
   - Toolbar: open new file, **Light/Dark toggle**.
- Charts: **Swift Charts** for the tempo line; lightweight custom `Canvas` drawing for the
  key ribbon and beat ticks. No third-party UI dependencies.

## Testing Strategy

- **TDD on `TempoKeyCore`:**
  - Synthetic click tracks at known BPMs → detected tempo within tolerance.
  - Pure-tone / triad signals → detected key correct.
  - Focused unit tests for `Statistics` and chroma pitch-class folding.
- UI is intentionally thin and verified manually.

## Build / Run

- Opens and runs in **Xcode** as a macOS SwiftUI app.
- README with run instructions.
- **License/attribution:** original BTT is MIT — include a NOTICE/attribution file
  crediting Michael Krzyzaniak and the BTT project.

## Windows (Future) Note

A Windows front-end is planned but not built now. `docs/WINDOWS.md` will record:
- `TempoKeyCore`'s algorithm logic (onset, tempo histogram, CBSS, chromagram, K-S) is
  portable.
- Its AVFoundation (decoding) and Accelerate (FFT) layers are Apple-only.
- A Windows version reuses the algorithms behind `AudioDecoder`/`DSP` protocol seams with
  platform-specific implementations (cross-platform FFT + Windows audio decoding).

## Open Questions / Risks

- Exact onset/tempo parameters may need tuning vs. the C defaults; tolerance-based tests
  guard correctness rather than bit-equality.
- Key detection on percussive/atonal material is inherently uncertain — confidence is
  surfaced in the UI rather than hidden.
```
