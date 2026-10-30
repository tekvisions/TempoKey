import XCTest
@testable import TempoKeyCore

final class SectionTempoTests: XCTestCase {
    private let energy = (0..<96).map { EnergyPoint(time: Double($0) * 0.25, rms: 0.4) }

    func testSustainedTempoStepPartitionsStableEnergyAtTwelveSeconds() throws {
        let tempo = (0..<96).map { TempoPoint(time: Double($0) * 0.25, bpm: $0 < 48 ? 120 : 140) }
        let sections = try DeeperAnalysis.sections(energy: energy, duration: 24, tempo: tempo)
        XCTAssertEqual(sections.count, 2)
        guard sections.count == 2 else { return }
        XCTAssertEqual(sections[0].start, 0)
        XCTAssertEqual(sections[0].end, 12, accuracy: 0.25)
        XCTAssertEqual(sections[0].bpm, 120)
        XCTAssertEqual(sections[1].bpm, 140)
        XCTAssertEqual(sections[0].end, sections[1].start)
        XCTAssertEqual(sections[1].end, 24)
        XCTAssertEqual(sections.map(\.label), ["Section 1", "Section 2"])
    }

    func testJitterStartupOctaveAndBriefGlitchDoNotSplitSections() throws {
        let tempo = (0..<96).map { i -> TempoPoint in
            let bpm: Double = i < 6 ? 240 : (i == 32 ? 60 : 120 + (i % 2 == 0 ? 1.5 : -1.5))
            return TempoPoint(time: Double(i) * 0.25, bpm: bpm)
        }
        let sections = try DeeperAnalysis.sections(energy: energy, duration: 24, tempo: tempo)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.start, 0)
        XCTAssertEqual(sections.last?.end, 24)
    }

    func testNearbyEnergyAndTempoEvidenceDeduplicatesBoundary() throws {
        let energy = (0..<96).map { EnergyPoint(time: Double($0) * 0.25, rms: $0 < 48 ? 0.2 : 0.6) }
        let tempo = (0..<96).map { TempoPoint(time: Double($0) * 0.25, bpm: $0 < 50 ? 120 : 140) }
        let sections = try DeeperAnalysis.sections(energy: energy, duration: 24, tempo: tempo)
        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections.first?.end ?? 0, 12, accuracy: 0.25)
        for section in sections { XCTAssertGreaterThanOrEqual(section.end - section.start, 4) }
        XCTAssertEqual(sections.last?.end, 24)
    }

    func testShortTempoPlateausDoNotCreateLongFalseSections() throws {
        for plateauLength in [5, 12] {
            let tempo = (0..<96).map { index in
                TempoPoint(time: Double(index) * 0.25,
                           bpm: (48..<(48 + plateauLength)).contains(index) ? 140 : 120)
            }
            let sections = try DeeperAnalysis.sections(energy: energy, duration: 24, tempo: tempo)
            XCTAssertEqual(sections.count, 1, "A temporary \(Double(plateauLength) * 0.25)s plateau is not a sustained section")
        }
    }
}
