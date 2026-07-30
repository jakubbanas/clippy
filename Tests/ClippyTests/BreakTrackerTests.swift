import XCTest
@testable import Clippy

final class BreakTrackerTests: XCTestCase {
    private let threshold: TimeInterval = 15 * 60

    func testReportsBreakWhenIdleDropsAfterLongAway() {
        // Was idle 30 min, now just moved (idle ~2s) → break of 30 min.
        let away = BreakTrackerFeature.breakEnded(previousIdle: 1800, currentIdle: 2, threshold: threshold)
        XCTAssertEqual(away, 1800)
    }

    func testNoReportWhileStillIdle() {
        // Idle keeps growing → not back yet.
        XCTAssertNil(BreakTrackerFeature.breakEnded(previousIdle: 1800, currentIdle: 1815, threshold: threshold))
    }

    func testNoReportForShortBreak() {
        // Returned, but was only away 5 min (< 15 min threshold).
        XCTAssertNil(BreakTrackerFeature.breakEnded(previousIdle: 300, currentIdle: 1, threshold: threshold))
    }

    func testNoReportDuringNormalActivity() {
        XCTAssertNil(BreakTrackerFeature.breakEnded(previousIdle: 3, currentIdle: 0, threshold: threshold))
    }

    func testDurationFormatting() {
        XCTAssertEqual(BreakTrackerFeature.formatDuration(1800), "30 min")
        XCTAssertEqual(BreakTrackerFeature.formatDuration(3900), "1h 5m")
    }
}
