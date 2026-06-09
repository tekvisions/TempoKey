import XCTest
@testable import TempoKeyCore

final class ChromagramTests: XCTestCase {
    func testPureToneLandsOnCorrectPitchClass() {
        // A4 = 440 Hz → pitch class A (index 9 with C=0)
        let x = TestSignals.tones([440], seconds: 1)
        let chroma = Chromagram(sampleRate: 44100, fftSize: 8192).compute(x)
        let peak = chroma.firstIndex(of: chroma.max()!)!
        XCTAssertEqual(peak, PitchClass.a.rawValue)
    }

    func testMajorTriadEnergyOnTriadTones() {
        // C major triad C-E-G
        let x = TestSignals.tones([TestSignals.freq("C4"), TestSignals.freq("E4"), TestSignals.freq("G4")], seconds: 1)
        let chroma = Chromagram(sampleRate: 44100, fftSize: 8192).compute(x)
        let triad = [PitchClass.c, .e, .g].map { chroma[$0.rawValue] }
        let others = PitchClass.allCases.filter { ![.c,.e,.g].contains($0) }.map { chroma[$0.rawValue] }
        XCTAssertGreaterThan(triad.min()!, others.max()!)
    }
}
