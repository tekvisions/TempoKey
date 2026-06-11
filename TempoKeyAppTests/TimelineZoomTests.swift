import XCTest
@testable import TempoKey

final class TimelineZoomTests: XCTestCase {
    func testZoomInAnchoredAtCenter() {
        let r = TimelineZoom.zoom(0...100, factor: 2, anchor: 0.5, total: 100)
        XCTAssertEqual(r.lowerBound, 25, accuracy: 1e-6)
        XCTAssertEqual(r.upperBound, 75, accuracy: 1e-6)
    }

    func testZoomInAnchoredAtLeftEdgeClamps() {
        let r = TimelineZoom.zoom(0...100, factor: 2, anchor: 0.0, total: 100)
        XCTAssertEqual(r.lowerBound, 0, accuracy: 1e-6)
        XCTAssertEqual(r.upperBound, 50, accuracy: 1e-6)
    }

    func testZoomOutClampsToFullSong() {
        let r = TimelineZoom.zoom(25...75, factor: 0.25, anchor: 0.5, total: 100)
        XCTAssertEqual(r.lowerBound, 0, accuracy: 1e-6)
        XCTAssertEqual(r.upperBound, 100, accuracy: 1e-6)
    }

    func testPanClampsAtStart() {
        let r = TimelineZoom.pan(20...60, byFraction: -10, total: 100)
        XCTAssertEqual(r.lowerBound, 0, accuracy: 1e-6)
        XCTAssertEqual(r.upperBound, 40, accuracy: 1e-6)   // width (40) preserved
    }

    func testPanClampsAtEnd() {
        let r = TimelineZoom.pan(20...60, byFraction: 10, total: 100)
        XCTAssertEqual(r.lowerBound, 60, accuracy: 1e-6)
        XCTAssertEqual(r.upperBound, 100, accuracy: 1e-6)
    }

    func testCenterPreservesWidthAndClamps() {
        let r = TimelineZoom.center(40...60, on: 0, total: 100)
        XCTAssertEqual(r.lowerBound, 0, accuracy: 1e-6)
        XCTAssertEqual(r.upperBound, 20, accuracy: 1e-6)
    }

    func testCannotZoomBelowMinWindow() {
        let total = 100.0
        let minW = TimelineZoom.minWindow(total: total)
        let r = TimelineZoom.zoom(0...total, factor: 100000, anchor: 0.5, total: total)
        XCTAssertEqual(r.upperBound - r.lowerBound, minW, accuracy: 1e-6)
    }
}
