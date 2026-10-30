import Foundation

final class TempoTracker {
    private let ossRate: Double
    private let ossLen: Int
    private let minLag: Int
    private let maxLag: Int
    private let exponent: Float
    private let effectiveDecay: Double      // per-update decay (already raised to updateInterval)
    private let gaussWidth: Double          // lag-domain std for histogram bump
    private let biasMeanBPM: Double
    private let biasWidth: Double           // lag-domain std for log-gaussian tempo bias
    private let numCandidates: Int
    private let updateInterval: Int         // run the (expensive) autocorrelation every N OSS samples

    private var ring: [Float]
    private var ringFilled = 0
    private var ringHead = 0
    private var sinceUpdate = 0
    private let fft: RealTransform
    private var histogram: [Double]         // indexed by lag

    /// `updateInterval`: the autocorrelation/histogram update is the expensive step (a full
    /// `ossLen`-point FFT). Running it every OSS sample dominates analysis time, so by default we
    /// run it every 8 samples (~23 ms). `decay` is specified per-OSS-sample and raised to
    /// `updateInterval` internally, so the histogram's time-based decay is unchanged by throttling.
    init(ossRate: Double,
         ossLen: Int = 1024,
         minTempo: Double = 50, maxTempo: Double = 200,
         exponent: Float = 0.5,
         decay: Double = 0.999,
         gaussWidth: Double = 5,
         biasMeanBPM: Double = 120, biasWidth: Double = 75,
         numCandidates: Int = 10,
         updateInterval: Int = 8, fft: RealTransform? = nil) {
        self.ossRate = ossRate
        self.ossLen = ossLen
        self.minLag = Int((60.0 * ossRate / maxTempo).rounded(.down))
        self.maxLag = min(ossLen - 1, Int((60.0 * ossRate / minTempo).rounded(.up)))
        self.exponent = exponent
        self.updateInterval = max(1, updateInterval)
        self.effectiveDecay = pow(decay, Double(max(1, updateInterval)))
        self.gaussWidth = gaussWidth
        self.biasMeanBPM = biasMeanBPM
        self.biasWidth = biasWidth
        self.numCandidates = numCandidates
        self.ring = [Float](repeating: 0, count: ossLen)
        self.fft = fft ?? RealFFT(size: ossLen)
        self.histogram = [Double](repeating: 0, count: ossLen)
    }

    func push(_ value: Float) {
        ring[ringHead] = value
        ringHead = (ringHead + 1) % ossLen
        if ringFilled < ossLen { ringFilled += 1; return }
        sinceUpdate += 1
        if sinceUpdate >= updateInterval {
            sinceUpdate = 0
            update()
        }
    }

    private func biasWeight(forLag lag: Int) -> Double {
        let meanLag = 60.0 * ossRate / biasMeanBPM
        let d = log(Double(lag)) - log(meanLag)
        let sigma = biasWidth / meanLag
        return exp(-(d * d) / (2 * sigma * sigma))
    }

    private func update() {
        var win = [Float](repeating: 0, count: ossLen)
        for i in 0..<ossLen { win[i] = ring[(ringHead + i) % ossLen] }

        let raw = fft.generalizedAutocorrelation(win, exponent: exponent)
        var ac = raw
        // Harmonic comb: reinforce a candidate fundamental with its real harmonics (2x,3x,4x lag).
        // Including the 3x term is important: without it a lag at 1.5*T (a 3:2 sub-tempo) picks up
        // the strong 3*T autocorrelation peak at its 2x position and competes with the true tempo,
        // causing the reading to flip between T and (2/3)T.
        for i in minLag...maxLag {
            var v = raw[i]
            if 2 * i < ossLen { v += raw[2 * i] }
            if 3 * i < ossLen { v += raw[3 * i] }
            if 4 * i < ossLen { v += raw[4 * i] }
            ac[i] = v
        }
        var candidates: [(lag: Int, score: Float)] = []
        for i in (minLag + 1)..<maxLag {
            if ac[i] > ac[i - 1] && ac[i] >= ac[i + 1] {
                candidates.append((i, ac[i]))
            }
        }
        guard !candidates.isEmpty else { return }
        candidates.sort { $0.score > $1.score }
        let top = Array(candidates.prefix(numCandidates))

        for i in 0..<histogram.count { histogram[i] *= effectiveDecay }
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

    var currentBPM: Double {
        guard let best = histogram.enumerated().max(by: { $0.element < $1.element }),
              best.element > 0, best.offset > 0 else { return 0 }
        // Parabolic sub-bin interpolation around the peak: integer lags quantize BPM (~1 BPM steps
        // near 130-140), which shows up as stair-stepping. Refine to a continuous lag.
        let i = best.offset
        var lag = Double(i)
        if i > 0, i < histogram.count - 1 {
            let a = histogram[i - 1], b = histogram[i], c = histogram[i + 1]
            let denom = a - 2 * b + c
            if denom != 0 {
                let delta = 0.5 * (a - c) / denom
                if delta > -1, delta < 1 { lag = Double(i) + delta }
            }
        }
        return 60.0 * ossRate / lag
    }

    var certainty: Double {
        let total = histogram.reduce(0, +)
        guard total > 0 else { return 0 }
        let peak = histogram.max() ?? 0
        return min(1.0, peak / total * Double(histogram.count) * 0.05)
    }
}
