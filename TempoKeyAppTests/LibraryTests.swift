import XCTest
import AVFoundation
@testable import TempoKey
import TempoKeyCore

final class LibraryTests: XCTestCase {
    func testFolderExpansionFiltersDeduplicatesAndSkipsHiddenFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let song = root.appendingPathComponent("song.wav")
        for name in ["song.wav", "notes.txt", ".hidden.mp3"] {
            try Data().write(to: root.appendingPathComponent(name))
        }
        XCTAssertEqual(try LibraryFiles.expand([root, song]), [song])
    }

    func testCSVQuotesFileNamesAndUsesCorrections() {
        let result = AnalysisResult(fileName: "a,\"b\".wav", duration: 10, overallBPM: 120,
                                    overallKey: .init(tonic: .c, mode: .major), bpmConfidence: 0.8,
                                    tempoSeries: [], keySeries: [], beats: [])
        let csv = AnalysisExport.csv([(result, DisplayOverrides(bpmMultiplier: 0.5))])
        XCTAssertTrue(csv.contains("\"a,\"\"b\"\".wav\""))
        XCTAssertTrue(csv.contains("60.00"))
    }

    @MainActor
    func testResetPreventsLateAnalysisFromReplacingState() async throws {
        let state = AppState()
        state.analyze(url: URL(fileURLWithPath: "/nonexistent.wav"))
        state.reset()
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(state.phase, .idle)
        XCTAssertNil(state.result)
    }

    func testTransportClampsSeekAndLoopBoundaries() {
        XCTAssertEqual(TransportBounds.seek(-10, duration: 12), 0)
        XCTAssertEqual(TransportBounds.seek(15, duration: 12), 12)
        XCTAssertEqual(TransportBounds.loop(5...20, duration: 10), 5...10)
        XCTAssertNil(TransportBounds.loop(5...5, duration: 10))
    }
    @MainActor
    func testBatchKeepsSuccessesWhenOneFileIsInvalid() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try makeAudio(root.appendingPathComponent("good.wav"))
        try Data("invalid audio".utf8).write(to: root.appendingPathComponent("bad.wav"))
        let suite = "TempoKeyTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let state = AppState(defaults: defaults)
        state.importFiles([root])
        for _ in 0..<100 where state.isAnalyzing { try await Task.sleep(for: .milliseconds(30)) }
        XCTAssertFalse(state.isAnalyzing)
        XCTAssertEqual(state.tracks.count, 2)
        XCTAssertEqual(state.tracks.filter { $0.result != nil }.count, 1)
        XCTAssertEqual(state.tracks.filter { $0.error != nil }.count, 1)
        XCTAssertEqual(state.progress, 1)
        state.reset()
    }

    func testLiveBufferRetainsLatestMonoSamples() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
        let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 6))
        pcm.frameLength = 6
        for index in 0..<6 { pcm.floatChannelData![0][index] = Float(index); pcm.floatChannelData![1][index] = Float(index + 2) }
        let buffer = LiveSampleBuffer(capacity: 4)
        buffer.append(pcm)
        XCTAssertEqual(buffer.snapshot(), [3, 4, 5, 6])
        buffer.append(pcm)
        XCTAssertEqual(buffer.snapshot(), [3, 4, 5, 6])
    }

    @MainActor
    func testPlaybackLoadSeekAndClose() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try makeAudio(url)
        let playback = PlaybackController()
        try playback.load(url: url, accessURL: url, beats: [])
        XCTAssertTrue(playback.available)
        playback.seek(999)
        XCTAssertEqual(playback.time, playback.duration)
        playback.close()
        XCTAssertFalse(playback.available)
        XCTAssertFalse(playback.isPlaying)
        XCTAssertEqual(playback.time, 0)
    }

    @MainActor
    func testRecentBookmarksPersistAndClear() throws {
        let suite = "TempoKeyTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        try Data([1]).write(to: file); defer { try? FileManager.default.removeItem(at: file) }
        let recents = RecentFiles(defaults: defaults)
        recents.add(file); recents.add(file)
        XCTAssertEqual(recents.items.count, 1)
        let reloaded = RecentFiles(defaults: defaults)
        XCTAssertEqual(reloaded.items.count, 1)
        XCTAssertEqual(try reloaded.resolve(XCTUnwrap(reloaded.items.first)).standardizedFileURL, file.standardizedFileURL)
        reloaded.clear()
        XCTAssertTrue(RecentFiles(defaults: defaults).items.isEmpty)
    }

    private func makeAudio(_ url: URL) throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let pcm = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44100 * 4))
        pcm.frameLength = pcm.frameCapacity
        for index in 0..<Int(pcm.frameLength) { pcm.floatChannelData![0][index] = Float(sin(Double(index) * 2 * .pi * 440 / 44100)) * 0.2 }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: pcm)
    }

}
