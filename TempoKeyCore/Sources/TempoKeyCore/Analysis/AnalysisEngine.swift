import Foundation

public final class AnalysisEngine {
    private let analysisRate: Double
    public init(analysisRate: Double = 44100) { self.analysisRate = analysisRate }

    /// progress: 0…1. Runs synchronously; call off the main thread.
    public func analyze(url: URL, progress: ((Double) -> Void)? = nil) throws -> AnalysisResult {
        progress?(0.0)
        let decoded = try AudioDecoder(analysisRate: analysisRate).decode(url: url)
        progress?(0.3)

        let bt = BeatTempoTracker(sampleRate: analysisRate).process(decoded.samples)
        progress?(0.7)

        let key = KeyDetector(sampleRate: analysisRate).analyze(decoded.samples)
        progress?(1.0)

        return AnalysisResult(
            fileName: url.lastPathComponent,
            duration: decoded.duration,
            overallBPM: bt.overallBPM,
            overallKey: key.overall,
            bpmConfidence: bt.bpmConfidence,
            tempoSeries: bt.tempoSeries.map { TempoPoint(time: $0.time, bpm: $0.bpm) },
            keySeries: key.segments,
            beats: bt.beats
        )
    }
}
