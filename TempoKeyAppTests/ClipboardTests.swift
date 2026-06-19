import XCTest
@testable import TempoKey
import TempoKeyCore

final class ClipboardTests: XCTestCase {
    func testSummaryString() {
        let s = Clipboard.summary(bpm: 128.0, key: MusicalKey(tonic: .a, mode: .minor))
        XCTAssertEqual(s, "128.00 BPM · A min (8A)")
    }
}
