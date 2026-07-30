import XCTest
@testable import Clippy

final class NudgesFeatureTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let water = NudgeConfig(name: "Water", enabled: true, everyMinutes: 45, message: "w")

    func testFiresOnceIntervalElapsed() {
        let lastFired = ["Water": now.addingTimeInterval(-45 * 60)]
        let due = NudgesFeature.dueNudges(nudges: [water], now: now, lastFired: lastFired)
        XCTAssertEqual(due.map(\.name), ["Water"])
    }

    func testDoesNotFireBeforeInterval() {
        let lastFired = ["Water": now.addingTimeInterval(-44 * 60)]
        XCTAssertTrue(NudgesFeature.dueNudges(nudges: [water], now: now, lastFired: lastFired).isEmpty)
    }

    func testDisabledNeverFires() {
        let off = NudgeConfig(name: "Water", enabled: false, everyMinutes: 45, message: "w")
        let lastFired = ["Water": now.addingTimeInterval(-999 * 60)]
        XCTAssertTrue(NudgesFeature.dueNudges(nudges: [off], now: now, lastFired: lastFired).isEmpty)
    }

    func testMissingLastFiredIsNotDue() {
        XCTAssertTrue(NudgesFeature.dueNudges(nudges: [water], now: now, lastFired: [:]).isEmpty)
    }

    func testNothingFiresWhileUserIsAway() {
        let lastFired = ["Water": now.addingTimeInterval(-999 * 60)] // long overdue
        XCTAssertTrue(
            NudgesFeature.dueNudges(nudges: [water], now: now, lastFired: lastFired, userIsActive: false).isEmpty
        )
    }

    func testOnlyElapsedNudgesFire() {
        let breaks = NudgeConfig(name: "Breaks", enabled: true, everyMinutes: 90, message: "b")
        let lastFired = [
            "Water": now.addingTimeInterval(-50 * 60),  // elapsed
            "Breaks": now.addingTimeInterval(-50 * 60),  // not yet
        ]
        let due = NudgesFeature.dueNudges(nudges: [water, breaks], now: now, lastFired: lastFired)
        XCTAssertEqual(due.map(\.name), ["Water"])
    }
}
