import Foundation
import TempoKeyCore

struct Manifest: Decodable {
    let schemaVersion: Int
    let tracks: [Track]
    struct Track: Decodable {
        let path: String
        let reference: CorpusReference?
    }
}
struct Measurement: Encodable {
    let file: String
    let seconds: Double
    let duration: Double?
    let bpm: Double?
    let key: MusicalKey?
    let tempoEvidence: Double?
    let score: CorpusScore?
    let labelStatus: String
    let error: String?
}
struct Report: Encodable {
    let schemaVersion = 1
    let measurements: [Measurement]
    let analyzed: Int
    let fullyLabeled: Int
    let exactTempoMatches: Int
    let tempoLabels: Int
    let octaveTempoMatches: Int
    let exactKeyMatches: Int
    let keyLabels: Int
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    guard (1...2).contains(arguments.count), arguments.count == 1 || arguments[1] == "--require-labels" else {
        throw NSError(domain: "TempoKeyBenchmark", code: 2, userInfo: [NSLocalizedDescriptionKey:
            "Usage: tempokey-benchmark manifest.json [--require-labels]"])
    }
    let manifestURL = URL(fileURLWithPath: arguments[0])
    let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
    guard manifest.schemaVersion == 1, !manifest.tracks.isEmpty else {
        throw NSError(domain: "TempoKeyBenchmark", code: 2, userInfo: [NSLocalizedDescriptionKey: "Expected schemaVersion 1 and a nonempty tracks array."])
    }
    let requireLabels = arguments.contains("--require-labels")
    var measurements: [Measurement] = []
    for track in manifest.tracks {
        let url = URL(fileURLWithPath: track.path, relativeTo: manifestURL.deletingLastPathComponent()).standardizedFileURL
        let started = ProcessInfo.processInfo.systemUptime
        do {
            let result = try autoreleasepool { try AnalysisEngine().analyze(url: url) }
            let score = track.reference?.evaluate(bpm: result.overallBPM, key: result.overallKey)
            measurements.append(Measurement(file: url.lastPathComponent,
                seconds: ProcessInfo.processInfo.systemUptime - started, duration: result.duration,
                bpm: result.overallBPM, key: result.overallKey, tempoEvidence: result.bpmConfidence,
                score: score, labelStatus: score?.isFullyLabeled == true ? "fully-labeled"
                    : (score?.tempoMatches != nil || score?.keyMatches != nil ? "partially-labeled" : "unlabeled"), error: nil))
        } catch {
            measurements.append(Measurement(file: url.lastPathComponent,
                seconds: ProcessInfo.processInfo.systemUptime - started, duration: nil, bpm: nil,
                key: nil, tempoEvidence: nil, score: nil, labelStatus: "not-evaluated", error: error.localizedDescription))
        }
    }
    let scores = measurements.compactMap(\.score)
    let report = Report(measurements: measurements, analyzed: measurements.filter { $0.error == nil }.count,
                        fullyLabeled: scores.filter(\.isFullyLabeled).count,
                        exactTempoMatches: scores.filter { $0.tempoMatches == true }.count,
                        tempoLabels: scores.filter { $0.tempoMatches != nil }.count,
                        octaveTempoMatches: scores.filter { $0.octaveTempoMatches == true }.count,
                        exactKeyMatches: scores.filter { $0.keyMatches == true }.count,
                        keyLabels: scores.filter { $0.keyMatches != nil }.count)
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(report), as: UTF8.self))
    let failed = measurements.contains { $0.error != nil || $0.score?.tempoMatches == false || $0.score?.keyMatches == false }
        || (requireLabels && report.fullyLabeled != manifest.tracks.count)
    exit(failed ? 1 : 0)
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(2)
}
