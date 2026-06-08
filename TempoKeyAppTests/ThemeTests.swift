import XCTest
import SwiftUI
@testable import TempoKey
import TempoKeyCore

final class ThemeTests: XCTestCase {
    func testDurationFormatting() {
        XCTAssertEqual(Theme.duration(0), "0:00")
        XCTAssertEqual(Theme.duration(65), "1:05")
        XCTAssertEqual(Theme.duration(222), "3:42")
    }

    func testKeyColorIsStableAndDistinguishesMode() {
        let cMaj = MusicalKey(tonic: .c, mode: .major)
        let cMin = MusicalKey(tonic: .c, mode: .minor)
        // same hue family, different saturation/brightness for mode
        XCTAssertNotEqual(Theme.keyColorComponents(cMaj).saturation,
                          Theme.keyColorComponents(cMin).saturation)
        // determinism
        XCTAssertEqual(Theme.keyColorComponents(cMaj).hue, cMaj.hue, accuracy: 1e-9)
    }
}
