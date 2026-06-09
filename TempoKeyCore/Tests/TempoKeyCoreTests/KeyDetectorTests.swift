import XCTest
@testable import TempoKeyCore

final class KeyDetectorTests: XCTestCase {
    func testCMajorScaleDetectsCMajor() {
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
