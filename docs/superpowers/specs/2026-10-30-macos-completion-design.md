# macOS completion design

User intent: revive TempoKey and implement the remaining useful roadmap functionality. User selected macOS first; Windows implementation and release publication are excluded from this pass.

Keep SwiftUI/macOS 14 and the offline Swift analysis core. No third-party runtime dependencies. Preserve detected measurements separately from per-track corrections. Use native materials, clear hierarchy, keyboard controls, accessible labels, and light/dark/system appearance.

## Workflows
- Import multiple audio files or folders into a bounded analysis queue. Show individual successes/errors, cancellation, sortable results, and persistent security-scoped recents. Never let obsolete tasks replace current results.
- Export CSV, structured JSON, and a report PNG. Include user corrections and original measurements. Metadata export creates a separate tagged audio copy; never silently overwrite source audio. Support MP3 ID3 and M4A metadata, reporting unsupported formats explicitly.
- Playback with play/pause, seeking, shared playhead, looping of the visible region, and beat click. Release file scopes when transport closes. Stop playback before microphone capture.
- Energy/section timeline, estimated meter/downbeats with uncertainty, and section tempo. Do not present inferred intro/build/drop labels as ground truth.
- Explicit live-input start/stop, microphone permission, bounded rolling audio analysis, input-device selection, and clear warming-up/silence/error states. Stop capture when leaving live mode.
- Core seams for decoding, FFT, and window generation; preserve Apple implementations and numerical tests.

## Reliability
Cancel obsolete work, reject invalid/empty/silent audio, avoid unbounded parallel decoded buffers, keep UI responsive, reset tap state per track. Key segments must partition the timeline without overlaps. Limit live analysis backlog to one job.

## Acceptance
Core and hosted app tests pass; Debug and Release builds succeed. Verify export round trips, cancellation/replacement, folder expansion/deduplication, sorting, recents failures, transport boundaries, and streaming boundedness. Record manual audio/device and release-signing checks separately from automated evidence. Roadmap records shipped implementation versus release gates honestly; do not call this a cross-platform 1.0 release.
