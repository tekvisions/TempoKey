import SwiftUI

struct BeatTickView: View {
    let beats: [Double]
    let duration: Double

    var body: some View {
        Canvas { ctx, size in
            guard duration > 0 else { return }
            for t in beats {
                let x = CGFloat(t / duration) * size.width
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(path, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
            }
        }
        .frame(height: 16)
    }
}
