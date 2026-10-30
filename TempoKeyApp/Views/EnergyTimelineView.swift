import SwiftUI
import TempoKeyCore

struct EnergyTimelineView: View {
    let series: [EnergyPoint]
    let window: ClosedRange<Double>
    var body: some View {
        Canvas { context, size in
            let maximum = max(series.map(\.rms).max() ?? 0, 0.0001)
            let span = max(0.001, window.upperBound - window.lowerBound)
            var path = Path(); path.move(to: CGPoint(x: 0, y: size.height))
            for point in series where window.contains(point.time) {
                path.addLine(to: CGPoint(x: (point.time - window.lowerBound) / span * size.width, y: size.height * (1 - point.rms / maximum)))
            }
            path.addLine(to: CGPoint(x: size.width, y: size.height)); path.closeSubpath()
            context.fill(path, with: .color(Theme.accent.opacity(0.3)))
        }.frame(height: 52).background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
            .accessibilityLabel("Relative audio energy across the visible timeline")
    }
}
