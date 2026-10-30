import AppKit
import AVFoundation
import UniformTypeIdentifiers
import TempoKeyCore

struct MetadataExportError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum MetadataExport {
    @MainActor
    static func saveCopy(track: LibraryTrack, bpm: Double, key: MusicalKey) async throws {
        let ext = track.url.pathExtension.lowercased()
        guard ["mp3", "m4a"].contains(ext) else { throw MetadataExportError(message: "Tagged copies support MP3 and M4A. Use JSON or CSV for this format.") }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = track.url.deletingPathExtension().lastPathComponent + "-tagged." + ext
        panel.allowedContentTypes = [UTType(filenameExtension: ext) ?? .audio]
        panel.message = ext == "m4a" ? "Saves a separate copy with BPM and a comment containing key and Camelot." : "Saves a separate copy with BPM, initial key, and Camelot tags."
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        let scoped = track.accessURL.startAccessingSecurityScopedResource()
        defer { if scoped { track.accessURL.stopAccessingSecurityScopedResource() } }
        try AnalysisExport.validateDestination(destination, source: track.url)
        try await writeCopy(source: track.url, destination: destination, bpm: bpm, key: key)
    }

    static func writeCopy(source: URL, destination: URL, bpm: Double, key: MusicalKey) async throws {
        try AnalysisExport.validateDestination(destination, source: source)
        guard bpm.isFinite, bpm > 0, bpm < 1000 else { throw MetadataExportError(message: "A valid BPM is required for tagging.") }
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("tempokey-\(UUID().uuidString).\(source.pathExtension)")
        defer { try? FileManager.default.removeItem(at: temporary) }
        switch source.pathExtension.lowercased() {
        case "mp3":
            try await Task.detached(priority: .utility) { try writeMP3(source: source, destination: temporary, bpm: bpm, key: key) }.value
        case "m4a":
            let asset = AVURLAsset(url: source)
            guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else { throw MetadataExportError(message: "This M4A file cannot be exported.") }
            let existing = try await asset.load(.metadata)
            let bpmItem = AVMutableMetadataItem(); bpmItem.identifier = .iTunesMetadataBeatsPerMin
            bpmItem.value = NSNumber(value: Int(bpm.rounded())); bpmItem.dataType = "com.apple.metadata.datatype.int16"
            let comment = AVMutableMetadataItem(); comment.identifier = .iTunesMetadataUserComment
            var comments: [String] = []
            for item in existing where item.identifier == .iTunesMetadataUserComment {
                if let value = try await item.load(.stringValue) { comments.append(value) }
            }
            comments.append("TempoKey: \(String(format: "%.2f", bpm)) BPM; Key \(tagKey(key)); Camelot \(key.camelot)")
            comment.value = comments.joined(separator: "\n") as NSString
            comment.dataType = "com.apple.metadata.datatype.UTF-8"
            session.metadata = existing.filter { $0.identifier != .iTunesMetadataBeatsPerMin && $0.identifier != .iTunesMetadataUserComment } + [bpmItem, comment]
            session.outputURL = temporary; session.outputFileType = .m4a
            await session.export()
            guard session.status == .completed else { throw session.error ?? MetadataExportError(message: "M4A export failed.") }
        default: throw MetadataExportError(message: "Tagged copies support MP3 and M4A only.")
        }
        try Task.checkCancellation()
        // Foundation's atomic safe-save uses the selected destination authorization;
        // staging arbitrary sibling files is not permitted by the Release sandbox.
        try Data(contentsOf: temporary, options: .mappedIfSafe).write(to: destination, options: .atomic)
    }

    static func tagKey(_ key: MusicalKey) -> String { key.tonic.name.replacingOccurrences(of: "♯", with: "#") + (key.mode == .minor ? "m" : "") }

