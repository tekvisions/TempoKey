import XCTest
@testable import TempoKeyCore

final class BeatTempoTrackerTests: XCTestCase {
    func testEndToEndBeatTempo() {
        let x = TestSignals.clickTrack(bpm: 128, seconds: 12)
        let result = BeatTempoTracker(sampleRate: 44100).process(x)
        XCTAssertEqual(result.overallBPM, 128, accuracy: 4)
        XCTAssertFalse(result.tempoSeries.isEmpty)
        // ~128 BPM over ~12 s ≈ 25 beats; allow generous tolerance
        XCTAssertGreaterThan(result.beats.count, 12)
        XCTAssertLessThan(result.beats.count, 40)
    }
}
