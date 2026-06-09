import XCTest
@testable import TempoKeyCore

final class AnalysisEngineTests: XCTestCase {
    func testFullPipelineOnSynthesizedFile() throws {
        // 120 BPM clicks mixed with a C-major triad bed
        var sig = TestSignals.clickTrack(bpm: 120, seconds: 10)
        let bed = TestSignals.tones([TestSignals.freq("C4"), TestSignals.freq("E4"), TestSignals.freq("G4")], seconds: 10)
        for i in 0..<sig.count { sig[i] = sig[i] * 0.7 + bed[i] * 0.3 }
        let url = try TestSignals.writeWAV(sig)
        defer { try? FileManager.default.removeItem(at: url) }

        var progressSeen = false
        let result = try AnalysisEngine().analyze(url: url) { _ in progressSeen = true }

        XCTAssertEqual(result.overallBPM, 120, accuracy: 4)
        XCTAssertEqual(result.overallKey.tonic, .c)
        XCTAssertFalse(result.tempoSeries.isEmpty)
        XCTAssertFalse(result.keySeries.isEmpty)
        XCTAssertEqual(result.fileName, url.lastPathComponent)
        XCTAssertEqual(result.duration, 10, accuracy: 0.5)
        XCTAssertTrue(progressSeen)
    }
}