    private static func writeMP3(source: URL, destination: URL, bpm: Double, key: MusicalKey) throws {
        let reader = try FileHandle(forReadingFrom: source)
        defer { try? reader.close() }
        let header = try reader.read(upToCount: 10) ?? Data()
        var version: UInt8 = 4
        var retained = Data()
        var audioOffset: UInt64 = 0
        if header.count == 10 && String(data: header.prefix(3), encoding: .ascii) == "ID3" {
            version = header[3]
            guard [3, 4].contains(version), header[5] == 0, header[6..<10].allSatisfy({ $0 < 128 }) else {
                throw MetadataExportError(message: "This MP3 uses an unsupported ID3 tag variant. Export JSON instead; the original file is unchanged.")
            }
            let size = header[6..<10].reduce(0) { ($0 << 7) | Int($1) }
            guard size <= 16 * 1024 * 1024, let tag = try reader.read(upToCount: size), tag.count == size else { throw MetadataExportError(message: "The MP3 metadata is invalid or too large.") }
            retained = try retainedFrames(tag, version: version)
            audioOffset = UInt64(size + 10)
        }
        let frames = retained + frame("TBPM", value: String(Int(bpm.rounded())), version: version)
            + frame("TKEY", value: tagKey(key), version: version)
            + frame("TXXX", value: "TEMPOKEY_CAMELOT\0" + key.camelot, version: version)
        var tagHeader = Data("ID3".utf8); tagHeader.append(contentsOf: [version, 0, 0]); tagHeader.append(sizeBytes(frames.count, syncSafe: true))
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        let writer = try FileHandle(forWritingTo: destination); defer { try? writer.close() }
        try writer.write(contentsOf: tagHeader + frames)
        try reader.seek(toOffset: audioOffset)
        while let chunk = try reader.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            try Task.checkCancellation(); try writer.write(contentsOf: chunk)
        }
    }
    private static func retainedFrames(_ tag: Data, version: UInt8) throws -> Data {
        var offset = 0, result = Data()
        while offset + 10 <= tag.count && tag[offset] != 0 {
            let header = tag.subdata(in: offset..<offset + 10)
            guard let id = String(data: header.prefix(4), encoding: .ascii), id.utf8.allSatisfy({ (65...90).contains($0) || (48...57).contains($0) }), version != 4 || header[4..<8].allSatisfy({ $0 < 128 }) else { throw MetadataExportError(message: "Malformed ID3 frame.") }
            let size = header[4..<8].reduce(0) { ($0 << (version == 4 ? 7 : 8)) | Int($1) }
            guard size > 0, offset + 10 + size <= tag.count else { throw MetadataExportError(message: "Malformed ID3 frame size.") }
            let payload = tag.subdata(in: offset + 10..<offset + 10 + size)
            let text: String? = payload.first == 3 ? String(data: payload.dropFirst(), encoding: .utf8) : payload.first == 1 ? String(data: payload.dropFirst(), encoding: .utf16) : String(data: payload.dropFirst(), encoding: .isoLatin1)
            let ownCamelot = id == "TXXX" && (text?.hasPrefix("TEMPOKEY_CAMELOT\0") == true)
            if id != "TBPM" && id != "TKEY" && !ownCamelot { result.append(tag.subdata(in: offset..<offset + 10 + size)) }
            offset += 10 + size
        }
        guard tag[offset...].allSatisfy({ $0 == 0 }) else { throw MetadataExportError(message: "Malformed ID3 padding.") }
        return result
    }
    private static func frame(_ id: String, value: String, version: UInt8) -> Data {
        var payload = Data([version == 4 ? 3 : 1])
        payload.append(value.data(using: version == 4 ? .utf8 : .utf16)!)
        var data = Data(id.utf8); data.append(sizeBytes(payload.count, syncSafe: version == 4)); data.append(contentsOf: [0, 0]); data.append(payload)
        return data
    }
    private static func sizeBytes(_ size: Int, syncSafe: Bool) -> Data {
        let shift = syncSafe ? 7 : 8, mask = syncSafe ? 127 : 255
        return Data((0..<4).reversed().map { UInt8((size >> ($0 * shift)) & mask) })
    }
}
