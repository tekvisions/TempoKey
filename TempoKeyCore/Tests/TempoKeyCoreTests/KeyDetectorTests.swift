import XCTest
@testable import TempoKeyCore

final class KeyDetectorTests: XCTestCase {
    func testSilenceCannotOutvoteTheMusicalKey() {
        let music = TestSignals.tones([293.66, 369.99, 440], seconds: 8)
        let result = KeyDetector(sampleRate: 44100).analyze(music + [Float](repeating: 0, count: 44100 * 24))
        XCTAssertEqual(result.overall, MusicalKey(tonic: .d, mode: .major))
        XCTAssertTrue(result.segments.filter { $0.start >= 12 }.allSatisfy { $0.confidence == 0 })
    }

    func testSilentWindowsDoNotMergeIntoConfidentCMajorSegment() {
        let music = TestSignals.tones([261.63, 329.63, 392], seconds: 8)
        let result = KeyDetector(sampleRate: 44100).analyze(music + [Float](repeating: 0, count: 44100 * 12))
        XCTAssertEqual(result.overall, MusicalKey(tonic: .c, mode: .major))
        XCTAssertTrue(result.segments.contains { $0.start >= 8 && $0.confidence == 0 })
        XCTAssertFalse(result.segments.contains { $0.end > 12 && $0.confidence > 0 })
    }

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
