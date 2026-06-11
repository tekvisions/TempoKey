import SwiftUI
import TempoKeyCore

struct ReportView: View {
    @EnvironmentObject var state: AppState
    let result: AnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SummaryHeaderView(result: result)
            Divider()
            TimelineSection(result: result)
            Spacer(minLength: 0)
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
}
