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
            for i in 1..<mag.count {     // skip DC (index 0)
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
