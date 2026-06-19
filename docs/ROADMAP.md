# TempoKey Release Roadmap

A versioned plan for shipping the proposed features as signed, notarized GitHub releases.

## Versioning strategy
Pre-1.0, each themed feature set is a **minor** release (`0.2.0`, `0.3.0`, …); bug-fix-only
follow-ups are **patch** releases (`0.2.1`). `1.0.0` is the stabilization release once the
feature set is complete. Every release is a **full** GitHub release (not pre-release) so the
in-app update banner (`GET /releases/latest`) detects it.

## Release procedure (identical for every version below)
Each version follows this once-defined pipeline. `X.Y.Z` = the target version.

1. **Branch & implement (TDD).** `git checkout -b feat/<theme>`; build the feature; keep
   `cd TempoKeyCore && swift test` and `xcodebuild -project TempoKey.xcodeproj -scheme TempoKey
   -destination 'platform=macOS' test` green. Each version gets its own detailed
   implementation plan via the `writing-plans` flow before coding starts.
2. **Bump version.** In `project.yml`: `MARKETING_VERSION: "X.Y.Z"`, increment
   `CURRENT_PROJECT_VERSION`; then `xcodegen generate`.
3. **Merge to `main`** (PR or local merge); confirm tests green on `main`.
4. **Build + sign + notarize + staple:**
   ```bash
   export DEVELOPER_ID="Developer ID Application: Kymata Labs LLC (72G9XN68CV)"
   export NOTARY_PROFILE="TempoKeyNotary"
   ./scripts/package-dmg.sh
   ```
5. **Verify the artifact:**
   ```bash
   xcrun stapler validate dist/TempoKey-X.Y.Z.dmg
   spctl -a -vv -t open --context context:primary-signature dist/TempoKey-X.Y.Z.dmg
   # expect: accepted / source=Notarized Developer ID
   ```
6. **Commit, tag, push:**
   ```bash
   git commit -am "release: bump version to X.Y.Z"
   git tag -a vX.Y.Z -m "TempoKey X.Y.Z"
   git push origin main vX.Y.Z
   ```
7. **Publish the release with the notarized DMG:**
   ```bash
   gh release create vX.Y.Z dist/TempoKey-X.Y.Z.dmg --title "TempoKey X.Y.Z" --notes "…"
   ```
   *Alternative (after CI secrets are configured per `docs/RELEASING-GITHUB.md`):* skip steps
   4–7's manual build and just `git push origin vX.Y.Z` — the guarded `release.yml` workflow
   builds, signs, notarizes, and publishes automatically.

> **Entitlement changes** (v0.4.0, v0.7.0) require re-running the security audit and re-checking
> the shipped entitlements before release.

---

## Roadmap at a glance

| Version | Theme | Headline features | Notable delta |
|---|---|---|---|
| 0.2.0 | Harmonic mixing & quick fixes | Camelot notation, mixing hints, tap-tempo, ×½/×2, manual key override, copy | UI + small logic only |
| 0.3.0 | Library / batch | Folder/multi-file analysis, sortable table, CSV export, recents | Concurrency |
| 0.4.0 | Metadata & export | Write BPM/key to file tags, JSON export, report image | **read-write entitlement** |
| 0.5.0 | Playback & sync | Playback, synced playhead, click-to-seek, beat metronome, loop | AVAudioEngine |
| 0.6.0 | Deeper analysis | Downbeats, time signature, per-section tempo, structure + energy | Core algorithms |
| 0.7.0 | Real-time | Live BPM/key from mic / input | **microphone entitlement** |
| R | Core portability seams (enabler) | Abstract FFT/decode/window behind protocols (macOS, no behavior change) | prerequisite for Windows; land before 1.0.0 |
| 1.0.0 | Stabilization **+ Windows launch** | Polish/perf/a11y; ship macOS `.dmg` **and** the first Windows `.exe`, both versioned 1.0.0 | cross-platform release |

---

## v0.2.0 — Harmonic Mixing & Quick Corrections
**Features:** Camelot/Open-Key notation alongside the standard key + compatible-key hints;
tap-tempo; ×½/×2 BPM toggle; manual key override; "copy BPM & key."
**Implementation:** extend `MusicalKey` with a pure Camelot mapping (`TempoKeyCore`); add a
display-override layer in `AppState` (overrides never mutate the analysis); small header/toolbar
controls. No entitlement change.
**Tests:** Camelot mapping table, ×½/×2 math, override precedence.

## v0.3.0 — Library / Batch Analysis
**Features:** drop a folder or multiple files → sortable results table (file · BPM · key ·
Camelot · duration); CSV export; recent-files list.
**Implementation:** `BatchAnalyzer` running the existing `AnalysisEngine` over files with a
bounded `TaskGroup`; a results table view; CSV writer; security-scoped folder access. Reuses
the read-only entitlement.
**Tests:** CSV formatting, batch orchestration over synthesized files, sort/aggregate logic.

## v0.4.0 — Metadata Tagging & Export
**Features:** write detected BPM/key (+Camelot) into the file's tags (ID3 / MP4); export
analysis as JSON; export the report as a PNG (via `ImageRenderer`).
**Implementation:** metadata write (AVFoundation/`AVAssetExportSession` or a tagging helper);
`Codable` on `AnalysisResult`. **Entitlement:** upgrade `files.user-selected.read-only` →
`read-write`; re-run the security audit.
**Tests:** JSON encode/decode, tag write→read round-trip on a temp file.

