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
        process(samples, checkCancellation: {})
    }

    func process(_ samples: [Float], checkCancellation: () throws -> Void) rethrows -> BeatTempoOutput {
        let oss = try onset.process(samples, checkCancellation: checkCancellation)
        var times: [Double] = []
        var rawBPM: [Double] = []
        for (i, v) in oss.enumerated() {
            if i.isMultiple(of: 64) { try checkCancellation() }
            tempo.push(v)
            let bpm = tempo.currentBPM
            let T = bpm > 0 ? 60.0 * ossRate / bpm : 0
            beat.push(v, beatPeriod: T)
            if i % tempoSamplePeriod == 0 && bpm > 0 {
                times.append(Double(i) / ossRate)
                rawBPM.append(bpm)
            }
        }

        // Edge-preserving median smoothing of the displayed tempo: removes isolated frame-to-frame
        // flips (and ambiguous intro/outro/transition spikes) while keeping genuine tempo steps.
        let smoothBPM = Self.medianFilter(rawBPM, radius: 4)
        let series = zip(times, smoothBPM).map { (time: $0.0, bpm: $0.1) }

        // Overall = median of the smoothed series (robust to intro/outro/transition outliers).
        // The decaying histogram's end-of-song peak is not representative for tempo-changing songs.
        let overall = Self.median(smoothBPM) ?? tempo.currentBPM
        let T = overall > 0 ? 60.0 * ossRate / overall : 0
        let beats = beat.beatIndices(beatPeriod: T).map { Double($0) / ossRate }

        return BeatTempoOutput(overallBPM: overall,
                               bpmConfidence: tempo.certainty,
                               tempoSeries: series,
                               beats: beats)
    }

    static func median(_ a: [Double]) -> Double? {
        guard !a.isEmpty else { return nil }
        let s = a.sorted()
        let n = s.count
        return n.isMultiple(of: 2) ? (s[n / 2 - 1] + s[n / 2]) / 2 : s[n / 2]
    }

    /// Sliding-window median (window = 2*radius+1). Edge-preserving; clamps window at the ends.
    static func medianFilter(_ a: [Double], radius r: Int) -> [Double] {
        guard r > 0, a.count > 2 * r else { return a }
        var out = a
        for i in a.indices {
            let lo = max(0, i - r), hi = min(a.count - 1, i + r)
            out[i] = median(Array(a[lo...hi])) ?? a[i]
        }
        return out
    }
}
