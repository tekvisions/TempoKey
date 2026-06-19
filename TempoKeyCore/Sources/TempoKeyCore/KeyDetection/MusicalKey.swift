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

    /// Camelot wheel code, e.g. "8A" (minor) / "8B" (major).
    public var camelot: String {
        let major = [8, 3, 10, 5, 12, 7, 2, 9, 4, 11, 6, 1]   // indexed by PitchClass (C…B)
        let minor = [5, 12, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10]
        let n = (mode == .major ? major : minor)[tonic.rawValue]
        return "\(n)\(mode == .major ? "B" : "A")"
    }

    /// The three harmonically-compatible Camelot codes: ±1 on the same ring, plus the relative
    /// (same number, other ring).
    public var compatibleCamelot: [String] {
        let letter = mode == .major ? "B" : "A"
        let other = mode == .major ? "A" : "B"
        let n = Int(camelot.dropLast()) ?? 1
        let down = (n + 10) % 12 + 1   // n-1, wrapping 1→12
        let up = n % 12 + 1            // n+1, wrapping 12→1
        return ["\(down)\(letter)", "\(up)\(letter)", "\(n)\(other)"]
    }
}
