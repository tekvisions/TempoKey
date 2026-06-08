import Foundation

public struct TempoPoint: Equatable {
    public let time: Double
    public let bpm: Double
    public init(time: Double, bpm: Double) { self.time = time; self.bpm = bpm }
}

public struct AnalysisResult {
    public let fileName: String
    public let duration: Double
    public let overallBPM: Double
    public let overallKey: MusicalKey
    public let bpmConfidence: Double
    public let tempoSeries: [TempoPoint]
    public let keySeries: [KeySegment]
    public let beats: [Double]

    public init(fileName: String, duration: Double, overallBPM: Double, overallKey: MusicalKey,
                bpmConfidence: Double, tempoSeries: [TempoPoint], keySeries: [KeySegment], beats: [Double]) {
        self.fileName = fileName; self.duration = duration
        self.overallBPM = overallBPM; self.overallKey = overallKey
        self.bpmConfidence = bpmConfidence; self.tempoSeries = tempoSeries
        self.keySeries = keySeries; self.beats = beats
    }
}
