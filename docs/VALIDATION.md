# macOS validation — 0.7.1 (5), 2026-10-30

Host: Apple M4, macOS 27.0.1, Xcode 27.2. Scope remains macOS first.
Local logs and private fixtures are under `.superpowers/validation/0.7.1/` (git ignored).

## Automated verification

- **59 core tests and 39 hosted app tests pass: 98 total, zero failures.**
- Regressions reproduced before fixes: stale tempo/beats through silence; confidence based
  only on the ending; silence outvoting the musical key; zero-evidence C major merging into
  confident regions; smoothing stale tempo across a gap; ID3v2.3 Camelot string decoding;
  valid empty ID3 tag rejection. Each is green after the fix.
- Report tests cover missing-evidence line runs/hover and key-only correction captions.
- 2,000-file folder enumeration remains naturally sorted and deduplicates overlapping inputs.
- The real benchmark CLI passes unlabeled/default and strict-label behavior, independent
  120 BPM reference, octave mismatch, mixed success/failure, relative paths, schema and usage
  checks. The separate evaluator covers key mismatch and invalid references.
- Independent read-only review found cross-gap median smoothing could replace a resumed
  150 BPM section with 90 BPM. Focused 3.5/4-second regressions failed before the fix and
  passed afterward, followed by complete core/app suite runs. No other material findings.
- Later MP3 readback found a pre-existing ID3v2.3 TXXX bug: Unicode description/value were
  encoded as a single BOM-prefixed string, so the value decoded incorrectly independently.
  Newly generated ASCII fields now use Latin-1; unrelated frames remain byte-identical.
  Reference: [ID3v2.3 text encoding rules](https://id3.org/id3v2.3.0).

## Supplied MP3 corpus and exports

Three private recordings (239.49, 326.23 and 379.60 seconds, stereo 44.1 kHz MP3) analyze
successfully in the CLI and through native multi-selection in the sandboxed Release app.
Typical measured analysis times were 0.9–1.4 seconds per file. Whole-track predictions
remain approximately 89.79, 108.26 and 100.93 BPM; these are **not reference labels**.
No reference BPM/key tags were present. Accuracy denominators therefore remain zero.

For all three tagged copies, the original SHA-256 hashes remain unchanged, the complete
MP3 audio payloads match byte-for-byte, and original non-tempo/key frames—including artwork
and lyrics—remain unchanged. Independent `ffprobe` readback now reports TBPM, TKEY and
TEMPOKEY_CAMELOT without diagnostics. Supplied audio, lyrics, artwork, hashes and private
paths are not committed or included in GitHub assets.

## Resource profile

Comparable optimized standalone probes, one-hour mono 44.1 kHz synthesized WAV:

| Measurement | 0.7.0 baseline | Stabilized decoder |
|---|---:|---:|
| Analysis wall time | 9.49 s | 9.33 s |
| Peak resident size | 1,353,908,224 bytes | 714,326,016 bytes |
| Peak memory footprint | 1,345,963,664 bytes | 706,036,888 bytes |

The 1 GiB resident-memory budget failed before reservation and passed afterward (about
47% reduction). Whole-track PCM is still retained; this is not constant-memory streaming.
Cancellation probes during decoding and DSP completed in under 1 ms after cancellation
was requested, passing a 500 ms local budget. This is not a worst-case latency guarantee.

## Native Release smoke checks

- Imported exactly the three supplied originals through NSOpenPanel; 3/3 library rows completed.
- Inspected dark and light report layouts; restored System appearance.
- Zoomed the timeline, moved later using the new button, then moved earlier using the
  overview's exposed accessibility Decrement action; reported ranges changed correctly.
- Exported a tagged MP3 using NSSavePanel to the validation directory outside the original
  import folder. Saved copy decoded and its BPM/key tags read back correctly. Subsequent
  encoding regressions/readback validate the final Camelot fix.
- Keyboard-only and spoken VoiceOver end-to-end behavior were not exhaustively audited;
  exposed accessibility actions are a smoke check, not full accessibility certification.

## Remaining validation

Independently labeled and varied musical corpus; actual microphone denial/regrant, device
unplug/rate changes and long capture; audible metronome/loop timing; external drives;
minimum-size/full keyboard/VoiceOver audit; large analyzed libraries and diverse long-file
codecs; Intel and minimum-supported macOS runtime. Windows/iOS remain deferred.

Distribution verification follows below when the 0.7.1 signed/notarized artifacts are ready.

---

# Historical 0.7.0 validation — 2026-10-30

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
