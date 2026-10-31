import XCTest
import TempoKeyCore
@testable import TempoKey

final class TimelineEvidenceTests: XCTestCase {
    func testSilentGapBreaksLineAndHoverDoesNotInventTempo() {
        let series = [TempoPoint(time: 1, bpm: 120), TempoPoint(time: 1.25, bpm: 120),
                      TempoPoint(time: 8, bpm: 150), TempoPoint(time: 8.25, bpm: 150)]
        XCTAssertEqual(TempoTimelineData.runs(series).map(\.count), [2, 2])
        XCTAssertNil(TempoTimelineData.bpm(at: 4, series: series))
        XCTAssertEqual(TempoTimelineData.bpm(at: 8.1, series: series), 150)
    }

    func testKeyCorrectionDoesNotLabelBPMAsCorrected() {
        let keyOnly = DisplayOverrides(manualKey: .init(tonic: .d, mode: .minor))
        XCTAssertEqual(Theme.tempoCaption(0.9, overrides: keyOnly), "Strong tempo evidence")
        XCTAssertEqual(Theme.tempoCaption(0.5, overrides: .init()), "Mixed tempo evidence")
        XCTAssertEqual(Theme.tempoCaption(0.1, overrides: .init()), "Weak tempo evidence")
        XCTAssertEqual(Theme.tempoCaption(0.9, overrides: .init(manualBPM: 123)), "Corrected tempo")
    }
}
