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

    /// A song that changes tempo (140 → 130) should read each section steadily (low jitter) and
    /// keep the step between them — guards the smoothing/comb/interpolation work.
    func testTwoSectionTempoIsStableAndStepped() {
        let sig = TestSignals.clickTrack(bpm: 140, seconds: 9) + TestSignals.clickTrack(bpm: 130, seconds: 9)
        let out = BeatTempoTracker(sampleRate: 44100).process(sig)

        let first = out.tempoSeries.filter { $0.time > 4 && $0.time < 8.5 }.map(\.bpm)
        let second = out.tempoSeries.filter { $0.time > 12.5 && $0.time < 17.5 }.map(\.bpm)
        XCTAssertFalse(first.isEmpty); XCTAssertFalse(second.isEmpty)
        XCTAssertEqual(first.reduce(0, +) / Double(first.count), 140, accuracy: 4)
        XCTAssertEqual(second.reduce(0, +) / Double(second.count), 130, accuracy: 4)

        func jitter(_ a: [Double]) -> Double {
            zip(a.dropFirst(), a).map { abs($0 - $1) }.reduce(0, +) / Double(max(1, a.count - 1))
        }
        XCTAssertLessThan(jitter(first), 1.0, "first section should be smooth")
        XCTAssertLessThan(jitter(second), 1.0, "second section should be smooth")
    }

    func testMedianAndMedianFilter() {
        XCTAssertEqual(BeatTempoTracker.median([3, 1, 2]), 2)
        XCTAssertEqual(BeatTempoTracker.median([1, 2, 3, 4]), 2.5)
        // a single-point spike is removed; a sustained step is preserved
        let filtered = BeatTempoTracker.medianFilter([130, 130, 130, 90, 130, 130, 130, 100, 100, 100], radius: 2)
        XCTAssertEqual(filtered[3], 130)                 // spike at index 3 removed
        XCTAssertEqual(filtered[8], 100)                 // step to 100 preserved
    }
}
