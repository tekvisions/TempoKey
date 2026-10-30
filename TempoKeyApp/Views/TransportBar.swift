import SwiftUI

struct TransportBar: View {
    @ObservedObject var playback: PlaybackController
    var body: some View {
        HStack(spacing: 14) {
            Button { playback.toggle() } label: { Image(systemName: playback.isPlaying ? "pause.fill" : "play.fill").frame(width: 20, height: 20) }
                .buttonStyle(.borderedProminent).help("Play / pause (Space)").accessibilityLabel(playback.isPlaying ? "Pause" : "Play")
            Text(Theme.duration(playback.time)).monospacedDigit().font(.callout).frame(width: 48)
            Slider(value: Binding(get: { playback.time }, set: { playback.seek($0) }), in: 0...max(0.001, playback.duration))
                .accessibilityLabel("Playback position")
            Text(Theme.duration(playback.duration)).monospacedDigit().font(.callout).foregroundStyle(.secondary)
            Toggle(isOn: $playback.metronome) { Image(systemName: "metronome") }.toggleStyle(.button).help("Click at detected beats").accessibilityLabel("Beat metronome")
            if playback.loopRange != nil {
                Button { playback.loopRange = nil } label: { Label("Loop on", systemImage: "repeat") }.tint(Theme.accent)
            }
        }.padding(14).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .disabled(!playback.available)
    }
}
