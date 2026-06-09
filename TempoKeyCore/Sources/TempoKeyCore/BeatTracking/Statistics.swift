import Foundation

/// Fixed-size sliding window mean/std (population). O(1) push using running sums.
struct RunningStats {
    private var buffer: [Double]
    private var index = 0
    private var filled = 0
    private var sum = 0.0
    private var sumSq = 0.0

    init(capacity: Int) {
        precondition(capacity > 0)
        buffer = Array(repeating: 0, count: capacity)
    }

    mutating func push(_ value: Double) {
        if filled == buffer.count {
            let old = buffer[index]
            sum -= old; sumSq -= old * old
        } else {
            filled += 1
        }
        buffer[index] = value
        sum += value; sumSq += value * value
        index = (index + 1) % buffer.count
    }

    var count: Int { filled }
    var mean: Double { filled == 0 ? 0 : sum / Double(filled) }
    var variance: Double {
        guard filled > 0 else { return 0 }
        let m = mean
        return max(0, sumSq / Double(filled) - m * m)
    }
    var std: Double { variance.squareRoot() }
}

/// Returns true when the newest value exceeds mean + numStdDevs*std (and an absolute floor).
struct AdaptiveThreshold {
    private var stats: RunningStats
    private let numStdDevs: Double
    private let floor: Double

    init(window: Int, numStdDevs: Double, floor: Double) {
        stats = RunningStats(capacity: window)
        self.numStdDevs = numStdDevs
        self.floor = floor
    }

    mutating func update(_ value: Double) -> Bool {
        let threshold = max(floor, stats.mean + numStdDevs * stats.std)
        stats.push(value)
        return value > threshold && value > floor
    }
}
