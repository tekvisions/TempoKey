import TempoKeyCore

/// Timeline sampling is roughly 0.25 s. A missing run is missing evidence, not a ramp.
enum TempoTimelineData {
    static func runs(_ series: [TempoPoint]) -> [[TempoPoint]] {
        var result: [[TempoPoint]] = []
        for point in series {
            if let previous = result.last?.last, point.time - previous.time <= 0.5 {
                result[result.count - 1].append(point)
            } else { result.append([point]) }
        }
        return result
    }

    static func bpm(at time: Double, series: [TempoPoint]) -> Double? {
        guard let nearest = series.min(by: { abs($0.time - time) < abs($1.time - time) }),
              abs(nearest.time - time) <= 0.5 else { return nil }
        return nearest.bpm
    }
}
