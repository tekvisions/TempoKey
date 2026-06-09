import XCTest
@testable import TempoKeyCore

final class SmokeTests: XCTestCase {
    func testPackageBuilds() {
        XCTAssertEqual(TempoKeyCoreVersion.value, "0.1.0")
    }
}
