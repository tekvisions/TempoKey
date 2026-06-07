# TempoKey Core (Analysis Engine) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `TempoKeyCore`, a pure-Swift, UI-free Swift Package that decodes an audio file and produces an `AnalysisResult` containing overall BPM + key and how tempo/key vary over time.

**Architecture:** A Swift Package with no AppKit/UI. DSP primitives use Apple's Accelerate/vDSP. The beat/tempo logic is a Swift translation of the MIT-licensed Beat-and-Tempo-Tracking (BTT) C library; key detection is net-new (chromagram + Krumhansl-Schmuckler). An `AnalysisEngine` orchestrates decode → beat/tempo → key → `AnalysisResult`. Everything testable via XCTest using synthetic signals.

**Tech Stack:** Swift 5.9+, Swift Package Manager, Accelerate (vDSP), AVFoundation (decoding only), XCTest.

**Reference source (the implementer should open these):**
- `https://github.com/michaelkrzyzaniak/Beat-and-Tempo-Tracking` — files `src/BTT.c`, `BTT.h`, `src/STFT.c`, `src/Statistics.c`.
- License: MIT (attribution required — handled in Task 12).

**Derived constants used throughout (compute once, reuse):**
- Analysis sample rate `SR = 44100`
- STFT length `N = 1024`, overlap `8` → hop `H = N / 8 = 128`
- OSS (onset-strength-signal) rate `ossRate = SR / H = 344.53 Hz`
- OSS ring-buffer length `ossLen = 1024` (~2.97 s of history)
- Tempo range `50…200 BPM`. Lag↔BPM: `bpm = 60 * ossRate / lag`; `lag = 60 * ossRate / bpm` (range ≈ 103…413 OSS samples)
- Generalized autocorrelation exponent `0.5`
- Tempo histogram: decay `0.999`, gaussian width `5` (lag samples), log-gaussian tempo bias mean `120 BPM`, width `75`
- CBSS: `alpha = 0.9`, `eta = 300`

---

## File Structure

```
TempoKeyCore/                                  (Swift Package root)
├── Package.swift
├── NOTICE.md                                  (BTT MIT attribution)
└── Sources/TempoKeyCore/
    ├── DSP/
    │   └── RealFFT.swift                      vDSP real FFT: magnitude spectrum + generalized autocorrelation
    ├── BeatTracking/
    │   ├── Statistics.swift                   RunningStats + AdaptiveThreshold
    │   ├── OnsetDetector.swift                STFT framing → spectral flux → 10 Hz LPF → OSS samples
    │   ├── TempoTracker.swift                 generalized autocorrelation → peaks → decaying histogram → BPM
    │   ├── BeatTracker.swift                  CBSS accumulation → beat peak extraction
    │   └── BeatTempoTracker.swift             orchestrates onset→tempo→cbss per hop; collects series + beats
    ├── KeyDetection/
    │   ├── MusicalKey.swift                   PitchClass, Mode, MusicalKey, circle-of-fifths hue
    │   ├── Chromagram.swift                   FFT magnitude → 12 pitch-class energies
    │   └── KeyDetector.swift                  windowed chroma → Krumhansl-Schmuckler → KeySegments + overall key
    ├── Audio/
    │   └── AudioDecoder.swift                 AVAudioFile → mono Float32 @ 44100
    └── Analysis/
        ├── AnalysisResult.swift              TempoPoint, KeySegment, AnalysisResult
        └── AnalysisEngine.swift              decode → beat/tempo + key → AnalysisResult (+ progress)
└── Tests/TempoKeyCoreTests/
    ├── TestSignals.swift                      helpers: click tracks, tones/chords, temp WAV writer
    ├── StatisticsTests.swift
    ├── RealFFTTests.swift
    ├── OnsetDetectorTests.swift
    ├── TempoTrackerTests.swift
    ├── ChromagramTests.swift
    ├── KeyDetectorTests.swift
    ├── AudioDecoderTests.swift
    └── AnalysisEngineTests.swift
```

---

## Task 1: Swift Package scaffold

**Files:**
- Create: `TempoKeyCore/Package.swift`
- Create: `TempoKeyCore/Sources/TempoKeyCore/Placeholder.swift`
- Create: `TempoKeyCore/Tests/TempoKeyCoreTests/SmokeTests.swift`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TempoKeyCore",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TempoKeyCore", targets: ["TempoKeyCore"]),
    ],
    targets: [
        .target(name: "TempoKeyCore"),
        .testTarget(name: "TempoKeyCoreTests", dependencies: ["TempoKeyCore"]),
    ]
)
```

- [ ] **Step 2: Create a placeholder source so the target compiles**

`Sources/TempoKeyCore/Placeholder.swift`:
```swift
enum TempoKeyCoreVersion { static let value = "0.1.0" }
```

- [ ] **Step 3: Write a smoke test**

`Tests/TempoKeyCoreTests/SmokeTests.swift`:
```swift
import XCTest
@testable import TempoKeyCore

final class SmokeTests: XCTestCase {
    func testPackageBuilds() {
        XCTAssertEqual(TempoKeyCoreVersion.value, "0.1.0")
    }
}
```

- [ ] **Step 4: Build and test**

Run: `cd TempoKeyCore && swift test`
Expected: builds, `testPackageBuilds` PASSES.

- [ ] **Step 5: Commit** (only if the user has initialized git; otherwise skip all commit steps)

```bash
git add TempoKeyCore && git commit -m "chore: scaffold TempoKeyCore swift package"
```

---

## Task 2: Statistics (RunningStats + AdaptiveThreshold)

**Files:**
- Create: `Sources/TempoKeyCore/BeatTracking/Statistics.swift`
- Test: `Tests/TempoKeyCoreTests/StatisticsTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TempoKeyCore

final class StatisticsTests: XCTestCase {
    func testRunningMeanAndStd() {
        var s = RunningStats(capacity: 4)
        for v in [2.0, 4.0, 4.0, 4.0] { s.push(v) }   // window full: [2,4,4,4]
        XCTAssertEqual(s.mean, 3.5, accuracy: 1e-9)
        // population std of [2,4,4,4] = sqrt( ( (1.5^2)+(0.5^2)*3 )/4 ) = sqrt(3/4) = 0.8660254
        XCTAssertEqual(s.std, 0.8660254, accuracy: 1e-6)
    }

