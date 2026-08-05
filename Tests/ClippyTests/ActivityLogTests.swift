import XCTest
@testable import Clippy

final class ActivityLogTests: XCTestCase {
    // MARK: - upsert

    func testUpsertCreatesNewKey() {
        let rows = ActivityLog.upsert([:], key: ActivityLogKey(date: "2026-08-05", hour: 14), activeDelta: 15, observedDelta: 15, hadMeeting: false)
        XCTAssertEqual(rows[ActivityLogKey(date: "2026-08-05", hour: 14)], ActivityLogRow(activeSeconds: 15, observedSeconds: 15, hadMeeting: false))
    }

    func testUpsertAccumulatesOnExistingKey() {
        let key = ActivityLogKey(date: "2026-08-05", hour: 14)
        var rows = ActivityLog.upsert([:], key: key, activeDelta: 15, observedDelta: 15, hadMeeting: false)
        rows = ActivityLog.upsert(rows, key: key, activeDelta: 0, observedDelta: 15, hadMeeting: false)
        XCTAssertEqual(rows[key], ActivityLogRow(activeSeconds: 15, observedSeconds: 30, hadMeeting: false))
    }

    func testUpsertOverwritesHadMeetingRatherThanOring() {
        let key = ActivityLogKey(date: "2026-08-05", hour: 14)
        var rows = ActivityLog.upsert([:], key: key, activeDelta: 15, observedDelta: 15, hadMeeting: true)
        rows = ActivityLog.upsert(rows, key: key, activeDelta: 15, observedDelta: 15, hadMeeting: false)
        XCTAssertEqual(rows[key]?.hadMeeting, false, "latest calendar check should win, not accumulate")
    }

