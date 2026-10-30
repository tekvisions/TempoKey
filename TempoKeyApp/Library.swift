import Foundation
import TempoKeyCore

struct LibraryTrack: Identifiable {
    let id = UUID()
    let url: URL
    let accessURL: URL
    var result: AnalysisResult?
    var error: String?
    var overrides = DisplayOverrides()
    var name: String { url.lastPathComponent }
    var bpm: Double { result.map { overrides.displayedBPM(detected: $0.overallBPM) } ?? 0 }
    var key: String { result.map { overrides.displayedKey(detected: $0.overallKey).name } ?? "—" }
    var camelot: String { result.map { overrides.displayedKey(detected: $0.overallKey).camelot } ?? "—" }
    var duration: Double { result?.duration ?? 0 }
}

enum LibraryFiles {
    static let extensions: Set<String> = ["mp3", "m4a", "aac", "wav", "aif", "aiff", "caf", "flac", "mp4"]
    static func expand(_ urls: [URL]) throws -> [URL] {
        var seen = Set<URL>()
        var files: [URL] = []
        for url in urls {
            try Task.checkCancellation()
            let values = try url.resourceValues(forKeys: [.isDirectoryKey])
            if values.isDirectory == true {
                var enumerationError: Error?
                if let iterator = FileManager.default.enumerator(at: url,
                    includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants],
                    errorHandler: { _, error in enumerationError = error; return false }) {
                    for case let child as URL in iterator {
                        try Task.checkCancellation()
                        let info = try child.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                        if info.isRegularFile == true && info.isSymbolicLink != true && extensions.contains(child.pathExtension.lowercased()) {
                            let normalized = child.standardizedFileURL
                            if seen.insert(normalized).inserted { files.append(normalized) }
                        }
                    }
                }
                if let enumerationError { throw enumerationError }
            } else if extensions.contains(url.pathExtension.lowercased()) {
                let normalized = url.standardizedFileURL
                if seen.insert(normalized).inserted { files.append(normalized) }
            }
        }
        return files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
}

struct RecentImport: Codable, Identifiable {
    let id: UUID
    let name: String
    let bookmark: Data
}

@MainActor
final class RecentFiles: ObservableObject {
    @Published private(set) var items: [RecentImport] = []
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "recentImports"), let decoded = try? JSONDecoder().decode([RecentImport].self, from: data) { items = decoded }
    }
    func add(_ url: URL) {
        guard let bookmark = try? url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil) else { return }
        items.removeAll { item in (try? resolve(item).standardizedFileURL) == url.standardizedFileURL }
        items.insert(RecentImport(id: UUID(), name: url.lastPathComponent, bookmark: bookmark), at: 0)
        items = Array(items.prefix(12))
        save()
    }
    func resolve(_ item: RecentImport) throws -> URL {
        var stale = false
        return try URL(resolvingBookmarkData: item.bookmark, options: [.withSecurityScope, .withoutUI], relativeTo: nil, bookmarkDataIsStale: &stale)
    }
    func clear() { items.removeAll(); save() }
    private func save() { if let data = try? JSONEncoder().encode(items) { defaults.set(data, forKey: "recentImports") } }
}
