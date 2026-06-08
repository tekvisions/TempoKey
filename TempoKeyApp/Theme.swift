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
