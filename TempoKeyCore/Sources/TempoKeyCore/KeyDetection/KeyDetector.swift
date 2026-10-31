import Foundation

public struct KeySegment: Equatable, Codable, Sendable {
    public let start: Double
    public let end: Double
    public let key: MusicalKey
    public let confidence: Double
    public init(start: Double, end: Double, key: MusicalKey, confidence: Double) {
        self.start = start; self.end = end; self.key = key; self.confidence = confidence
    }
}

struct KeyAnalysis {
    let overall: MusicalKey
    let segments: [KeySegment]
}

final class KeyDetector {
    private static let major: [Double] = [6.35,2.23,3.48,2.33,4.38,4.09,2.52,5.19,2.39,3.66,2.29,2.88]
    private static let minor: [Double] = [6.33,2.68,3.52,5.38,2.60,3.53,2.54,4.75,3.98,2.69,3.34,3.17]

    private let sampleRate: Double
    private let windowSeconds: Double
    private let hopSeconds: Double
    private let chromagram: Chromagram

    init(sampleRate: Double, windowSeconds: Double = 4, hopSeconds: Double = 1, fftSize: Int = 8192) {
        self.sampleRate = sampleRate
        self.windowSeconds = windowSeconds
        self.hopSeconds = hopSeconds
        self.chromagram = Chromagram(sampleRate: sampleRate, fftSize: fftSize)
    }

    private func correlate(_ chroma: [Double], _ profile: [Double], rotation: Int) -> Double {
        let rotated = (0..<12).map { profile[(($0 - rotation) % 12 + 12) % 12] }
        let mc = chroma.reduce(0,+)/12, mp = rotated.reduce(0,+)/12
        var num = 0.0, dc = 0.0, dp = 0.0
        for i in 0..<12 {
            let a = chroma[i]-mc, b = rotated[i]-mp
            num += a*b; dc += a*a; dp += b*b
        }
        let den = (dc*dp).squareRoot()
        return den == 0 ? 0 : num/den
    }

    private func bestKey(_ chroma: [Double]) -> (MusicalKey, Double) {
        var best = (MusicalKey(tonic: .c, mode: .major), -2.0)
        for pc in PitchClass.allCases {
            let maj = correlate(chroma, Self.major, rotation: pc.rawValue)
            if maj > best.1 { best = (MusicalKey(tonic: pc, mode: .major), maj) }
            let min = correlate(chroma, Self.minor, rotation: pc.rawValue)
            if min > best.1 { best = (MusicalKey(tonic: pc, mode: .minor), min) }
        }
        return best
    }

    func analyze(_ samples: [Float]) -> KeyAnalysis {
        analyze(samples, checkCancellation: {})
    }

    func analyze(_ samples: [Float], checkCancellation: () throws -> Void) rethrows -> KeyAnalysis {
        let winN = Int(windowSeconds * sampleRate)
        let hopN = max(1, Int(hopSeconds * sampleRate))
        var raw: [(start: Double, end: Double, key: MusicalKey, conf: Double)] = []
        var start = 0
        while start < samples.count {
            let end = min(start + winN, samples.count)
            try checkCancellation()
            if end - start < winN / 2 && !raw.isEmpty { break }
            let slice = Array(samples[start..<end])
            let chroma = try chromagram.compute(slice, hop: nil, checkCancellation: checkCancellation)
            let (key, conf) = bestKey(chroma)
            raw.append((Double(start)/sampleRate, Double(end)/sampleRate, key, min(conf, Double(end - start) / Double(winN))))
            start += hopN
        }
        var segments: [KeySegment] = []
        for (index, r) in raw.enumerated() {
            // Overlapping analysis windows vote on adjacent, disjoint timeline cells.
            let cellEnd = index + 1 < raw.count ? raw[index + 1].start : Double(samples.count) / sampleRate
            if let last = segments.last, last.key == r.key,
               (last.confidence > 0) == (r.conf > 0) {
                segments[segments.count-1] = KeySegment(start: last.start, end: cellEnd,
                                                        key: last.key,
                                                        confidence: max(last.confidence, r.conf))
            } else {
                segments.append(KeySegment(start: r.start, end: cellEnd, key: r.key, confidence: r.conf))
            }
        }
        var durationByKey: [String: (MusicalKey, Double)] = [:]
        for s in segments where s.confidence > 0 {
            let cur = durationByKey[s.key.name]?.1 ?? 0
            durationByKey[s.key.name] = (s.key, cur + (s.end - s.start))
        }
        let overall = durationByKey.values.sorted { $0.0.name < $1.0.name }.max(by: { $0.1 < $1.1 })?.0
            ?? MusicalKey(tonic: .c, mode: .major)
        return KeyAnalysis(overall: overall, segments: segments)
    }
}
