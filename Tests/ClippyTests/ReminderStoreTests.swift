import XCTest
@testable import Clippy

final class ReminderStoreTests: XCTestCase {
    func testRoundTripPersistsAcrossInstances() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("clippy-store-test-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ReminderStore(url: url)
        XCTAssertTrue(store.all().isEmpty)

        let reminder = Reminder(text: "call dentist", fireAt: Date(timeIntervalSinceReferenceDate: 1000))
        store.add(reminder)

        // A fresh instance must read what the first wrote.
        XCTAssertEqual(ReminderStore(url: url).all(), [reminder])

        store.remove(id: reminder.id)
        XCTAssertTrue(ReminderStore(url: url).all().isEmpty)
    }
}
