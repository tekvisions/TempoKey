import Foundation

public struct TempoPoint: Equatable, Codable, Sendable {
    public let time: Double
    public let bpm: Double
    public init(time: Double, bpm: Double) { self.time = time; self.bpm = bpm }
}

public struct AnalysisResult: Equatable, Codable, Sendable {
    public let fileName: String
    public let duration: Double
    public let overallBPM: Double
    public let overallKey: MusicalKey
    public let bpmConfidence: Double
    public let tempoSeries: [TempoPoint]
    public let keySeries: [KeySegment]
    public let beats: [Double]

    public let energySeries: [EnergyPoint]
    public let sections: [AnalysisSection]
    public let meter: MeterEstimate?
    public let downbeats: [Double]

    public init(fileName: String, duration: Double, overallBPM: Double, overallKey: MusicalKey,
                bpmConfidence: Double, tempoSeries: [TempoPoint], keySeries: [KeySegment], beats: [Double],
                energySeries: [EnergyPoint] = [], sections: [AnalysisSection] = [],
                meter: MeterEstimate? = nil, downbeats: [Double] = []) {
        self.fileName = fileName; self.duration = duration
        self.overallBPM = overallBPM; self.overallKey = overallKey
        self.bpmConfidence = bpmConfidence; self.tempoSeries = tempoSeries
        self.keySeries = keySeries; self.beats = beats
        self.energySeries = energySeries; self.sections = sections
        self.meter = meter; self.downbeats = downbeats
    }
    private enum CodingKeys: String, CodingKey {
        case fileName, duration, overallBPM, overallKey, bpmConfidence, tempoSeries, keySeries, beats
        case energySeries, sections, meter, downbeats
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(fileName: try c.decode(String.self, forKey: .fileName),
                  duration: try c.decode(Double.self, forKey: .duration),
                  overallBPM: try c.decode(Double.self, forKey: .overallBPM),
                  overallKey: try c.decode(MusicalKey.self, forKey: .overallKey),
                  bpmConfidence: try c.decode(Double.self, forKey: .bpmConfidence),
                  tempoSeries: try c.decode([TempoPoint].self, forKey: .tempoSeries),
                  keySeries: try c.decode([KeySegment].self, forKey: .keySeries),
                  beats: try c.decode([Double].self, forKey: .beats),
                  energySeries: try c.decodeIfPresent([EnergyPoint].self, forKey: .energySeries) ?? [],
                  sections: try c.decodeIfPresent([AnalysisSection].self, forKey: .sections) ?? [],
                  meter: try c.decodeIfPresent(MeterEstimate.self, forKey: .meter),
                  downbeats: try c.decodeIfPresent([Double].self, forKey: .downbeats) ?? [])
    }
}

public struct EnergyPoint: Equatable, Codable, Sendable {
    public let time: Double
    public let rms: Double
    public init(time: Double, rms: Double) { self.time = time; self.rms = rms }
}

public struct AnalysisSection: Equatable, Codable, Sendable {
    public let start: Double
    public let end: Double
    public let label: String
    /// Median local tempo; zero means insufficient rhythmic evidence.
    public let bpm: Double
    public let energy: Double
    public init(start: Double, end: Double, label: String, bpm: Double, energy: Double) {
        self.start = start; self.end = end; self.label = label; self.bpm = bpm; self.energy = energy
    }
}

public struct MeterEstimate: Equatable, Codable, Sendable {
    public let beatsPerBar: Int
    /// Heuristic accent consistency, not a calibrated probability.
    public let confidence: Double
    public init(beatsPerBar: Int, confidence: Double) {
        self.beatsPerBar = beatsPerBar; self.confidence = confidence
    }
}
