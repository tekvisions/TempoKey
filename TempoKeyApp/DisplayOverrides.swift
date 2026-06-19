import Foundation
import TempoKeyCore

/// User corrections applied to the *displayed* tempo/key only — the analysis result is untouched.
struct DisplayOverrides: Equatable {
    var bpmMultiplier: Double = 1     // 0.5, 1, or 2
    var manualBPM: Double?            // from tap-tempo
    var manualKey: MusicalKey?

    func displayedBPM(detected: Double) -> Double { (manualBPM ?? detected) * bpmMultiplier }
    func displayedKey(detected: MusicalKey) -> MusicalKey { manualKey ?? detected }
    var isActive: Bool { bpmMultiplier != 1 || manualBPM != nil || manualKey != nil }
    mutating func clear() { self = DisplayOverrides() }
}
