# TempoKey macOS App (Front-End) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Prerequisite:** Plan `2026-06-07-tempokey-core.md` is complete (`swift test` green in `TempoKeyCore/`).

**Goal:** A minimalist macOS SwiftUI app that lets the user drop/open an audio file, runs `TempoKeyCore`, and shows a report: large **BPM** top-left → **Key** → **file name + length** side by side, with stacked **Tempo / Key / Beats** timelines on a shared time axis. Light "paper" default + Dark mode toggle. Fully client-side.

**Architecture:** An Xcode macOS app target generated from an `project.yml` via **XcodeGen**, depending on the local `TempoKeyCore` Swift package. SwiftUI app lifecycle. Analysis runs off the main thread; `AppState` (an `@MainActor ObservableObject`) holds phase/progress/result. Views are thin; pure helpers (duration formatting, key→color) are unit-tested.

**Tech Stack:** Swift 5.9+, SwiftUI, Swift Charts, XcodeGen, App Sandbox (user-selected read-only), XCTest.

**Final repo layout:**
```
TempoKey/
├── project.yml                         XcodeGen spec
├── TempoKey.xcodeproj                  generated (committed for double-click-to-run)
├── TempoKeyCore/                       (from Plan 1)
├── TempoKeyApp/
│   ├── TempoKeyApp.swift               @main App + RootView
│   ├── AppState.swift                  ObservableObject: phase/progress/result/appearance
│   ├── Theme.swift                     paper/dark palettes + key→Color + duration format
│   ├── Views/
│   │   ├── ImportView.swift            drop zone + Open button + error
│   │   ├── AnalyzingView.swift         progress
│   │   ├── ReportView.swift            header + stacked timelines + toolbar
│   │   ├── SummaryHeaderView.swift     BPM / Key / file / length
│   │   ├── TempoTimelineView.swift     Swift Charts line + hover readout
│   │   ├── KeyRibbonView.swift         Canvas colored segments
│   │   └── BeatTickView.swift          Canvas beat ticks
│   ├── Info.plist
│   └── TempoKey.entitlements
├── TempoKeyAppTests/
│   └── ThemeTests.swift
├── docs/WINDOWS.md
└── README.md
```

---

## Task 1: Promote TempoKeyCore public API

The app is a separate module, so symbols it consumes must be `public`. Make these edits in `TempoKeyCore/Sources/TempoKeyCore/`.

**Files:**
- Modify: `Analysis/AnalysisResult.swift`
- Modify: `Analysis/AnalysisEngine.swift`
- Modify: `KeyDetection/MusicalKey.swift`
- Modify: `KeyDetection/KeyDetector.swift`

- [ ] **Step 1: Make the model public**

In `AnalysisResult.swift`, replace the file with:
```swift
import Foundation

public struct TempoPoint: Equatable {
    public let time: Double
    public let bpm: Double
    public init(time: Double, bpm: Double) { self.time = time; self.bpm = bpm }
}

public struct AnalysisResult {
    public let fileName: String
    public let duration: Double
    public let overallBPM: Double
    public let overallKey: MusicalKey
    public let bpmConfidence: Double
    public let tempoSeries: [TempoPoint]
    public let keySeries: [KeySegment]
    public let beats: [Double]

    public init(fileName: String, duration: Double, overallBPM: Double, overallKey: MusicalKey,
                bpmConfidence: Double, tempoSeries: [TempoPoint], keySeries: [KeySegment], beats: [Double]) {
        self.fileName = fileName; self.duration = duration
        self.overallBPM = overallBPM; self.overallKey = overallKey
        self.bpmConfidence = bpmConfidence; self.tempoSeries = tempoSeries
        self.keySeries = keySeries; self.beats = beats
    }
}
```

- [ ] **Step 2: Make the engine entry point public**

In `AnalysisEngine.swift`, change `func analyze(url:` to `public func analyze(url:`.

- [ ] **Step 3: Make key types public**

In `MusicalKey.swift`: add `public` to `enum PitchClass`, `enum Mode`, `struct MusicalKey`, and their members (`name`, `hue`, `tonic`, `mode`, an explicit `public init(tonic:mode:)`). PitchClass/Mode are simple enums — `public enum PitchClass: Int, CaseIterable` and add `public var name`. For `MusicalKey` add:
```swift
public struct MusicalKey: Equatable {
    public let tonic: PitchClass
    public let mode: Mode
    public init(tonic: PitchClass, mode: Mode) { self.tonic = tonic; self.mode = mode }
    public var name: String { "\(tonic.name) \(mode == .major ? "maj" : "min")" }
    public var hue: Double { /* unchanged body */ }
}
```
Also `public var name: String` on `PitchClass`, and `public enum Mode: String { case major, minor }`.

