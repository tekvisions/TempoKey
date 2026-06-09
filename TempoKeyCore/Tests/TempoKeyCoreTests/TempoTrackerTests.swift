import XCTest
@testable import TempoKeyCore

final class TempoTrackerTests: XCTestCase {
    private func detectBPM(_ bpm: Double) -> Double {
        let x = TestSignals.clickTrack(bpm: bpm, seconds: 12)
        let oss = OnsetDetector(sampleRate: 44100).process(x)
        let tracker = TempoTracker(ossRate: 44100.0 / 128.0)
        for v in oss { tracker.push(v) }
        return tracker.currentBPM
    }

    func test120() { XCTAssertEqual(detectBPM(120), 120, accuracy: 3) }
    func test100() { XCTAssertEqual(detectBPM(100), 100, accuracy: 3) }
    func test150() { XCTAssertEqual(detectBPM(150), 150, accuracy: 4) }
}
