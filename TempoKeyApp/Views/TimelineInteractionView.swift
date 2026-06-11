import SwiftUI
import AppKit

/// Transparent overlay that turns trackpad/mouse events over the timeline into zoom/pan/hover.
/// - pinch (magnify) or vertical scroll → zoom around the cursor
/// - horizontal scroll or click-drag → pan
/// - double-click → reset
struct TimelineInteractionView: NSViewRepresentable {
    var onZoom: (_ factor: Double, _ anchorFraction: Double) -> Void
    var onPan: (_ fractionDelta: Double) -> Void
    var onReset: () -> Void
    var onHover: (_ fraction: Double?) -> Void

    func makeNSView(context: Context) -> InteractionNSView {
        let v = InteractionNSView()
        v.apply(onZoom: onZoom, onPan: onPan, onReset: onReset, onHover: onHover)
        return v
    }

    func updateNSView(_ v: InteractionNSView, context: Context) {
        v.apply(onZoom: onZoom, onPan: onPan, onReset: onReset, onHover: onHover)
    }

    final class InteractionNSView: NSView {
        private var onZoom: ((Double, Double) -> Void)?
        private var onPan: ((Double) -> Void)?
        private var onReset: (() -> Void)?
        private var onHover: ((Double?) -> Void)?
        private var tracking: NSTrackingArea?

        func apply(onZoom: @escaping (Double, Double) -> Void,
                   onPan: @escaping (Double) -> Void,
                   onReset: @escaping () -> Void,
                   onHover: @escaping (Double?) -> Void) {
            self.onZoom = onZoom; self.onPan = onPan; self.onReset = onReset; self.onHover = onHover
        }

        override var isFlipped: Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? { self }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let t = tracking { removeTrackingArea(t) }
            let t = NSTrackingArea(rect: bounds,
                                   options: [.activeInActiveApp, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect],
                                   owner: self, userInfo: nil)
            addTrackingArea(t); tracking = t
        }

        private func fraction(_ event: NSEvent) -> Double {
            let p = convert(event.locationInWindow, from: nil)
            return max(0, min(1, Double(p.x / max(1, bounds.width))))
        }

        override func scrollWheel(with e: NSEvent) {
            if abs(e.scrollingDeltaX) > abs(e.scrollingDeltaY) {
                onPan?(Double(-e.scrollingDeltaX) / Double(max(1, bounds.width)))
            } else if e.scrollingDeltaY != 0 {
                let factor = e.scrollingDeltaY > 0 ? 1.06 : (1 / 1.06)
                onZoom?(factor, fraction(e))
            }
        }

        override func magnify(with e: NSEvent) {
            onZoom?(1 + Double(e.magnification), fraction(e))
        }

        override func mouseDragged(with e: NSEvent) {
            onPan?(Double(-e.deltaX) / Double(max(1, bounds.width)))
            onHover?(fraction(e))
        }

        override func mouseDown(with e: NSEvent) {
            if e.clickCount == 2 { onReset?() } else { onHover?(fraction(e)) }
        }

        override func mouseMoved(with e: NSEvent) { onHover?(fraction(e)) }
        override func mouseEntered(with e: NSEvent) { onHover?(fraction(e)) }
        override func mouseExited(with e: NSEvent) { onHover?(nil) }
    }
}

/// Compact time-axis labels for the visible window.
struct TimeRuler: View {
    let window: ClosedRange<Double>
    var body: some View {
        Canvas { ctx, size in
            let lo = window.lowerBound
            let hi = max(window.upperBound, lo + 0.0001)
            let n = 6
            for i in 0...n {
                let frac = Double(i) / Double(n)
                let x = min(max(CGFloat(frac) * size.width, 14), size.width - 14)
                ctx.draw(Text(Theme.duration(lo + frac * (hi - lo))).font(.system(size: 9)).foregroundStyle(.secondary),
                         at: CGPoint(x: x, y: 7), anchor: .center)
            }
        }
        .frame(height: 14)
    }
}
