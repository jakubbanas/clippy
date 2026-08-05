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
}
