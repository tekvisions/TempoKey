import Foundation

public enum PitchClass: Int, CaseIterable {
    case c = 0, cSharp, d, dSharp, e, f, fSharp, g, gSharp, a, aSharp, b
    public var name: String {
        ["C","C♯","D","D♯","E","F","F♯","G","G♯","A","A♯","B"][rawValue]
    }
}

public enum Mode: String { case major, minor }

public struct MusicalKey: Equatable {
    public let tonic: PitchClass
    public let mode: Mode
    public init(tonic: PitchClass, mode: Mode) { self.tonic = tonic; self.mode = mode }
    public var name: String { "\(tonic.name) \(mode == .major ? "maj" : "min")" }

    /// Hue (0…1) by circle of fifths — adjacent keys get adjacent hues.
    public var hue: Double {
        let circle: [PitchClass] = [.c,.g,.d,.a,.e,.b,.fSharp,.cSharp,.gSharp,.dSharp,.aSharp,.f]
        let pos = circle.firstIndex(of: tonic) ?? 0
        return Double(pos) / 12.0
    }
}
