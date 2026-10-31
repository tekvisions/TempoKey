import XCTest
import AVFoundation
@testable import TempoKey
import TempoKeyCore

final class ExportTests: XCTestCase {
    func testJSONKeepsRawAndCorrectedValues() throws {
        let result = AnalysisResult(fileName: "song.wav", duration: 10, overallBPM: 120,
                                    overallKey: .init(tonic: .c, mode: .major), bpmConfidence: 0.8,
                                    tempoSeries: [], keySeries: [], beats: [])
        let data = try AnalysisExport.json(result: result, overrides: DisplayOverrides(bpmMultiplier: 2))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["correctedBPM"] as? Double, 240)
        XCTAssertEqual((json["analysis"] as? [String: Any])?["overallBPM"] as? Double, 120)
    }
    func testSourceAndSymlinkDestinationAreRejected() throws {
        let source = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let alias = source.appendingPathExtension("alias")
        try Data([1, 2, 3]).write(to: source)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: source)
        defer { try? FileManager.default.removeItem(at: source); try? FileManager.default.removeItem(at: alias) }
        XCTAssertThrowsError(try AnalysisExport.validateDestination(source, source: source))
        XCTAssertThrowsError(try AnalysisExport.validateDestination(alias, source: source))
    }
    func testMP3TaggingPreservesAudioAndReplacesExistingTempo() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("source.mp3")
        let tagged = dir.appendingPathComponent("tagged.mp3")
        let second = dir.appendingPathComponent("second.mp3")
        let payload = Data([0xff, 0xfb, 0x90, 0x64] + Array(repeating: UInt8(42), count: 1024))
        try payload.write(to: source)
        try await MetadataExport.writeCopy(source: source, destination: tagged, bpm: 120, key: .init(tonic: .a, mode: .minor))
        try await MetadataExport.writeCopy(source: tagged, destination: second, bpm: 140, key: .init(tonic: .c, mode: .major))
        let bytes = try Data(contentsOf: second)
        XCTAssertEqual(try Data(contentsOf: source), payload)
        XCTAssertEqual(bytes.suffix(payload.count), payload)
        let tag = String(decoding: bytes.dropLast(payload.count), as: UTF8.self)
        XCTAssertTrue(tag.contains("140")); XCTAssertFalse(tag.contains("120"))
        XCTAssertTrue(tag.contains("TKEY")); XCTAssertTrue(tag.contains("TEMPOKEY_CAMELOT")); XCTAssertTrue(tag.contains("8B"))
    }
    func testID3v23CamelotValueDecodesIndependentlyAfterDescription() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("source.mp3"), destination = dir.appendingPathComponent("copy.mp3")
        // ID3v2.3 tag with one padding byte followed by an opaque audio payload.
        try Data([73, 68, 51, 3, 0, 0, 0, 0, 0, 1, 0, 0xff, 0xfb, 0x90, 0x64]).write(to: source)
        try await MetadataExport.writeCopy(source: source, destination: destination, bpm: 128, key: .init(tonic: .a, mode: .minor))
        let bytes = try Data(contentsOf: destination)
        let tagSize = bytes[6..<10].reduce(0) { ($0 << 7) | Int($1) }
        var offset = 10
        var values: [String] = []
        while offset + 10 <= 10 + tagSize {
            let size = bytes[offset + 4..<offset + 8].reduce(0) { ($0 << 8) | Int($1) }
            if String(data: bytes[offset..<offset + 4], encoding: .ascii) == "TXXX" {
                let payload = Data(bytes[offset + 10..<offset + 10 + size])
                if payload[0] == 1 {
                    // ID3v2.3 requires a BOM on EACH Unicode string, not just the description.
                    let separator = try XCTUnwrap(stride(from: 1, to: payload.count - 1, by: 2).first { payload[$0] == 0 && payload[$0 + 1] == 0 })
                    values.append(try XCTUnwrap(String(data: payload[(separator + 2)...], encoding: .utf16)))
                } else {
                    let strings = try XCTUnwrap(String(data: payload.dropFirst(), encoding: .isoLatin1)).components(separatedBy: "\0")
                    XCTAssertEqual(strings.first, "TEMPOKEY_CAMELOT")
                    values.append(try XCTUnwrap(strings.last))
                }
            }
            offset += 10 + size
        }
        XCTAssertEqual(values, ["8A"])
    }

    func testEmptyID3v23TagCanBeExported() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("source.mp3"), destination = dir.appendingPathComponent("copy.mp3")
        try Data([73, 68, 51, 3, 0, 0, 0, 0, 0, 0, 0xff, 0xfb, 0x90, 0x64]).write(to: source)
        try await MetadataExport.writeCopy(source: source, destination: destination, bpm: 128, key: .init(tonic: .a, mode: .minor))
        XCTAssertEqual(try Data(contentsOf: destination).suffix(4), Data([0xff, 0xfb, 0x90, 0x64]))
    }

    func testUnsupportedID3LeavesDestinationUntouched() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("source.mp3"), destination = dir.appendingPathComponent("copy.mp3")
        try Data([73, 68, 51, 2, 0, 0, 0, 0, 0, 0]).write(to: source)
        try Data([9]).write(to: destination)
        do { try await MetadataExport.writeCopy(source: source, destination: destination, bpm: 120, key: .init(tonic: .c, mode: .major)); XCTFail("Must reject unsupported tag") } catch { }
        XCTAssertEqual(try Data(contentsOf: destination), Data([9]))
    }
    func testM4AMetadataRoundTrip() async throws {
        let dir = try directory(); defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("source.m4a"), destination = dir.appendingPathComponent("copy.m4a")
        try makeM4A(source)
        let original = try Data(contentsOf: source)
        try await MetadataExport.writeCopy(source: source, destination: destination, bpm: 128, key: .init(tonic: .a, mode: .minor))
        let asset = AVURLAsset(url: destination)
        let metadata = try await asset.load(.metadata)
        let bpm = try XCTUnwrap(metadata.first { $0.identifier == .iTunesMetadataBeatsPerMin })
        let number = try await bpm.load(.numberValue)
        XCTAssertEqual(number?.intValue, 128)
        let comment = try XCTUnwrap(metadata.first { $0.identifier == .iTunesMetadataUserComment })
        let text = try await comment.load(.stringValue)
        XCTAssertTrue(text?.contains("Key Am; Camelot 8A") == true)
        XCTAssertEqual(try Data(contentsOf: source), original)
        XCTAssertGreaterThan(try AVAudioFile(forReading: destination).length, 0)
    }
    @MainActor
    func testPNGIsNonemptyImage() throws {
        let result = AnalysisResult(fileName: "song.wav", duration: 10, overallBPM: 120,
                                    overallKey: .init(tonic: .c, mode: .major), bpmConfidence: 0.8,
                                    tempoSeries: [], keySeries: [], beats: [])
        let data = try AnalysisExport.png(result: result, overrides: .init())
        try data.write(to: URL(fileURLWithPath: "/tmp/TempoKey-report-preview.png"))
        XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
    }
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
    }
    private func makeM4A(_ url: URL) throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100))
        buffer.frameLength = 44100
        for i in 0..<44100 { buffer.floatChannelData![0][i] = Float(sin(Double(i) * 2 * .pi * 440 / 44100)) * 0.2 }
        let file = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 128000])
        try file.write(from: buffer)
    }
}
