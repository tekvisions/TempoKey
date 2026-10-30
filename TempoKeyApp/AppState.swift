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
    @Published var appearance: Appearance = .system {
        didSet { defaults.set(appearance.rawValue, forKey: "appearance") }
    }
    @Published var availableUpdate: AppUpdate?
    @Published var tracks: [LibraryTrack] = []
    @Published var selectedTrackID: UUID?
    @Published var showLibrary = false
    @Published var showLive = false
    @Published var isAnalyzing = false
    @Published var analysisLabel = "Preparing files…"
    @Published var notice: String?
    @Published var overrides = DisplayOverrides() {
        didSet {
            if let index = tracks.firstIndex(where: { $0.id == selectedTrackID }) { tracks[index].overrides = overrides }
        }
    }
    let recents: RecentFiles
    private let defaults: UserDefaults
    let playback = PlaybackController()
    private var tapTempo = TapTempo()
    private var analysisTask: Task<Void, Never>?
    private var generation = UUID()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.recents = RecentFiles(defaults: defaults)
        self.appearance = Appearance(rawValue: defaults.string(forKey: "appearance") ?? "system") ?? .system
    }

    var colorScheme: ColorScheme? {
        switch appearance { case .system: nil; case .light: .light; case .dark: .dark }
    }
    var currentTrack: LibraryTrack? { tracks.first { $0.id == selectedTrackID } }

    func analyze(url: URL, securityScoped: Bool = false) {
        // Compatibility for callers that acquired a scope before handing off.
        importFiles([url])
        if securityScoped { url.stopAccessingSecurityScopedResource() }
    }

    func importFiles(_ urls: [URL]) {
        cancelAnalysis()
        playback.close()
        selectedTrackID = nil; result = nil; overrides.clear(); tapTempo.reset()
        tracks = []; progress = 0; showLive = false; showLibrary = true
        phase = .analyzing; isAnalyzing = true; analysisLabel = "Preparing files…"
        let token = generation
        let scoped = urls.filter { $0.startAccessingSecurityScopedResource() }
        urls.forEach { recents.add($0) }
        analysisTask = Task.detached(priority: .userInitiated) { [weak self] in
            defer { scoped.forEach { $0.stopAccessingSecurityScopedResource() } }
            do {
                let files = try LibraryFiles.expand(urls)
                guard !files.isEmpty else { throw CocoaError(.fileReadUnknown, userInfo: [NSLocalizedDescriptionKey: "No supported audio files found. Choose MP3, M4A, WAV, AIFF, CAF, or FLAC files."]) }
                let entries = files.map { file in
                    LibraryTrack(url: file, accessURL: urls.first(where: { file == $0.standardizedFileURL || file.path.hasPrefix($0.standardizedFileURL.path + "/") }) ?? file)
                }
                await MainActor.run { [weak self] in
                    guard let self, self.generation == token else { return }; self.tracks = entries
                }
                for (index, entry) in entries.enumerated() {
                    try Task.checkCancellation()
                    await MainActor.run { [weak self] in
                        guard let self, self.generation == token else { return }
                        self.analysisLabel = "Analyzing \(index + 1) of \(entries.count): \(entry.name)"
                    }
                    do {
                        let analyzed = try AnalysisEngine().analyze(url: entry.url) { fraction in
                            Task { @MainActor [weak self] in
                                guard let self, self.generation == token, self.isAnalyzing else { return }
                                self.progress = max(self.progress, (Double(index) + fraction) / Double(entries.count))
                            }
                        }
                        try Task.checkCancellation()
                        await MainActor.run { [weak self] in
                            guard let self, self.generation == token else { return }
                            self.tracks[index].result = analyzed
                        }
                    } catch is CancellationError { throw CancellationError() }
                    catch {
                        await MainActor.run { [weak self] in
                            guard let self, self.generation == token else { return }; self.tracks[index].error = error.localizedDescription
                        }
                    }
                }
                await MainActor.run { [weak self] in
                    guard let self, self.generation == token else { return }
                    self.progress = 1; self.isAnalyzing = false; self.phase = .done
                    if self.tracks.count == 1, let first = self.tracks.first, first.result != nil { self.select(first.id) }
                }
            } catch is CancellationError { }
            catch {
                await MainActor.run { [weak self] in
                    guard let self, self.generation == token else { return }
                    self.isAnalyzing = false; self.phase = .error(error.localizedDescription)
                    self.notice = error.localizedDescription
                }
            }
        }
    }

    func cancelAnalysis() {
        generation = UUID(); analysisTask?.cancel(); analysisTask = nil; isAnalyzing = false
        for index in tracks.indices where tracks[index].result == nil && tracks[index].error == nil { tracks[index].error = "Cancelled" }
        if phase == .analyzing { phase = .done }
    }
    func select(_ id: UUID) {
        guard let track = tracks.first(where: { $0.id == id }), let analyzed = track.result else { return }
        playback.close(); selectedTrackID = id; result = analyzed; overrides = track.overrides; tapTempo.reset()
        showLibrary = false; showLive = false; phase = .done
        do { try playback.load(url: track.url, accessURL: track.accessURL, beats: analyzed.beats) }
        catch { notice = "Playback unavailable: \(error.localizedDescription)" }
    }
    func navigateToLibrary() {
        playback.close(); selectedTrackID = nil; result = nil; overrides.clear(); tapTempo.reset()
        showLibrary = true; showLive = false
    }
    func reset() {
        cancelAnalysis(); playback.close(); selectedTrackID = nil; result = nil; progress = 0
        overrides.clear(); tapTempo.reset(); phase = .idle; showLibrary = !tracks.isEmpty; showLive = false
    }
    func openRecent(_ item: RecentImport) {
        do { importFiles([try recents.resolve(item)]) }
        catch { notice = "This recent item is unavailable. Use Import to choose it again. \(error.localizedDescription)" }
    }
    func displayedBPM() -> Double? { result.map { overrides.displayedBPM(detected: $0.overallBPM) } }
    func displayedKey() -> MusicalKey? { result.map { overrides.displayedKey(detected: $0.overallKey) } }
    func registerTap() {
        if let bpm = tapTempo.tap(at: ProcessInfo.processInfo.systemUptime) { overrides.manualBPM = bpm; overrides.bpmMultiplier = 1 }
    }
    func checkForUpdates() async {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
        guard let update = await UpdateCheck.latest(), UpdateCheck.isNewer(update.version, than: UpdateCheck.currentVersion()) else { return }
        availableUpdate = update
    }
}
