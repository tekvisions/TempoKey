#!/usr/bin/env python3
"""Exercise the real benchmark CLI. No private audio or third-party dependencies."""
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import wave

binary = str(Path(sys.argv[1]).resolve())
with tempfile.TemporaryDirectory(prefix="tempokey-benchmark-") as directory:
    root = Path(directory)
    audio = root / "click.wav"
    with wave.open(str(audio), "wb") as output:
        output.setparams((1, 2, 44100, 0, "NONE", "not compressed"))
        output.writeframes(b"".join(struct.pack("<h", int(25000 * math.exp(-(i % 22050) / 8)))
                                    for i in range(12 * 44100)))
    manifest = root / "manifest.json"

    def run(tracks, expected, strict=False):
        manifest.write_text(json.dumps({"schemaVersion": 1, "tracks": tracks}))
        process = subprocess.run([binary, str(manifest)] + (["--require-labels"] if strict else []),
                                 capture_output=True, text=True)
        assert process.returncode == expected, (process.returncode, process.stderr, process.stdout)
        return json.loads(process.stdout)

    unlabeled = run([{"path": "click.wav"}], 0)
    assert unlabeled["analyzed"] == 1 and unlabeled["tempoLabels"] == 0
    assert unlabeled["measurements"][0]["labelStatus"] == "unlabeled"
    run([{"path": "click.wav"}], 1, strict=True)
    labeled = run([{"path": "click.wav", "reference": {"bpm": 120}}], 0)
    assert labeled["exactTempoMatches"] == 1 and labeled["tempoLabels"] == 1
    assert labeled["fullyLabeled"] == 0 and labeled["keyLabels"] == 0
    mismatch = run([{"path": "click.wav", "reference": {"bpm": 60}}], 1)
    assert mismatch["exactTempoMatches"] == 0 and mismatch["octaveTempoMatches"] == 1
    mixed = run([{"path": "missing.mp3"}, {"path": "click.wav"}], 1)
    assert mixed["analyzed"] == 1 and len(mixed["measurements"]) == 2
    assert mixed["measurements"][0]["error"]
    assert mixed["measurements"][1]["file"] == "click.wav"
    assert str(root) not in json.dumps(mixed), "Reports should not expose local directory paths"
    manifest.write_text('{"schemaVersion":999,"tracks":[]}')
    assert subprocess.run([binary, str(manifest)], capture_output=True).returncode == 2
    assert subprocess.run([binary], capture_output=True).returncode == 2
print("Benchmark CLI: unlabeled, strict, labeled, octave mismatch, mixed failure, relative paths, invalid manifest and usage passed")
