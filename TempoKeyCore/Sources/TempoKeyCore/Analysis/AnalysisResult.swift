import Foundation

struct TempoPoint: Equatable { let time: Double; let bpm: Double }

public struct AnalysisResult {
    let fileName: String
    let duration: Double
    let overallBPM: Double
    let overallKey: MusicalKey
    let bpmConfidence: Double
    let tempoSeries: [TempoPoint]
    let keySeries: [KeySegment]
    let beats: [Double]
}
