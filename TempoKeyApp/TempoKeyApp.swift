import SwiftUI
import UniformTypeIdentifiers

@main
struct TempoKeyApp: App {
    @StateObject private var state = AppState()
    var body: some Scene {
        Window("TempoKey", id: "main") {
            RootView().environmentObject(state).frame(minWidth: 860, minHeight: 640)
                .preferredColorScheme(state.colorScheme)
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import audio…") { ImportPanel.open(state: state) }.keyboardShortcut("o")
            }
            CommandMenu("Playback") {
                Button("Play / Pause") { state.playback.toggle() }.keyboardShortcut(.space, modifiers: [])
                Button("Back 5 seconds") { state.playback.seek(state.playback.time - 5) }.keyboardShortcut(.leftArrow, modifiers: .command)
                Button("Forward 5 seconds") { state.playback.seek(state.playback.time + 5) }.keyboardShortcut(.rightArrow, modifiers: .command)
            }
        }
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState
    @State private var dropTarget = false
    var body: some View {
        VStack(spacing: 0) {
            if let update = state.availableUpdate { UpdateBanner(update: update) { state.availableUpdate = nil } }
            if state.showLive { LiveInputView() }
            else if state.showLibrary && !state.tracks.isEmpty { LibraryView() }
            else if let result = state.result, !state.showLibrary { ReportView(result: result).id(state.selectedTrackID) }
            else if state.isAnalyzing { AnalyzingView() }
            else { ImportView(errorMessage: errorMessage) }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay { if dropTarget { RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.accent, lineWidth: 3).padding(5).allowsHitTesting(false) } }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button { state.navigateToLibrary() } label: { Label("Library", systemImage: "square.stack") }.help("Library")
                Button { state.reset(); state.showLibrary = false } label: { Label("Home", systemImage: "house") }.help("Home and recent files")
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("Appearance", selection: $state.appearance) { ForEach(AppState.Appearance.allCases) { Text($0.label).tag($0) } }.frame(width: 100)
                Button { state.cancelAnalysis(); state.playback.close(); state.showLive = true } label: { Label("Live input", systemImage: "mic") }
                Button { state.showLive = false; ImportPanel.open(state: state) } label: { Label("Import", systemImage: "plus") }.help("Import audio (⌘O)")
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $dropTarget) { providers in
            Task { @MainActor in
                var urls: [URL] = []
                for provider in providers {
                    let url: URL? = await withCheckedContinuation { continuation in
                        _ = provider.loadObject(ofClass: URL.self) { url, _ in continuation.resume(returning: url) }
                    }
                    if let url { urls.append(url) }
                }
                if !urls.isEmpty { state.showLive = false; state.importFiles(urls) }
            }
            return !providers.isEmpty
        }
        .alert("TempoKey", isPresented: Binding(get: { state.notice != nil }, set: { if !$0 { state.notice = nil } })) { Button("OK") { state.notice = nil } } message: { Text(state.notice ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            if let window = notification.object as? NSWindow, window.title == "TempoKey" { state.cancelAnalysis(); state.playback.close() }
        }
        .task { await state.checkForUpdates() }
    }
    private var errorMessage: String? { if case .error(let message) = state.phase { message } else { nil } }
}