    func testAdaptiveThresholdDetectsSpike() {
        var t = AdaptiveThreshold(window: 8, numStdDevs: 2.0, floor: 0.0)
        for _ in 0..<8 { _ = t.update(0.1) }     // baseline ~0.1, ~0 variance
        XCTAssertTrue(t.update(5.0), "a large jump above mean+2*std should cross threshold")
        XCTAssertFalse(t.update(0.1), "a value at baseline should not cross")
    }
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `swift test --filter StatisticsTests`
Expected: FAIL — `RunningStats`/`AdaptiveThreshold` undefined.

- [ ] **Step 3: Implement**

`Sources/TempoKeyCore/BeatTracking/Statistics.swift`:
```swift
import Foundation

/// Fixed-size sliding window mean/std (population). O(1) push using running sums.
struct RunningStats {
    private var buffer: [Double]
    private var index = 0
    private var filled = 0
    private var sum = 0.0
    private var sumSq = 0.0

    init(capacity: Int) {
        precondition(capacity > 0)
        buffer = Array(repeating: 0, count: capacity)
    }

    mutating func push(_ value: Double) {
        if filled == buffer.count {
            let old = buffer[index]
            sum -= old; sumSq -= old * old
        } else {
            filled += 1
        }
        buffer[index] = value
        sum += value; sumSq += value * value
        index = (index + 1) % buffer.count
    }

    var count: Int { filled }
    var mean: Double { filled == 0 ? 0 : sum / Double(filled) }
    var variance: Double {
        guard filled > 0 else { return 0 }
        let m = mean
        return max(0, sumSq / Double(filled) - m * m)
    }
    var std: Double { variance.squareRoot() }
}

/// Returns true when the newest value exceeds mean + numStdDevs*std (and an absolute floor).
struct AdaptiveThreshold {
    private var stats: RunningStats
    private let numStdDevs: Double
    private let floor: Double

    init(window: Int, numStdDevs: Double, floor: Double) {
        stats = RunningStats(capacity: window)
        self.numStdDevs = numStdDevs
        self.floor = floor
    }

    mutating func update(_ value: Double) -> Bool {
        let threshold = max(floor, stats.mean + numStdDevs * stats.std)
        stats.push(value)
        return value > threshold && value > floor
    }
}
```

- [ ] **Step 4: Run test, verify PASS**

Run: `swift test --filter StatisticsTests` → PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoKeyCore/BeatTracking/Statistics.swift Tests/TempoKeyCoreTests/StatisticsTests.swift
git commit -m "feat(core): running stats + adaptive threshold"
```

---

## Task 3: RealFFT (vDSP wrapper)

**Files:**
- Create: `Sources/TempoKeyCore/DSP/RealFFT.swift`
- Test: `Tests/TempoKeyCoreTests/RealFFTTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TempoKeyCore

final class RealFFTTests: XCTestCase {
    func testMagnitudeOfSingleBin() {
        let n = 64
        let fft = RealFFT(size: n)
        // pure cosine at bin k=4 → magnitude concentrated at index 4
        var x = [Float](repeating: 0, count: n)
        for i in 0..<n { x[i] = cos(2 * .pi * 4 * Float(i) / Float(n)) }
        let mag = fft.magnitudes(x)          // length n/2+1
        XCTAssertEqual(mag.count, n/2 + 1)
        let peak = mag.firstIndex(of: mag.max()!)!
        XCTAssertEqual(peak, 4)
    }

    func testAutocorrelationOfPeriodicSignalPeaksAtPeriod() {
        let n = 256
        let fft = RealFFT(size: n)
        let period = 16
        var x = [Float](repeating: 0, count: n)
        for i in stride(from: 0, to: n, by: period) { x[i] = 1 }   // impulse train
        let ac = fft.generalizedAutocorrelation(x, exponent: 0.5)  // length n
        // ignore lag 0; the largest peak among lags >= 1 should be near `period`
        let searchable = Array(ac[1...]).enumerated().max(by: { $0.element < $1.element })!
        let lag = searchable.offset + 1
        XCTAssertTrue(abs(lag - period) <= 1, "expected lag ≈ \(period), got \(lag)")
    }
}
```

- [ ] **Step 2: Run, verify it fails** — `swift test --filter RealFFTTests` → FAIL (RealFFT undefined).

- [ ] **Step 3: Implement**

`Sources/TempoKeyCore/DSP/RealFFT.swift`:
```swift
import Accelerate

/// Real-input FFT helpers built on vDSP. `size` must be a power of two.
final class RealFFT {
    let size: Int
    private let log2n: vDSP_Length
    private let setup: FFTSetup
    private let halfN: Int

    init(size: Int) {
        precondition(size > 0 && (size & (size - 1)) == 0, "size must be a power of two")
        self.size = size
        self.halfN = size / 2
        self.log2n = vDSP_Length(log2(Double(size)))
        self.setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    /// Magnitude spectrum, length size/2 + 1 (DC … Nyquist).
    func magnitudes(_ input: [Float]) -> [Float] {
        precondition(input.count == size)
        var real = [Float](repeating: 0, count: halfN)
        var imag = [Float](repeating: 0, count: halfN)
        var mags = [Float](repeating: 0, count: halfN + 1)

        input.withUnsafeBufferPointer { inPtr in
            real.withUnsafeMutableBufferPointer { rp in
                imag.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                    // pack real input into split-complex form
                    inPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { cplx in
                        vDSP_ctoz(cplx, 2, &split, 1, vDSP_Length(halfN))
                    }
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
                    // In packed format: real[0]=DC, imag[0]=Nyquist
                    let nyquist = abs(ip[0])
                    ip[0] = 0
                    var tmp = [Float](repeating: 0, count: halfN)
                    vDSP_zvabs(&split, 1, &tmp, 1, vDSP_Length(halfN))
                    // vDSP packs values at 2x; scale by 0.5 to get true magnitude
                    var half: Float = 0.5
                    vDSP_vsmul(tmp, 1, &half, &tmp, 1, vDSP_Length(halfN))
                    for i in 0..<halfN { mags[i] = tmp[i] }
                    mags[0] = abs(rp[0]) * 0.5     // DC
                    mags[halfN] = nyquist * 0.5    // Nyquist
                }
            }
        }
        return mags
    }

