import SwiftUI
import TempoKeyCore

enum Theme {
    /// mm:ss
    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// BPM to two decimal places (hundredths), e.g. "130.83".
    static func bpm(_ value: Double) -> String {
        guard value.isFinite, value > 0 else { return "—" }
        return String(format: "%.2f", value)
    }

    static func tempoCaption(_ confidence: Double, overrides: DisplayOverrides) -> String {
        if overrides.manualBPM != nil || overrides.bpmMultiplier != 1 { return "Corrected tempo" }
        if confidence >= 0.75 { return "Strong tempo evidence" }
        if confidence >= 0.4 { return "Mixed tempo evidence" }
        return "Weak tempo evidence"
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
