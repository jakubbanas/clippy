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
}
