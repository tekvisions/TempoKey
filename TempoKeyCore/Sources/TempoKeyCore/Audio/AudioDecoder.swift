import AVFoundation

struct DecodedAudio {
    let samples: [Float]     // mono
    let sampleRate: Double
    var duration: Double { Double(samples.count) / sampleRate }
}

enum AudioDecoderError: LocalizedError {
    case unreadableFile(String)
    case tooLong(String)
    case cannotCreateConverter, cannotCreateBuffer, readFailed

    var errorDescription: String? {
        switch self {
        case .unreadableFile(let name):
            return "Couldn't read “\(name)”. It may not be a supported audio file."
        case .tooLong(let name):
            return "“\(name)” is too long to analyze. Please try a shorter file."
        case .cannotCreateConverter, .cannotCreateBuffer, .readFailed:
            return "Couldn't process this audio file. It may be corrupted or in an unsupported format."
        }
    }
}

/// Decodes any AVFoundation-readable file to mono Float32 at a fixed analysis rate.
final class AudioDecoder {
    let analysisRate: Double
    let maxDuration: Double   // seconds; caps memory use and rejects length-spoofed files

    init(analysisRate: Double = 44100, maxDuration: Double = 3600) {
        self.analysisRate = analysisRate
        self.maxDuration = maxDuration
    }

    func decode(url: URL) throws -> DecodedAudio {
        let file: AVAudioFile
        do {
            file = try AVAudioFile(forReading: url)
        } catch {
            throw AudioDecoderError.unreadableFile(url.lastPathComponent)
        }
        let inFormat = file.processingFormat

        // Reject absurdly long files up front so a huge (or length-spoofed) file can't
        // exhaust memory by decoding into an unbounded buffer.
        if inFormat.sampleRate > 0,
           Double(file.length) / inFormat.sampleRate > maxDuration {
            throw AudioDecoderError.tooLong(url.lastPathComponent)
        }
        let maxSamples = Int(maxDuration * analysisRate)

        let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                      sampleRate: analysisRate,
                                      channels: 1, interleaved: false)!
        guard let converter = AVAudioConverter(from: inFormat, to: outFormat) else {
            throw AudioDecoderError.cannotCreateConverter
        }

        var output: [Float] = []
        let inCap: AVAudioFrameCount = 16384
        guard let inBuf = AVAudioPCMBuffer(pcmFormat: inFormat, frameCapacity: inCap) else {
            throw AudioDecoderError.cannotCreateBuffer
        }

        // Read all source frames. AVAudioFile.read(into:) throws a nilError (_GenericObjCError)
        // when called past EOF rather than returning 0 frames, so we guard against that by
        // checking framePosition before each read.
        while file.framePosition < file.length {
            try file.read(into: inBuf)
            if inBuf.frameLength == 0 { break }

            let ratio = analysisRate / inFormat.sampleRate
            let outCap = AVAudioFrameCount(Double(inBuf.frameLength) * ratio) + 1024
            guard let outBuf = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: outCap) else {
                throw AudioDecoderError.cannotCreateBuffer
            }
            var fed = false
            var error: NSError?
            let status = converter.convert(to: outBuf, error: &error) { _, inputStatus in
                if fed { inputStatus.pointee = .noDataNow; return nil }
                fed = true
                inputStatus.pointee = .haveData
                return inBuf
            }
            if error != nil || status == .error { throw AudioDecoderError.readFailed }
            if let ch = outBuf.floatChannelData, outBuf.frameLength > 0 {
                output.append(contentsOf: UnsafeBufferPointer(start: ch[0], count: Int(outBuf.frameLength)))
            }
            // Defensive cap in case the header under-reported length.
            if output.count > maxSamples {
                throw AudioDecoderError.tooLong(url.lastPathComponent)
            }
        }

        // Drain any resampler latency by signaling end of stream.
        let drainCap: AVAudioFrameCount = 4096
        guard let drainBuf = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: drainCap) else {
            throw AudioDecoderError.cannotCreateBuffer
        }
        var drained = false
        var drainError: NSError?
        let drainStatus = converter.convert(to: drainBuf, error: &drainError) { _, inputStatus in
            if drained { inputStatus.pointee = .noDataNow; return nil }
            drained = true
            inputStatus.pointee = .endOfStream
            return nil
        }
        if drainError == nil, drainStatus != .error,
           let ch = drainBuf.floatChannelData, drainBuf.frameLength > 0 {
            output.append(contentsOf: UnsafeBufferPointer(start: ch[0], count: Int(drainBuf.frameLength)))
        }

        return DecodedAudio(samples: output, sampleRate: analysisRate)
    }
}