    /// Generalized autocorrelation via IFFT(|X|^(2*exponent)). Returns `size` real lags.
    /// exponent 1.0 == standard autocorrelation; 0.5 == BTT default.
    func generalizedAutocorrelation(_ input: [Float], exponent: Float) -> [Float] {
        precondition(input.count == size)
        var real = [Float](repeating: 0, count: halfN)
        var imag = [Float](repeating: 0, count: halfN)
        var out = [Float](repeating: 0, count: size)

        input.withUnsafeBufferPointer { inPtr in
            real.withUnsafeMutableBufferPointer { rp in
                imag.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                    inPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { cplx in
                        vDSP_ctoz(cplx, 2, &split, 1, vDSP_Length(halfN))
                    }
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Forward))
                    // power spectrum: |X|^2, then raise to `exponent`
                    for i in 0..<halfN {
                        let p = rp[i] * rp[i] + ip[i] * ip[i]
                        let shaped = powf(p, exponent)
                        // store shaped magnitude back as a zero-phase spectrum
                        rp[i] = shaped
                        ip[i] = 0
                    }
                    // inverse FFT to get autocorrelation lags
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(kFFTDirection_Inverse))
                    var scale = Float(1.0 / Float(size))
                    vDSP_vsmul(rp.baseAddress!, 1, &scale, rp.baseAddress!, 1, vDSP_Length(halfN))
                    vDSP_vsmul(ip.baseAddress!, 1, &scale, ip.baseAddress!, 1, vDSP_Length(halfN))
                    // unpack: real lags interleave rp/ip (packed real-FFT inverse)
                    rp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: 0) { _ in }
                    out.withUnsafeMutableBufferPointer { op in
                        op.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: halfN) { cplx in
                            vDSP_ztoc(&split, 1, cplx, 2, vDSP_Length(halfN))
                        }
                    }
                }
            }
        }
        return out
    }
}
```

> **Implementer note:** vDSP packed real-FFT scaling is fiddly. The tests only assert *peak location* (bin index / lag), which is scale-invariant, so don't chase exact amplitudes. If `generalizedAutocorrelation` peak indices look off by the packing, verify the `ctoz`/`ztoc` stride and the half-size memory rebind against Apple's "Data Packing for Fourier Transforms" doc.

- [ ] **Step 4: Run, verify PASS** — `swift test --filter RealFFTTests` → PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoKeyCore/DSP Tests/TempoKeyCoreTests/RealFFTTests.swift
git commit -m "feat(core): vDSP real FFT magnitude + generalized autocorrelation"
```

---

## Task 4: Test signal helpers

**Files:**
- Create: `Tests/TempoKeyCoreTests/TestSignals.swift`

- [ ] **Step 1: Implement helpers (no test of their own; used by later tests)**

```swift
import Foundation
import AVFoundation

enum TestSignals {
    static let sr: Double = 44100

    /// Impulse "click track" at a given BPM for `seconds`.
    static func clickTrack(bpm: Double, seconds: Double, sampleRate: Double = sr) -> [Float] {
        let n = Int(seconds * sampleRate)
        var x = [Float](repeating: 0, count: n)
        let period = Int((60.0 / bpm) * sampleRate)
        var i = 0
        while i < n {
            // short decaying click so there is spectral content across bins
            for k in 0..<min(64, n - i) { x[i + k] = Float(exp(-Double(k) / 8.0)) }
            i += period
        }
        return x
    }

    /// Sum of equal-amplitude sinusoids (Hz). Useful for chords/tones.
    static func tones(_ freqs: [Double], seconds: Double, sampleRate: Double = sr) -> [Float] {
        let n = Int(seconds * sampleRate)
        var x = [Float](repeating: 0, count: n)
        for f in freqs {
            for i in 0..<n { x[i] += Float(sin(2 * .pi * f * Double(i) / sampleRate)) }
        }
        let scale = Float(1.0 / Double(max(1, freqs.count)))
        return x.map { $0 * scale }
    }

    /// Equal-temperament frequency for a note name like "C4", "A4", "E4".
    static func freq(_ note: String) -> Double {
        let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let letter = note.prefix(while: { !$0.isNumber || $0 == "#" })
        let octave = Int(note.suffix(from: note.firstIndex(where: { $0.isNumber })!))!
        let semitone = names.firstIndex(of: String(letter))!
        let midi = (octave + 1) * 12 + semitone        // C-1 = 0
        return 440.0 * pow(2.0, Double(midi - 69) / 12.0)
    }

    /// Write mono Float samples to a temp .wav and return its URL.
    static func writeWAV(_ samples: [Float], sampleRate: Double = sr) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tk-\(UUID().uuidString).wav")
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                sampleRate: sampleRate, channels: 1, interleaved: false)!
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(samples.count))!
        buf.frameLength = AVAudioFrameCount(samples.count)
        memcpy(buf.floatChannelData![0], samples, samples.count * MemoryLayout<Float>.size)
        try file.write(from: buf)
        return url
    }
}
```

- [ ] **Step 2: Build to confirm it compiles**

Run: `swift build --build-tests`
Expected: builds with no errors.

- [ ] **Step 3: Commit**

```bash
git add Tests/TempoKeyCoreTests/TestSignals.swift
git commit -m "test(core): synthetic signal + temp WAV helpers"
```

---

## Task 5: OnsetDetector (STFT → spectral flux → OSS)

**Files:**
- Create: `Sources/TempoKeyCore/BeatTracking/OnsetDetector.swift`
- Test: `Tests/TempoKeyCoreTests/OnsetDetectorTests.swift`

Translate the spectral-flux portion of `btt_onset_tracking` (BTT.c): Hann-windowed frames of length `N=1024`, hop `H=128`; magnitude spectrum with DC zeroed; flux = sum of positive bin-to-bin increases vs previous frame; a single-pole ~10 Hz low-pass filter on the flux yields one OSS sample per hop.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TempoKeyCore

final class OnsetDetectorTests: XCTestCase {
    func testOSSHasPeaksAtClicks() {
        let bpm = 120.0
        let x = TestSignals.clickTrack(bpm: bpm, seconds: 4)
        let det = OnsetDetector(sampleRate: 44100, fftSize: 1024, hop: 128)
        let oss = det.process(x)
        XCTAssertGreaterThan(oss.count, 100)
        // OSS rate ≈ 344.5 Hz → expected click spacing in OSS samples:
        let expectedSpacing = (60.0 / bpm) * (44100.0 / 128.0)   // ≈ 172
        // find indices of the largest 10% of OSS values; consecutive gaps should cluster near spacing
        let threshold = oss.max()! * 0.5
        let peaks = oss.enumerated().filter { $0.element > threshold }.map { $0.offset }
        XCTAssertFalse(peaks.isEmpty)
        let gaps = zip(peaks.dropFirst(), peaks).map { Double($0 - $1) }.filter { $0 > expectedSpacing * 0.5 }
        let medianGap = gaps.sorted()[gaps.count / 2]
        XCTAssertEqual(medianGap, expectedSpacing, accuracy: expectedSpacing * 0.25)
    }
}
```

- [ ] **Step 2: Run, verify it fails** — `swift test --filter OnsetDetectorTests` → FAIL.

- [ ] **Step 3: Implement**

`Sources/TempoKeyCore/BeatTracking/OnsetDetector.swift`:
```swift
import Accelerate

/// Spectral-flux onset strength signal (OSS). One output sample per hop.
final class OnsetDetector {
    private let fftSize: Int
    private let hop: Int
    private let fft: RealFFT
    private var window: [Float]
    private var prevMag: [Float]
    private let lpAlpha: Float   // single-pole low-pass coefficient (~10 Hz)

    init(sampleRate: Double, fftSize: Int = 1024, hop: Int = 128, cutoffHz: Double = 10) {
        self.fftSize = fftSize
        self.hop = hop
        self.fft = RealFFT(size: fftSize)
        self.prevMag = [Float](repeating: 0, count: fftSize / 2 + 1)
        var w = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&w, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = w
        let ossRate = sampleRate / Double(hop)
        let rc = 1.0 / (2 * Double.pi * cutoffHz)
        let dt = 1.0 / ossRate
        self.lpAlpha = Float(dt / (rc + dt))
    }

