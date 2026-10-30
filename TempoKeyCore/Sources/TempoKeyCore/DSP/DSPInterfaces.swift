import Accelerate

/// Platform adapters implement these operations without exposing Accelerate to algorithms.
protocol RealTransform {
    func magnitudes(_ input: [Float]) -> [Float]
    func generalizedAutocorrelation(_ input: [Float], exponent: Float) -> [Float]
}

protocol WindowGenerating {
    func hann(size: Int) -> [Float]
}

struct AccelerateWindows: WindowGenerating {
    func hann(size: Int) -> [Float] {
        var window = [Float](repeating: 0, count: size)
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
        return window
    }
}
