import Foundation

struct DeeperAnalysis {
    static func energy(_ samples: [Float], sampleRate: Double) throws -> [EnergyPoint] {
        let width = max(1, Int(sampleRate * 0.25))
        var points: [EnergyPoint] = []
        for start in stride(from: 0, to: samples.count, by: width) {
            try Task.checkCancellation()
            let end = min(samples.count, start + width)
            var sum = 0.0
            for index in start..<end { let v = Double(samples[index]); sum += v * v }
            points.append(EnergyPoint(time: Double(start) / sampleRate, rms: sqrt(sum / Double(end - start))))
        }
        return points
    }

    /// Sustained RMS or tempo changes. These boundaries carry no inferred musical meaning.
    static func sections(energy: [EnergyPoint], duration: Double, tempo: [TempoPoint]) throws -> [AnalysisSection] {
        guard !energy.isEmpty else { return [] }
        var boundaries = [0.0]
        let context = 8 // two seconds on each side
        if energy.count > context * 2 {
            for i in context..<(energy.count - context) {
                try Task.checkCancellation()
                guard energy[i].time - (boundaries.last ?? 0) >= 4,
                      duration - energy[i].time >= 4 else { continue }
                let before = BeatTempoTracker.median(energy[(i-context)..<i].map(\.rms)) ?? 0
                let after = BeatTempoTracker.median(energy[i..<(i+context)].map(\.rms)) ?? 0
                let ratio = max(before, after) / max(0.000001, min(before, after))
                // Locate the step itself instead of the first window that sees it.
                let localChange = abs(energy[i].rms - energy[i-1].rms)
                if ratio >= 1.8 && localChange > max(0.015, abs(after - before) * 0.5) {
                    boundaries.append(energy[i].time)
                }
            }
        }
        // Preserve sharp RMS boundaries when tempo evidence is slightly delayed.
        // Boundaries closer than four seconds describe the same change; no short cells.
        for time in try tempoBoundaries(tempo, duration: duration) {
            if time >= 4, duration - time >= 4,
               boundaries.allSatisfy({ abs($0 - time) >= 4 }) {
                boundaries.append(time)
            }
        }
        boundaries.sort()
        boundaries.append(duration)
        return zip(boundaries, boundaries.dropFirst()).enumerated().map { index, pair in
            let points = energy.filter { $0.time >= pair.0 && $0.time < pair.1 }
            let localTempo = tempo.filter { $0.time >= pair.0 && $0.time < pair.1 }.map(\.bpm)
            return AnalysisSection(start: pair.0, end: pair.1, label: "Section \(index + 1)",
                                   bpm: BeatTempoTracker.median(localTempo) ?? 0,
                                   energy: points.map(\.rms).reduce(0, +) / Double(max(1, points.count)))
        }
    }