- [ ] **Step 4: Make `KeySegment` public**

In `KeyDetector.swift`:
```swift
public struct KeySegment: Equatable {
    public let start: Double
    public let end: Double
    public let key: MusicalKey
    public let confidence: Double
    public init(start: Double, end: Double, key: MusicalKey, confidence: Double) {
        self.start = start; self.end = end; self.key = key; self.confidence = confidence
    }
}
```

- [ ] **Step 5: Re-run core tests** — `cd TempoKeyCore && swift test`
Expected: still all PASS (public widening is non-breaking).

- [ ] **Step 6: Commit**
```bash
git add TempoKeyCore && git commit -m "feat(core): expose public API for app consumption"
```

---

## Task 2: XcodeGen project spec + app skeleton

**Files:**
- Create: `project.yml`
- Create: `TempoKeyApp/Info.plist`
- Create: `TempoKeyApp/TempoKey.entitlements`
- Create: `TempoKeyApp/TempoKeyApp.swift`
- Create: `TempoKeyApp/AppState.swift`

- [ ] **Step 1: Ensure XcodeGen is available**

Run: `which xcodegen || brew install xcodegen`
Expected: a path to `xcodegen`.

- [ ] **Step 2: Create `project.yml`**

```yaml
name: TempoKey
options:
  bundleIdPrefix: com.tempokey
  deploymentTarget:
    macOS: "13.0"
packages:
  TempoKeyCore:
    path: TempoKeyCore
targets:
  TempoKey:
    type: application
    platform: macOS
    sources: [TempoKeyApp]
    dependencies:
      - package: TempoKeyCore
        product: TempoKeyCore
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.tempokey.app
        INFOPLIST_FILE: TempoKeyApp/Info.plist
        CODE_SIGN_ENTITLEMENTS: TempoKeyApp/TempoKey.entitlements
        ENABLE_HARDENED_RUNTIME: YES
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
        SWIFT_VERSION: "5.9"
  TempoKeyAppTests:
    type: bundle.unit-test
    platform: macOS
    sources: [TempoKeyAppTests]
    dependencies:
      - target: TempoKey
schemes:
  TempoKey:
    build:
      targets:
        TempoKey: all
        TempoKeyAppTests: [test]
    run:
      config: Debug
    test:
      targets: [TempoKeyAppTests]
```

- [ ] **Step 3: Create `TempoKeyApp/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>TempoKey</string>
    <key>CFBundleDisplayName</key><string>TempoKey</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHumanReadableCopyright</key><string>Includes a Swift port of Beat-and-Tempo-Tracking (MIT, © Michael Krzyzaniak).</string>
</dict>
</plist>
```

- [ ] **Step 4: Create `TempoKeyApp/TempoKey.entitlements`** (sandbox + user-selected files)

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key><true/>
    <key>com.apple.security.files.user-selected.read-only</key><true/>
</dict>
</plist>
```

- [ ] **Step 5: Create `TempoKeyApp/TempoKeyApp.swift`**

```swift
import SwiftUI

@main
struct TempoKeyApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .frame(minWidth: 760, minHeight: 520)
                .preferredColorScheme(state.colorScheme)
        }
        .windowResizability(.contentMinSize)
    }
}

