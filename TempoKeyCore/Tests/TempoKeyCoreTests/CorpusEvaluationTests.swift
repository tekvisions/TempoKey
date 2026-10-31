import XCTest
@testable import TempoKeyCore

final class CorpusEvaluationTests: XCTestCase {
    func testUnlabeledMusicIsNotReportedAsAccurate() throws {
        let reference = try JSONDecoder().decode(CorpusReference.self, from: Data(#"{}"#.utf8))
        let score = reference.evaluate(bpm: 120, key: .init(tonic: .c, mode: .major))
        XCTAssertNil(score.tempoMatches)
        XCTAssertNil(score.keyMatches)
        XCTAssertFalse(score.isFullyLabeled)
    }
    func testOctaveTempoAndRelativeKeyAreNotExactMatches() throws {
        let reference = try JSONDecoder().decode(CorpusReference.self, from: Data(#"{"bpm":120,"key":{"tonic":0,"mode":"major"}}"#.utf8))
        let score = reference.evaluate(bpm: 60, key: .init(tonic: .a, mode: .minor))
        XCTAssertEqual(score.tempoMatches, false)
        XCTAssertEqual(score.octaveTempoMatches, true)
        XCTAssertEqual(score.keyMatches, false)
        XCTAssertTrue(score.isFullyLabeled)
    }
    func testTempoUsesTwoPercentTolerance() throws {
        let reference = try JSONDecoder().decode(CorpusReference.self, from: Data(#"{"bpm":120}"#.utf8))
        XCTAssertEqual(reference.evaluate(bpm: 122, key: .init(tonic: .c, mode: .major)).tempoMatches, true)
        XCTAssertEqual(reference.evaluate(bpm: 123, key: .init(tonic: .c, mode: .major)).tempoMatches, false)
    }
    func testInvalidReferenceCannotProduceMisleadingScore() {
        for json in [#"{"bpm":0}"#, #"{"bpm":-20}"#, #"{"key":{"tonic":25,"mode":"major"}}"#] {
            XCTAssertThrowsError(try JSONDecoder().decode(CorpusReference.self, from: Data(json.utf8)))
        }
    }
}
