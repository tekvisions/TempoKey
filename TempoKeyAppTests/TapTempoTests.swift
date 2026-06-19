import XCTest
@testable import TempoKey

final class TapTempoTests: XCTestCase {
    func testSteadyTapsGive120() {
        var t = TapTempo()
        XCTAssertNil(t.tap(at: 0.0))          // first tap: not enough data
        _ = t.tap(at: 0.5)
        _ = t.tap(at: 1.0)
        let bpm = t.tap(at: 1.5)              // 0.5s spacing → 120 BPM
        XCTAssertEqual(bpm ?? 0, 120, accuracy: 0.5)
    }

    func testLongGapResetsSequence() {
        var t = TapTempo()
        _ = t.tap(at: 0.0); _ = t.tap(at: 0.5)
        XCTAssertNil(t.tap(at: 10.0))         // >2s gap restarts; single tap → nil
    }
}