    /// Returns the OSS for the whole signal (one value per hop).
    func process(_ samples: [Float]) -> [Float] {
        var oss: [Float] = []
        var filtered: Float = 0
        var frame = [Float](repeating: 0, count: fftSize)
        var start = 0
        while start + fftSize <= samples.count {
            for i in 0..<fftSize { frame[i] = samples[start + i] * window[i] }
            let mag = fft.magnitudes(frame)
            var flux: Float = 0
            // skip DC (index 0)
            for i in 1..<mag.count {
                let d = mag[i] - prevMag[i]
                if d > 0 { flux += d }
            }
            prevMag = mag
            filtered += lpAlpha * (flux - filtered)   // single-pole LPF
            oss.append(filtered)
            start += hop
        }
        return oss
    }
}
```

- [ ] **Step 4: Run, verify PASS** — `swift test --filter OnsetDetectorTests` → PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoKeyCore/BeatTracking/OnsetDetector.swift Tests/TempoKeyCoreTests/OnsetDetectorTests.swift
git commit -m "feat(core): spectral-flux onset strength signal"
```

---

## Task 6: TempoTracker (autocorrelation → histogram → BPM)

**Files:**
- Create: `Sources/TempoKeyCore/BeatTracking/TempoTracker.swift`
- Test: `Tests/TempoKeyCoreTests/TempoTrackerTests.swift`

Translate `btt_tempo_tracking` (BTT.c): over the most recent `ossLen` OSS samples, compute generalized autocorrelation; enhance harmonics (`ac[i] += ac[2i] + ac[4i]` within bounds); pick peaks within the valid lag range; update a decaying tempo histogram with a Gaussian bump around the best lag, weighted by a log-Gaussian tempo bias centered at 120 BPM; the histogram argmax → current BPM.

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TempoKeyCore

final class TempoTrackerTests: XCTestCase {
    private func detectBPM(_ bpm: Double) -> Double {
        let x = TestSignals.clickTrack(bpm: bpm, seconds: 12)
        let oss = OnsetDetector(sampleRate: 44100).process(x)
        let tracker = TempoTracker(ossRate: 44100.0 / 128.0)
        for v in oss { tracker.push(v) }
        return tracker.currentBPM
    }

    func test120() { XCTAssertEqual(detectBPM(120), 120, accuracy: 3) }
    func test100() { XCTAssertEqual(detectBPM(100), 100, accuracy: 3) }
    func test150() { XCTAssertEqual(detectBPM(150), 150, accuracy: 4) }
}
```

- [ ] **Step 2: Run, verify it fails** — `swift test --filter TempoTrackerTests` → FAIL.

- [ ] **Step 3: Implement**

`Sources/TempoKeyCore/BeatTracking/TempoTracker.swift`:
```swift
import Foundation

final class TempoTracker {
    private let ossRate: Double
    private let ossLen: Int
    private let minLag: Int
    private let maxLag: Int
    private let exponent: Float
    private let decay: Double
    private let gaussWidth: Double          // lag-domain std for histogram bump
    private let biasMeanBPM: Double
    private let biasWidth: Double           // lag-domain std for log-gaussian tempo bias
    private let numCandidates: Int

    private var ring: [Float]
    private var ringFilled = 0
    private var ringHead = 0
    private let fft: RealFFT
    private var histogram: [Double]         // indexed by lag

    init(ossRate: Double,
         ossLen: Int = 1024,
         minTempo: Double = 50, maxTempo: Double = 200,
         exponent: Float = 0.5,
         decay: Double = 0.999,
         gaussWidth: Double = 5,
         biasMeanBPM: Double = 120, biasWidth: Double = 75,
         numCandidates: Int = 10) {
        self.ossRate = ossRate
        self.ossLen = ossLen
        self.minLag = Int((60.0 * ossRate / maxTempo).rounded(.down))
        self.maxLag = min(ossLen - 1, Int((60.0 * ossRate / minTempo).rounded(.up)))
        self.exponent = exponent
        self.decay = decay
        self.gaussWidth = gaussWidth
        self.biasMeanBPM = biasMeanBPM
        self.biasWidth = biasWidth
        self.numCandidates = numCandidates
        self.ring = [Float](repeating: 0, count: ossLen)
        self.fft = RealFFT(size: ossLen)
        self.histogram = [Double](repeating: 0, count: ossLen)
    }

    /// Push one OSS sample; updates the running tempo estimate.
    func push(_ value: Float) {
        ring[ringHead] = value
        ringHead = (ringHead + 1) % ossLen
        if ringFilled < ossLen { ringFilled += 1; return }   // wait until full
        update()
    }

    private func biasWeight(forLag lag: Int) -> Double {
        // log-gaussian preference for tempos near biasMeanBPM (computed in lag domain)
        let meanLag = 60.0 * ossRate / biasMeanBPM
        let d = log(Double(lag)) - log(meanLag)
        let sigma = biasWidth / meanLag         // approximate log-domain width
        return exp(-(d * d) / (2 * sigma * sigma))
    }

    private func update() {
        // linearize the ring into time order
        var win = [Float](repeating: 0, count: ossLen)
        for i in 0..<ossLen { win[i] = ring[(ringHead + i) % ossLen] }

        var ac = fft.generalizedAutocorrelation(win, exponent: exponent)
        // harmonic enhancement
        for i in minLag...maxLag {
            var v = ac[i]
            if 2 * i < ossLen { v += ac[2 * i] }
            if 4 * i < ossLen { v += ac[4 * i] }
            ac[i] = v
        }
        // peak-pick candidates in [minLag, maxLag]
        var candidates: [(lag: Int, score: Float)] = []
        for i in (minLag + 1)..<maxLag {
            if ac[i] > ac[i - 1] && ac[i] >= ac[i + 1] {
                candidates.append((i, ac[i]))
            }
        }
        guard !candidates.isEmpty else { return }
        candidates.sort { $0.score > $1.score }
        let top = Array(candidates.prefix(numCandidates))

        // decay histogram, then add a gaussian bump at each candidate (bias-weighted)
        for i in 0..<histogram.count { histogram[i] *= decay }
        for c in top {
            let weight = Double(c.score) * biasWeight(forLag: c.lag)
            let lo = max(minLag, c.lag - Int(4 * gaussWidth))
            let hi = min(maxLag, c.lag + Int(4 * gaussWidth))
            for j in lo...hi {
                let d = Double(j - c.lag)
                histogram[j] += weight * exp(-(d * d) / (2 * gaussWidth * gaussWidth))
            }
        }
    }

    /// argmax of histogram → BPM. Returns 0 before enough data.
    var currentBPM: Double {
        guard let best = histogram.enumerated().max(by: { $0.element < $1.element }),
              best.element > 0, best.offset > 0 else { return 0 }
        return 60.0 * ossRate / Double(best.offset)
    }

