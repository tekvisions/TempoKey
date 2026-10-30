import AVFoundation

/// Keeps detector time constants independent of source/device sample rate.
protocol AudioResampling {
    func resample(_ samples: [Float], from sourceRate: Double, to targetRate: Double) throws -> [Float]
}

struct AppleAudioResampler: AudioResampling {
    func resample(_ samples: [Float], from sourceRate: Double, to targetRate: Double) throws -> [Float] {
        try Task.checkCancellation()
        guard sourceRate.isFinite, targetRate.isFinite,
              (8000...384000).contains(sourceRate), (8000...384000).contains(targetRate) else {
            throw AnalysisError.invalidSampleRate
        }
        guard Double(samples.count) / sourceRate <= 3600 else { throw AnalysisError.tooLongAudio }
        if sourceRate == targetRate || samples.isEmpty { return samples }
        guard let inputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sourceRate, channels: 1, interleaved: false),
              let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: targetRate, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: inputFormat, to: outputFormat),
              let input = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: 16384),
              let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: 16384) else {
            throw AudioResamplingError.conversionFailed
        }
        converter.sampleRateConverterQuality = AVAudioQuality.high.rawValue
        let expectedCount = max(1, Int((Double(samples.count) * targetRate / sourceRate).rounded()))
        var converted: [Float] = []
        converted.reserveCapacity(expectedCount)
        var position = 0
        while converted.count < expectedCount {
            try Task.checkCancellation()
            var error: NSError?
            let status = converter.convert(to: output, error: &error) { requested, inputStatus in
                guard !Task.isCancelled, position < samples.count else {
                    inputStatus.pointee = .endOfStream
                    return nil
                }
                let count = min(Int(requested), Int(input.frameCapacity), samples.count - position)
                input.frameLength = AVAudioFrameCount(count)
                // AVAudioConverter owns no pointer into the caller's Swift Array.
                samples.withUnsafeBufferPointer { source in
                    input.floatChannelData![0].update(from: source.baseAddress!.advanced(by: position), count: count)
                }
                position += count
                inputStatus.pointee = .haveData
                return input
            }
            try Task.checkCancellation()
            guard error == nil, status != .error else { throw AudioResamplingError.conversionFailed }
            let count = min(Int(output.frameLength), expectedCount - converted.count)
            if count > 0 {
                converted.append(contentsOf: UnsafeBufferPointer(start: output.floatChannelData![0], count: count))
            }
            if status == .endOfStream || (count == 0 && status == .inputRanDry) { break }
            if count == 0 { throw AudioResamplingError.conversionFailed }
        }
        // Converter rounding can omit the final fractional output frame; one zero
        // sample closes that sub-sample duration difference without fabricating a tail.
        guard converted.count >= expectedCount - 1 else { throw AudioResamplingError.conversionFailed }
        if converted.count < expectedCount { converted.append(0) }
        return converted
    }
}

enum AudioResamplingError: LocalizedError {
    case conversionFailed
    var errorDescription: String? { "Couldn't normalize the audio sample rate for analysis." }
}
