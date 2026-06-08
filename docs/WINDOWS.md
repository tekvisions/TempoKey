# Windows Front-End (Planned)

A Windows version of TempoKey is planned but not yet built. This note records the seam so the
port is straightforward when we get to it.

## What is portable

The detection *algorithms* in `TempoKeyCore` are platform-neutral and contain the real value:
onset spectral flux, autocorrelation tempo histogram, CBSS beat tracking, the chromagram, and
Krumhansl-Schmuckler key estimation. None of that logic is Apple-specific.

## What is Apple-only (must be reimplemented)

- **Audio decoding** — currently `AVFoundation` (`TempoKeyCore/.../Audio/AudioDecoder.swift`).
- **FFT/DSP** — currently `Accelerate`/vDSP (`TempoKeyCore/.../DSP/RealFFT.swift`, plus
  `vDSP_hann_window` in the onset detector and chromagram).
- **UI** — SwiftUI does not exist on Windows.

## Recommended approach

1. Introduce two protocols for the Apple-coupled seams and make all algorithm files depend
   only on them:
   - `AudioDecoding` → `decode(url:) -> DecodedAudio`
   - `FFTProviding`  → `magnitudes(_:)` + `generalizedAutocorrelation(_:exponent:)`
2. Keep the algorithm files (onset, tempo, beat, chromagram, key) depending only on those
   protocols — they already form a clean core.
3. Provide Windows implementations of the two seams:
   - Decoding via Media Foundation, or bundle a cross-platform decoder (e.g. dr_libs /
     miniaudio) and add a Hann window helper.
   - FFT via a cross-platform library (e.g. KissFFT / PFFFT).
4. Front-end options:
   - A cross-platform shell (e.g. a thin web/Tauri UI, or .NET/WinUI) calling the algorithm
     core compiled for Windows, **or**
   - A small native reimplementation of the same minimalist report.
   Either way, the analysis core stays the single source of truth and the UX (BPM →
   key → file/length header; stacked tempo/key/beat timelines; Light default + Dark toggle)
   is mirrored from the macOS app.

No Windows code exists yet — this is the documented plan only.
