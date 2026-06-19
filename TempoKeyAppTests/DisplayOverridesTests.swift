import XCTest
@testable import TempoKey
import TempoKeyCore

final class DisplayOverridesTests: XCTestCase {
    func testDefaultsPassThrough() {
        let o = DisplayOverrides()
        XCTAssertEqual(o.displayedBPM(detected: 128), 128, accuracy: 1e-9)
        XCTAssertEqual(o.displayedKey(detected: MusicalKey(tonic: .a, mode: .minor)),
                       MusicalKey(tonic: .a, mode: .minor))
        XCTAssertFalse(o.isActive)
    }

    func testHalfAndDoubleAndManual() {
        var o = DisplayOverrides()
        o.bpmMultiplier = 0.5
        XCTAssertEqual(o.displayedBPM(detected: 140), 70, accuracy: 1e-9)
        o.bpmMultiplier = 2
        XCTAssertEqual(o.displayedBPM(detected: 70), 140, accuracy: 1e-9)
        o.manualBPM = 128          // tap overrides detected; multiplier still applies
        XCTAssertEqual(o.displayedBPM(detected: 999), 256, accuracy: 1e-9)
        XCTAssertTrue(o.isActive)
    }

    func testManualKeyAndClear() {
        var o = DisplayOverrides()
        o.manualKey = MusicalKey(tonic: .c, mode: .major)
        XCTAssertEqual(o.displayedKey(detected: MusicalKey(tonic: .a, mode: .minor)),
                       MusicalKey(tonic: .c, mode: .major))
        o.clear()
        XCTAssertFalse(o.isActive)
        XCTAssertEqual(o.displayedBPM(detected: 100), 100, accuracy: 1e-9)
    }
}
