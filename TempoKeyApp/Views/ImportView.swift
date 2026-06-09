import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject var state: AppState
    let errorMessage: String?
    @State private var isTargeted = false
    @State private var showImporter = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("TempoKey").font(.system(size: 26, weight: .semibold, design: .default))
            Text("BPM & key detection for your music").foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                .foregroundStyle(isTargeted ? Theme.accent : Color.secondary.opacity(0.5))
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(isTargeted ? 0.08 : 0.03)))
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform").font(.system(size: 34, weight: .light))
                        Text("Drop an audio file").font(.headline)
                        Text("or").foregroundStyle(.secondary).font(.caption)
                        Button("Choose File…") { showImporter = true }
                    }
                }
                .frame(width: 360, height: 200)
                .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                    handleDrop(providers)
                }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result { startAnalysis(url) }
        }
    }

    private func startAnalysis(_ url: URL) {
        // Hold the security scope until analysis finishes reading the file;
        // AppState releases it when the background task completes.
        let scoped = url.startAccessingSecurityScopedResource()
        state.analyze(url: url, securityScoped: scoped)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url { DispatchQueue.main.async { startAnalysis(url) } }
        }
        return true
    }
}
