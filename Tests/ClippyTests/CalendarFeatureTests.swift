import XCTest
@testable import Clippy

final class CalendarFeatureTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFiresLeadReminderOneMinuteBefore() {
        let due = dueReminders(events: [makeEvent(startingIn: 60)], now: now)
        XCTAssertEqual(due.map(\.lead), [60])
    }

    func testFiresOnlyStartReminderAtStart() {
        let due = dueReminders(events: [makeEvent(startingIn: 0)], now: now)
        XCTAssertEqual(due.map(\.lead), [0], "stale lead reminder must not fire once meeting started")
    }

    func testLateLeadReminderStillFiresBeforeStart() {
        let due = dueReminders(events: [makeEvent(startingIn: 30)], now: now)
        XCTAssertEqual(due.map(\.lead), [60])
    }

    func testDoesNotRefireSameReminder() {
        let event = makeEvent(startingIn: 60)
        let first = dueReminders(events: [event], now: now)
        XCTAssertEqual(first.count, 1)
        let second = dueReminders(events: [event], now: now, alreadyFired: Set(first.map(\.key)))
        XCTAssertTrue(second.isEmpty)
    }

    func testRescheduledEventFiresAgain() {
        let event = makeEvent(startingIn: 60)
        let firedKeys = Set(dueReminders(events: [event], now: now).map(\.key))

        let moved = makeEvent(startingIn: 55)
        let due = dueReminders(events: [moved], now: now, alreadyFired: firedKeys)
        XCTAssertEqual(due.count, 1, "moved start time should produce a new key and re-fire")
    }

    func testSkipsRemindersOlderThanGraceWindow() {
        let event = makeEvent(startingIn: -120)
        XCTAssertTrue(dueReminders(events: [event], now: now).isEmpty)
    }

    func testFiresWithinGraceWindowAfterMissedMoment() {
        let event = makeEvent(startingIn: -30)
        XCTAssertEqual(dueReminders(events: [event], now: now).map(\.lead), [0])
    }

    func testSkipsFutureReminders() {
        let event = makeEvent(startingIn: 600)
        XCTAssertTrue(dueReminders(events: [event], now: now).isEmpty)
    }

    func testSkipsAllDayAndDeclinedEvents() {
        let allDay = makeEvent(startingIn: 0, isAllDay: true)
        let declined = makeEvent(startingIn: 0, isDeclined: true)
        XCTAssertTrue(dueReminders(events: [allDay, declined], now: now).isEmpty)
    }

    private func dueReminders(
        events: [EventInfo],
        now: Date,
        alreadyFired: Set<String> = []
    ) -> [CalendarFeature.DueReminder] {
        CalendarFeature.dueReminders(
            events: events,
            now: now,
            leadTimes: [60, 0],
            graceWindow: 90,
            alreadyFired: alreadyFired
        )
    }

    private func makeEvent(startingIn seconds: TimeInterval, isAllDay: Bool = false, isDeclined: Bool = false) -> EventInfo {
        let start = now.addingTimeInterval(seconds)
        return EventInfo(
            id: "evt1",
            title: "Standup",
            start: start,
            end: start.addingTimeInterval(1800),
            location: nil,
            notes: nil,
            url: nil,
            isAllDay: isAllDay,
            isDeclined: isDeclined,
            calendarTitle: "Work"
        )
    }
}