    /// Histogram peak strength normalized 0…1 (used as confidence).
    var certainty: Double {
        let total = histogram.reduce(0, +)
        guard total > 0 else { return 0 }
        let peak = histogram.max() ?? 0
        return min(1.0, peak / total * Double(histogram.count) * 0.05)
    }
}
```

> **Implementer note:** If `test150` lands on an octave (e.g. 75 or 300), revisit harmonic enhancement and the bias width — the tolerance-based tests are the contract. Tune `biasWidth`/`gaussWidth` rather than changing the public API.

- [ ] **Step 4: Run, verify PASS** — `swift test --filter TempoTrackerTests` → PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoKeyCore/BeatTracking/TempoTracker.swift Tests/TempoKeyCoreTests/TempoTrackerTests.swift
git commit -m "feat(core): autocorrelation tempo histogram tracker"
```

---

## Task 7: BeatTracker (CBSS → beat peaks)

**Files:**
- Create: `Sources/TempoKeyCore/BeatTracking/BeatTracker.swift`
- Test: covered by `BeatTempoTracker` integration in Task 8 (no standalone test file).

Translate the CBSS accumulation from `btt_beat_tracking` (BTT.c), adapted for offline use: maintain a cumulative beat-strength signal where each new sample combines the current OSS with the best score one beat-period back, weighted by a log-Gaussian around the period `T` (in OSS samples). For offline display we extract beats as local maxima of the CBSS spaced at least `0.5*T` apart (instead of the real-time phase predictor — simpler and more stable for a static timeline).

- [ ] **Step 1: Implement (verified via Task 8 integration test)**

`Sources/TempoKeyCore/BeatTracking/BeatTracker.swift`:
```swift
import Foundation

final class BeatTracker {
    private let alpha: Double            // CBSS mix (0.9)
    private let etaWidth: Double         // log-gaussian width over the back-search
    private var cbss: [Double] = []
    private var oss: [Double] = []

    init(alpha: Double = 0.9, etaWidth: Double = 0.1) {
        self.alpha = alpha
        self.etaWidth = etaWidth
    }

    /// Append one OSS sample with the current beat period T (in OSS samples).
    func push(_ ossSample: Float, beatPeriod T: Double) {
        let x = Double(ossSample)
        oss.append(x)
        let n = cbss.count
        guard T >= 2 else { cbss.append(x); return }
        // search window [-2T, -0.5T] back from n for the best phase-weighted prior score
        let lo = max(0, n - Int(2 * T))
        let hi = max(0, n - Int(0.5 * T))
        var best = 0.0
        if hi > lo {
            for v in lo..<hi {
                let d = log(Double(n - v) / T)
                let w = exp(-(d * d) / (2 * etaWidth * etaWidth))
                best = max(best, w * cbss[v])
            }
        }
        cbss.append((1 - alpha) * x + alpha * best)
    }

    /// Beats (as OSS-sample indices) = local maxima of CBSS, min-spaced by 0.5*T.
    func beatIndices(beatPeriod T: Double) -> [Int] {
        guard cbss.count > 2, T >= 2 else { return [] }
        let minSpacing = Int(0.5 * T)
        let threshold = (cbss.max() ?? 0) * 0.1
        var beats: [Int] = []
        for i in 1..<(cbss.count - 1) {
            if cbss[i] > cbss[i-1] && cbss[i] >= cbss[i+1] && cbss[i] > threshold {
                if let last = beats.last, i - last < minSpacing {
                    if cbss[i] > cbss[last] { beats[beats.count - 1] = i }
                } else {
                    beats.append(i)
                }
            }
        }
        return beats
    }
}
```

- [ ] **Step 2: Build** — `swift build` → compiles.

- [ ] **Step 3: Commit**

```bash
git add Sources/TempoKeyCore/BeatTracking/BeatTracker.swift
git commit -m "feat(core): CBSS beat tracker (offline peak extraction)"
```

---

## Task 8: BeatTempoTracker (orchestration) + integration test

**Files:**
- Create: `Sources/TempoKeyCore/BeatTracking/BeatTempoTracker.swift`
- Test: `Tests/TempoKeyCoreTests/TempoTrackerTests.swift` (add an integration case here)

Combines onset → tempo → beat per hop and collects the time series, beats, overall BPM, confidence.

- [ ] **Step 1: Add the failing integration test** (append to `TempoTrackerTests.swift`)

```swift
extension TempoTrackerTests {
    func testEndToEndBeatTempo() {
        let x = TestSignals.clickTrack(bpm: 128, seconds: 12)
        let result = BeatTempoTracker(sampleRate: 44100).process(x)
        XCTAssertEqual(result.overallBPM, 128, accuracy: 4)
        XCTAssertFalse(result.tempoSeries.isEmpty)
        // ~128 BPM over ~12 s ≈ 25 beats; allow generous tolerance
        XCTAssertGreaterThan(result.beats.count, 12)
        XCTAssertLessThan(result.beats.count, 40)
    }
}
```

- [ ] **Step 2: Run, verify it fails** — FAIL (`BeatTempoTracker` undefined).

- [ ] **Step 3: Implement**

`Sources/TempoKeyCore/BeatTracking/BeatTempoTracker.swift`:
```swift
import Foundation

struct BeatTempoOutput {
    var overallBPM: Double
    var bpmConfidence: Double
    var tempoSeries: [(time: Double, bpm: Double)]
    var beats: [Double]      // seconds
}

final class BeatTempoTracker {
    private let sampleRate: Double
    private let hop: Int
    private let ossRate: Double
    private let onset: OnsetDetector
    private let tempo: TempoTracker
    private let beat: BeatTracker
    private let tempoSamplePeriod: Int   // emit a tempo point every N hops (~0.25 s)

    init(sampleRate: Double = 44100, fftSize: Int = 1024, hop: Int = 128) {
        self.sampleRate = sampleRate
        self.hop = hop
        self.ossRate = sampleRate / Double(hop)
        self.onset = OnsetDetector(sampleRate: sampleRate, fftSize: fftSize, hop: hop)
        self.tempo = TempoTracker(ossRate: ossRate)
        self.beat = BeatTracker()
        self.tempoSamplePeriod = max(1, Int(ossRate * 0.25))
    }

    func process(_ samples: [Float]) -> BeatTempoOutput {
        let oss = onset.process(samples)
        var series: [(Double, Double)] = []
        for (i, v) in oss.enumerated() {
            tempo.push(v)
            let bpm = tempo.currentBPM
            let T = bpm > 0 ? 60.0 * ossRate / bpm : 0
            beat.push(v, beatPeriod: T)
            if i % tempoSamplePeriod == 0 && bpm > 0 {
                series.append((Double(i) / ossRate, bpm))
            }
        }
        let overall = tempo.currentBPM
        let T = overall > 0 ? 60.0 * ossRate / overall : 0
        let beats = beat.beatIndices(beatPeriod: T).map { Double($0) / ossRate }
        return BeatTempoOutput(overallBPM: overall,
                               bpmConfidence: tempo.certainty,
                               tempoSeries: series,
                               beats: beats)
    }
}
```

