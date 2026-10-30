import SwiftUI
import TempoKeyCore

struct ReportView: View {
    @EnvironmentObject var state: AppState
    let result: AnalysisResult
    @State private var exporting = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SummaryHeaderView(result: result)
                HStack {
                    CorrectionsBar()
                    exportMenu
                }
                TransportBar(playback: state.playback)
                TimelineSection(result: result, playback: state.playback)
                if let meter = result.meter {
                    Label("Estimated meter: \(meter.beatsPerBar)/4 · \(Int(meter.confidence * 100))% confidence", systemImage: "music.note.list")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Meter undetermined — no consistent bar accents detected.").font(.caption).foregroundStyle(.secondary)
                }
                if !result.sections.isEmpty {
                    Text("Sections").font(.headline)
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(Array(result.sections.enumerated()), id: \.offset) { _, section in
                                Button { state.playback.seek(section.start) } label: {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(section.label).font(.callout.weight(.medium))
                                        Text("\(Theme.duration(section.start))–\(Theme.duration(section.end))").font(.caption).foregroundStyle(.secondary)
                                        Text("\(Theme.bpm(section.bpm)) BPM").font(.callout).monospacedDigit()
                                    }.padding(12).frame(minWidth: 130, alignment: .leading)
                                }.buttonStyle(.plain).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                Text("Timelines show detected values. Corrections apply to the summary, library, and exports. Sections and meter are estimates.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24)
        }
    }
    private var exportMenu: some View {
        Menu {
            Button("Analysis JSON…") { perform { try AnalysisExport.save(AnalysisExport.json(result: result, overrides: state.overrides), name: stem + ".json", type: .json, excluding: state.currentTrack?.url) } }
            Button("Report image…") { perform { try AnalysisExport.save(AnalysisExport.png(result: result, overrides: state.overrides), name: stem + ".png", type: .png, excluding: state.currentTrack?.url) } }
            Button("Tagged audio copy…") {
                guard let track = state.currentTrack else { return }
                exporting = true
                Task {
                    defer { exporting = false }
                    do { try await MetadataExport.saveCopy(track: track, bpm: state.displayedBPM() ?? result.overallBPM, key: state.displayedKey() ?? result.overallKey) }
                    catch { state.notice = error.localizedDescription }
                }
            }
        } label: { Label(exporting ? "Exporting…" : "Export", systemImage: "square.and.arrow.up") }.disabled(exporting)
    }
    private var stem: String { (result.fileName as NSString).deletingPathExtension + "-analysis" }
    private func perform(_ action: () throws -> Void) { do { try action() } catch { state.notice = error.localizedDescription } }
}
