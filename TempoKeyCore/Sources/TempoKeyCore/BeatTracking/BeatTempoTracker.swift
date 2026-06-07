import Foundation

struct BeatTempoOutput {
    var overallBPM: Double
    var bpmConfidence: Double
    var tempoSeries: [(time: Double, bpm: Double)]
    var beats: [Double]      // seconds
}

final class BeatTempoTracker {
    private let sampleRate: Double
    private let hop: Int
    private let ossRate: Double
    private let onset: OnsetDetector
    private let tempo: TempoTracker
    private let beat: BeatTracker
    private let tempoSamplePeriod: Int   // emit a tempo point every N hops (~0.25 s)

    init(sampleRate: Double = 44100, fftSize: Int = 1024, hop: Int = 128) {
        self.sampleRate = sampleRate
        self.hop = hop
        self.ossRate = sampleRate / Double(hop)
        self.onset = OnsetDetector(sampleRate: sampleRate, fftSize: fftSize, hop: hop)
        self.tempo = TempoTracker(ossRate: ossRate)
        self.beat = BeatTracker()
        self.tempoSamplePeriod = max(1, Int(ossRate * 0.25))
    }

    func process(_ samples: [Float]) -> BeatTempoOutput {
        let oss = onset.process(samples)
        var series: [(Double, Double)] = []
        for (i, v) in oss.enumerated() {
            tempo.push(v)
            let bpm = tempo.currentBPM
            let T = bpm > 0 ? 60.0 * ossRate / bpm : 0
            beat.push(v, beatPeriod: T)
            if i % tempoSamplePeriod == 0 && bpm > 0 {
                series.append((Double(i) / ossRate, bpm))
            }
        }
        let overall = tempo.currentBPM
        let T = overall > 0 ? 60.0 * ossRate / overall : 0
        let beats = beat.beatIndices(beatPeriod: T).map { Double($0) / ossRate }
        return BeatTempoOutput(overallBPM: overall,
                               bpmConfidence: tempo.certainty,
                               tempoSeries: series,
                               beats: beats)
    }
}
