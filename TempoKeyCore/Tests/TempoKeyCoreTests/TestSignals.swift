import Foundation
import AVFoundation

enum TestSignals {
    static let sr: Double = 44100

    /// Impulse "click track" at a given BPM for `seconds`.
    static func clickTrack(bpm: Double, seconds: Double, sampleRate: Double = sr) -> [Float] {
        let n = Int(seconds * sampleRate)
        var x = [Float](repeating: 0, count: n)
        let period = Int((60.0 / bpm) * sampleRate)
        var i = 0
        while i < n {
            // short decaying click so there is spectral content across bins
            for k in 0..<min(64, n - i) { x[i + k] = Float(exp(-Double(k) / 8.0)) }
            i += period
        }
        return x
    }

    /// Sum of equal-amplitude sinusoids (Hz). Useful for chords/tones.
    static func tones(_ freqs: [Double], seconds: Double, sampleRate: Double = sr) -> [Float] {
        let n = Int(seconds * sampleRate)
        var x = [Float](repeating: 0, count: n)
        for f in freqs {
            for i in 0..<n { x[i] += Float(sin(2 * .pi * f * Double(i) / sampleRate)) }
        }
        let scale = Float(1.0 / Double(max(1, freqs.count)))
        return x.map { $0 * scale }
    }

    /// Equal-temperament frequency for a note name like "C4", "A4", "E4".
    static func freq(_ note: String) -> Double {
        let names = ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"]
        let letter = note.prefix(while: { !$0.isNumber || $0 == "#" })
        let octave = Int(note.suffix(from: note.firstIndex(where: { $0.isNumber })!))!
        let semitone = names.firstIndex(of: String(letter))!
        let midi = (octave + 1) * 12 + semitone        // C-1 = 0
        return 440.0 * pow(2.0, Double(midi - 69) / 12.0)
    }

    /// Write mono Float samples to a temp .wav and return its URL.
    static func writeWAV(_ samples: [Float], sampleRate: Double = sr) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tk-\(UUID().uuidString).wav")
        let fmt = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                sampleRate: sampleRate, channels: 1, interleaved: false)!
        let file = try AVAudioFile(forWriting: url, settings: fmt.settings)
        let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: AVAudioFrameCount(samples.count))!
        buf.frameLength = AVAudioFrameCount(samples.count)
        memcpy(buf.floatChannelData![0], samples, samples.count * MemoryLayout<Float>.size)
        try file.write(from: buf)
        return url
    }
}
