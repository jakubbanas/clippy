import XCTest
@testable import Clippy

final class PriorityStoreTests: XCTestCase {
    private func priority(_ text: String, id: String = "id", done: Bool = false) -> Priority {
        Priority(id: id, text: text, done: done)
    }

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jsonl")
    }

    // MARK: - add

    func testAddAppendsToTheEnd() {
        let list = PriorityStore.add([priority("first", id: "a")], text: "second", id: "b")
        XCTAssertEqual(list.map(\.text), ["first", "second"])
        XCTAssertFalse(list[1].done)
    }

    func testAddTrimsSurroundingWhitespace() {
        XCTAssertEqual(PriorityStore.add([], text: "  ship it \n", id: "a").map(\.text), ["ship it"])
    }

    func testAddOfBlankTextChangesNothing() {
        let existing = [priority("kept", id: "a")]
        XCTAssertEqual(PriorityStore.add(existing, text: "   \n", id: "b"), existing)
    }

    // MARK: - toggle

    func testToggleFlipsOnlyTheMatchingItem() {
        let list = PriorityStore.toggle([priority("a", id: "a"), priority("b", id: "b")], id: "b")
        XCTAssertEqual(list.map(\.done), [false, true])
    }

    func testToggleTwiceReturnsToNotDone() {
        var list = [priority("a", id: "a")]
        list = PriorityStore.toggle(list, id: "a")
        list = PriorityStore.toggle(list, id: "a")
        XCTAssertFalse(list[0].done)
    }

    func testToggleOfUnknownIDChangesNothing() {
        let existing = [priority("a", id: "a")]
        XCTAssertEqual(PriorityStore.toggle(existing, id: "missing"), existing)
    }

    // MARK: - remove

    func testRemoveDropsOnlyTheMatchingItem() {
        let list = PriorityStore.remove([priority("a", id: "a"), priority("b", id: "b")], id: "a")
        XCTAssertEqual(list.map(\.text), ["b"])
    }

    func testRemoveOfUnknownIDChangesNothing() {
        let existing = [priority("a", id: "a")]
        XCTAssertEqual(PriorityStore.remove(existing, id: "missing"), existing)
    }

    // MARK: - serialize / parse

    func testRoundTripsAwkwardText() {
        let list = [
            priority("line one\nline two\ttabbed", id: "a"),
            priority("he said \"hello\", then left", id: "b", done: true),
            priority("emoji 📎 and unicode ąęś", id: "c"),
        ]
        XCTAssertEqual(PriorityStore.parse(PriorityStore.serialize(list)), list)
    }

    func testSerializeWritesOneLinePerPriority() {
        let text = PriorityStore.serialize([priority("a\nb", id: "a"), priority("c", id: "b")])
        XCTAssertEqual(text.split(separator: "\n").count, 2)
    }

    func testParseSkipsMalformedLinesAndKeepsTheRest() {
        let good = PriorityStore.serialize([priority("kept", id: "a")]).trimmingCharacters(in: .newlines)
        XCTAssertEqual(PriorityStore.parse("not json\n\(good)\n{\"partial\":true}\n").map(\.text), ["kept"])
    }

    func testParseOfEmptyStringIsEmpty() {
        XCTAssertEqual(PriorityStore.parse(""), [])
    }

    // MARK: - disk

    func testSaveThenLoadRoundTripsInOrder() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        let list = [priority("one", id: "a"), priority("two", id: "b", done: true)]
        PriorityStore.save(list, to: url)
        XCTAssertEqual(PriorityStore.load(from: url), list)
    }

    func testSaveOverwritesRatherThanAppends() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }
        PriorityStore.save([priority("first", id: "a")], to: url)
        PriorityStore.save([priority("second", id: "b")], to: url)
        XCTAssertEqual(PriorityStore.load(from: url).map(\.text), ["second"])
    }

    func testLoadOfMissingFileIsEmpty() {
        XCTAssertEqual(PriorityStore.load(from: tempURL()), [])
    }
}