    func testUpsertDoesNotBleedAcrossDifferentKeys() {
        var rows = ActivityLog.upsert([:], key: ActivityLogKey(date: "2026-08-05", hour: 14), activeDelta: 15, observedDelta: 15, hadMeeting: false)
        rows = ActivityLog.upsert(rows, key: ActivityLogKey(date: "2026-08-05", hour: 15), activeDelta: 5, observedDelta: 15, hadMeeting: true)
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[ActivityLogKey(date: "2026-08-05", hour: 14)]?.activeSeconds, 15)
        XCTAssertEqual(rows[ActivityLogKey(date: "2026-08-05", hour: 15)]?.activeSeconds, 5)
    }

    // MARK: - serialize / parse round-trip

    func testSerializeAndParseRoundTrip() {
        let rows: [ActivityLogKey: ActivityLogRow] = [
            ActivityLogKey(date: "2026-08-05", hour: 14): ActivityLogRow(activeSeconds: 620, observedSeconds: 900, hadMeeting: true),
            ActivityLogKey(date: "2026-08-05", hour: 9): ActivityLogRow(activeSeconds: 0, observedSeconds: 300, hadMeeting: false),
        ]
        let csv = ActivityLog.serialize(rows)
        XCTAssertEqual(ActivityLog.parse(csv), rows)
    }

    func testSerializeSortsByDateThenHour() {
        let rows: [ActivityLogKey: ActivityLogRow] = [
            ActivityLogKey(date: "2026-08-05", hour: 14): ActivityLogRow(activeSeconds: 1, observedSeconds: 1, hadMeeting: false),
            ActivityLogKey(date: "2026-08-05", hour: 9): ActivityLogRow(activeSeconds: 1, observedSeconds: 1, hadMeeting: false),
            ActivityLogKey(date: "2026-08-04", hour: 23): ActivityLogRow(activeSeconds: 1, observedSeconds: 1, hadMeeting: false),
        ]
        let lines = ActivityLog.serialize(rows).split(separator: "\n")
        XCTAssertEqual(Array(lines), [
            "date,hour,active_seconds,observed_seconds,had_meeting",
            "2026-08-04,23,1.0,1.0,false",
            "2026-08-05,9,1.0,1.0,false",
            "2026-08-05,14,1.0,1.0,false",
        ])
    }

    func testParseSkipsMalformedLines() {
        let csv = "date,hour,active_seconds,observed_seconds,had_meeting\n2026-08-05,14,620,900,true\nnot,a,valid,row\n"
        let rows = ActivityLog.parse(csv)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[ActivityLogKey(date: "2026-08-05", hour: 14)], ActivityLogRow(activeSeconds: 620, observedSeconds: 900, hadMeeting: true))
    }

    // MARK: - url

    func testURLEncodesYearAndMonth() {
        let date = Date(timeIntervalSince1970: 1_754_395_200) // 2025-08-05T12:00:00Z, safely mid-month in any timezone
        let url = ActivityLog.url(for: date)
        XCTAssertTrue(url.lastPathComponent.hasPrefix("activity-2025-08"), url.lastPathComponent)
        XCTAssertTrue(url.path.contains("com.jbanas.clippy"))
    }

    // MARK: - load / save (disk round-trip via a scratch temp file)

    func testLoadReturnsEmptyDictWhenFileMissing() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("activity-log-tests-missing-\(UUID().uuidString).csv")
        XCTAssertEqual(ActivityLog.load(from: url), [:])
    }

    func testSaveThenLoadRoundTrip() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("activity-log-tests-\(UUID().uuidString).csv")
        defer { try? FileManager.default.removeItem(at: url) }

        let rows: [ActivityLogKey: ActivityLogRow] = [
            ActivityLogKey(date: "2026-08-05", hour: 14): ActivityLogRow(activeSeconds: 620, observedSeconds: 900, hadMeeting: true),
        ]
        ActivityLog.save(rows, to: url)
        XCTAssertEqual(ActivityLog.load(from: url), rows)
    }

    // MARK: - ActivityLogFeature.bucketKey

    func testBucketKeyUsesLocalDateAndHour() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        // 2026-08-05T21:30:00Z == 2026-08-05 14:30 PDT
        let date = ISO8601DateFormatter().date(from: "2026-08-05T21:30:00Z")!
        let key = ActivityLogFeature.bucketKey(for: date, calendar: calendar)
        XCTAssertEqual(key, ActivityLogKey(date: "2026-08-05", hour: 14))
    }

    // MARK: - ActivityLogFeature.hasMeeting

    private func makeActivityEvent(
        startOffset: TimeInterval,
        endOffset: TimeInterval,
        from hourStart: Date,
        isAllDay: Bool = false,
        isDeclined: Bool = false
    ) -> EventInfo {
        EventInfo(
            id: "evt",
            title: "Meeting",
            start: hourStart.addingTimeInterval(startOffset),
            end: hourStart.addingTimeInterval(endOffset),
            location: nil,
            notes: nil,
            url: nil,
            isAllDay: isAllDay,
            isDeclined: isDeclined,
            calendarTitle: "Work"
        )
    }

    func testHasMeetingFalseWithNoEvents() {
        let hourStart = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertFalse(ActivityLogFeature.hasMeeting(events: [], hourStart: hourStart))
    }

    func testHasMeetingTrueWhenEventFullyInsideHour() {
        let hourStart = Date(timeIntervalSince1970: 1_800_000_000)
        let event = makeActivityEvent(startOffset: 600, endOffset: 1200, from: hourStart)
        XCTAssertTrue(ActivityLogFeature.hasMeeting(events: [event], hourStart: hourStart))
    }

    func testHasMeetingTrueWhenEventOverlapsHourStart() {
        let hourStart = Date(timeIntervalSince1970: 1_800_000_000)
        let event = makeActivityEvent(startOffset: -600, endOffset: 300, from: hourStart)
        XCTAssertTrue(ActivityLogFeature.hasMeeting(events: [event], hourStart: hourStart))
    }

    func testHasMeetingTrueWhenEventOverlapsHourEnd() {
        let hourStart = Date(timeIntervalSince1970: 1_800_000_000)
        let event = makeActivityEvent(startOffset: 3000, endOffset: 4200, from: hourStart) // starts 3000s in, hour is 3600s long
        XCTAssertTrue(ActivityLogFeature.hasMeeting(events: [event], hourStart: hourStart))
    }

    func testHasMeetingFalseWhenEventEndsExactlyAtHourStart() {
        let hourStart = Date(timeIntervalSince1970: 1_800_000_000)
        let event = makeActivityEvent(startOffset: -600, endOffset: 0, from: hourStart)
        XCTAssertFalse(ActivityLogFeature.hasMeeting(events: [event], hourStart: hourStart))
    }

    func testHasMeetingFalseWhenEventStartsExactlyAtHourEnd() {
        let hourStart = Date(timeIntervalSince1970: 1_800_000_000)
        let event = makeActivityEvent(startOffset: 3600, endOffset: 4200, from: hourStart)
        XCTAssertFalse(ActivityLogFeature.hasMeeting(events: [event], hourStart: hourStart))
    }

    func testHasMeetingFalseWhenEventEntirelyBeforeHour() {
        let hourStart = Date(timeIntervalSince1970: 1_800_000_000)
        let event = makeActivityEvent(startOffset: -1200, endOffset: -600, from: hourStart)
        XCTAssertFalse(ActivityLogFeature.hasMeeting(events: [event], hourStart: hourStart))
    }

    func testHasMeetingFalseForAllDayEventEvenThoughItOverlaps() {
        let hourStart = Date(timeIntervalSince1970: 1_800_000_000)
        let event = makeActivityEvent(startOffset: -3600, endOffset: 7200, from: hourStart, isAllDay: true)
        XCTAssertFalse(ActivityLogFeature.hasMeeting(events: [event], hourStart: hourStart))
    }

    func testHasMeetingFalseForDeclinedEventEvenThoughItOverlaps() {
        let hourStart = Date(timeIntervalSince1970: 1_800_000_000)
        let event = makeActivityEvent(startOffset: 600, endOffset: 1200, from: hourStart, isDeclined: true)
        XCTAssertFalse(ActivityLogFeature.hasMeeting(events: [event], hourStart: hourStart))
    }

    func testHasMeetingTrueWhenARealMeetingIsMixedWithAllDayAndDeclined() {
        let hourStart = Date(timeIntervalSince1970: 1_800_000_000)
        let allDay = makeActivityEvent(startOffset: -3600, endOffset: 7200, from: hourStart, isAllDay: true)
        let declined = makeActivityEvent(startOffset: 0, endOffset: 1800, from: hourStart, isDeclined: true)
        let real = makeActivityEvent(startOffset: 600, endOffset: 1200, from: hourStart)
        XCTAssertTrue(ActivityLogFeature.hasMeeting(events: [allDay, declined, real], hourStart: hourStart))
    }

    // MARK: - ActivityLog.weekStats

    private func pacificCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        calendar.firstWeekday = 2 // Monday
        return calendar
    }

    func testWeekStatsSumsActiveAndObservedAcrossHoursPerDay() {
        let calendar = pacificCalendar()
        // Wednesday 2026-08-05; week is Mon 2026-08-03 ... Sun 2026-08-09.
        let reference = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 12))!
        let rows: [ActivityLogKey: ActivityLogRow] = [
            ActivityLogKey(date: "2026-08-03", hour: 9): ActivityLogRow(activeSeconds: 1800, observedSeconds: 3600, hadMeeting: false),
            ActivityLogKey(date: "2026-08-03", hour: 10): ActivityLogRow(activeSeconds: 900, observedSeconds: 1800, hadMeeting: false),
        ]
        let week = ActivityLog.weekStats(from: rows, for: reference, calendar: calendar)

        XCTAssertEqual(week.count, 7)
        let days = week.map { calendar.component(.day, from: $0.date) }
        XCTAssertEqual(days, [3, 4, 5, 6, 7, 8, 9])
        XCTAssertEqual(week[0].activePercent, 0.5) // (1800+900)/(3600+1800)
        for other in week.dropFirst() {
            XCTAssertNil(other.activePercent)
        }
    }

    func testWeekStatsNilWhenNoObservedTimeAnyDay() {
        let calendar = pacificCalendar()
        let reference = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 12))!
        let week = ActivityLog.weekStats(from: [:], for: reference, calendar: calendar)
        XCTAssertEqual(week.count, 7)
        XCTAssertTrue(week.allSatisfy { $0.activePercent == nil })
    }

    func testWeekStatsWorksAcrossKeysFromDifferentMonths() {
        let calendar = pacificCalendar()
        // Wednesday 2026-07-29; week is Mon 2026-07-27 ... Sun 2026-08-02, spanning July/August.
        let reference = calendar.date(from: DateComponents(year: 2026, month: 7, day: 29, hour: 12))!
        let rows: [ActivityLogKey: ActivityLogRow] = [
            ActivityLogKey(date: "2026-07-29", hour: 5): ActivityLogRow(activeSeconds: 300, observedSeconds: 600, hadMeeting: false),
            ActivityLogKey(date: "2026-08-01", hour: 10): ActivityLogRow(activeSeconds: 100, observedSeconds: 100, hadMeeting: false),
        ]
        let week = ActivityLog.weekStats(from: rows, for: reference, calendar: calendar)

        let days = week.map { calendar.component(.day, from: $0.date) }
        XCTAssertEqual(days, [27, 28, 29, 30, 31, 1, 2])
        XCTAssertEqual(week[2].activePercent, 0.5) // July 29
        XCTAssertEqual(week[5].activePercent, 1.0) // Aug 1
        XCTAssertNil(week[0].activePercent)
    }

    // MARK: - ActivityLog.dayStats

    func testDayStatsPerHourWithActivePercentAndHadMeetingPassthrough() {
        let calendar = pacificCalendar()
        let reference = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 12))!
        let rows: [ActivityLogKey: ActivityLogRow] = [
            ActivityLogKey(date: "2026-08-05", hour: 9): ActivityLogRow(activeSeconds: 1800, observedSeconds: 3600, hadMeeting: true),
            ActivityLogKey(date: "2026-08-05", hour: 11): ActivityLogRow(activeSeconds: 300, observedSeconds: 300, hadMeeting: false),
        ]
        let day = ActivityLog.dayStats(from: rows, for: reference, calendar: calendar)

        XCTAssertEqual(day.count, 24)
        XCTAssertEqual(day[9].hour, 9)
        XCTAssertEqual(day[9].activePercent, 0.5)
        XCTAssertEqual(day[9].hadMeeting, true)
        XCTAssertNil(day[10].activePercent, "no row for hour 10 -> nil, not 0%")
        XCTAssertEqual(day[10].hadMeeting, false)
        XCTAssertEqual(day[11].activePercent, 1.0)
    }

    func testDayStatsNilWhenRowHasZeroObservedSeconds() {
        let calendar = pacificCalendar()
        let reference = calendar.date(from: DateComponents(year: 2026, month: 8, day: 5, hour: 12))!
        let rows: [ActivityLogKey: ActivityLogRow] = [
            ActivityLogKey(date: "2026-08-05", hour: 3): ActivityLogRow(activeSeconds: 0, observedSeconds: 0, hadMeeting: true),
        ]
        let day = ActivityLog.dayStats(from: rows, for: reference, calendar: calendar)
        XCTAssertNil(day[3].activePercent, "zero observed seconds must not divide-by-zero into 0%")
        XCTAssertEqual(day[3].hadMeeting, true, "hadMeeting still passes through even with no observed time")
    }
}