    private static func tempoBoundaries(_ tempo: [TempoPoint], duration: Double) throws -> [Double] {
        let points = tempo.filter { $0.time.isFinite && $0.time >= 0 && $0.time < duration && $0.bpm.isFinite && $0.bpm > 0 }
            .sorted { $0.time < $1.time }
        guard points.count >= 16 else { return [] }
        var boundaries: [Double] = []
        var lo = 0, hi = 0
        for i in 1..<points.count {
            try Task.checkCancellation()
            let time = points[i].time
            guard time >= 4, duration - time >= 4 else { continue }
            while lo < i && points[lo].time < time - 2 { lo += 1 }
            hi = max(hi, i)
            while hi < points.count && points[hi].time < time + 2 { hi += 1 }
            guard i - lo >= 6, hi - i >= 6,
                  points[i - 1].time - points[lo].time >= 1.5,
                  points[hi - 1].time - time >= 1.5 else { continue }
            let before = points[lo..<i].map(\.bpm)
            let after = points[i..<hi].map(\.bpm)
            guard let left = BeatTempoTracker.median(before), let right = BeatTempoTracker.median(after) else { continue }
            let change = abs(right - left)
            guard change >= max(5, min(left, right) * 0.04) else { continue }
            let ratio = max(left, right) / min(left, right)
            // Half/double-time interpretation changes are too ambiguous to mark as structure.
            guard !(1.9...2.1).contains(ratio) else { continue }
            let leftMAD = BeatTempoTracker.median(before.map { abs($0 - left) }) ?? 0
            let rightMAD = BeatTempoTracker.median(after.map { abs($0 - right) }) ?? 0
            guard leftMAD <= max(1.5, left * 0.015), rightMAD <= max(1.5, right * 0.015) else { continue }
            // A majority in a two-second window can still be a short false plateau.
            // Confirm the new tempo through the minimum four-second section span,
            // including its end, before suppressing nearby boundary candidates.
            var confirmationEnd = hi
            while confirmationEnd < points.count && points[confirmationEnd].time < time + 4 {
                confirmationEnd += 1
            }
            let confirmation = points[i..<confirmationEnd]
            let tolerance = max(1.5, right * 0.015)
            guard let last = confirmation.last, last.time - time >= 3.5,
                  Double(confirmation.filter { abs($0.bpm - right) <= tolerance }.count) / Double(confirmation.count) >= 0.8,
                  confirmation.suffix(2).allSatisfy({ abs($0.bpm - right) <= tolerance }) else { continue }
            // Confirm the old plateau as well: otherwise the return from a short
            // glitch would itself look like a sustained change to the original BPM.
            var confirmationStart = lo
            while confirmationStart > 0 && points[confirmationStart - 1].time >= time - 4 {
                confirmationStart -= 1
            }
            let preceding = points[confirmationStart..<i]
            let leftTolerance = max(1.5, left * 0.015)
            guard let first = preceding.first, time - first.time >= 3.5,
                  Double(preceding.filter { abs($0.bpm - left) <= leftTolerance }.count) / Double(preceding.count) >= 0.8,
                  preceding.prefix(2).allSatisfy({ abs($0.bpm - left) <= leftTolerance }) else { continue }
            // Anchor the boundary where local tempo crosses the two stable medians.
            // This prevents looking-ahead windows from splitting before the actual step.
            let midpoint = (left + right) / 2
            let previous = points[i - 1].bpm, current = points[i].bpm
            let crosses = right > left ? (previous < midpoint && current >= midpoint)
                : (previous > midpoint && current <= midpoint)
            if crosses { boundaries.append(time) }
        }
        return boundaries
    }

    static func beatStrengths(samples: [Float], sampleRate: Double, beats: [Double]) throws -> [Double] {
        var strengths: [Double] = []
        for time in beats {
            try Task.checkCancellation()
            let lo = max(0, Int((time - 0.08) * sampleRate))
            let hi = min(samples.count, Int((time + 0.08) * sampleRate))
            var sum = 0.0
            if hi > lo { for index in lo..<hi { let v = Double(samples[index]); sum += v * v } }
            strengths.append(sqrt(sum / Double(max(1, hi - lo))))
        }
        return strengths
    }
}

struct MeterEstimator {
    /// Only distinguish simple triple/quadruple accent patterns. Equal clicks, unstable
    /// beat spacing, compound rhythms and short excerpts deliberately remain unknown.
    static func estimate(beats: [Double], strengths: [Double]) -> (meter: MeterEstimate?, downbeats: [Double]) {
        guard beats.count == strengths.count, beats.count >= 24 else { return (nil, []) }
        let intervals = zip(beats, beats.dropFirst()).map { $0.1 - $0.0 }
        guard let period = BeatTempoTracker.median(intervals), period > 0,
              intervals.allSatisfy({ abs($0 - period) / period < 0.15 }) else { return (nil, []) }
        var candidates: [(count: Int, phase: Int, score: Double)] = []
        for count in [3, 4] {
            var means = [Double](repeating: 0, count: count)
            var totals = [Int](repeating: 0, count: count)
            for i in strengths.indices { means[i % count] += strengths[i]; totals[i % count] += 1 }
            for i in means.indices { means[i] /= Double(max(1, totals[i])) }
            let phase = means.indices.max(by: { means[$0] < means[$1] }) ?? 0
            let other = means.enumerated().filter { $0.offset != phase }.map(\.element).reduce(0, +) / Double(count - 1)
            let contrast = (means[phase] - other) / max(means[phase], 0.000001)
            let accents = stride(from: phase, to: strengths.count, by: count).map { strengths[$0] }
            let consistency = accents.filter { $0 > other * 1.3 }.count
            let score = max(0, contrast) * Double(consistency) / Double(max(1, accents.count))
            candidates.append((count, phase, score))
        }
        candidates.sort { $0.score > $1.score }
        let best = candidates[0]
        guard best.score >= 0.35, best.score - candidates[1].score >= 0.2 else { return (nil, []) }
        return (MeterEstimate(beatsPerBar: best.count, confidence: min(0.85, best.score)),
                stride(from: best.phase, to: beats.count, by: best.count).map { beats[$0] })
    }
}