- [ ] **Step 4: Run, verify PASS** — `swift test --filter TempoTrackerTests` → all PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoKeyCore/BeatTracking/BeatTempoTracker.swift Tests/TempoKeyCoreTests/TempoTrackerTests.swift
git commit -m "feat(core): beat+tempo orchestration with time series"
```

---

## Task 9: MusicalKey + Chromagram

**Files:**
- Create: `Sources/TempoKeyCore/KeyDetection/MusicalKey.swift`
- Create: `Sources/TempoKeyCore/KeyDetection/Chromagram.swift`
- Test: `Tests/TempoKeyCoreTests/ChromagramTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TempoKeyCore

final class ChromagramTests: XCTestCase {
    func testPureToneLandsOnCorrectPitchClass() {
        // A4 = 440 Hz → pitch class A (index 9 with C=0)
        let x = TestSignals.tones([440], seconds: 1)
        let chroma = Chromagram(sampleRate: 44100, fftSize: 8192).compute(x)
        let peak = chroma.firstIndex(of: chroma.max()!)!
        XCTAssertEqual(peak, PitchClass.a.rawValue)
    }

    func testMajorTriadEnergyOnTriadTones() {
        // C major triad C-E-G
        let x = TestSignals.tones([TestSignals.freq("C4"), TestSignals.freq("E4"), TestSignals.freq("G4")], seconds: 1)
        let chroma = Chromagram(sampleRate: 44100, fftSize: 8192).compute(x)
        let triad = [PitchClass.c, .e, .g].map { chroma[$0.rawValue] }
        let others = PitchClass.allCases.filter { ![.c,.e,.g].contains($0) }.map { chroma[$0.rawValue] }
        XCTAssertGreaterThan(triad.min()!, others.max()!)
    }
}
```

- [ ] **Step 2: Run, verify it fails** — FAIL.

- [ ] **Step 3: Implement `MusicalKey.swift`**

```swift
import Foundation

enum PitchClass: Int, CaseIterable {
    case c = 0, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b
    var name: String {
        ["C","C♯","D","D♯","E","F","F♯","G","G♯","A","A♯","B"][rawValue]
    }
}

enum Mode: String { case major, minor }

struct MusicalKey: Equatable {
    let tonic: PitchClass
    let mode: Mode
    var name: String { "\(tonic.name) \(mode == .major ? "maj" : "min")" }

    /// Hue (0…1) by circle of fifths — adjacent keys get adjacent hues.
    var hue: Double {
        let circle: [PitchClass] = [.c,.g,.d,.a,.e,.b,.fSharp,.cSharp,.gSharp,.dSharp,.aSharp,.f]
        let pos = circle.firstIndex(of: tonic) ?? 0
        return Double(pos) / 12.0
    }
}
```

- [ ] **Step 4: Implement `Chromagram.swift`**

```swift
import Accelerate

/// Folds an FFT magnitude spectrum into 12 pitch-class energies (C=0 … B=11).
final class Chromagram {
    private let sampleRate: Double
    private let fftSize: Int
    private let fft: RealFFT
    private var window: [Float]
    private let binPitchClass: [Int]    // pitch class per FFT bin, -1 if out of range

    init(sampleRate: Double, fftSize: Int = 8192) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.fft = RealFFT(size: fftSize)
        var w = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&w, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        self.window = w
        let bins = fftSize / 2 + 1
        var map = [Int](repeating: -1, count: bins)
        for k in 1..<bins {
            let f = Double(k) * sampleRate / Double(fftSize)
            if f < 27.5 || f > 5000 { continue }          // A0 … ~D#8
            let midi = 69.0 + 12.0 * log2(f / 440.0)
            map[k] = ((Int(midi.rounded()) % 12) + 12) % 12
        }
        self.binPitchClass = map
    }

    /// Average chroma over all full frames of `samples`. Returns 12 normalized energies.
    func compute(_ samples: [Float], hop: Int? = nil) -> [Double] {
        let h = hop ?? fftSize / 2
        var chroma = [Double](repeating: 0, count: 12)
        var frame = [Float](repeating: 0, count: fftSize)
        var frames = 0
        var start = 0
        while start + fftSize <= samples.count {
            for i in 0..<fftSize { frame[i] = samples[start + i] * window[i] }
            let mag = fft.magnitudes(frame)
            for k in 1..<mag.count {
                let pc = binPitchClass[k]
                if pc >= 0 { chroma[pc] += Double(mag[k]) }
            }
            frames += 1
            start += h
        }
        if frames == 0 { return chroma }
        let total = chroma.reduce(0, +)
        if total > 0 { for i in 0..<12 { chroma[i] /= total } }
        return chroma
    }
}
```

- [ ] **Step 5: Run, verify PASS** — `swift test --filter ChromagramTests` → PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/TempoKeyCore/KeyDetection/MusicalKey.swift Sources/TempoKeyCore/KeyDetection/Chromagram.swift Tests/TempoKeyCoreTests/ChromagramTests.swift
git commit -m "feat(core): musical key types + chromagram"
```

---

## Task 10: KeyDetector (Krumhansl-Schmuckler, windowed)

**Files:**
- Create: `Sources/TempoKeyCore/KeyDetection/KeyDetector.swift`
- Test: `Tests/TempoKeyCoreTests/KeyDetectorTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TempoKeyCore

final class KeyDetectorTests: XCTestCase {
    func testCMajorScaleDetectsCMajor() {
        // C major scale tones across 2 s
        let notes = ["C4","D4","E4","F4","G4","A4","B4","C5"].map { TestSignals.freq($0) }
        var sig: [Float] = []
        for f in notes { sig += TestSignals.tones([f], seconds: 0.25) }
        let det = KeyDetector(sampleRate: 44100)
        let result = det.analyze(sig)
        XCTAssertEqual(result.overall.tonic, .c)
        XCTAssertEqual(result.overall.mode, .major)
    }

    func testKeyChangeProducesMultipleSegments() {
        var sig: [Float] = []
        for f in ["C4","E4","G4"].map({ TestSignals.freq($0) }) { sig += TestSignals.tones([f], seconds: 0.6) }
        for f in ["F4","A4","C5"].map({ TestSignals.freq($0) }) { sig += TestSignals.tones([f], seconds: 0.6) }
        let result = KeyDetector(sampleRate: 44100, windowSeconds: 0.5, hopSeconds: 0.25).analyze(sig)
        XCTAssertGreaterThan(result.segments.count, 1)
    }
}
```

- [ ] **Step 2: Run, verify it fails** — FAIL.

- [ ] **Step 3: Implement**

