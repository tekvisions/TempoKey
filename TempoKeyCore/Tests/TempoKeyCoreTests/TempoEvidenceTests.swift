import XCTest
@testable import TempoKeyCore

final class TempoEvidenceTests: XCTestCase {
    func testSilentTailDoesNotKeepTempoOrPredictedBeats() {
        let samples = TestSignals.clickTrack(bpm: 120, seconds: 12)
            + [Float](repeating: 0, count: 44100 * 12)
        let result = BeatTempoTracker().process(samples)
        XCTAssertEqual(result.overallBPM, 120, accuracy: 3)
        XCTAssertFalse(result.tempoSeries.contains { $0.time > 14 }, "Silence must not inherit a stale tempo")
        XCTAssertFalse(result.beats.contains { $0 > 14 }, "Silence must not contain phantom beats")
    }

    func testConfidenceReflectsWholeTrackInsteadOfOnlyEnding() {
        let stable = BeatTempoTracker().process(TestSignals.clickTrack(bpm: 120, seconds: 36))
        let changing = BeatTempoTracker().process(
            TestSignals.clickTrack(bpm: 90, seconds: 18) + TestSignals.clickTrack(bpm: 150, seconds: 18))
        XCTAssertGreaterThan(stable.bpmConfidence, 0.7)
        XCTAssertLessThan(changing.bpmConfidence, stable.bpmConfidence - 0.15)
        XCTAssertLessThan(stable.bpmConfidence, 1, "Heuristic evidence is not certainty")
    }

    func testTempoRestartsAfterSilentBreakWithoutOldHistogram() {
        let samples = TestSignals.clickTrack(bpm: 90, seconds: 12)
            + [Float](repeating: 0, count: 44100 * 8)
            + TestSignals.clickTrack(bpm: 150, seconds: 12)
        let result = BeatTempoTracker().process(samples)
        let resumed = result.tempoSeries.filter { $0.time > 25 }.map(\.bpm)
        XCTAssertFalse(resumed.isEmpty)
        XCTAssertTrue(resumed.allSatisfy { abs($0 - 150) < 4 })
        XCTAssertFalse(result.tempoSeries.contains { $0.time > 14 && $0.time < 20 })
    }
}
