import SwiftUI
import Charts
import TempoKeyCore

struct TempoTimelineView: View {
    let series: [TempoPoint]
    let duration: Double
    @State private var hover: TempoPoint?

    private var yDomain: ClosedRange<Double> {
        let bpms = series.map(\.bpm)
        let lo = (bpms.min() ?? 60) - 8, hi = (bpms.max() ?? 160) + 8
        return lo...max(hi, lo + 1)
    }

    var body: some View {
        Chart {
            ForEach(series, id: \.time) { p in
                LineMark(x: .value("Time", p.time), y: .value("BPM", p.bpm))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.accent)
            }
            if let hover {
                RuleMark(x: .value("Time", hover.time)).foregroundStyle(.secondary.opacity(0.4))
                PointMark(x: .value("Time", hover.time), y: .value("BPM", hover.bpm))
                    .foregroundStyle(Theme.accent)
                    .annotation(position: .top) {
                        Text("\(Int(hover.bpm)) BPM").font(.caption2).monospacedDigit()
                    }
            }
        }
        .chartXScale(domain: 0...max(duration, 0.001))
        .chartYScale(domain: yDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { v in
                AxisValueLabel { if let t = v.as(Double.self) { Text(Theme.duration(t)) } }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let pt):
                            if let plot = proxy.plotFrame {
                                let x = pt.x - geo[plot].origin.x
                                if let t: Double = proxy.value(atX: x) {
                                    hover = series.min(by: { abs($0.time - t) < abs($1.time - t) })
                                }
                            }
                        case .ended: hover = nil
                        }
                    }
            }
        }
        .frame(height: 120)
    }
}
