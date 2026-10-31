import SwiftUI
import TempoKeyCore

struct SummaryHeaderView: View {
    @EnvironmentObject var state: AppState
    let result: AnalysisResult

    private var bpm: Double { state.displayedBPM() ?? result.overallBPM }
    private var key: MusicalKey { state.displayedKey() ?? result.overallKey }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 22) {
            VStack(alignment: .leading, spacing: 0) {
                Text(Theme.bpm(bpm))
                    .font(.system(size: 46, weight: .bold, design: .rounded)).monospacedDigit()
                HStack(spacing: 6) {
                    Text("BPM").font(.caption2).tracking(2).foregroundStyle(Theme.accent)
                    Text("· " + Theme.tempoCaption(result.bpmConfidence, overrides: state.overrides))
                        .font(.caption2).foregroundStyle(.secondary)
                        .help("Agreement among local tempo estimates, not a probability of correctness. Check by ear; half/double-time interpretations are common.")
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("\(key.name)  ·  \(key.camelot)").font(.system(size: 24, weight: .semibold))
                Text("\(key.openKey) Open Key · mixes with \(key.compatibleCamelot.joined(separator: " "))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    Clipboard.copy(Clipboard.summary(bpm: bpm, key: key))
                } label: { Label("Copy", systemImage: "doc.on.doc") }
                    .controlSize(.small)
                HStack(spacing: 22) {
                    labeled(result.fileName, "FILE")
                    labeled(Theme.duration(result.duration), "LENGTH")
                }
            }
        }
    }

    private func labeled(_ value: String, _ label: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value).font(.system(size: 14, weight: .medium)).lineLimit(1).truncationMode(.middle)
            Text(label).font(.caption2).tracking(1).foregroundStyle(.secondary)
        }
    }
}
