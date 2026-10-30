import XCTest
@testable import TempoKeyCore

final class AnalysisSeamTests: XCTestCase {
    func testInjectedPCMDecoderUsesDecodedRateAndDuration() throws {
        struct PCMDecoder: AudioDecoding {
            func decode(url: URL) throws -> DecodedAudio {
                DecodedAudio(samples: TestSignals.tones([440], seconds: 0.5, sampleRate: 48000), sampleRate: 48000)
            }
        }
        let result = try AnalysisEngine(analysisRate: 44100, decoder: PCMDecoder()).analyze(url: URL(fileURLWithPath: "/fixture.wav"))
        XCTAssertEqual(result.duration, 0.5, accuracy: 0.0001)
        XCTAssertEqual(result.fileName, "fixture.wav")
        XCTAssertEqual(result.overallBPM, 0)
        XCTAssertEqual(result.bpmConfidence, 0)
    }

    func testWindowSeamPreservesEnergyNormalizedPeriodicHannNumerics() {
        let actual = AccelerateWindows().hann(size: 8)
        let expected: [Float] = [0, 0.23914631, 0.81649658, 1.39384685, 1.63299316, 1.39384685, 0.81649658, 0.23914631]
        for (a, b) in zip(actual, expected) { XCTAssertEqual(a, b, accuracy: 0.00001) }
    }

    func testInjectedFFTAndWindowFeedChromaFolding() {
        struct FlatWindow: WindowGenerating { func hann(size: Int) -> [Float] { [Float](repeating: 1, count: size) } }
        struct BinFFT: RealTransform {
            func magnitudes(_ input: [Float]) -> [Float] {
                // 128 Hz sample rate / 128 bins: bin 55 = A1.
                var bins = [Float](repeating: 0, count: 65)
                bins[55] = input.reduce(0, +)
                return bins
            }
            func generalizedAutocorrelation(_ input: [Float], exponent: Float) -> [Float] { input }
        }
        let chroma = Chromagram(sampleRate: 128, fftSize: 128, fft: BinFFT(), windows: FlatWindow()).compute([Float](repeating: 1, count: 128))
        XCTAssertEqual(chroma[9], 1)
        XCTAssertEqual(chroma.reduce(0, +), 1)
    }
}
