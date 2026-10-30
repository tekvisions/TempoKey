import XCTest
@testable import TempoKeyCore

final class DeeperAnalysisTests: XCTestCase {
    func testOpenKeyWheelMappings() {
        let major = ["1d", "8d", "3d", "10d", "5d", "12d", "7d", "2d", "9d", "4d", "11d", "6d"]
        let minor = ["10m", "5m", "12m", "7m", "2m", "9m", "4m", "11m", "6m", "1m", "8m", "3m"]
        for pc in PitchClass.allCases {
            XCTAssertEqual(MusicalKey(tonic: pc, mode: .major).openKey, major[pc.rawValue])
            XCTAssertEqual(MusicalKey(tonic: pc, mode: .minor).openKey, minor[pc.rawValue])
        }
    }

    func testJSONRoundTripPreservesMeasurementsAndLegacyDefaults() throws {
        let result = try AnalysisEngine().analyze(samples: TestSignals.tones([261.63, 329.63, 392], seconds: 1), sampleRate: 44100, fileName: "tone.wav")
        let data = try JSONEncoder().encode(result)
        XCTAssertEqual(try JSONDecoder().decode(AnalysisResult.self, from: data), result)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["energySeries", "sections", "meter", "downbeats"] { object.removeValue(forKey: key) }
        let legacy = try JSONDecoder().decode(AnalysisResult.self, from: JSONSerialization.data(withJSONObject: object))
        XCTAssertEqual(legacy.energySeries, [])
        XCTAssertEqual(legacy.sections, [])
        XCTAssertNil(legacy.meter)
        XCTAssertEqual(legacy.downbeats, [])
        XCTAssertEqual(legacy.overallKey, result.overallKey)
    }

    func testRejectsEmptySilenceAndInvalidSampleInput() {
        let engine = AnalysisEngine()
        for (samples, rate) in [([], 44100.0), ([0, 0], 44100), ([1], 0), ([Float.nan], 44100)] {
            XCTAssertThrowsError(try engine.analyze(samples: samples, sampleRate: rate, fileName: "invalid"))
        }
    }

    func testEnergyStepProducesNeutralSectionsWithExactRMS() throws {
        let samples = [Float](repeating: 0.1, count: 44100 * 6) + [Float](repeating: 0.8, count: 44100 * 6)
        let result = try AnalysisEngine().analyze(samples: samples, sampleRate: 44100, fileName: "step")
        XCTAssertEqual(result.energySeries.first?.rms ?? 0, 0.1, accuracy: 0.0001)
        XCTAssertEqual(result.energySeries.last?.rms ?? 0, 0.8, accuracy: 0.0001)
        XCTAssertEqual(result.sections.count, 2)
        XCTAssertEqual(result.sections[0].start, 0)
        XCTAssertEqual(result.sections[0].end, 6, accuracy: 0.25)
        XCTAssertEqual(result.sections[1].end, 12)
        XCTAssertEqual(result.sections.map(\.label), ["Section 1", "Section 2"])
        XCTAssertNil(result.meter)
        XCTAssertTrue(result.downbeats.isEmpty)
    }

    func testMeterNeedsRepeatedAccentsAndDistinguishesTripleFromQuadruple() {
        let beats = (0..<48).map { Double($0) * 0.5 }
        let equal = [Double](repeating: 1, count: 48)
        XCTAssertNil(MeterEstimator.estimate(beats: beats, strengths: equal).meter)
        for count in [3, 4] {
            let strengths = (0..<48).map { $0 % count == 0 ? 1.0 : 0.2 }
            let estimate = MeterEstimator.estimate(beats: beats, strengths: strengths)
            XCTAssertEqual(estimate.meter?.beatsPerBar, count)
            XCTAssertLessThanOrEqual(estimate.meter?.confidence ?? 1, 0.85)
            XCTAssertEqual(estimate.downbeats.first, 0)
            XCTAssertEqual(estimate.downbeats[1], Double(count) * 0.5)
        }
    }

    func testAmbiguousAndShortAccentPatternsHaveNoMeter() {
        let beats = (0..<48).map { Double($0) * 0.5 }
        let ambiguous = (0..<48).map { $0 % 3 == 0 || $0 % 4 == 0 ? 1.0 : 0.2 }
        XCTAssertNil(MeterEstimator.estimate(beats: beats, strengths: ambiguous).meter)
        XCTAssertNil(MeterEstimator.estimate(beats: Array(beats.prefix(12)), strengths: [Double](repeating: 1, count: 12)).meter)
        let irregular = beats.enumerated().map { $0.element + ($0.offset % 2 == 0 ? 0.15 : 0) }
        XCTAssertNil(MeterEstimator.estimate(beats: irregular, strengths: ambiguous).meter)
    }

    func testSampleAnalysisHonorsCancellationBetweenStages() async {
        let cancelled = await Task.detached { () -> Bool in
            do {
                _ = try AnalysisEngine().analyze(samples: TestSignals.clickTrack(bpm: 120, seconds: 5), sampleRate: 44100, fileName: "cancel") { progress in
                    if progress >= 0.55 { withUnsafeCurrentTask { $0?.cancel() } }
                }
                return false
            } catch is CancellationError { return true }
            catch { return false }
        }.value
        XCTAssertTrue(cancelled)
    }

    func testRollingAudioBufferKeepsNewestSamplesAndResets() {
        let buffer = RollingAudioBuffer(sampleRate: 10, maxDuration: 1)
        buffer.append(Array(0..<7).map(Float.init))
        buffer.append(Array(7..<15).map(Float.init))
        XCTAssertEqual(buffer.samples, Array(5..<15).map(Float.init))
        XCTAssertEqual(buffer.count, 10)
        buffer.append(Array(15..<40).map(Float.init))
        XCTAssertEqual(buffer.samples, Array(30..<40).map(Float.init))
        XCTAssertEqual(buffer.count, 10)
        buffer.reset()
        XCTAssertEqual(buffer.samples, [])
    }

    func testLongAnalysisLoopsCooperateWithCancellation() {
        let signal = TestSignals.tones([440], seconds: 1)
        var checks = 0
        XCTAssertThrowsError(try Chromagram(sampleRate: 44100).compute(signal, checkCancellation: {
            checks += 1
            if checks == 3 { throw CancellationError() }
        })) { XCTAssertTrue($0 is CancellationError) }
        checks = 0
        XCTAssertThrowsError(try BeatTempoTracker().process(signal, checkCancellation: {
            checks += 1
            if checks == 3 { throw CancellationError() }
        })) { XCTAssertTrue($0 is CancellationError) }
    }
}
