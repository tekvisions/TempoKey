import Foundation

/// Folds an FFT magnitude spectrum into 12 pitch-class energies (C=0 … B=11).
final class Chromagram {
    private let sampleRate: Double
    private let fftSize: Int
    private let fft: RealTransform
    private var window: [Float]
    private let binPitchClass: [Int]    // pitch class per FFT bin, -1 if out of range

    init(sampleRate: Double, fftSize: Int = 8192, fft: RealTransform? = nil, windows: WindowGenerating = AccelerateWindows()) {
        self.sampleRate = sampleRate
        self.fftSize = fftSize
        self.fft = fft ?? RealFFT(size: fftSize)
        self.window = windows.hann(size: fftSize)
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
        compute(samples, hop: hop, checkCancellation: {})
    }

    func compute(_ samples: [Float], hop: Int? = nil, checkCancellation: () throws -> Void) rethrows -> [Double] {
        let h = hop ?? fftSize / 2
        var chroma = [Double](repeating: 0, count: 12)
        var frame = [Float](repeating: 0, count: fftSize)
        var frames = 0
        var start = 0
        while start + fftSize <= samples.count {
            try checkCancellation()
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
