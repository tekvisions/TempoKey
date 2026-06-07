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

    func push(_ value: Float) {
        ring[ringHead] = value
        ringHead = (ringHead + 1) % ossLen
        if ringFilled < ossLen { ringFilled += 1; return }
        update()
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

        var ac = fft.generalizedAutocorrelation(win, exponent: exponent)
        for i in minLag...maxLag {
            var v = ac[i]
            if 2 * i < ossLen { v += ac[2 * i] }
            if 4 * i < ossLen { v += ac[4 * i] }
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

    var currentBPM: Double {
        guard let best = histogram.enumerated().max(by: { $0.element < $1.element }),
              best.element > 0, best.offset > 0 else { return 0 }
        return 60.0 * ossRate / Double(best.offset)
    }

    var certainty: Double {
        let total = histogram.reduce(0, +)
        guard total > 0 else { return 0 }
        let peak = histogram.max() ?? 0
        return min(1.0, peak / total * Double(histogram.count) * 0.05)
    }
}
