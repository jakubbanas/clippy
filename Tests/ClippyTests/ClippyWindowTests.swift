import XCTest
import AppKit
@testable import Clippy

final class ClippyWindowTests: XCTestCase {
    func testSmallMovementIsNotADrag() {
        let start = NSPoint(x: 100, y: 100)
        let end = NSPoint(x: 102, y: 101)
        XCTAssertFalse(ClippyWindow.isDrag(from: start, to: end, threshold: 4))
    }

    func testMovementBeyondThresholdIsADrag() {
        let start = NSPoint(x: 100, y: 100)
        let end = NSPoint(x: 106, y: 100)
        XCTAssertTrue(ClippyWindow.isDrag(from: start, to: end, threshold: 4))
    }

    func testMovementExactlyAtThresholdIsNotADrag() {
        let start = NSPoint(x: 0, y: 0)
        let end = NSPoint(x: 4, y: 0)
        XCTAssertFalse(
            ClippyWindow.isDrag(from: start, to: end, threshold: 4),
            "boundary distance should count as a click, not a drag"
        )
    }

    func testPickIdleAnimationCyclesThroughSetByIndex() {
        let set = ["GetAttention", "Explain", "Congratulate"]
        XCTAssertEqual(ClippyWindow.pickIdleAnimation(from: set, index: 0), "GetAttention")
        XCTAssertEqual(ClippyWindow.pickIdleAnimation(from: set, index: 1), "Explain")
        XCTAssertEqual(ClippyWindow.pickIdleAnimation(from: set, index: 2), "Congratulate")
    }

    func testPickIdleAnimationWrapsAroundForOutOfRangeIndex() {
        let set = ["GetAttention", "Explain", "Congratulate"]
        XCTAssertEqual(ClippyWindow.pickIdleAnimation(from: set, index: 3), "GetAttention")
    }
}
