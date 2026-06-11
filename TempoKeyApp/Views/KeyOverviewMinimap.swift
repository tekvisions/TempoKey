import SwiftUI
import TempoKeyCore

/// Full-song key overview with a draggable highlight showing the current zoom window.
/// Click or drag anywhere to re-center the window on that point.
struct KeyOverviewMinimap: View {
    let segments: [KeySegment]
    let total: Double
    @Binding var window: ClosedRange<Double>

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let safeTotal = max(total, 0.0001)
            let x0 = CGFloat(window.lowerBound / safeTotal) * w
            let winW = CGFloat((window.upperBound - window.lowerBound) / safeTotal) * w

            ZStack(alignment: .leading) {
                // full-song ribbon
                Canvas { ctx, size in
                    for seg in segments {
                        let sx0 = CGFloat(seg.start / safeTotal) * size.width
                        let sx1 = CGFloat(seg.end / safeTotal) * size.width
                        let rect = CGRect(x: sx0, y: 0, width: max(0.5, sx1 - sx0), height: size.height)
                        ctx.fill(Path(rect), with: .color(Theme.color(for: seg.key).opacity(0.85)))
                    }
                }
                // dim the parts outside the window
                HStack(spacing: 0) {
                    Rectangle().fill(.black.opacity(0.28)).frame(width: max(0, x0))
                    Rectangle().fill(.clear).frame(width: max(2, winW))
                    Rectangle().fill(.black.opacity(0.28))
                }
                // window outline
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Theme.accent, lineWidth: 1.5)
                    .frame(width: max(4, winW))
                    .offset(x: x0)
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { v in
                    let t = Double(v.location.x / max(1, w)) * safeTotal
                    window = TimelineZoom.center(window, on: t, total: total)
                }
            )
        }
        .frame(height: 22)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(.secondary.opacity(0.2), lineWidth: 0.5))
    }
}
