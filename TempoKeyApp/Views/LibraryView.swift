import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var state: AppState
    @State private var selection: UUID?
    @State private var sortOrder = [KeyPathComparator(\LibraryTrack.name)]
    private var sorted: [LibraryTrack] { state.tracks.sorted(using: sortOrder) }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your tracks").font(.largeTitle.weight(.semibold))
                    Text("\(state.tracks.filter { $0.result != nil }.count) analyzed · \(state.tracks.count) files").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Export CSV…", systemImage: "square.and.arrow.up") {
                    do {
                        try AnalysisExport.save(Data(AnalysisExport.csv(sorted.compactMap { track in track.result.map { ($0, track.overrides) } }).utf8), name: "TempoKey-library.csv", type: .commaSeparatedText)
                    } catch { state.notice = error.localizedDescription }
                }.disabled(!state.tracks.contains { $0.result != nil })
            }.padding(24)
            if state.isAnalyzing {
                HStack {
                    ProgressView(value: state.progress).frame(width: 120)
                    Text(state.analysisLabel).lineLimit(1).font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button("Cancel") { state.cancelAnalysis() }
                }.padding(.horizontal, 24).padding(.bottom, 16)
            }
            Table(sorted, selection: $selection, sortOrder: $sortOrder) {
                TableColumn("File", value: \.name) { track in
                    HStack(spacing: 10) {
                        Image(systemName: track.error == nil ? "waveform" : "exclamationmark.circle").foregroundStyle(track.error == nil ? Theme.accent : .orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(track.name).lineLimit(1).help(track.url.path)
                            if let error = track.error { Text(error).font(.caption).foregroundStyle(.secondary).lineLimit(1).help(error) }
                            else if track.result == nil { Text("Waiting for analysis").font(.caption).foregroundStyle(.secondary) }
                        }
                    }.padding(.vertical, 5)
                }.width(min: 220, ideal: 350)
                TableColumn("BPM", value: \.bpm) { track in Text(track.result == nil ? "—" : Theme.bpm(track.bpm)).monospacedDigit() }.width(80)
                TableColumn("Key", value: \.key).width(85)
                TableColumn("Camelot", value: \.camelot).width(70)
                TableColumn("Length", value: \.duration) { track in Text(track.result == nil ? "—" : Theme.duration(track.duration)).monospacedDigit() }.width(65)
                TableColumn("Report") { track in Button("Open") { state.select(track.id) }.disabled(track.result == nil) }.width(60)
            }
            .contextMenu(forSelectionType: UUID.self) { ids in
                if let id = ids.first { Button("Open report") { state.select(id) } }
            } primaryAction: { ids in if let id = ids.first { state.select(id) } }
            HStack {
                Image(systemName: "lock.shield"); Text("Audio stays on your Mac")
                Spacer(); Text("Double-click a track to inspect its timeline")
            }.font(.caption).foregroundStyle(.secondary).padding(16)
        }
    }
}
