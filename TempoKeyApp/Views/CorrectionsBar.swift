import SwiftUI
import TempoKeyCore

/// Quick manual corrections: tap-tempo, ½ / ×2 BPM, key override, reset.
struct CorrectionsBar: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack(spacing: 8) {
            Button("Tap") { state.registerTap() }.help("Tap to the beat to set BPM")
            Button("½") {
                state.overrides.bpmMultiplier = state.overrides.bpmMultiplier == 0.5 ? 1 : 0.5
            }.help("Halve the BPM")
            Button("×2") {
                state.overrides.bpmMultiplier = state.overrides.bpmMultiplier == 2 ? 1 : 2
            }.help("Double the BPM")

            Menu("Key") {
                ForEach(PitchClass.allCases, id: \.rawValue) { pc in
                    Button("\(pc.name) maj") { state.overrides.manualKey = MusicalKey(tonic: pc, mode: .major) }
                    Button("\(pc.name) min") { state.overrides.manualKey = MusicalKey(tonic: pc, mode: .minor) }
                }
            }.help("Override the detected key")

            if state.overrides.isActive {
                Button("Reset") { state.overrides.clear() }.foregroundStyle(.secondary)
            }
            Spacer()
        }
        .controlSize(.small)
        .font(.caption)
    }
}
