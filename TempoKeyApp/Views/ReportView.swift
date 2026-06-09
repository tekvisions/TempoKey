import SwiftUI
import TempoKeyCore

struct ReportView: View {
    @EnvironmentObject var state: AppState
    let result: AnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SummaryHeaderView(result: result)
            Divider()
            track("TEMPO", color: Theme.accent) {
                TempoTimelineView(series: result.tempoSeries, duration: result.duration)
            }
            track("KEY", color: .secondary) {
                KeyRibbonView(segments: result.keySeries, duration: result.duration)
            }
            track("BEATS", color: .secondary) {
                BeatTickView(beats: result.beats, duration: result.duration)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItemGroup {
                Picker("Appearance", selection: $state.appearance) {
                    ForEach(AppState.Appearance.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented).frame(width: 180)
                Button { state.reset() } label: { Label("Open File", systemImage: "folder") }
            }
        }
    }

    @ViewBuilder
    private func track<Content: View>(_ label: String, color: Color, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption2).tracking(1.5).foregroundStyle(color)
            content()
        }
    }
}
