import AVFoundation
import Combine

struct TransportBounds {
    static func seek(_ time: Double, duration: Double) -> Double {
        guard time.isFinite, duration.isFinite else { return 0 }
        return min(max(0, time), max(0, duration))
    }
    static func loop(_ range: ClosedRange<Double>, duration: Double) -> ClosedRange<Double>? {
        let lo = seek(range.lowerBound, duration: duration), hi = seek(range.upperBound, duration: duration)
        return hi - lo >= 0.1 ? lo...hi : nil
    }
}

@MainActor
final class PlaybackController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var time: Double = 0
    @Published private(set) var duration: Double = 0
    @Published var loopRange: ClosedRange<Double>?
    @Published var metronome = false { didSet { click?.stop(); scheduledBeat = nil } }
    @Published private(set) var available = false
    private var player: AVAudioPlayer?
    private var click: AVAudioPlayer?
    private var scope: URL?
    private var timer: AnyCancellable?
    private var beats: [Double] = []
    private var scheduledBeat: Double?

    func load(url: URL, accessURL: URL, beats: [Double]) throws {
        close()
        if accessURL.startAccessingSecurityScopedResource() { scope = accessURL }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            duration = player?.duration ?? 0
            self.beats = beats.sorted()
            available = duration > 0
            click = try AVAudioPlayer(data: Self.clickWAV())
            click?.volume = 0.45; click?.prepareToPlay()
        } catch { close(); throw error }
    }
    func toggle() {
        guard let player else { return }
        if isPlaying { pause() }
        else {
            if time >= duration - 0.02 { seek(0) }
            if let loopRange, !loopRange.contains(time) { seek(loopRange.lowerBound) }
            isPlaying = player.play()
            if isPlaying {
                timer = Timer.publish(every: 1 / 30, on: .main, in: .common).autoconnect().sink { [weak self] _ in self?.tick() }
            }
        }
    }
    func pause() { player?.pause(); click?.stop(); scheduledBeat = nil; isPlaying = false; timer = nil }
    func seek(_ value: Double) {
        time = TransportBounds.seek(value, duration: duration); player?.currentTime = time
        click?.stop(); scheduledBeat = nil
    }
    func close() {
        pause(); player = nil; click = nil; time = 0; duration = 0; available = false; loopRange = nil; beats = []
        scope?.stopAccessingSecurityScopedResource(); scope = nil
    }
    private func tick() {
        guard let player else { return }
        time = player.currentTime
        if let loop = loopRange, time >= loop.upperBound {
            seek(loop.lowerBound); player.play()
        } else if !player.isPlaying {
            // AVAudioPlayer resets its clock to zero at EOF. A delayed UI tick
            // must still restart an active loop that includes the file end.
            if let loop = loopRange {
                seek(loop.lowerBound)
                if !player.play() { pause(); return }
            } else { time = duration; pause(); return }
        }
        if metronome, let click, let next = beats.first(where: { $0 >= time && $0 != scheduledBeat }), next - time < 0.12 {
            if let loopRange, next >= loopRange.upperBound { return }
            click.currentTime = 0
            click.play(atTime: click.deviceCurrentTime + max(0, next - time))
            scheduledBeat = next
        }
    }
    private static func clickWAV() -> Data {
        let rate = 44100, count = 1102
        var data = Data()
        func ascii(_ text: String) { data.append(contentsOf: text.utf8) }
        func u16(_ x: UInt16) { var n = x.littleEndian; withUnsafeBytes(of: &n) { data.append(contentsOf: $0) } }
        func u32(_ x: UInt32) { var n = x.littleEndian; withUnsafeBytes(of: &n) { data.append(contentsOf: $0) } }
        ascii("RIFF"); u32(UInt32(36 + count * 2)); ascii("WAVEfmt "); u32(16); u16(1); u16(1)
        u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16); ascii("data"); u32(UInt32(count * 2))
        for i in 0..<count {
            let amplitude = sin(2 * .pi * 1600 * Double(i) / Double(rate)) * exp(-Double(i) / 180) * 20000
            u16(UInt16(bitPattern: Int16(amplitude)))
        }
        return data
    }
}
