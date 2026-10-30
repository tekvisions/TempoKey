import AVFoundation
import CoreAudio
import SwiftUI
import TempoKeyCore

struct AudioInputDevice: Identifiable {
    let id: AudioDeviceID
    let name: String
    static func available() -> [AudioInputDevice] {
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            var input = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            var bytes: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &input, 0, nil, &bytes) == noErr, bytes > 0 else { return nil }
            var nameAddress = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var name: Unmanaged<CFString>?
            var nameSize = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
            guard AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &nameSize, &name) == noErr else { return nil }
            return AudioInputDevice(id: id, name: name?.takeRetainedValue() as String? ?? "Audio input")
        }
    }
}

// Fixed storage; the audio callback never waits for an analysis job or enqueues a backlog.
final class LiveSampleBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [Float]
    private var index = 0
    private var count = 0
    init(capacity: Int) { storage = Array(repeating: 0, count: max(1, capacity)) }
    func append(_ buffer: AVAudioPCMBuffer) {
        guard let channels = buffer.floatChannelData, buffer.format.channelCount > 0, lock.try() else { return }
        defer { lock.unlock() }
        for frame in 0..<Int(buffer.frameLength) {
            var value: Float = 0
            for channel in 0..<Int(buffer.format.channelCount) { value += channels[channel][frame] }
            storage[index] = value / Float(buffer.format.channelCount)
            index = (index + 1) % storage.count; count = min(count + 1, storage.count)
        }
    }
    func snapshot() -> [Float] {
        lock.lock(); defer { lock.unlock() }
        let start = (index - count + storage.count) % storage.count
        return (0..<count).map { storage[(start + $0) % storage.count] }
    }
}

@MainActor
final class LiveInputController: ObservableObject {
    @Published private(set) var running = false
    @Published private(set) var requesting = false
    @Published private(set) var status = "Choose an input and start listening."
    @Published private(set) var result: AnalysisResult?
    @Published private(set) var level: Double = 0
    @Published var selectedDevice: AudioDeviceID = 0
    @Published var devices: [AudioInputDevice] = AudioInputDevice.available()
    private var engine: AVAudioEngine?
    private var loop: Task<Void, Never>?
    private var analysis: Task<AnalysisResult, Error>?
    private var generation = UUID()
    private var configurationObserver: NSObjectProtocol?

    func start() async {
        stop()
        let token = generation
        requesting = true; status = "Requesting microphone access…"
        let allowed = await AVCaptureDevice.requestAccess(for: .audio)
        guard generation == token else { return }
        requesting = false
        guard allowed else { status = "Microphone access is off. Enable TempoKey in System Settings → Privacy & Security → Microphone."; return }
        let engine = AVAudioEngine()
        let input = engine.inputNode
        if selectedDevice != 0, let unit = input.audioUnit {
            var id = selectedDevice
            let code = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &id, UInt32(MemoryLayout<AudioDeviceID>.size))
            guard code == noErr else { status = "The selected input is unavailable. Refresh inputs and try again."; return }
        }
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0, format.commonFormat == .pcmFormatFloat32, !format.isInterleaved else { status = "This input has no supported audio stream."; return }
        let rate = format.sampleRate
        let buffer = LiveSampleBuffer(capacity: Int(rate * 12))
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { pcm, _ in buffer.append(pcm) }
        do { try engine.start() }
        catch { input.removeTap(onBus: 0); status = error.localizedDescription; return }
        self.engine = engine; running = true; status = "Listening — gathering 6 seconds of audio…"
        configurationObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.generation == token else { return }
                self.stop(); self.status = "Audio input changed. Select an input and start again."
            }
        }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                guard let self, self.generation == token else { return }
                let samples = buffer.snapshot()
                let tail = samples.suffix(Int(rate))
                self.level = tail.isEmpty ? 0 : sqrt(tail.reduce(0) { $0 + Double($1 * $1) } / Double(tail.count))
                guard samples.count >= Int(rate * 6) else { continue }
                guard self.level > 0.0001 else { self.result = nil; self.status = "Listening — no signal detected."; continue }
                let job = Task.detached(priority: .utility) { try AnalysisEngine().analyze(samples: samples, sampleRate: rate, fileName: "Live input") }
                self.analysis = job
                do {
                    let result = try await job.value
                    guard self.generation == token, !Task.isCancelled else { return }
                    self.result = result; self.status = "Live estimate · last \(Int(result.duration)) seconds"
                } catch {
                    guard self.generation == token, !Task.isCancelled else { return }
                    self.result = nil; self.status = error.localizedDescription
                }
                self.analysis = nil
            }
        }
    }
    func stop() {
        generation = UUID(); loop?.cancel(); loop = nil; analysis?.cancel(); analysis = nil
        if let configurationObserver { NotificationCenter.default.removeObserver(configurationObserver) }; configurationObserver = nil
        if let engine { engine.inputNode.removeTap(onBus: 0); engine.stop() }; engine = nil
        running = false; requesting = false; result = nil; level = 0; status = "Input stopped."
    }
}

struct LiveInputView: View {
    @StateObject private var live = LiveInputController()
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: live.running ? "mic.fill" : "mic").font(.system(size: 44, weight: .light)).foregroundStyle(Theme.accent)
            Text("Live input").font(.largeTitle.weight(.semibold))
            HStack {
                Picker("Input", selection: $live.selectedDevice) {
                    Text("System default").tag(AudioDeviceID(0))
                    ForEach(live.devices) { Text($0.name).tag($0.id) }
                }.frame(width: 320).disabled(live.running || live.requesting)
                Button { live.devices = AudioInputDevice.available() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh audio inputs").disabled(live.running)
            }
            HStack(spacing: 40) {
                VStack { Text(live.result.map { Theme.bpm($0.overallBPM) } ?? "—").font(.system(size: 56, weight: .semibold, design: .rounded)).monospacedDigit(); Text("BPM").foregroundStyle(.secondary) }
                VStack { Text(live.result?.overallKey.name ?? "—").font(.system(size: 36, weight: .medium)); Text(live.result?.overallKey.camelot ?? "Key").foregroundStyle(.secondary) }
            }.frame(height: 110)
            ProgressView(value: min(1, live.level * 5)).frame(width: 300).accessibilityLabel("Input level")
            Text(live.status).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 500)
            Button(live.running || live.requesting ? "Stop listening" : "Start listening") {
                if live.running || live.requesting { live.stop() } else { Task { await live.start() } }
            }.buttonStyle(.borderedProminent).controlSize(.large)
            Text("Audio is analyzed on this Mac and never saved or uploaded.\nLive estimates use a rolling window; verify tempo and key by ear.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(24)
        .onDisappear { live.stop() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            if let window = notification.object as? NSWindow, window.title == "TempoKey" { live.stop() }
        }
    }
}
