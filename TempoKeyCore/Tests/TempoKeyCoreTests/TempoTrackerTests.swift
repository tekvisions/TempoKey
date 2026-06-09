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

    // Throttling the autocorrelation update (every N OSS samples instead of every sample)
    // must not change the detected tempo materially.
    func testThrottledMatchesUnthrottled() {
        let oss = OnsetDetector(sampleRate: 44100).process(TestSignals.clickTrack(bpm: 120, seconds: 12))
        func bpm(updateEvery interval: Int) -> Double {
            let t = TempoTracker(ossRate: 44100.0 / 128.0, updateInterval: interval)
            for v in oss { t.push(v) }
            return t.currentBPM
        }
        XCTAssertEqual(bpm(updateEvery: 1), bpm(updateEvery: 8), accuracy: 3)
        XCTAssertEqual(bpm(updateEvery: 8), 120, accuracy: 3)
    }
}
