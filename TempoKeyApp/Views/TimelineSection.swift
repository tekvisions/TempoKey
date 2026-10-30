import SwiftUI
import TempoKeyCore

/// The zoomable Tempo / Key / Beats stack: shared time window, pinch/scroll/drag interaction,
/// hover crosshair, zoom controls, and a full-song minimap for navigation.
struct TimelineSection: View {
    let result: AnalysisResult
    @ObservedObject var playback: PlaybackController

    @State private var window: ClosedRange<Double> = 0...1
    @State private var hoverFraction: Double?

    private var total: Double { max(result.duration, 0.001) }
    private var isZoomed: Bool { window.lowerBound > 0.01 || window.upperBound < total - 0.01 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            controls
            tracks
            TimeRuler(window: window)
            KeyOverviewMinimap(segments: result.keySeries, total: total, window: $window)
                .padding(.top, 2)
        }
        .onAppear { if window == 0...1 { window = 0...total } }
        .onChange(of: result.fileName) { _, _ in window = 0...total; hoverFraction = nil }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Text("\(Theme.duration(window.lowerBound))–\(Theme.duration(window.upperBound))")
                .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
            if isZoomed { Text("· zoomed").font(.caption2).foregroundStyle(Theme.accent) }
            Spacer()
            Button { playback.loopRange = TransportBounds.loop(window, duration: total); playback.seek(window.lowerBound) } label: { Label("Loop region", systemImage: "repeat") }
                .disabled(!playback.available).help("Loop the visible timeline range")
            Button { zoom(1 / 1.6) } label: { Image(systemName: "minus.magnifyingglass") }
                .help("Zoom out")
            Button { window = 0...total } label: { Text("Reset") }
                .disabled(!isZoomed)
            Button { zoom(1.6) } label: { Image(systemName: "plus.magnifyingglass") }
                .help("Zoom in")
        }
        .buttonStyle(.borderless).font(.caption)
    }

    private var tracks: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeled("TEMPO", Theme.accent) { TempoTimelineView(series: result.tempoSeries, window: window) }
            labeled("KEY", .secondary) { KeyRibbonView(segments: result.keySeries, window: window) }
            labeled("BEATS", .secondary) { BeatTickView(beats: result.beats, window: window) }
            if !result.energySeries.isEmpty {
                labeled("ENERGY", .secondary) { EnergyTimelineView(series: result.energySeries, window: window) }
            }
            if !result.downbeats.isEmpty {
                labeled("ESTIMATED DOWNBEATS", .secondary) { BeatTickView(beats: result.downbeats, window: window) }
            }
        }
        .overlay {
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    if window.contains(playback.time) {
                        let x = CGFloat((playback.time - window.lowerBound) / max(0.001, window.upperBound - window.lowerBound)) * geo.size.width
                        Rectangle().fill(Theme.accent).frame(width: 2, height: geo.size.height).offset(x: x).allowsHitTesting(false)
                    }
                    if let f = hoverFraction { crosshair(f, geo.size) }
                    TimelineInteractionView(
                        onZoom: { factor, anchor in
                            window = TimelineZoom.zoom(window, factor: factor, anchor: anchor, total: total)
                        },
                        onPan: { d in window = TimelineZoom.pan(window, byFraction: d, total: total) },
                        onReset: { window = 0...total },
                        onHover: { hoverFraction = $0 },
                        onSeek: { playback.seek(window.lowerBound + $0 * (window.upperBound - window.lowerBound)) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func labeled<C: View>(_ label: String, _ color: Color, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption2).tracking(1.5).foregroundStyle(color)
            content()
        }
    }

    private func crosshair(_ f: Double, _ size: CGSize) -> some View {
        let x = CGFloat(f) * size.width
        let t = window.lowerBound + f * (window.upperBound - window.lowerBound)
        return ZStack(alignment: .topLeading) {
            Path { p in p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: size.height)) }
                .stroke(Theme.accent.opacity(0.55), lineWidth: 1)
            Text(readout(at: t))
                .font(.caption2).monospacedDigit()
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 4))
                .fixedSize()
                .offset(x: min(max(x + 6, 0), max(0, size.width - 150)), y: 0)
        }
        .allowsHitTesting(false)
    }

    private func readout(at t: Double) -> String {
        var parts = [Theme.duration(t)]
        if let bpm = result.tempoSeries.min(by: { abs($0.time - t) < abs($1.time - t) })?.bpm {
            parts.append("\(Theme.bpm(bpm)) BPM")
        }
        if let key = result.keySeries.first(where: { t >= $0.start && t < $0.end })?.key {
            parts.append(key.name)
        }
        return parts.joined(separator: " · ")
    }

    private func zoom(_ factor: Double) {
        window = TimelineZoom.zoom(window, factor: factor, anchor: 0.5, total: total)
    }
}
