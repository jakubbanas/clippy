import XCTest
@testable import Clippy

final class ReminderTimeTests: XCTestCase {
    private var utc: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    // 2001-01-01 08:00:00 UTC
    private let now = Date(timeIntervalSinceReferenceDate: 8 * 3600)

    func testRelativeMinutes() {
        XCTAssertEqual(ReminderTime.parse("20m", now: now), now.addingTimeInterval(1200))
        XCTAssertEqual(ReminderTime.parse("5 mins", now: now), now.addingTimeInterval(300))
    }

    func testRelativeHoursAndDays() {
        XCTAssertEqual(ReminderTime.parse("2h", now: now), now.addingTimeInterval(7200))
        XCTAssertEqual(ReminderTime.parse("1 hour", now: now), now.addingTimeInterval(3600))
        XCTAssertEqual(ReminderTime.parse("3d", now: now), now.addingTimeInterval(3 * 86400))
    }

    func testAbsoluteLaterTodayStaysToday() {
        let expected = utc.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: 15, minute: 0))
        XCTAssertEqual(ReminderTime.parse("3pm", now: now, calendar: utc), expected)
        let half = utc.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: 9, minute: 30))
        XCTAssertEqual(ReminderTime.parse("9:30am", now: now, calendar: utc), half)
    }

    func testAbsolutePastTimeRollsToTomorrow() {
        // 7am is already past 8am now → tomorrow.
        let expected = utc.date(from: DateComponents(year: 2001, month: 1, day: 2, hour: 7, minute: 0))
        XCTAssertEqual(ReminderTime.parse("7am", now: now, calendar: utc), expected)
    }

    func testTwentyFourHourClock() {
        let expected = utc.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: 14, minute: 30))
        XCTAssertEqual(ReminderTime.parse("14:30", now: now, calendar: utc), expected)
    }

    func testUnparseableReturnsNil() {
        XCTAssertNil(ReminderTime.parse("", now: now))
        XCTAssertNil(ReminderTime.parse("banana", now: now))
        XCTAssertNil(ReminderTime.parse("25pm", now: now))
        XCTAssertNil(ReminderTime.parse("10:99", now: now))
    }
}
