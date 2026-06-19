import XCTest
@testable import TempoKeyCore

final class CamelotTests: XCTestCase {
    func testKnownCamelotCodes() {
        XCTAssertEqual(MusicalKey(tonic: .a, mode: .minor).camelot, "8A")
        XCTAssertEqual(MusicalKey(tonic: .c, mode: .major).camelot, "8B")
        XCTAssertEqual(MusicalKey(tonic: .e, mode: .minor).camelot, "9A")
        XCTAssertEqual(MusicalKey(tonic: .g, mode: .major).camelot, "9B")
        XCTAssertEqual(MusicalKey(tonic: .gSharp, mode: .minor).camelot, "1A")
        XCTAssertEqual(MusicalKey(tonic: .b, mode: .major).camelot, "1B")
    }

    func testHarmonicNeighbors() {
        XCTAssertEqual(Set(MusicalKey(tonic: .a, mode: .minor).compatibleCamelot), Set(["7A", "9A", "8B"]))
        XCTAssertEqual(Set(MusicalKey(tonic: .gSharp, mode: .minor).compatibleCamelot), Set(["12A", "2A", "1B"]))
    }
}
