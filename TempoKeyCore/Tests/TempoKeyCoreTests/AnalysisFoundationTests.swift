import XCTest
@testable import TempoKeyCore

final class AnalysisFoundationTests: XCTestCase {
    func testSilentFileDoesNotProduceMusicalResult() throws {
        let url = try TestSignals.writeWAV([Float](repeating: 0, count: 44100))
        defer { try? FileManager.default.removeItem(at: url) }
        XCTAssertThrowsError(try AnalysisEngine().analyze(url: url))
    }

    func testCancelledTaskStopsBeforeDecodingMissingFile() async {
        let cancelled = await Task.detached { () -> Bool in
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                _ = try AnalysisEngine().analyze(url: URL(fileURLWithPath: "/missing.wav"))
                return false
            } catch is CancellationError { return true }
            catch { return false }
        }.value
        XCTAssertTrue(cancelled)
    }

    func testKeySegmentsPartitionIncludingShortTail() {
        let first = TestSignals.tones([261.63, 329.63, 392], seconds: 6)
        let second = TestSignals.tones([369.99, 466.16, 554.37], seconds: 6.7)
        let segments = KeyDetector(sampleRate: 44100).analyze(first + second).segments
        XCTAssertGreaterThan(segments.count, 1)
        XCTAssertEqual(segments.first?.start, 0)
        XCTAssertEqual(segments.last?.end ?? 0, 12.7, accuracy: 0.001)
        for (left, right) in zip(segments, segments.dropFirst()) {
            XCTAssertEqual(left.end, right.start, accuracy: 0.0001)
        }
    }

    func testShortTonalFileHasKeyCoverageWithLowConfidence() {
        let samples = TestSignals.tones([261.63, 329.63, 392], seconds: 0.5)
        let segments = KeyDetector(sampleRate: 44100).analyze(samples).segments
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments.last?.end ?? 0, 0.5, accuracy: 0.001)
        XCTAssertLessThanOrEqual(segments.first?.confidence ?? 1, 0.25)
    }
}
