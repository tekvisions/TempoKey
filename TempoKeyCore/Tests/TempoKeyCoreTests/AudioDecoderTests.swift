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

    func testNonAudioFileThrowsFriendlyError() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("notaudio-\(UUID().uuidString).txt")
        try "this is not audio".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try AudioDecoder().decode(url: url)) { error in
            // The app surfaces error.localizedDescription; it must be human-friendly, not a raw OSStatus.
            let message = error.localizedDescription
            XCTAssertTrue(message.contains("Couldn't read"), "expected a friendly message, got: \(message)")
            XCTAssertTrue(message.contains(url.lastPathComponent), "message should name the file")
        }
    }

    func testRejectsFileLongerThanMaxDuration() throws {
        let url = try TestSignals.writeWAV(TestSignals.tones([440], seconds: 2), sampleRate: 44100)
        defer { try? FileManager.default.removeItem(at: url) }
        // A 2 s file exceeds a 0.5 s cap → rejected with a friendly "too long" message (no OOM).
        XCTAssertThrowsError(try AudioDecoder(maxDuration: 0.5).decode(url: url)) { error in
            XCTAssertTrue(error.localizedDescription.contains("too long"),
                          "expected too-long message, got: \(error.localizedDescription)")
        }
        // Same file decodes fine under the default cap.
        XCTAssertNoThrow(try AudioDecoder().decode(url: url))
    }
}
