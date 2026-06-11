import SwiftUI

/// Beat tick marks over the visible time window. When zoomed in, individual beats separate out.
struct BeatTickView: View {
    let beats: [Double]
    let window: ClosedRange<Double>

    var body: some View {
        Canvas { ctx, size in
            let lo = window.lowerBound
            let hi = max(window.upperBound, lo + 0.0001)
            let span = hi - lo
            for t in beats where t >= lo && t <= hi {
                let x = CGFloat((t - lo) / span) * size.width
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(path, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
            }
        }
        .frame(height: 16)
    }
}