`Sources/TempoKeyCore/KeyDetection/KeyDetector.swift`:
```swift
import Foundation

struct KeySegment: Equatable {
    let start: Double
    let end: Double
    let key: MusicalKey
    let confidence: Double
}

struct KeyAnalysis {
    let overall: MusicalKey
    let segments: [KeySegment]
}

final class KeyDetector {
    // Krumhansl-Kessler key profiles
    private static let major: [Double] = [6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88]
    private static let minor: [Double] = [6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17]

    private let sampleRate: Double
    private let windowSeconds: Double
    private let hopSeconds: Double
    private let chromagram: Chromagram

    init(sampleRate: Double, windowSeconds: Double = 4, hopSeconds: Double = 1, fftSize: Int = 8192) {
        self.sampleRate = sampleRate
        self.windowSeconds = windowSeconds
        self.hopSeconds = hopSeconds
        self.chromagram = Chromagram(sampleRate: sampleRate, fftSize: fftSize)
    }

    /// Pearson correlation of a 12-bin chroma against a rotated profile.
    private func correlate(_ chroma: [Double], _ profile: [Double], rotation: Int) -> Double {
        let rotated = (0..<12).map { profile[(($0 - rotation) % 12 + 12) % 12] }
        let mc = chroma.reduce(0,+)/12, mp = rotated.reduce(0,+)/12
        var num = 0.0, dc = 0.0, dp = 0.0
        for i in 0..<12 {
            let a = chroma[i]-mc, b = rotated[i]-mp
            num += a*b; dc += a*a; dp += b*b
        }
        let den = (dc*dp).squareRoot()
        return den == 0 ? 0 : num/den
    }

    /// Best key for a single chroma vector + its correlation score.
    private func bestKey(_ chroma: [Double]) -> (MusicalKey, Double) {
        var best = (MusicalKey(tonic: .c, mode: .major), -2.0)
        for pc in PitchClass.allCases {
            let maj = correlate(chroma, Self.major, rotation: pc.rawValue)
            if maj > best.1 { best = (MusicalKey(tonic: pc, mode: .major), maj) }
            let min = correlate(chroma, Self.minor, rotation: pc.rawValue)
            if min > best.1 { best = (MusicalKey(tonic: pc, mode: .minor), min) }
        }
        return best
    }

    func analyze(_ samples: [Float]) -> KeyAnalysis {
        let winN = Int(windowSeconds * sampleRate)
        let hopN = max(1, Int(hopSeconds * sampleRate))
        var raw: [(start: Double, end: Double, key: MusicalKey, conf: Double)] = []
        var start = 0
        while start < samples.count {
            let end = min(start + winN, samples.count)
            if end - start < winN / 2 { break }
            let slice = Array(samples[start..<end])
            let chroma = chromagram.compute(slice)
            let (key, conf) = bestKey(chroma)
            raw.append((Double(start)/sampleRate, Double(end)/sampleRate, key, conf))
            start += hopN
        }
        // merge consecutive equal-key windows into segments
        var segments: [KeySegment] = []
        for r in raw {
            if let last = segments.last, last.key == r.key {
                segments[segments.count-1] = KeySegment(start: last.start, end: r.end,
                                                        key: last.key,
                                                        confidence: max(last.confidence, r.conf))
            } else {
                segments.append(KeySegment(start: r.start, end: r.end, key: r.key, confidence: r.conf))
            }
        }
        // overall = key covering the most time
        var durationByKey: [String: (MusicalKey, Double)] = [:]
        for s in segments {
            let cur = durationByKey[s.key.name]?.1 ?? 0
            durationByKey[s.key.name] = (s.key, cur + (s.end - s.start))
        }
        let overall = durationByKey.values.max(by: { $0.1 < $1.1 })?.0
            ?? MusicalKey(tonic: .c, mode: .major)
        return KeyAnalysis(overall: overall, segments: segments)
    }
}
```

- [ ] **Step 4: Run, verify PASS** — `swift test --filter KeyDetectorTests` → PASS.

> **Implementer note:** K-S can confuse a key with its relative major/minor on ambiguous material. If `testCMajorScaleDetectsCMajor` flips to A minor, double-check the profile rotation direction (`rotation` shifts the profile so index 0 aligns with the tonic). The scale test is deliberately tonal/unambiguous.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoKeyCore/KeyDetection/KeyDetector.swift Tests/TempoKeyCoreTests/KeyDetectorTests.swift
git commit -m "feat(core): Krumhansl-Schmuckler windowed key detection"
```

---

## Task 11: AudioDecoder

**Files:**
- Create: `Sources/TempoKeyCore/Audio/AudioDecoder.swift`
- Test: `Tests/TempoKeyCoreTests/AudioDecoderTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TempoKeyCore

final class AudioDecoderTests: XCTestCase {
    func testDecodesWavToMono44k() throws {
        let url = try TestSignals.writeWAV(TestSignals.tones([440], seconds: 1), sampleRate: 44100)
        defer { try? FileManager.default.removeItem(at: url) }
        let decoded = try AudioDecoder().decode(url: url)
        XCTAssertEqual(decoded.sampleRate, 44100, accuracy: 1)
        XCTAssertEqual(Double(decoded.samples.count), 44100, accuracy: 2048) // ~1 s
        XCTAssertGreaterThan(decoded.samples.map { abs($0) }.max() ?? 0, 0.1)
    }

    func testResamplesWhenSourceRateDiffers() throws {
        let url = try TestSignals.writeWAV(TestSignals.tones([440], seconds: 1, sampleRate: 22050), sampleRate: 22050)
        defer { try? FileManager.default.removeItem(at: url) }
        let decoded = try AudioDecoder().decode(url: url)
        XCTAssertEqual(decoded.sampleRate, 44100, accuracy: 1)  // upsampled to analysis rate
    }
}
```

- [ ] **Step 2: Run, verify it fails** — FAIL.

- [ ] **Step 3: Implement**

`Sources/TempoKeyCore/Audio/AudioDecoder.swift`:
```swift
import AVFoundation

struct DecodedAudio {
    let samples: [Float]     // mono
    let sampleRate: Double
    var duration: Double { Double(samples.count) / sampleRate }
}

enum AudioDecoderError: Error { case cannotCreateConverter, cannotCreateBuffer, readFailed }

/// Decodes any AVFoundation-readable file to mono Float32 at a fixed analysis rate.
final class AudioDecoder {
    let analysisRate: Double
    init(analysisRate: Double = 44100) { self.analysisRate = analysisRate }

    func decode(url: URL) throws -> DecodedAudio {
        let file = try AVAudioFile(forReading: url)
        let inFormat = file.processingFormat
        let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                      sampleRate: analysisRate,
                                      channels: 1, interleaved: false)!
        guard let converter = AVAudioConverter(from: inFormat, to: outFormat) else {
            throw AudioDecoderError.cannotCreateConverter
        }

