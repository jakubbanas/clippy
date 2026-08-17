import XCTest
@testable import Clippy

final class FrecencyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_755_432_000)

    private func ago(_ seconds: Double) -> Double {
        now.timeIntervalSince1970 - seconds
    }

    func testRecordCreatesEntry() {
        let store = Frecency.record([:], id: "app:/Applications/Slack.app", now: now)
        XCTAssertEqual(store["app:/Applications/Slack.app"]?.uses, 1)
        XCTAssertEqual(store["app:/Applications/Slack.app"]?.lastUsed, now.timeIntervalSince1970)
    }

    func testRecordIncrementsAndUpdatesTimestamp() {
        var store = ["a": FrecencyEntry(uses: 3, lastUsed: ago(9_999))]
        store = Frecency.record(store, id: "a", now: now)
        XCTAssertEqual(store["a"]?.uses, 4)
        XCTAssertEqual(store["a"]?.lastUsed, now.timeIntervalSince1970)
    }

    func testRecordLeavesOtherEntriesAlone() {
        let store = Frecency.record(["b": FrecencyEntry(uses: 2, lastUsed: ago(60))], id: "a", now: now)
        XCTAssertEqual(store["b"]?.uses, 2)
        XCTAssertEqual(store.count, 2)
    }

    func testUnknownIdGetsNoBoost() {
        XCTAssertEqual(Frecency.boost(nil, now: now), 0)
    }

    func testMoreRecentWinsAtEqualUses() {
        let recent = FrecencyEntry(uses: 2, lastUsed: ago(120))
        let old = FrecencyEntry(uses: 2, lastUsed: ago(60 * 60 * 24 * 10))
        XCTAssertGreaterThan(Frecency.boost(recent, now: now), Frecency.boost(old, now: now))
    }

    func testMoreUsedWinsAtEqualRecency() {
        let heavy = FrecencyEntry(uses: 9, lastUsed: ago(120))
        let light = FrecencyEntry(uses: 1, lastUsed: ago(120))
        XCTAssertGreaterThan(Frecency.boost(heavy, now: now), Frecency.boost(light, now: now))
    }

    /// Decay must actually decay: heavy use a year ago loses to light use today.
    func testStaleHeavyUseLosesToFreshLightUse() {
        let stale = FrecencyEntry(uses: 20, lastUsed: ago(60 * 60 * 24 * 365))
        let fresh = FrecencyEntry(uses: 2, lastUsed: ago(60))
        XCTAssertGreaterThan(Frecency.boost(fresh, now: now), Frecency.boost(stale, now: now))
    }

    func testUseCountIsCappedSoOneAppCannotDominateForever() {
        let ten = FrecencyEntry(uses: 10, lastUsed: ago(60))
        let thousand = FrecencyEntry(uses: 1000, lastUsed: ago(60))
        XCTAssertEqual(Frecency.boost(ten, now: now), Frecency.boost(thousand, now: now))
    }

    func testSaveThenLoadRoundTrips() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }

        let store = ["a": FrecencyEntry(uses: 4, lastUsed: 1_700_000_000)]
        Frecency.save(store, to: url)
        XCTAssertEqual(Frecency.load(from: url), store)
    }

    func testLoadOfMissingFileIsEmpty() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        XCTAssertEqual(Frecency.load(from: url), [:])
    }

    func testLoadOfGarbageIsEmpty() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + ".json")
        defer { try? FileManager.default.removeItem(at: url) }
        try "not json at all".write(to: url, atomically: true, encoding: .utf8)
        XCTAssertEqual(Frecency.load(from: url), [:])
    }
}
