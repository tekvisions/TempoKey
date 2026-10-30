import XCTest
@testable import TempoKeyCore

final class SampleRateAnalysisTests: XCTestCase {
    private func signal(rate: Double) -> [Float] {
        var pulse = TestSignals.clickTrack(bpm: 120, seconds: 12, sampleRate: rate)
        let chord = TestSignals.tones([261.6256, 329.6276, 391.9954], seconds: 12, sampleRate: rate)
        for i in pulse.indices { pulse[i] = pulse[i] * 0.8 + chord[i] * 0.15 }
        return pulse
    }

    func testPCMAtLowAndHighRatesMatchesCanonicalTempoAndKey() throws {
        let engine = AnalysisEngine()
        let reference = try engine.analyze(samples: signal(rate: 44100), sampleRate: 44100, fileName: "reference")
        XCTAssertEqual(reference.overallBPM, 120, accuracy: 4)
        for rate in [8000.0, 96000, 384000] {
            let samples = signal(rate: rate)
            let original = samples
            let result = try engine.analyze(samples: samples, sampleRate: rate, fileName: "\(rate)")
            XCTAssertEqual(result.overallBPM, 120, accuracy: 4, "rate \(rate)")
            XCTAssertEqual(result.overallBPM, reference.overallBPM, accuracy: 4, "rate \(rate)")
            XCTAssertEqual(result.overallKey, reference.overallKey, "rate \(rate)")
            XCTAssertEqual(result.duration, 12, accuracy: 0.000001)
            XCTAssertEqual(result.keySeries.last?.end ?? 0, 12, accuracy: 0.000001)
            XCTAssertFalse(result.beats.isEmpty)
            XCTAssertEqual(samples, original)
        }
    }

    func testCustomFileDecodeRateStillUsesCanonicalDetectorTimeConstants() throws {
        let url = try TestSignals.writeWAV(signal(rate: 44100))
        defer { try? FileManager.default.removeItem(at: url) }
        let result = try AnalysisEngine(analysisRate: 8000).analyze(url: url)
        XCTAssertEqual(result.overallBPM, 120, accuracy: 4)
        XCTAssertEqual(result.overallKey, MusicalKey(tonic: .c, mode: .major))
        XCTAssertEqual(result.duration, 12, accuracy: 0.01)
    }

    func testResamplingRetainsFractionalOriginalDurationAndShortTail() throws {
        for (samples, rate) in [(TestSignals.tones([440], seconds: 0.23, sampleRate: 48000), 48000.0), ([Float(1)], 8000.0)] {
            let duration = Double(samples.count) / rate
            let result = try AnalysisEngine().analyze(samples: samples, sampleRate: rate, fileName: "short")
            XCTAssertEqual(result.duration, duration, accuracy: 1e-12)
            XCTAssertEqual(result.keySeries.last?.end ?? 0, duration, accuracy: 1e-12)
            XCTAssertEqual(result.overallBPM, 0)
            XCTAssertEqual(result.bpmConfidence, 0)
        }
    }

    func testInvalidDecoderRateFailsBeforeOpeningFile() {
        for rate in [0.0, Double.nan, Double.infinity, 1000000] {
            XCTAssertThrowsError(try AnalysisEngine(analysisRate: rate).analyze(url: URL(fileURLWithPath: "/missing.wav"))) {
                guard case AnalysisError.invalidSampleRate = $0 else { return XCTFail("Expected sample-rate validation, got \($0)") }
            }
        }
    }
}
