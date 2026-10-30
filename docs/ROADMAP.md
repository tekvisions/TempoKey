# TempoKey roadmap

Updated 2026-10-30. **macOS first**, per the current product scope. Release **0.7.0 (4)** consolidates the macOS milestones below. See the
[release notes](releases/v0.7.0.md) for the full change list and validation limits.

## Implemented in macOS 0.7.0

| Milestone | Status | Delivered behavior |
|---|---|---|
| 0.2 · Harmonic mixing | Implemented | Standard/Camelot/Open Key notation, compatible keys, tap tempo, numeric BPM, half/double, manual key, copy summary |
| 0.3 · Library | Implemented | Multi-file/folder import, deterministic deduplication, sortable table, per-file errors, cancellation, per-track corrections, security-scoped recents, CSV |
| 0.4 · Export | Implemented with format limits | Versioned JSON with raw/corrected values, PNG report, source-preserving MP3/M4A tagged copies |
| 0.5 · Playback | Implemented; hardware QA pending | Play/pause, keyboard controls, seek slider/timeline, shared playhead, visible-region loop, detected-beat click |
| 0.6 · Deeper analysis | Conservative implementation | RMS energy, energy/tempo-change sections with median local BPM, estimated 3/4 or 4/4 and downbeats when repeated accents support them |
| 0.7 · Live input | Implemented; device QA pending | Explicit microphone permission, selectable Core Audio input, bounded 12-second rolling window, one analysis at a time, silence/warm-up/error states |
| R · Portability seams | macOS seams implemented | Decoder, FFT, window, and resampler interfaces retain Apple backends; alternate platform backends remain future work |

### Intentional adjustments

- **Batch concurrency is one.** Whole-track PCM is memory intensive; a serial queue prevents
  multiple hour-long decoded buffers from exhausting memory. Work runs off the main actor.
- **Tagging saves a copy.** Original audio is never edited in place. MP3 writes ID3v2.3/2.4
  TBPM, TKEY, and a `TEMPOKEY_CAMELOT` user-text frame while preserving other frames/audio.
  Unsupported ID3 variants are rejected explicitly. M4A retains audio via passthrough,
  stores native BPM, and appends key/Camelot to the comment. M4A DJ-specific key atoms and
  FLAC/WAV tagging are not implemented.
- **Structure labels are neutral.** Energy changes do not reliably prove “intro/build/drop.”
  Sections are numbered. Meter is unknown for ambiguous/short/nonmatching rhythms;
  confidence is a heuristic, not a calibrated probability. Compound/irregular meters
  and genre-trained semantic section labels remain future research.
- **Live input uses rolling analysis.** It reuses the tested offline pipeline instead of
  exposing mutable DSP state to the audio callback. PCM is normalized to 44.1 kHz for
  consistent detector timing across input rates; audio is not saved or uploaded.
- **No cross-platform 1.0 claim.** The Windows frontend, decoder/FFT backends, installer,
  signing and platform validation are deferred.

## Reliability fixes included

- Cooperative decoding/DSP cancellation and generation checks prevent stale results.
- Empty/silent/invalid PCM is rejected; short clips do not invent a tempo consensus.
- Key segments cover the track without overlapping or counting a transition twice.
- Tap tempo uses the latest eight taps and resets on track changes.
- Recents use security-scoped bookmarks; source access remains active while needed.
- CSV handles quotes/newlines and guards formula-like filenames.
- Export checks reject the source path, symlink aliases and hard-link aliases.
- Live buffers have fixed capacity; stopping invalidates permission/analysis callbacks.
- Appearance persists; library navigation retains an in-progress batch.

## Release gates — remaining work

These are validation/release tasks, not completed claims:

- [ ] Audition varied real music (electronic, acoustic, changing tempo, quiet intros,
  percussion-only material) and record BPM/key accuracy against a curated corpus.
- [ ] On actual hardware: verify playback, metronome timing, loop boundaries, input-device
  removal/rate changes, microphone denial/regrant, and long live sessions.
- [ ] In the sandboxed Release app, use native panels to test external folders, bookmarked
  recents after relaunch, and exports to external drives. Local-folder import, bookmark
  relaunch and native-panel export outside the import folder passed; external drives remain.
- [ ] Visually inspect minimum-width layout, dark/light mode, VoiceOver, keyboard-only
  navigation, and timeline gestures. Home/report/library visual smoke checks passed in
  dark/light mode; exhaustive accessibility and sizing checks remain.
- [ ] Profile hour-long tracks and large folders for memory, CPU, cancellation latency.
- [x] Build universal Developer ID DMG, notarize app and DMG, staple both tickets, and
  validate Gatekeeper. GitHub distribution was explicitly authorized on 2026-10-30.
  Follow [RELEASING.md](RELEASING.md) and [RELEASING-GITHUB.md](RELEASING-GITHUB.md).

## Subsequent milestones

1. Complete the remaining hardware/accuracy checks; use 0.7.x patch releases for fixes.
2. Improve analysis using a measured corpus; add broader meter support and interoperable
   M4A key atoms if user demand warrants it.
3. Implement Windows backends/frontend and validate platform parity; see [WINDOWS.md](WINDOWS.md).
4. Publish 1.0 only when macOS stabilization and the agreed Windows launch are both ready.
5. Evaluate iOS separately after desktop workflows stabilize.
