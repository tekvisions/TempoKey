import XCTest
@testable import TempoKeyCore

final class AudioDecoderTests: XCTestCase {
    func testDecodesWavToMono44k() throws {
        let url = try TestSignals.writeWAV(TestSignals.tones([440], seconds: 1), sampleRate: 44100)
        defer { try? FileManager.default.removeItem(at: url) }
        let decoded = try AudioDecoder().decode(url: url)
        XCTAssertEqual(decoded.sampleRate, 44100, accuracy: 1)
        XCTAssertEqual(Double(decoded.samples.count), 44100, accuracy: 2048) // ~1 s
        XCTAssertGreaterThan(decoded.samples.map { abs($0) }.max() ?? 0, 0.1)
    }

    func testResamplesWhenSourceRateDiffers() throws {
        let url = try TestSignals.writeWAV(TestSignals.tones([440], seconds: 1, sampleRate: 22050), sampleRate: 22050)
        defer { try? FileManager.default.removeItem(at: url) }
        let decoded = try AudioDecoder().decode(url: url)
        XCTAssertEqual(decoded.sampleRate, 44100, accuracy: 1)  // upsampled to analysis rate
    }
}
