# macOS development validation — 2026-10-30

Build: 0.7.0 (4), branch `codex/macos-roadmap`. This records local development verification,
not release certification.

## Automated checks

- Core XCTest: **49 tests pass** (baseline 25); expanded suite includes cancellation, empty/silent PCM,
  key-segment coverage, JSON compatibility, Open Key, FFT/window injection, energy,
  meter ambiguity, bounded buffers, sample-rate normalization and tempo sections.
- Hosted app XCTest: **34 tests pass**, including mixed success/failure batches, obsolete
  analysis reset, bookmark persistence, CSV escaping, raw/corrected JSON, PNG rendering,
  source/symlink protection, MP3 payload preservation, M4A metadata readback, fixed-capacity
  stereo-to-mono capture buffering, playback load/seek/close and tap-tempo adaptation.
- Post-restart verification logs are retained in `.superpowers/validation/`.
- Debug test build and sandboxed Release build succeed with Xcode 27.2.
- `git diff --check` and plist lint pass.
- Release app signature verifies with `codesign --verify --deep --strict`; entitlements
  include sandbox, user-selected read/write, app-scoped bookmarks, audio input and network client.
  Release explicitly disables base-entitlement injection; `get-task-allow` is absent.
- Independent code review identified sample-rate timing as a defect. Reproduction before:
  a 120 BPM track yielded 0 BPM at 8 kHz and ~178 BPM at 384 kHz. After normalization,
  the same probe yielded ~120.754 BPM and 23 beats at 8/44.1/384 kHz. Scoped re-review accepted.
- Final scoped review caught false section boundaries from brief tempo plateaus.
  Regression fixtures at 1.25 and 3 seconds failed before the fix and now pass; both
  sides of a tempo boundary require sustained evidence over the minimum section span.
  Independent scoped re-review accepted the fix.
- Review also prompted sandbox-safe export staging and playback/file-scope cleanup on
  window close. PNG report output was rendered and visually inspected as an image.

## Interactive Release checks

After the restart, native UI automation became available. Verified the sandboxed Release app:
- Imported a folder containing synthesized WAV/M4A audio through NSOpenPanel; both rows completed.
- Opened a report and inspected the timelines; applied a numeric 128 BPM correction.
- Exported an M4A through NSSavePanel to a sibling directory outside the imported folder;
  read back its corrected BPM/key/Camelot comment. Native BPM readback is covered by XCTest.
- Started playback, observed the transport time advance, and paused it.
- Quit/relaunched the app and successfully reanalyzed the recent folder through its bookmark.
- Inspected the dark home/report and light library; restored System appearance.
- Opened live-input controls without starting capture or requesting microphone permission.
- Narrowed live window-close handling to the main window; fixed ownership of Core Audio names.

## Not verified by these checks

- Live microphone permission/denial, device unplug/rate changes, long capture sessions.
- Audible playback, metronome latency and loop timing on actual hardware.
- External-drive exports and device/file removal during operations.
- Exhaustive window-resizing, VoiceOver and gesture usability testing.
- Real-music accuracy corpus, hour-long file memory profile, minimum supported macOS runtime.
- Windows implementation/runtime validation.

See [ROADMAP.md](ROADMAP.md) for the release checklist. The environment prints unrelated
CoreSimulator-version and AppIntents metadata-extraction diagnostics; macOS tests/builds
complete successfully. No simulator is used.

Runnable local artifact: `dist/TempoKey-0.7.0.app` (development signed; not notarized).

## GitHub release distribution verification

The user subsequently authorized GitHub release publication. Built `TempoKey-0.7.0.dmg`
from the release source with the universal packaging script and Developer ID Application:
Kymata Labs LLC (72G9XN68CV).

- App notarization accepted: `f4a99b9d-647b-45f4-88b6-87bbe9f0e204`.
- DMG notarization accepted: `66f9ff59-567c-4154-9686-a7cc9969fa77`.
- App and DMG tickets stapled and independently validated.
- Gatekeeper accepts both artifacts as `Notarized Developer ID`.
- Mounted DMG verified: version 0.7.0, arm64 and x86_64 slices, MIT license and upstream
  notice resources, sandbox/input/bookmark/file/network entitlements, no `get-task-allow`.
- Integrated-source verification again passed 49 core and 34 hosted app tests.
- Distribution assets: `TempoKey-0.7.0.dmg` and `TempoKey-0.7.0.sha256`.
- Full release notes: [v0.7.0](releases/v0.7.0.md).
