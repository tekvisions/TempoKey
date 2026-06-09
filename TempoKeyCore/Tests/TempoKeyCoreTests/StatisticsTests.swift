import XCTest
@testable import TempoKeyCore

final class StatisticsTests: XCTestCase {
    func testRunningMeanAndStd() {
        var s = RunningStats(capacity: 4)
        for v in [2.0, 4.0, 4.0, 4.0] { s.push(v) }   // window full: [2,4,4,4]
        XCTAssertEqual(s.mean, 3.5, accuracy: 1e-9)
        // population std of [2,4,4,4] = sqrt( ( (1.5^2)+(0.5^2)*3 )/4 ) = sqrt(3/4) = 0.8660254
        XCTAssertEqual(s.std, 0.8660254, accuracy: 1e-6)
    }

    func testAdaptiveThresholdDetectsSpike() {
        var t = AdaptiveThreshold(window: 8, numStdDevs: 2.0, floor: 0.0)
        for _ in 0..<8 { _ = t.update(0.1) }     // baseline ~0.1, ~0 variance
        XCTAssertTrue(t.update(5.0), "a large jump above mean+2*std should cross threshold")
        XCTAssertFalse(t.update(0.1), "a value at baseline should not cross")
    }
}
