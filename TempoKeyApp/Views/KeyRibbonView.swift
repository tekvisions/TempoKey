import SwiftUI
import TempoKeyCore

/// Circle-of-fifths colored key ribbon over the visible time window.
struct KeyRibbonView: View {
    let segments: [KeySegment]
    let window: ClosedRange<Double>

    var body: some View {
        Canvas { ctx, size in
            let lo = window.lowerBound
            let hi = max(window.upperBound, lo + 0.0001)
            let span = hi - lo
            for seg in segments where seg.end > lo && seg.start < hi {
                let x0 = CGFloat((max(seg.start, lo) - lo) / span) * size.width
                let x1 = CGFloat((min(seg.end, hi) - lo) / span) * size.width
                let rect = CGRect(x: x0, y: 0, width: max(1, x1 - x0), height: size.height)
                // confidence is surfaced as opacity: less-certain key segments appear fainter
                let conf = min(1.0, max(0.0, seg.confidence))
                ctx.fill(Path(roundedRect: rect, cornerRadius: 2),
                         with: .color(Theme.color(for: seg.key).opacity(0.5 + 0.5 * conf)))
                if (x1 - x0) > 42 {
                    ctx.draw(Text(seg.key.name).font(.caption2).foregroundStyle(.white),
                             at: CGPoint(x: x0 + 6, y: size.height / 2), anchor: .leading)
                }
            }
        }
        .frame(height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
