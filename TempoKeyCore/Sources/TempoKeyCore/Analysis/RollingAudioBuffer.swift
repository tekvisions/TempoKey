import Foundation

/// Fixed-capacity mono PCM ring. Serialize append/snapshot/reset on the capture owner queue.
/// It retains only the latest window; callers must also limit analysis to one pending job.
public final class RollingAudioBuffer {
    public let capacity: Int
    private var storage: [Float]
    private var head = 0
    public private(set) var count = 0

    public init(sampleRate: Double, maxDuration: Double = 12) {
        precondition(sampleRate.isFinite && sampleRate > 0 && maxDuration.isFinite && maxDuration > 0)
        let size = sampleRate * maxDuration
        precondition(size.isFinite && size < Double(Int.max))
        capacity = max(1, Int(size))
        storage = [Float](repeating: 0, count: capacity)
    }

    public func append(_ samples: [Float]) {
        // Oversized chunks skip their obsolete prefix without temporary allocation.
        for sample in samples.suffix(capacity) {
            storage[head] = sample
            head = (head + 1) % capacity
            count = min(capacity, count + 1)
        }
    }

    public var samples: [Float] {
        let start = (head - count + capacity) % capacity
        return (0..<count).map { storage[(start + $0) % capacity] }
    }

    public func reset() { head = 0; count = 0 }
}
