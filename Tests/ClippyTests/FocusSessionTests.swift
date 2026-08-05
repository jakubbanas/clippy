import XCTest
@testable import Clippy

final class FocusSessionTests: XCTestCase {
    func testEndOnlyWhenMidCheckInOff() {
        let beats = FocusSessionFeature.beats(durationMinutes: 25, midCheckIn: false)
        XCTAssertEqual(beats.map(\.kind), [.end])
        XCTAssertEqual(beats.map(\.offset), [25 * 60])
    }

    func testMidAndEndForLongEnabledBlock() {
        let beats = FocusSessionFeature.beats(durationMinutes: 50, midCheckIn: true)
        XCTAssertEqual(beats.map(\.kind), [.mid, .end])
        XCTAssertEqual(beats.map(\.offset), [25 * 60, 50 * 60])
    }

    func testMidDroppedForShortBlockEvenWhenEnabled() {
        let beats = FocusSessionFeature.beats(durationMinutes: 15, midCheckIn: true)
        XCTAssertEqual(beats.map(\.kind), [.end], "blocks under 20 min shouldn't be interrupted")
    }

    func testStatusTextRoundsUpMinutes() {
        XCTAssertEqual(
            FocusSessionFeature.statusText(goal: "Fix auth bug", remaining: 14 * 60 + 1),
            "Fix auth bug — 15m left"
        )
    }

    func testStatusTextExactMinuteBoundary() {
        XCTAssertEqual(
            FocusSessionFeature.statusText(goal: "Fix auth bug", remaining: 60),
            "Fix auth bug — 1m left"
        )
    }

    func testStatusTextUnderAMinute() {
        XCTAssertEqual(
            FocusSessionFeature.statusText(goal: "Fix auth bug", remaining: 59),
            "Fix auth bug — under a minute"
        )
    }

    func testProgressFractionZeroAtStart() {
        XCTAssertEqual(FocusSessionFeature.progressFraction(remaining: 1500, total: 1500), 0)
    }

    func testProgressFractionOneAtTimeUp() {
        XCTAssertEqual(FocusSessionFeature.progressFraction(remaining: 0, total: 1500), 1)
    }

    func testProgressFractionHalfway() {
        XCTAssertEqual(FocusSessionFeature.progressFraction(remaining: 750, total: 1500), 0.5)
    }

    func testProgressFractionClampsWhenRemainingExceedsTotal() {
        XCTAssertEqual(FocusSessionFeature.progressFraction(remaining: 2000, total: 1500), 0)
    }

    func testProgressFractionClampsWhenRemainingIsNegative() {
        XCTAssertEqual(FocusSessionFeature.progressFraction(remaining: -30, total: 1500), 1)
    }

    func testProgressFractionOneWhenTotalIsZeroOrNegative() {
        XCTAssertEqual(FocusSessionFeature.progressFraction(remaining: 0, total: 0), 1)
        XCTAssertEqual(FocusSessionFeature.progressFraction(remaining: 10, total: -5), 1)
    }
}
