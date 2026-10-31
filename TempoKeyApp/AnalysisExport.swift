import SwiftUI
import AppKit
import UniformTypeIdentifiers
import TempoKeyCore

struct ExportedAnalysis: Encodable {
    let schemaVersion = 1
    let analysis: AnalysisResult
    let correctedBPM: Double
    let correctedKey: MusicalKey
    let hasCorrections: Bool
}

enum AnalysisExport {
    static func csv(_ rows: [(AnalysisResult, DisplayOverrides)]) -> String {
        func cell(_ text: String) -> String {
            // Spreadsheet apps interpret leading formula characters even in quoted fields.
            let safe = ["=", "+", "-", "@", "\t", "\r"].contains(String(text.prefix(1))) ? "'" + text : text
            return "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        var lines = ["File,BPM,Key,Camelot,Duration seconds,Detected BPM,Detected key,Corrected"]
        for (result, overrides) in rows {
            let key = overrides.displayedKey(detected: result.overallKey)
            lines.append([cell(result.fileName), String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), overrides.displayedBPM(detected: result.overallBPM)), cell(key.name), cell(key.camelot), String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), result.duration), String(result.overallBPM), cell(result.overallKey.name), overrides.isActive ? "true" : "false"].joined(separator: ","))
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }
    static func json(result: AnalysisResult, overrides: DisplayOverrides) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(ExportedAnalysis(analysis: result, correctedBPM: overrides.displayedBPM(detected: result.overallBPM), correctedKey: overrides.displayedKey(detected: result.overallKey), hasCorrections: overrides.isActive))
    }
    @MainActor
    static func save(_ data: Data, name: String, type: UTType, excluding source: URL? = nil) throws {
        let panel = NSSavePanel(); panel.nameFieldStringValue = name; panel.allowedContentTypes = [type]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try validateDestination(url, source: source)
        try data.write(to: url, options: .atomic)
    }
    static func validateDestination(_ destination: URL, source: URL?) throws {
        guard let source else { return }
        let sourcePath = source.resolvingSymlinksInPath().standardizedFileURL
        let destinationPath = destination.resolvingSymlinksInPath().standardizedFileURL
        let sourceID = try? source.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject
        let destinationID = try? destination.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject
        if sourcePath == destinationPath || (sourceID != nil && sourceID == destinationID) {
            throw CocoaError(.fileWriteInvalidFileName, userInfo: [NSLocalizedDescriptionKey: "Choose a different destination to preserve the original audio file."])
        }
    }
    @MainActor
    static func png(result: AnalysisResult, overrides: DisplayOverrides) throws -> Data {
        let renderer = ImageRenderer(content: ExportReportView(result: result, overrides: overrides).frame(width: 1100).padding(36).background(Color.white).environment(\.colorScheme, .light))
        renderer.scale = 2
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        return png
    }
}

private struct ExportReportView: View {
    let result: AnalysisResult
    let overrides: DisplayOverrides
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("TempoKey").font(.title2.weight(.semibold)).foregroundStyle(.secondary)
            Text(result.fileName).font(.title)
            HStack(alignment: .firstTextBaseline, spacing: 24) {
                Text("\(Theme.bpm(overrides.displayedBPM(detected: result.overallBPM))) BPM").font(.system(size: 44, weight: .bold, design: .rounded))
                Text(overrides.displayedKey(detected: result.overallKey).name).font(.title)
                Text(overrides.displayedKey(detected: result.overallKey).camelot).font(.title)
            }
            Text("\(Theme.duration(result.duration)) • \(Theme.tempoCaption(result.bpmConfidence, overrides: overrides))").foregroundStyle(.secondary)
            Divider()
            Text("Detected tempo").font(.headline)
            TempoTimelineView(series: result.tempoSeries, window: 0...max(result.duration, 0.001))
            Text("Detected key").font(.headline)
            KeyRibbonView(segments: result.keySeries, window: 0...max(result.duration, 0.001))
            Text("Beats").font(.headline)
            BeatTickView(beats: result.beats, window: 0...max(result.duration, 0.001))
            TimeRuler(window: 0...max(result.duration, 0.001))
            if !result.energySeries.isEmpty {
                Text("Relative energy").font(.headline)
                EnergyTimelineView(series: result.energySeries, window: 0...max(result.duration, 0.001))
            }
            Text("Analyzed offline • Musical estimates should be checked by ear.").font(.caption).foregroundStyle(.secondary)
        }.foregroundStyle(.black)
    }
}
