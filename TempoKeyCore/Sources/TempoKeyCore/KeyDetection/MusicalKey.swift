import Foundation

enum PitchClass: Int, CaseIterable {
    case c = 0, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b
    var name: String {
        ["C","C♯","D","D♯","E","F","F♯","G","G♯","A","A♯","B"][rawValue]
    }
}

enum Mode: String { case major, minor }

struct MusicalKey: Equatable {
    let tonic: PitchClass
    let mode: Mode
    var name: String { "\(tonic.name) \(mode == .major ? "maj" : "min")" }

    /// Hue (0…1) by circle of fifths — adjacent keys get adjacent hues.
    var hue: Double {
        let circle: [PitchClass] = [.c,.g,.d,.a,.e,.b,.fSharp,.cSharp,.gSharp,.dSharp,.aSharp,.f]
        let pos = circle.firstIndex(of: tonic) ?? 0
        return Double(pos) / 12.0
    }
}
