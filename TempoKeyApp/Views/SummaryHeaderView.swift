import SwiftUI
import TempoKeyCore

struct SummaryHeaderView: View {
    let result: AnalysisResult

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 22) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(Int(result.overallBPM.rounded()))")
                    .font(.system(size: 46, weight: .bold, design: .rounded)).monospacedDigit()
                HStack(spacing: 6) {
                    Text("BPM").font(.caption2).tracking(2).foregroundStyle(Theme.accent)
                    // tempo confidence surfaced subtly, not hidden
                    Text("· \(Int((result.bpmConfidence * 100).rounded()))% conf")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(result.overallKey.name).font(.system(size: 24, weight: .semibold))
                Text("KEY").font(.caption2).tracking(2).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 22) {
                labeled(result.fileName, "FILE")
                labeled(Theme.duration(result.duration), "LENGTH")
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
