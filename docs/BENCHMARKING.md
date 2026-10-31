# Local analysis corpus

`tempokey-benchmark` runs the same offline engine as the app, serially. It emits JSON
containing each file's duration, wall time, detected BPM/key, tempo evidence, reference
comparisons, and any error. The report contains filenames rather than absolute paths.
Audio and embedded metadata are never uploaded or included in the report.

```sh
swift run --package-path TempoKeyCore -c release tempokey-benchmark /path/to/manifest.json
```

Manifest paths are absolute or relative to the manifest itself:

```json
{
  "schemaVersion": 1,
  "tracks": [
    { "path": "music/unlabeled.mp3" },
    {
      "path": "music/reference.wav",
      "reference": { "bpm": 120, "key": { "tonic": 0, "mode": "major" } }
    }
  ]
}
```

Use independently curated reference labels, never this tool's predictions as ground truth.
`tonic` is a chromatic integer (C=0, C♯=1, …, B=11), `mode` is `major` or `minor`.
References may contain BPM, key, both, or neither. Unlabeled tracks remain explicitly
unlabeled and do not enter accuracy denominators. A tempo match allows 2% error; octave
matches are reported separately and never count as exact. Key matches require tonic and
mode to match exactly. Whole-track labels are insufficient to validate changing-tempo/key
tracks; inspect and label their sections separately before making accuracy claims.

Exit codes: **0** all analyses and supplied reference checks pass; **1** a file fails,
a supplied reference does not match, or required labels are missing; **2** invalid usage
or manifest. Processing continues after individual file failures. Add `--require-labels`
to require both reference labels on every track.

Keep private manifests/audio in `.superpowers/validation/` (git ignored) or outside the
repository. Do not commit third-party music, lyrics, artwork, or private directory paths.

## Repeatable checks

```sh
swift build --package-path TempoKeyCore -c release --product tempokey-benchmark
python3 scripts/test-benchmark.py "$(swift build --package-path TempoKeyCore -c release --show-bin-path)/tempokey-benchmark"
/usr/bin/time -l "$(swift build --package-path TempoKeyCore -c release --show-bin-path)/tempokey-benchmark" /path/to/manifest.json
```

Record host, build, codec, duration, wall time, maximum resident size, and cancellation
latency. Compare optimized builds on the same host. The app supports at most one hour per
file and analyzes one library item at a time. Whole-track PCM still scales with duration;
this is not a streaming decoder. A one-hour mono 44.1 kHz buffer alone needs about 606 MiB.

`bpmConfidence` in analysis JSON now measures the fraction of local estimates agreeing
within 3 BPM or 3% of the whole-track estimate, with a short-track evidence penalty and
0.95 ceiling. It is a heuristic agreement score, not a calibrated probability of accuracy.
The app labels it strong/mixed/weak evidence. Half/double-time or other rhythmic
interpretation errors still require listening and manual correction.
