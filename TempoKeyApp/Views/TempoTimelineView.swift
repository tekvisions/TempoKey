import SwiftUI
import TempoKeyCore

/// Tempo (BPM) line over the visible time window. Drawn with Canvas so it stays pixel-aligned
/// with the key/beat tracks under zoom (Swift Charts' axis gutter would offset it).
struct TempoTimelineView: View {
    let series: [TempoPoint]
    let window: ClosedRange<Double>

    var body: some View {
        Canvas { ctx, size in
            let lo = window.lowerBound
            let hi = max(window.upperBound, lo + 0.0001)
            let span = hi - lo
            func x(_ t: Double) -> CGFloat { CGFloat((t - lo) / span) * size.width }

            // y range from points in (or near) the window so zooming reveals detail
            let visible = series.filter { $0.time >= lo - span * 0.1 && $0.time <= hi + span * 0.1 }
            let bpms = (visible.isEmpty ? series.map(\.bpm) : visible.map(\.bpm))
            let yMin = (bpms.min() ?? 60) - 4
            let yMax = (bpms.max() ?? 160) + 4
            let yspan = max(1, yMax - yMin)
            func y(_ b: Double) -> CGFloat { size.height - CGFloat((b - yMin) / yspan) * size.height }

            // gridlines + bpm labels
            for b in [yMin, (yMin + yMax) / 2, yMax] {
                let yy = y(b)
                var line = Path(); line.move(to: CGPoint(x: 0, y: yy)); line.addLine(to: CGPoint(x: size.width, y: yy))
                ctx.stroke(line, with: .color(.secondary.opacity(0.12)), lineWidth: 0.5)
                ctx.draw(Text("\(Int(b.rounded()))").font(.system(size: 9)).foregroundStyle(.secondary),
                         at: CGPoint(x: size.width - 3, y: yy), anchor: .trailing)
            }

            // the line (draw a hair beyond the window so it doesn't clip mid-edge)
            var path = Path()
            for run in TempoTimelineData.runs(series) {
                var started = false
                for p in run where p.time >= lo - span && p.time <= hi + span {
                    let pt = CGPoint(x: x(p.time), y: y(p.bpm))
                    if started { path.addLine(to: pt) } else { path.move(to: pt); started = true }
                }
            }
            ctx.stroke(path, with: .color(Theme.accent),
                       style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 120)
    }
}
