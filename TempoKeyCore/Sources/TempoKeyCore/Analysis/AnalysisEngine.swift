import Foundation

public final class AnalysisEngine {
    private let analysisRate: Double
    private let decoder: AudioDecoding
    private let resampler: AudioResampling
    private static let detectorRate = 44100.0

    public convenience init(analysisRate: Double = 44100) {
        self.init(analysisRate: analysisRate, decoder: AudioDecoder(analysisRate: analysisRate))
    }

    init(analysisRate: Double, decoder: AudioDecoding, resampler: AudioResampling = AppleAudioResampler()) {
        self.analysisRate = analysisRate
        self.decoder = decoder
        self.resampler = resampler
    }

    /// Synchronous/off-main-thread. Task cancellation is checked throughout decoding and DSP.
    public func analyze(url: URL, progress: ((Double) -> Void)? = nil) throws -> AnalysisResult {
        try Task.checkCancellation()
        guard analysisRate.isFinite, (8000...384000).contains(analysisRate) else { throw AnalysisError.invalidSampleRate }
        progress?(0)
        let decoded = try decoder.decode(url: url)
        progress?(0.3)
        return try analyze(samples: decoded.samples, sampleRate: decoded.sampleRate,
                           fileName: url.lastPathComponent) { progress?(0.3 + $0 * 0.7) }
    }

    /// Analyze mono PCM (e.g. a bounded live window), normalizing detectors to 44.1 kHz.
    /// Original duration is retained; analysis is limited to one hour, matching file decoding.
    public func analyze(samples: [Float], sampleRate: Double, fileName: String,
                        progress: ((Double) -> Void)? = nil) throws -> AnalysisResult {
        try Task.checkCancellation()
        guard sampleRate.isFinite, (8000...384000).contains(sampleRate) else { throw AnalysisError.invalidSampleRate }
        guard !samples.isEmpty else { throw AnalysisError.emptyAudio }
        let duration = Double(samples.count) / sampleRate
        guard duration <= 3600 else { throw AnalysisError.tooLongAudio }
        var energySum = 0.0
        for i in samples.indices {
            if i.isMultiple(of: 16384) { try Task.checkCancellation() }
            guard samples[i].isFinite else { throw AnalysisError.invalidSamples }
            let value = Double(samples[i]); energySum += value * value
        }
        guard sqrt(energySum / Double(samples.count)) > 0.000001 else { throw AnalysisError.silentAudio }
        progress?(0)
        let normalized = try resampler.resample(samples, from: sampleRate, to: Self.detectorRate)
        let rate = Self.detectorRate
        let bt = try BeatTempoTracker(sampleRate: rate).process(normalized, checkCancellation: { try Task.checkCancellation() })
        progress?(0.55)
        let key = try KeyDetector(sampleRate: rate).analyze(normalized, checkCancellation: { try Task.checkCancellation() })
        progress?(0.8)
        let energy = try DeeperAnalysis.energy(normalized, sampleRate: rate)
        // Four seconds is insufficient to establish a useful tempo consensus.
        let tempo = duration >= 4 ? bt.tempoSeries.map { TempoPoint(time: $0.time, bpm: $0.bpm) } : []
        let beats = duration >= 4 ? bt.beats : []
        let segments = key.segments.enumerated().map { index, segment in
            KeySegment(start: segment.start, end: index == key.segments.count - 1 ? duration : segment.end,
                       key: segment.key, confidence: segment.confidence)
        }
        let sections = try DeeperAnalysis.sections(energy: energy, duration: duration, tempo: tempo)
        let strengths = try DeeperAnalysis.beatStrengths(samples: normalized, sampleRate: rate, beats: beats)
        let meter = MeterEstimator.estimate(beats: beats, strengths: strengths)
        try Task.checkCancellation()
        progress?(1)
        return AnalysisResult(fileName: fileName, duration: duration,
                              overallBPM: duration >= 4 ? bt.overallBPM : 0, overallKey: key.overall,
                              bpmConfidence: duration >= 4 ? bt.bpmConfidence : 0,
                              tempoSeries: tempo, keySeries: segments, beats: beats,
                              energySeries: energy, sections: sections, meter: meter.meter, downbeats: meter.downbeats)
    }
}

public enum AnalysisError: LocalizedError {
    case emptyAudio, silentAudio, invalidSampleRate, invalidSamples, tooLongAudio
    public var errorDescription: String? {
        switch self {
        case .emptyAudio: return "This file contains no audio samples."
        case .silentAudio: return "This audio is silent. Try a recording with audible music."
        case .invalidSampleRate: return "The audio sample rate must be between 8 kHz and 384 kHz."
        case .invalidSamples: return "The audio contains invalid sample values."
        case .tooLongAudio: return "This audio is longer than the one-hour analysis limit."
        }
    }
}
