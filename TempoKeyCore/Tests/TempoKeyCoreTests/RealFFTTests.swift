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

    // Verifies EVERY lag (even AND odd) matches a brute-force circular autocorrelation.
    // Guards against half-populated output (the even/odd packing concern).
    func testAutocorrelationMatchesBruteForceAllLags() {
        let n = 64
        let fft = RealFFT(size: n)
        var x = [Float](repeating: 0, count: n)
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func rnd() -> Float {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Float(Int32(truncatingIfNeeded: seed >> 33)) / Float(Int32.max)
        }
        for i in 0..<n { x[i] = rnd() }

        var brute = [Float](repeating: 0, count: n)
        for k in 0..<n {
            var s: Float = 0
            for i in 0..<n { s += x[i] * x[(i + k) % n] }
            brute[k] = s
        }

        let ac = fft.generalizedAutocorrelation(x, exponent: 1.0)   // |X|^2 → standard autocorrelation
        XCTAssertEqual(ac.count, n)
        XCTAssertGreaterThan(ac[0], 0)
        for k in 0..<n {
            XCTAssertEqual(ac[k] / ac[0], brute[k] / brute[0], accuracy: 2e-3, "mismatch at lag \(k)")
        }
    }
}
