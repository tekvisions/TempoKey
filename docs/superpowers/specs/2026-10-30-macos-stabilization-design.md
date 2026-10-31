# macOS stabilization — 0.7.1

The user authorized autonomous roadmap continuation and GitHub publication, supplied three
private MP3s for local testing, and previously selected macOS first.

## Scope

This is a bounded stabilization of existing analysis, library, and report flows:
- Establish a repeatable, local corpus runner with JSON measurements, optional independently
  supplied reference BPM/key labels, explicit unlabeled status, and per-file errors.
- Stop carrying tempo/beat estimates through sustained digital silence. Confidence should
  describe agreement across the analyzed track, not the final histogram peak; UI should
  describe evidence strength without implying calibrated probability.
- Profile the supported one-hour limit, memory growth and cooperative cancellation; repair
  defects found by measurements, retaining the serial library queue.
- Exercise the provided files, real MP3 metadata preservation, and sandboxed UI. Improve
  keyboard/accessibility labels where inspection finds gaps.
- Publish 0.7.1 with complete notes, universal signed/notarized DMG and checksums.

## Constraints

Do not publish the supplied audio, lyrics, private filesystem paths, or embedded artwork.
No guessed reference labels and no accuracy claims from unlabeled music. Keep existing
analysis JSON backward compatible. Windows/iOS, semantic section labels, broader meters,
and untestable hardware cases remain explicitly deferred. Originals must remain byte-identical.

## Verification

Regression tests before behavior fixes; full core and hosted app suites; three-file local
corpus report; hour-long benchmark and cancellation; native Release smoke check; fresh
independent review; universal signature, notarization, stapling, Gatekeeper and GitHub asset
verification. Hardware tests requiring physical intervention remain honestly unverified.
