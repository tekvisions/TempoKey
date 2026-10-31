import Foundation

/// Independently curated labels. Missing labels stay missing; estimates never become truth.
public struct CorpusReference: Decodable, Sendable {
    public let bpm: Double?
    public let key: MusicalKey?

    private enum CodingKeys: String, CodingKey { case bpm, key }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        bpm = try container.decodeIfPresent(Double.self, forKey: .bpm)
        key = try container.decodeIfPresent(MusicalKey.self, forKey: .key)
        if let bpm, !bpm.isFinite || bpm <= 0 {
            throw DecodingError.dataCorruptedError(forKey: .bpm, in: container, debugDescription: "Reference BPM must be finite and positive.")
        }
    }

    public func evaluate(bpm detected: Double, key detectedKey: MusicalKey) -> CorpusScore {
        let exact = bpm.map { detected.isFinite && abs(detected - $0) / $0 <= 0.02 }
        let octave = bpm.map { reference in
            [0.5, 1.0, 2.0].contains { factor in
                detected.isFinite && abs(detected * factor - reference) / reference <= 0.02
            }
        }
        return CorpusScore(tempoMatches: exact, octaveTempoMatches: octave,
                           keyMatches: key.map { $0 == detectedKey })
    }
}

public struct CorpusScore: Encodable, Sendable {
    public let tempoMatches: Bool?
    public let octaveTempoMatches: Bool?
    public let keyMatches: Bool?
    public var isFullyLabeled: Bool { tempoMatches != nil && keyMatches != nil }
}
