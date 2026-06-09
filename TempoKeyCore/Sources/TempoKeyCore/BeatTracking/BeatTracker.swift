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
