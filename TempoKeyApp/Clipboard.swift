import AppKit
import TempoKeyCore

enum Clipboard {
    static func summary(bpm: Double, key: MusicalKey) -> String {
        "\(Theme.bpm(bpm)) BPM · \(key.name) (\(key.camelot))"
    }

    static func copy(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
