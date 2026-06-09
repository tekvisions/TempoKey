# Third-Party Attribution

This project's beat/tempo detection is a Swift translation of:

**Beat-and-Tempo-Tracking** by Michael Krzyzaniak
https://github.com/michaelkrzyzaniak/Beat-and-Tempo-Tracking
Licensed under the MIT License.

The original onset-detection, autocorrelation tempo-estimation, and CBSS beat-tracking
algorithms are due to that project. DSP primitives were reimplemented using Apple's
Accelerate framework. Musical key detection (chromagram + Krumhansl-Schmuckler) is original
to TempoKey.