        var output: [Float] = []
        let inCap: AVAudioFrameCount = 16384
        guard let inBuf = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: inCap) else {
            throw AudioDecoderError.cannotCreateBuffer
        }

        while true {
            try file.read(into: inBuf)
            if inBuf.frameLength == 0 { break }
            let ratio = analysisRate / inFormat.sampleRate
            let outCap = AVAudioFrameCount(Double(inBuf.frameLength) * ratio) + 1024
            guard let outBuf = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: outCap) else {
                throw AudioDecoderError.cannotCreateBuffer
            }
            var fed = false
            var error: NSError?
            let status = converter.convert(to: outBuf, error: &error) { _, inputStatus in
                if fed { inputStatus.pointee = .noDataNow; return nil }
                fed = true
                inputStatus.pointee = .haveData
                return inBuf
            }
            if let error { throw error }
            if status == .error { throw AudioDecoderError.readFailed }
            if let ch = outBuf.floatChannelData, outBuf.frameLength > 0 {
                output.append(contentsOf: UnsafeBufferPointer(start: ch[0], count: Int(outBuf.frameLength)))
            }
        }
        return DecodedAudio(samples: output, sampleRate: analysisRate)
    }
}
```

- [ ] **Step 4: Run, verify PASS** — `swift test --filter AudioDecoderTests` → PASS.

> **Implementer note:** The single-shot converter input block above handles each read buffer; if you hear/see truncation on long files, switch to feeding the converter incrementally without the `fed` guard and drain until `.inputRanDry`. The two tests guard rate + length.

- [ ] **Step 5: Commit**

```bash
git add Sources/TempoKeyCore/Audio/AudioDecoder.swift Tests/TempoKeyCoreTests/AudioDecoderTests.swift
git commit -m "feat(core): AVFoundation audio decoder → mono 44.1k"
```

---

## Task 12: AnalysisResult, AnalysisEngine + NOTICE

**Files:**
- Create: `Sources/TempoKeyCore/Analysis/AnalysisResult.swift`
- Create: `Sources/TempoKeyCore/Analysis/AnalysisEngine.swift`
- Create: `TempoKeyCore/NOTICE.md`
- Test: `Tests/TempoKeyCoreTests/AnalysisEngineTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import XCTest
@testable import TempoKeyCore

final class AnalysisEngineTests: XCTestCase {
    func testFullPipelineOnSynthesizedFile() throws {
        // 120 BPM clicks mixed with a C-major triad bed
        var sig = TestSignals.clickTrack(bpm: 120, seconds: 10)
        let bed = TestSignals.tones([TestSignals.freq("C4"), TestSignals.freq("E4"), TestSignals.freq("G4")], seconds: 10)
        for i in 0..<sig.count { sig[i] = sig[i] * 0.7 + bed[i] * 0.3 }
        let url = try TestSignals.writeWAV(sig)
        defer { try? FileManager.default.removeItem(at: url) }

        var progressSeen = false
        let result = try AnalysisEngine().analyze(url: url) { _ in progressSeen = true }

        XCTAssertEqual(result.overallBPM, 120, accuracy: 4)
        XCTAssertEqual(result.overallKey.tonic, .c)
        XCTAssertFalse(result.tempoSeries.isEmpty)
        XCTAssertFalse(result.keySeries.isEmpty)
        XCTAssertEqual(result.fileName, url.lastPathComponent)
        XCTAssertEqual(result.duration, 10, accuracy: 0.5)
        XCTAssertTrue(progressSeen)
    }
}
```

- [ ] **Step 2: Run, verify it fails** — FAIL.

- [ ] **Step 3: Implement `AnalysisResult.swift`**

```swift
import Foundation

struct TempoPoint: Equatable { let time: Double; let bpm: Double }

public struct AnalysisResult {
    let fileName: String
    let duration: Double
    let overallBPM: Double
    let overallKey: MusicalKey
    let bpmConfidence: Double
    let tempoSeries: [TempoPoint]
    let keySeries: [KeySegment]
    let beats: [Double]
}
```

> Note: mark types `public` as needed when the app target imports them. For the test target (`@testable import`) internal access suffices; promote to `public` in Task usage if the app cannot see a symbol.

- [ ] **Step 4: Implement `AnalysisEngine.swift`**

```swift
import Foundation

public final class AnalysisEngine {
    private let analysisRate: Double
    public init(analysisRate: Double = 44100) { self.analysisRate = analysisRate }

    /// progress: 0…1. Runs synchronously; call off the main thread.
    func analyze(url: URL, progress: ((Double) -> Void)? = nil) throws -> AnalysisResult {
        progress?(0.0)
        let decoded = try AudioDecoder(analysisRate: analysisRate).decode(url: url)
        progress?(0.3)

        let bt = BeatTempoTracker(sampleRate: analysisRate).process(decoded.samples)
        progress?(0.7)

        let key = KeyDetector(sampleRate: analysisRate).analyze(decoded.samples)
        progress?(1.0)

        return AnalysisResult(
            fileName: url.lastPathComponent,
            duration: decoded.duration,
            overallBPM: bt.overallBPM,
            overallKey: key.overall,
            bpmConfidence: bt.bpmConfidence,
            tempoSeries: bt.tempoSeries.map { TempoPoint(time: $0.time, bpm: $0.bpm) },
            keySeries: key.segments,
            beats: bt.beats
        )
    }
}
```

- [ ] **Step 5: Create `NOTICE.md`**

```markdown
# Third-Party Attribution

This project's beat/tempo detection is a Swift translation of:

**Beat-and-Tempo-Tracking** by Michael Krzyzaniak
https://github.com/michaelkrzyzaniak/Beat-and-Tempo-Tracking
Licensed under the MIT License.

The original onset-detection, autocorrelation tempo-estimation, and CBSS beat-tracking
algorithms are due to that project. DSP primitives were reimplemented using Apple's
Accelerate framework. Musical key detection (chromagram + Krumhansl-Schmuckler) is original
to TempoKey.
```

- [ ] **Step 6: Run, verify PASS** — `swift test --filter AnalysisEngineTests` → PASS.

- [ ] **Step 7: Run the full suite** — `swift test` → all green.

- [ ] **Step 8: Commit**

```bash
git add Sources/TempoKeyCore/Analysis TempoKeyCore/NOTICE.md Tests/TempoKeyCoreTests/AnalysisEngineTests.swift
git commit -m "feat(core): analysis engine + result model + BTT attribution"
```

---

## Done criteria

- `swift test` passes all suites.
- `AnalysisEngine().analyze(url:)` returns a populated `AnalysisResult` for a real audio file.
- Public symbols the app needs (`AnalysisResult`, `AnalysisEngine`, `MusicalKey`, `KeySegment`, `TempoPoint`, `PitchClass`, `Mode`) are reachable (promote to `public` as the app target requires — Plan 2 Task 1 verifies this).
```
