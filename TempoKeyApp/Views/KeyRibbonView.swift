import SwiftUI
import TempoKeyCore

struct KeyRibbonView: View {
    let segments: [KeySegment]
    let duration: Double

    var body: some View {
        Canvas { ctx, size in
            guard duration > 0 else { return }
            for seg in segments {
                let x0 = CGFloat(seg.start / duration) * size.width
                let x1 = CGFloat(seg.end / duration) * size.width
                let rect = CGRect(x: x0, y: 0, width: max(1, x1 - x0), height: size.height)
                // confidence is surfaced as opacity: less-certain key segments appear fainter
                let conf = min(1.0, max(0.0, seg.confidence))
                ctx.fill(Path(roundedRect: rect, cornerRadius: 2),
                         with: .color(Theme.color(for: seg.key).opacity(0.5 + 0.5 * conf)))
                if (x1 - x0) > 42 {
                    let text = Text(seg.key.name).font(.caption2).foregroundStyle(.white)
                    ctx.draw(text, at: CGPoint(x: x0 + 6, y: size.height / 2), anchor: .leading)
                }
            }
        }
        .frame(height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
