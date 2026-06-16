import SwiftUI

@main
struct TempoKeyApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 760, minHeight: 520)
                .preferredColorScheme(state.colorScheme)
        }
        .windowResizability(.contentMinSize)
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        VStack(spacing: 0) {
            if let update = state.availableUpdate {
                UpdateBanner(update: update) { state.availableUpdate = nil }
            }
            content
        }
        .task { await state.checkForUpdates() }
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .idle:            ImportView(errorMessage: nil)
        case .error(let msg):  ImportView(errorMessage: msg)
        case .analyzing:       AnalyzingView()
        case .done:            if let r = state.result { ReportView(result: r) } else { ImportView(errorMessage: nil) }
        }
    }
}
