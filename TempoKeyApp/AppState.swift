import SwiftUI
import TempoKeyCore

@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable { case idle, analyzing, done, error(String) }
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    @Published var phase: Phase = .idle
    @Published var progress: Double = 0
    @Published var result: AnalysisResult?
    @Published var appearance: Appearance = .light    // "paper" default
    @Published var availableUpdate: AppUpdate?        // set when a newer GitHub release exists

    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// `securityScoped`: when true, this call owns the security-scoped resource
    /// for `url` and releases it once analysis finishes (success or failure),
    /// so AVFoundation can finish reading the file even for long tracks.
    func analyze(url: URL, securityScoped: Bool = false) {
        phase = .analyzing; progress = 0; result = nil
        Task.detached(priority: .userInitiated) { [weak self] in
            defer { if securityScoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let res = try AnalysisEngine().analyze(url: url) { p in
                    Task { @MainActor [weak self] in self?.progress = p }
                }
                await MainActor.run { [weak self] in
                    self?.result = res
                    self?.phase = .done
                }
            } catch {
                let message = error.localizedDescription
                await MainActor.run { [weak self] in self?.phase = .error(message) }
            }
        }
    }

    func reset() { phase = .idle; result = nil; progress = 0 }

    /// Checks GitHub for a newer release and surfaces a banner if one exists. Silent on failure;
    /// skipped under XCTest so the test runner never makes a network call.
    func checkForUpdates() async {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
        guard let update = await UpdateCheck.latest(),
              UpdateCheck.isNewer(update.version, than: UpdateCheck.currentVersion()) else { return }
        availableUpdate = update
    }
}