struct RootView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        switch state.phase {
        case .idle:            ImportView(errorMessage: nil)
        case .error(let msg):  ImportView(errorMessage: msg)
        case .analyzing:       AnalyzingView()
        case .done:            if let r = state.result { ReportView(result: r) } else { ImportView(errorMessage: nil) }
        }
    }
}
```

- [ ] **Step 6: Create `TempoKeyApp/AppState.swift`**

```swift
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
    @Published var appearance: Appearance = .light    // "paper" default

    var colorScheme: ColorScheme? {
        switch appearance {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    func analyze(url: URL) {
        phase = .analyzing; progress = 0; result = nil
        Task.detached(priority: .userInitiated) {
            do {
                let res = try AnalysisEngine().analyze(url: url) { p in
                    Task { @MainActor in self.progress = p }
                }
                await MainActor.run { self.result = res; self.phase = .done }
            } catch {
                await MainActor.run { self.phase = .error(error.localizedDescription) }
            }
        }
    }

    func reset() { phase = .idle; result = nil; progress = 0 }
}
```

- [ ] **Step 7: Generate the project** (Views referenced above are created in later tasks; this step only locks the project structure — full build happens in Task 7)

Run: `xcodegen generate`
Expected: `TempoKey.xcodeproj` created/regenerated.

- [ ] **Step 8: Commit**
```bash
git add project.yml TempoKeyApp TempoKey.xcodeproj
git commit -m "feat(app): xcodegen project + app skeleton + state"
```

---

## Task 3: Theme + pure helpers (TDD)

**Files:**
- Create: `TempoKeyApp/Theme.swift`
- Create: `TempoKeyAppTests/ThemeTests.swift`

- [ ] **Step 1: Write the failing test**

`TempoKeyAppTests/ThemeTests.swift`:
```swift
import XCTest
import SwiftUI
@testable import TempoKey
import TempoKeyCore

final class ThemeTests: XCTestCase {
    func testDurationFormatting() {
        XCTAssertEqual(Theme.duration(0), "0:00")
        XCTAssertEqual(Theme.duration(65), "1:05")
        XCTAssertEqual(Theme.duration(222), "3:42")
    }

    func testKeyColorIsStableAndDistinguishesMode() {
        let cMaj = MusicalKey(tonic: .c, mode: .major)
        let cMin = MusicalKey(tonic: .c, mode: .minor)
        // same hue family, different saturation/brightness for mode
        XCTAssertNotEqual(Theme.keyColorComponents(cMaj).saturation,
                          Theme.keyColorComponents(cMin).saturation)
        // determinism
        XCTAssertEqual(Theme.keyColorComponents(cMaj).hue, cMaj.hue, accuracy: 1e-9)
    }
}
```

- [ ] **Step 2: Run, verify it fails** (build the test scheme)

Run: `xcodebuild -project TempoKey.xcodeproj -scheme TempoKey -destination 'platform=macOS' test`
Expected: FAIL — `Theme` undefined.

- [ ] **Step 3: Implement `Theme.swift`**

```swift
import SwiftUI
import TempoKeyCore

enum Theme {
    /// mm:ss
    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    struct KeyColor { let hue: Double; let saturation: Double; let brightness: Double }

    /// Circle-of-fifths hue; major brighter/less saturated, minor deeper.
    static func keyColorComponents(_ key: MusicalKey) -> KeyColor {
        KeyColor(hue: key.hue,
                 saturation: key.mode == .major ? 0.45 : 0.62,
                 brightness: key.mode == .major ? 0.85 : 0.68)
    }

    static func color(for key: MusicalKey) -> Color {
        let c = keyColorComponents(key)
        return Color(hue: c.hue, saturation: c.saturation, brightness: c.brightness)
    }

    // Paper/dark surface colors derived from the SwiftUI environment where possible;
    // explicit accents kept minimal per the design.
    static let accent = Color(hue: 0.58, saturation: 0.7, brightness: 0.9)   // soft blue
    static func axisLabel(_ scheme: ColorScheme) -> Color { .secondary }
}
```

- [ ] **Step 4: Run, verify PASS** — same `xcodebuild ... test` → `ThemeTests` PASS.

- [ ] **Step 5: Commit**
```bash
git add TempoKeyApp/Theme.swift TempoKeyAppTests/ThemeTests.swift
git commit -m "feat(app): theme palette + duration/key-color helpers"
```

---

## Task 4: ImportView + AnalyzingView

**Files:**
- Create: `TempoKeyApp/Views/ImportView.swift`
- Create: `TempoKeyApp/Views/AnalyzingView.swift`

- [ ] **Step 1: Implement `ImportView.swift`** (drop zone + Open button + error; verified by build/run in Task 7)

```swift
import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject var state: AppState
    let errorMessage: String?
    @State private var isTargeted = false
    @State private var showImporter = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("TempoKey").font(.system(size: 26, weight: .semibold, design: .default))
            Text("BPM & key detection for your music").foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                .foregroundStyle(isTargeted ? Theme.accent : Color.secondary.opacity(0.5))
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.secondary.opacity(isTargeted ? 0.08 : 0.03)))
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "waveform").font(.system(size: 34, weight: .light))
                        Text("Drop an audio file").font(.headline)
                        Text("or").foregroundStyle(.secondary).font(.caption)
                        Button("Choose File…") { showImporter = true }
                    }
                }
                .frame(width: 360, height: 200)
                .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                    handleDrop(providers)
                }

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.audio]) { result in
            if case .success(let url) = result { startAnalysis(url) }
        }
    }

    private func startAnalysis(_ url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        state.analyze(url: url)
        if needsScope {
            // analysis copies decoded samples synchronously inside decode(); release after a tick
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { url.stopAccessingSecurityScopedResource() }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let url { DispatchQueue.main.async { startAnalysis(url) } }
        }
        return true
    }
}
```

> **Implementer note:** AVFoundation must finish *reading* the file before the security scope is released. If long files error under sandbox, change `AnalysisEngine` to accept the security-scoped URL and hold the scope until `decode` returns (move start/stop access into the engine). The 0.1 s delay is a pragmatic default for typical files.

- [ ] **Step 2: Implement `AnalyzingView.swift`**

```swift
import SwiftUI

