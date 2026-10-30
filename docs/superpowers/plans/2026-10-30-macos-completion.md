# macOS completion implementation plan

**Goal:** Complete the macOS roadmap workflows and fix existing analysis lifecycle defects.
**Architecture:** UI-free analysis models; main-actor app orchestration; separate transport, live capture, export, and recent-file services.
**Tech stack:** Swift, SwiftUI, AVFoundation, Accelerate, XCTest; macOS 14+.
**Spec:** `docs/superpowers/specs/2026-10-30-macos-completion-design.md`

## Global constraints
- macOS 14+, offline analysis, no third-party runtime dependencies.
- Preserve source audio and raw measurements; exported corrections are explicit.
- No publishing, signing, Windows implementation, or 1.0 release claim in this pass.

## Review focus
- Reset/reimport during analysis must ignore stale work.
- Silence/short files must not report confident musical results.
- Folder scopes must cover child decoding and playback.
- Export destinations must never replace source audio accidentally.
- Live stop/restart must discard old permission requests and pending analyses.

## Task 1: Analysis foundations and deeper analysis
- [x] Tests: cancellation, empty/silent input, nonoverlapping key coverage, JSON round trip, Open Key mapping, RMS sections and meter ambiguity, streaming boundedness.
- [x] Implement Codable models, decoder/FFT/window seams, cooperative cancellation, sample-array analysis, deeper analysis and bounded streaming helper in TempoKeyCore.
- [x] Run `swift test --package-path TempoKeyCore` and review algorithms and compatibility.

## Task 2: Library and state lifecycle
- [x] Add folder expansion/deduplication, bounded serial batch queue, per-row state and corrections, persisted security-scoped recents.
- [x] Integrate cancel/replacement protection, multi-import, sortable table, report navigation, onboarding, persisted appearance.
- [x] Add tests covering queue cancellation and library utilities; verify hosted tests.

## Task 3: Export and metadata
- [x] Implement CSV escaping, versioned JSON with corrections, standalone report PNG.
- [x] Implement source-preserving MP3/M4A tagged copies, reject same-file destinations, verify metadata round trips.
- [x] Connect native save panels and actionable error reporting.

## Task 4: Transport and live input
- [x] Implement transport state/boundaries, AVFoundation playback, timeline seeking/playhead and region loop, beat click.
- [x] Implement live input permissions, device selection, bounded capture and analysis, clear stop/error semantics.
- [x] Add entitlements/privacy purpose string and unit tests. Native UI smoke inspection completed after restart; exhaustive hardware/a11y checks remain release gates.

## Task 5: Integration and release readiness
- [x] Run full core/app suites, Debug/Release builds; independent code review and fixes.
- [x] Update README and roadmap with implemented features, validation evidence, and remaining release/manual gates.

Execution ruling: user authorized implementation and macOS-first scope; proceed through reversible local implementation without repeated approval gates. Work on `codex/macos-roadmap` in the existing clean checkout so the desktop workspace continues to show the changes.

Validation record: `docs/VALIDATION.md`. Reversible local implementation is complete; manual hardware/sandbox/visual validation and publication remain explicitly tracked in `docs/ROADMAP.md`.
