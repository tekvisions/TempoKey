import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject var state: AppState
    let errorMessage: String?
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "waveform.path").font(.system(size: 64, weight: .ultraLight)).foregroundStyle(Theme.accent)
                .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text("Know your music.").font(.system(size: 36, weight: .semibold, design: .rounded))
                    .shadow(color: .black.opacity(0.06), radius: 1, y: 1)
                Text("Tempo, key, and the shape of every track.").font(.title3).foregroundStyle(.secondary)
            }
            VStack(spacing: 16) {
                Text("Drop audio files or a folder anywhere").font(.headline)
                Button("Import audio…", systemImage: "plus") { ImportPanel.open(state: state) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                Text("MP3, M4A, WAV, AIFF, CAF, FLAC").font(.caption).foregroundStyle(.secondary)
            }.padding(30).frame(width: 380).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.08)))
            HStack(spacing: 28) {
                Label("Entirely offline", systemImage: "lock.shield")
                Label("Batch analysis", systemImage: "square.stack")
                Label("Listen and refine", systemImage: "headphones")
            }.font(.callout).foregroundStyle(.secondary)
            if let errorMessage { Text(errorMessage).foregroundStyle(.red).frame(maxWidth: 500) }
            RecentImportsView(recents: state.recents) { state.openRecent($0) }
            Spacer()
        }.padding(32).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RecentImportsView: View {
    @ObservedObject var recents: RecentFiles
    let open: (RecentImport) -> Void
    var body: some View {
        if !recents.items.isEmpty {
            HStack {
                Menu("Open recent") { ForEach(recents.items) { item in Button(item.name) { open(item) } } }
                Button("Clear recents") { recents.clear() }.buttonStyle(.plain).foregroundStyle(.secondary)
            }.frame(width: 360).font(.callout)
        }
    }
}

@MainActor
enum ImportPanel {
    static func open(state: AppState) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true; panel.canChooseDirectories = true; panel.allowsMultipleSelection = true
        panel.prompt = "Analyze"; panel.message = "Choose audio files or folders to analyze offline."
        if panel.runModal() == .OK { state.importFiles(panel.urls) }
    }
}