## v0.5.0 — Playback & Beat Sync
**Features:** audio playback with a playhead synced across the timelines; click-to-seek; an
audible beat metronome; loop the zoom-selected region.
**Implementation:** `AVAudioEngine`/player node + a transport bar; playhead overlay driven by
playback time; metronome scheduled at detected beat times. No new entitlement (playing an
already-opened file).
**Tests:** transport state machine; beat-time→x mapping (audio path verified manually via the
`verify` flow).

## v0.6.0 — Deeper Musical Analysis
**Features:** downbeats & time-signature detection; explicit per-section tempo labels
(e.g., "140 → 130"); structural segmentation (intro/build/drop) with an energy curve.
**Implementation:** `TempoKeyCore` additions — bar grouping from beats, novelty-based
segmentation, RMS energy; extend `AnalysisResult`. New timeline tracks in the report.
**Tests:** synthetic signals for downbeat grouping, segment boundaries, energy curve.

## v0.7.0 — Real-Time Mode
**Features:** live BPM/key from the microphone or an audio input device.
**Implementation:** streaming path feeding the existing detectors incrementally (the BTT design
is inherently streaming); `AVAudioEngine` input tap; a live view. **Entitlement:** add
`device.audio-input` + `NSMicrophoneUsageDescription`; re-run the security audit + privacy
review.
**Tests:** streaming-wrapper correctness vs. the offline path on the same signal.

## v1.0.0 — Stabilization & Cross-Platform Launch
macOS: bug-fix pass, performance, accessibility, first-run onboarding, finalized docs — the
"it's solid" release. **This is also the Windows launch:** the `v1.0.0` GitHub release carries
both the notarized macOS `.dmg` and the Authenticode-signed Windows installer (`.exe`), at the
same version. Requires **Milestone R** complete, plus the Windows build/UI/signing work (below)
finished during the 0.7.0 → 1.0.0 run-up.

## Milestone R — Core portability seams (Windows enabler, macOS-side)
A behind-the-scenes refactor in `TempoKeyCore`, shippable in any macOS release with **no
user-facing change** (recommend landing it alongside v0.6.0, since that already touches the core):
- Introduce protocols for the Apple-coupled boundaries: `FFTProviding`
  (magnitude + generalized autocorrelation), `AudioDecoding` (`decode(url:) -> DecodedAudio`),
  and a windowing helper. Make `OnsetDetector`/`TempoTracker`/`Chromagram` depend only on these.
- Keep the current Apple implementations (`RealFFT` via vDSP, `AudioDecoder` via AVFoundation,
  `vDSP_hann_window`) as the macOS conformances — existing tests must stay green (it's a pure
  refactor). This is exactly the seam already described in `docs/WINDOWS.md`.

## Windows Launch — ships at the v1.0.0 milestone
**Timing:** the Windows port is built during the **0.7.0 → 1.0.0** run-up and **released with
v1.0.0** as the same version (not its own version line) — so the first Windows build is `1.0.0`,
targeting the now-stable macOS feature set.
**Prerequisites:** Milestone R complete; macOS feature surface settled (~v0.7.0).

**Open decision (resolve when starting the Windows work):** how to build the Windows app.
- *Recommended:* keep the Swift algorithm core (it compiles on Windows once the seams exist),
  provide Windows conformances — a cross-platform **FFT** (KissFFT/PFFFT/pocketfft) and **audio
  decode** (miniaudio/dr_libs or Media Foundation) — and build the UI either as a thin
  cross-platform shell (e.g. web/Tauri or .NET WinUI) calling the core, or a native WinUI front
  end. SwiftUI is **not** available on Windows, so the UI is net-new regardless.
- *Alternative:* reimplement the core in a portable language (C++/Rust) shared by both platforms
  — more reuse long-term, larger up-front cost.

**Versioning:** shares the macOS version. The first Windows build is **1.0.0**, published as an
additional asset on the `v1.0.0` release (`TempoKeySetup-1.0.0.exe` alongside
`TempoKey-1.0.0.dmg`). After 1.0, both platforms advance together on the same version tags.

**Windows release procedure (the Authenticode analog of the macOS pipeline):**
1. Build the Windows app/core (Swift toolchain on Windows, or the chosen stack).
2. **Sign** with a code-signing certificate:
   ```bat
   signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /f cert.pfx /p %PWD% TempoKey.exe
   ```
   (EV cert → immediate SmartScreen trust; OV cert → reputation builds over time. No Apple-style
   notarization exists on Windows — SmartScreen is the analog.)
3. **Package** an installer (Inno Setup `.exe` or WiX `.msi`) or a portable `.zip`; sign the
   installer too.
4. **Release:** attach the signed installer to the existing v1.0.0 release —
   `gh release upload v1.0.0 TempoKeySetup-1.0.0.exe` (macOS + Windows share one 1.0.0 release).
5. **CI (optional):** a `windows-latest` job (its own workflow or a job in `release.yml`) that
   builds, imports the signing cert from a secret, runs `signtool`, packages, and uploads —
   mirroring the gated macOS job.

**Auto-update:** add a Windows updater (the GitHub-Releases check works cross-platform; the
*install* step differs — download + run the signed installer).

## Future (separate tracks)
- **iOS** — analyze from Files/Music on iPhone/iPad (SwiftUI core UI largely reusable; the
  `TempoKeyCore` package already runs on iOS with minor platform tweaks).

---

## Notes
- The signed/notarized DMG pipeline (`scripts/package-dmg.sh`) and the guarded `release.yml`
  workflow are already in place — no per-version release tooling work is needed.
- Each full release is auto-surfaced to existing installs by the in-app update banner.
- Group scope can shift between versions; this is a sequence, not a contract.
