import Foundation

/// Pure math for the shared zoom/pan window over a song timeline (seconds).
/// Kept UI-free so it can be unit-tested.
enum TimelineZoom {
    /// Smallest visible window, so you can't zoom past a useful level.
    static func minWindow(total: Double) -> Double { max(0.5, total * 0.004) }

    /// Keep a window within [0, total] and within the min/max width bounds.
    static func clamp(_ window: ClosedRange<Double>, total: Double) -> ClosedRange<Double> {
        guard total > 0 else { return 0...max(total, 0.001) }
        var lo = window.lowerBound
        var hi = window.upperBound
        if hi < lo { swap(&lo, &hi) }
        var w = hi - lo
        let minW = minWindow(total: total)
        if w > total { return 0...total }
        if w < minW {
            let c = (lo + hi) / 2
            lo = c - minW / 2; hi = c + minW / 2; w = minW
        }
        if lo < 0 { hi -= lo; lo = 0 }
        if hi > total { lo -= (hi - total); hi = total }
        lo = max(0, lo); hi = min(total, hi)
        return lo...hi
    }

    /// Zoom by `factor` (>1 zooms in) keeping the point at `anchor` (0…1 of the window) fixed.
    static func zoom(_ window: ClosedRange<Double>, factor: Double, anchor: Double, total: Double) -> ClosedRange<Double> {
        let w = window.upperBound - window.lowerBound
        guard w > 0, factor > 0 else { return clamp(window, total: total) }
        let a = min(1, max(0, anchor))
        let anchorTime = window.lowerBound + a * w
        let newW = w / factor
        let lo = anchorTime - a * newW
        return clamp(lo...(lo + newW), total: total)
    }

    /// Pan by a fraction of the current window width (positive = later in time).
    static func pan(_ window: ClosedRange<Double>, byFraction f: Double, total: Double) -> ClosedRange<Double> {
        let w = window.upperBound - window.lowerBound
        let d = f * w
        return clamp((window.lowerBound + d)...(window.upperBound + d), total: total)
    }

    /// Center the window on `time`, preserving its width.
    static func center(_ window: ClosedRange<Double>, on time: Double, total: Double) -> ClosedRange<Double> {
        let half = (window.upperBound - window.lowerBound) / 2
        return clamp((time - half)...(time + half), total: total)
    }
}