struct AnalyzingView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        VStack(spacing: 16) {
            ProgressView(value: state.progress) { Text("Analyzing…") }
                .progressViewStyle(.linear)
                .frame(width: 280)
            Text("\(Int(state.progress * 100))%").foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 3: Regenerate + build** — `xcodegen generate && xcodebuild -project TempoKey.xcodeproj -scheme TempoKey -destination 'platform=macOS' build`
Expected: build SUCCEEDS (ReportView still missing → if RootView refs it, comment the `.done` case temporarily OR proceed to Task 5 before building). To avoid a broken intermediate build, implement Task 5 next, then build.

- [ ] **Step 4: Commit**
```bash
git add TempoKeyApp/Views/ImportView.swift TempoKeyApp/Views/AnalyzingView.swift
git commit -m "feat(app): import drop zone + analyzing view"
```

---

## Task 5: Timeline views (Tempo / Key / Beats)

**Files:**
- Create: `TempoKeyApp/Views/TempoTimelineView.swift`
- Create: `TempoKeyApp/Views/KeyRibbonView.swift`
- Create: `TempoKeyApp/Views/BeatTickView.swift`

- [ ] **Step 1: Implement `TempoTimelineView.swift`** (Swift Charts line + hover readout)

```swift
import SwiftUI
import Charts
import TempoKeyCore

struct TempoTimelineView: View {
    let series: [TempoPoint]
    let duration: Double
    @State private var hover: TempoPoint?

    private var yDomain: ClosedRange<Double> {
        let bpms = series.map(\.bpm)
        let lo = (bpms.min() ?? 60) - 8, hi = (bpms.max() ?? 160) + 8
        return lo...max(hi, lo + 1)
    }

    var body: some View {
        Chart {
            ForEach(series, id: \.time) { p in
                LineMark(x: .value("Time", p.time), y: .value("BPM", p.bpm))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Theme.accent)
            }
            if let hover {
                RuleMark(x: .value("Time", hover.time)).foregroundStyle(.secondary.opacity(0.4))
                PointMark(x: .value("Time", hover.time), y: .value("BPM", hover.bpm))
                    .foregroundStyle(Theme.accent)
                    .annotation(position: .top) {
                        Text("\(Int(hover.bpm)) BPM").font(.caption2).monospacedDigit()
                    }
            }
        }
        .chartXScale(domain: 0...max(duration, 0.001))
        .chartYScale(domain: yDomain)
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 6)) { v in
            AxisValueLabel { if let t = v.as(Double.self) { Text(Theme.duration(t)) } }
        } }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle().fill(.clear).contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let pt):
                            if let plot = proxy.plotFrame {
                                let x = pt.x - geo[plot].origin.x
                                if let t: Double = proxy.value(atX: x) {
                                    hover = series.min(by: { abs($0.time - t) < abs($1.time - t) })
                                }
                            }
                        case .ended: hover = nil
                        }
                    }
            }
        }
        .frame(height: 120)
    }
}
```

- [ ] **Step 2: Implement `KeyRibbonView.swift`** (Canvas colored segments)

```swift
import SwiftUI
import TempoKeyCore

struct KeyRibbonView: View {
    let segments: [KeySegment]
    let duration: Double

    var body: some View {
        Canvas { ctx, size in
            guard duration > 0 else { return }
            for seg in segments {
                let x0 = CGFloat(seg.start / duration) * size.width
                let x1 = CGFloat(seg.end / duration) * size.width
                let rect = CGRect(x: x0, y: 0, width: max(1, x1 - x0), height: size.height)
                // confidence is surfaced as opacity: less-certain key segments appear fainter
                let conf = min(1.0, max(0.0, seg.confidence))
                ctx.fill(Path(roundedRect: rect, cornerRadius: 2),
                         with: .color(Theme.color(for: seg.key).opacity(0.5 + 0.5 * conf)))
                if (x1 - x0) > 42 {
                    let text = Text(seg.key.name).font(.caption2).foregroundStyle(.white)
                    ctx.draw(text, at: CGPoint(x: x0 + 6, y: size.height / 2), anchor: .leading)
                }
            }
        }
        .frame(height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
```

- [ ] **Step 3: Implement `BeatTickView.swift`** (Canvas ticks)

```swift
import SwiftUI

struct BeatTickView: View {
    let beats: [Double]
    let duration: Double

    var body: some View {
        Canvas { ctx, size in
            guard duration > 0 else { return }
            for t in beats {
                let x = CGFloat(t / duration) * size.width
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(path, with: .color(.secondary.opacity(0.6)), lineWidth: 1)
            }
        }
        .frame(height: 16)
    }
}
```

- [ ] **Step 4: Commit**
```bash
git add TempoKeyApp/Views/TempoTimelineView.swift TempoKeyApp/Views/KeyRibbonView.swift TempoKeyApp/Views/BeatTickView.swift
git commit -m "feat(app): tempo/key/beat timeline views"
```

---

## Task 6: SummaryHeaderView + ReportView

**Files:**
- Create: `TempoKeyApp/Views/SummaryHeaderView.swift`
- Create: `TempoKeyApp/Views/ReportView.swift`

- [ ] **Step 1: Implement `SummaryHeaderView.swift`** (BPM left → Key → file + length)

```swift
import SwiftUI
import TempoKeyCore

struct SummaryHeaderView: View {
    let result: AnalysisResult

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 22) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(Int(result.overallBPM.rounded()))")
                    .font(.system(size: 46, weight: .bold, design: .rounded)).monospacedDigit()
                HStack(spacing: 6) {
                    Text("BPM").font(.caption2).tracking(2).foregroundStyle(Theme.accent)
                    // tempo confidence surfaced subtly, not hidden
                    Text("· \(Int((result.bpmConfidence * 100).rounded()))% conf")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(result.overallKey.name).font(.system(size: 24, weight: .semibold))
                Text("KEY").font(.caption2).tracking(2).foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 22) {
                labeled(result.fileName, "FILE")
                labeled(Theme.duration(result.duration), "LENGTH")
            }
        }
    }

    private func labeled(_ value: String, _ label: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value).font(.system(size: 14, weight: .medium)).lineLimit(1).truncationMode(.middle)
            Text(label).font(.caption2).tracking(1).foregroundStyle(.secondary)
        }
    }
}
```

- [ ] **Step 2: Implement `ReportView.swift`** (header + stacked timelines + toolbar)

```swift
import SwiftUI
import TempoKeyCore

struct ReportView: View {
    @EnvironmentObject var state: AppState
    let result: AnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SummaryHeaderView(result: result)
            Divider()
            track("TEMPO", color: Theme.accent) {
                TempoTimelineView(series: result.tempoSeries, duration: result.duration)
            }
            track("KEY", color: .secondary) {
                KeyRibbonView(segments: result.keySeries, duration: result.duration)
            }
            track("BEATS", color: .secondary) {
                BeatTickView(beats: result.beats, duration: result.duration)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .toolbar {
            ToolbarItemGroup {
                Picker("Appearance", selection: $state.appearance) {
                    ForEach(AppState.Appearance.allCases) { Text($0.label).tag($0) }
                }.pickerStyle(.segmented).frame(width: 180)
                Button { state.reset() } label: { Label("Open File", systemImage: "folder") }
            }
        }
    }

    @ViewBuilder
    private func track<Content: View>(_ label: String, color: Color, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption2).tracking(1.5).foregroundStyle(color)
            content()
        }
    }
}
```

- [ ] **Step 3: Commit**
```bash
git add TempoKeyApp/Views/SummaryHeaderView.swift TempoKeyApp/Views/ReportView.swift
git commit -m "feat(app): summary header + report screen"
```

---

## Task 7: Build, run, verify end-to-end

**Files:** none (verification task)

- [ ] **Step 1: Regenerate and build**

Run:
```bash
xcodegen generate
xcodebuild -project TempoKey.xcodeproj -scheme TempoKey -destination 'platform=macOS' build
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 2: Run app unit tests**

Run: `xcodebuild -project TempoKey.xcodeproj -scheme TempoKey -destination 'platform=macOS' test`
Expected: `ThemeTests` PASS.

- [ ] **Step 3: Manual smoke test** (use the superpowers `run`/`verify` flow or launch from Xcode)

1. Open `TempoKey.xcodeproj` in Xcode, press Run.
2. Drag a real music file (mp3/m4a/wav) onto the drop zone.
3. Confirm: progress bar advances → report appears with BPM top-left, key, file name + length on the right, and three timelines. Toggle Light/Dark in the toolbar. Click "Open File" to analyze another.

Expected: BPM is a plausible value, the key ribbon shows colored segment(s), beats render as ticks. (Detection accuracy on real music is approximate — this verifies the pipeline and UI, not ground-truth correctness.)

- [ ] **Step 4: Commit any fixes**
```bash
git add -A && git commit -m "fix(app): end-to-end build/run adjustments"
```

---

## Task 8: README + Windows note

**Files:**
- Create: `README.md`
- Create: `docs/WINDOWS.md`

- [ ] **Step 1: Create `README.md`**

```markdown
# TempoKey

Minimalist, fully client-side **BPM & musical-key detection** for audio files, on macOS.

Load a track → TempoKey analyzes the whole song offline and shows the overall tempo and key
plus how each varies across the song on a shared timeline.

## Build & Run (macOS, Xcode)
Requirements: macOS 13+, Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate        # regenerates TempoKey.xcodeproj from project.yml
open TempoKey.xcodeproj   # then press Run, or:
xcodebuild -project TempoKey.xcodeproj -scheme TempoKey -destination 'platform=macOS' build
```

## Architecture
- `TempoKeyCore/` — UI-free Swift package (decode, beat/tempo, key). `cd TempoKeyCore && swift test`.
- `TempoKeyApp/` — SwiftUI front-end consuming `AnalysisResult`.

## Credits
Beat/tempo detection is a Swift port of [Beat-and-Tempo-Tracking](https://github.com/michaelkrzyzaniak/Beat-and-Tempo-Tracking)
by Michael Krzyzaniak (MIT). See `TempoKeyCore/NOTICE.md`.

## Roadmap
A Windows front-end is planned — see `docs/WINDOWS.md`.
```

- [ ] **Step 2: Create `docs/WINDOWS.md`**

```markdown
# Windows Front-End (Planned)

A Windows version of TempoKey is planned but not yet built. This note records the seam.

## What is portable
The detection *algorithms* in `TempoKeyCore` are platform-neutral:
onset spectral flux, autocorrelation tempo histogram, CBSS beat tracking,
chromagram, and Krumhansl-Schmuckler key estimation.

## What is Apple-only (must be reimplemented)
- **Audio decoding** — currently `AVFoundation` (`AudioDecoder.swift`).
- **FFT/DSP** — currently `Accelerate`/vDSP (`RealFFT.swift`).

## Recommended approach
1. Define protocols for the two Apple-coupled seams:
   - `AudioDecoding` → `decode(url:) -> DecodedAudio`
   - `FFTProviding`  → magnitude + generalized autocorrelation
2. Keep all algorithm files depending only on those protocols.
3. Provide Windows implementations:
   - Decoding via Media Foundation or a bundled cross-platform decoder (e.g. dr_libs/miniaudio).
   - FFT via a cross-platform library (e.g. KissFFT/PFFFT) or plow-level Windows DSP.
4. Front-end options: SwiftUI is not on Windows — use a cross-platform UI (e.g. a thin
   web/Tauri shell, or .NET/WinUI) calling the algorithm core compiled for Windows,
   or reimplement the small UI natively. The analysis core stays the single source of truth.

No Windows code exists yet; this is the documented plan only.
```

- [ ] **Step 3: Commit**
```bash
git add README.md docs/WINDOWS.md && git commit -m "docs: readme + windows porting note"
```

---

## Done criteria

- `xcodegen generate` + `xcodebuild ... build` → `BUILD SUCCEEDED`.
- App runs from Xcode; dropping a music file produces the report with the approved layout
  (BPM top-left → key → file + length; stacked tempo/key/beat timelines; Light default + Dark toggle).
- `ThemeTests` pass; `TempoKeyCore` tests still pass.
- `README.md` and `docs/WINDOWS.md` present.
```
