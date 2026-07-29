import XCTest
@testable import Clippy

final class QuickCaptureFeatureTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFiresDueAndOverdueButNotFuture() {
        let due = Reminder(text: "due", fireAt: now.addingTimeInterval(-1))
        let overdue = Reminder(text: "overdue", fireAt: now.addingTimeInterval(-99_999))
        let atNow = Reminder(text: "now", fireAt: now)
        let future = Reminder(text: "future", fireAt: now.addingTimeInterval(60))

        let fired = QuickCaptureFeature.dueReminders(
            reminders: [due, overdue, atNow, future], now: now
        )
        XCTAssertEqual(Set(fired.map(\.text)), ["due", "overdue", "now"])
    }
}
