import Foundation

/// Averages the intervals between recent taps into a BPM. A gap > 2 s starts a new sequence.
struct TapTempo {
    private var taps: [TimeInterval] = []

    mutating func tap(at time: TimeInterval) -> Double? {
        if let last = taps.last, time - last > 2.0 { taps.removeAll() }
        taps.append(time)
        if taps.count > 8 { taps.removeFirst(taps.count - 8) }
        guard taps.count >= 2 else { return nil }
        let intervals = zip(taps.dropFirst(), taps).map { $0 - $1 }
        let avg = intervals.reduce(0, +) / Double(intervals.count)
        return avg > 0 ? 60.0 / avg : nil
    }

    mutating func reset() { taps.removeAll() }
}
