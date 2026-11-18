import XCTest
@testable import Clippy

final class ClipboardStoreTests: XCTestCase {
    private func clip(_ text: String, at time: Double = 1_755_432_000, app: String? = "Slack") -> Clip {
        Clip(copiedAt: time, app: app, text: text)
    }

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jsonl")
    }

    // MARK: - serialize / parse

    func testRoundTripsAwkwardText() {
        let clips = [
            clip("line one\nline two\ttabbed"),
            clip("he said \"hello\", then left", at: 1_755_431_000),
            clip("emoji 📎 and unicode ąęś", at: 1_755_430_000, app: nil),
        ]
        XCTAssertEqual(ClipboardStore.parse(ClipboardStore.serialize(clips)), clips)
    }

    func testSerializeWritesOneLinePerClip() {
        let text = ClipboardStore.serialize([clip("a\nb"), clip("c", at: 1)])
        XCTAssertEqual(text.split(separator: "\n").count, 2)
    }

    func testParseSkipsMalformedLinesAndKeepsTheRest() {
        let good = ClipboardStore.serialize([clip("kept")]).trimmingCharacters(in: .newlines)
        let jsonl = "not json\n\(good)\n{\"partial\":true}\n"
        XCTAssertEqual(ClipboardStore.parse(jsonl).map(\.text), ["kept"])
    }

    func testParseOfEmptyStringIsEmpty() {
        XCTAssertEqual(ClipboardStore.parse(""), [])
    }

    // MARK: - record

    func testRecordPrependsNewestFirst() {
        let clips = ClipboardStore.record([clip("older", at: 1)], clip: clip("newer", at: 2), maxItems: 10)
        XCTAssertEqual(clips.map(\.text), ["newer", "older"])
    }

    func testRecordMovesAnExactDuplicateToTopWithoutGrowing() {
        let existing = [clip("b", at: 2), clip("a", at: 1)]
        let clips = ClipboardStore.record(existing, clip: clip("a", at: 3), maxItems: 10)
        XCTAssertEqual(clips.map(\.text), ["a", "b"])
        XCTAssertEqual(clips.count, 2)
        XCTAssertEqual(clips[0].copiedAt, 3, "the moved clip carries the new timestamp")
    }

    func testRecordTrimsOldestBeyondMaxItems() {
        var clips: [Clip] = []
        for index in 1...5 {
            clips = ClipboardStore.record(clips, clip: clip("clip \(index)", at: Double(index)), maxItems: 3)
        }
        XCTAssertEqual(clips.map(\.text), ["clip 5", "clip 4", "clip 3"])
    }

    // MARK: - pins

    func testPinPrependsNewestFirst() {
        let pins = ClipboardStore.pin([clip("old", at: 1)], clip: clip("new", at: 2))
        XCTAssertEqual(pins.map(\.text), ["new", "old"])
    }

    func testPinDeduplicatesByTextAndMovesToTop() {
        let pins = ClipboardStore.pin([clip("b", at: 2), clip("a", at: 1)], clip: clip("a", at: 3))
        XCTAssertEqual(pins.map(\.text), ["a", "b"])
    }

    func testUnpinRemovesOnlyThatText() {
        let pins = ClipboardStore.unpin([clip("a"), clip("b", at: 1)], text: "a")
        XCTAssertEqual(pins.map(\.text), ["b"])
    }

    func testUnpinnedHistoryHidesPinnedTexts() {
        let history = [clip("c", at: 3), clip("b", at: 2), clip("a", at: 1)]
        let visible = ClipboardStore.unpinnedHistory(history, pins: [clip("b", at: 9)])
        XCTAssertEqual(visible.map(\.text), ["c", "a"])
    }

    func testPinnedURLSitsNextToHistory() {
        XCTAssertEqual(ClipboardStore.pinnedURL.lastPathComponent, "pinned.jsonl")
        XCTAssertEqual(
            ClipboardStore.pinnedURL.deletingLastPathComponent(), ClipboardStore.url.deletingLastPathComponent()
        )
    }

    // MARK: - disk

    func testSaveThenLoadRoundTrips() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let clips = [clip("one"), clip("two", at: 1)]
        ClipboardStore.save(clips, to: url)
        XCTAssertEqual(ClipboardStore.load(from: url), clips)
    }

    func testLoadOfMissingFileIsEmpty() {
        XCTAssertEqual(ClipboardStore.load(from: tempURL()), [])
    }

    /// The one security mitigation that code has to enforce: `replaceItemAt`
    /// must not leave this file world-readable.
    func testSavedFileIsOwnerReadWriteOnly() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        ClipboardStore.save([clip("secret")], to: url)
        let mode = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(mode?.int16Value, 0o600)
    }

    /// Overwriting an existing file goes down the `replaceItemAt` path, which is
    /// where the mode is easiest to lose.
    func testModeSurvivesAnOverwrite() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        ClipboardStore.save([clip("first")], to: url)
        ClipboardStore.save([clip("second", at: 2)], to: url)
        let mode = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(mode?.int16Value, 0o600)
        XCTAssertEqual(ClipboardStore.load(from: url).map(\.text), ["second"])
    }

    // MARK: - ClipboardFeature pure helpers

    func testSkipsConcealedPasteboard() {
        XCTAssertTrue(ClipboardFeature.shouldSkip(
            text: "hunter2", types: ["public.utf8-plain-text", "org.nspasteboard.ConcealedType"],
            maxBytes: 100_000
        ))
    }

    func testSkipsTransientPasteboard() {
        XCTAssertTrue(ClipboardFeature.shouldSkip(
            text: "temp", types: ["de.petermaurer.TransientPasteboardType"], maxBytes: 100_000
        ))
    }

    func testSkipsWhitespaceOnly() {
        XCTAssertTrue(ClipboardFeature.shouldSkip(text: "   \n\t ", types: [], maxBytes: 100_000))
        XCTAssertTrue(ClipboardFeature.shouldSkip(text: "", types: [], maxBytes: 100_000))
    }

    func testSkipsOversizedText() {
        let big = String(repeating: "x", count: 200_000)
        XCTAssertTrue(ClipboardFeature.shouldSkip(text: big, types: [], maxBytes: 100_000))
    }

    func testKeepsOrdinaryText() {
        XCTAssertFalse(ClipboardFeature.shouldSkip(
            text: "https://example.com", types: ["public.utf8-plain-text"], maxBytes: 100_000
        ))
    }

    func testRowTitleCollapsesWhitespaceAndTruncates() {
        XCTAssertEqual(ClipboardFeature.rowTitle(for: "  hello\n  world  "), "hello world")
        let long = String(repeating: "ab", count: 100)
        let title = ClipboardFeature.rowTitle(for: long, maxLength: 10)
        XCTAssertEqual(title.count, 11, "10 characters plus the ellipsis")
        XCTAssertTrue(title.hasSuffix("…"))
    }

    func testRowTitleOfShortTextIsUnchanged() {
        XCTAssertEqual(ClipboardFeature.rowTitle(for: "short"), "short")
    }
}
