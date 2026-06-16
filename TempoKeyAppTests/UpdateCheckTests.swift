import XCTest
@testable import TempoKey

final class UpdateCheckTests: XCTestCase {
    func testIsNewerComparesSemanticVersions() {
        XCTAssertTrue(UpdateCheck.isNewer("v1.1.0", than: "1.0.0"))
        XCTAssertTrue(UpdateCheck.isNewer("1.0.1", than: "1.0.0"))
        XCTAssertTrue(UpdateCheck.isNewer("v2.0.0", than: "1.9.9"))
        XCTAssertTrue(UpdateCheck.isNewer("0.2.0", than: "0.1.0"))
    }

    func testIsNewerFalseForSameOrOlder() {
        XCTAssertFalse(UpdateCheck.isNewer("1.0.0", than: "1.0.0"))
        XCTAssertFalse(UpdateCheck.isNewer("v1.0.0", than: "v1.0.0"))
        XCTAssertFalse(UpdateCheck.isNewer("0.9.0", than: "1.0.0"))
        XCTAssertFalse(UpdateCheck.isNewer("1.0.0", than: "1.0.1"))
    }

    func testIsNewerToleratesPrefixesAndSuffixes() {
        XCTAssertTrue(UpdateCheck.isNewer("v1.2", than: "1.1.9"))          // missing patch
        XCTAssertTrue(UpdateCheck.isNewer("1.0.1-beta", than: "1.0.0"))   // non-numeric suffix
        XCTAssertFalse(UpdateCheck.isNewer("1.0.0", than: "v1.0.0"))
    }
}
