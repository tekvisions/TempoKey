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
        let threshold = oss.max()! * 0.5
        let peaks = oss.enumerated().filter { $0.element > threshold }.map { $0.offset }
        XCTAssertFalse(peaks.isEmpty)
        let gaps = zip(peaks.dropFirst(), peaks).map { Double($0 - $1) }.filter { $0 > expectedSpacing * 0.5 }
        let medianGap = gaps.sorted()[gaps.count / 2]
        XCTAssertEqual(medianGap, expectedSpacing, accuracy: expectedSpacing * 0.25)
    }
}
