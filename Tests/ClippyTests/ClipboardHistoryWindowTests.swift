import XCTest
@testable import Clippy

final class ClipboardHistoryWindowTests: XCTestCase {
    private func clip(_ text: String) -> Clip { Clip(copiedAt: 0, app: nil, text: text) }

    /// Pinning h1 at row 2 of [p0, h0, h1, h2] moves it to the top; the cursor
    /// must follow it, not stay on row 2 (now h0) where a second ⌘P pins h0.
    func testCursorFollowsTheToggledClip() {
        let rows = [clip("h1"), clip("p0"), clip("h0"), clip("h2")]
        XCTAssertEqual(ClipboardHistoryWindow.row(of: "h1", in: rows, fallback: 2), 0)
    }

    /// An unpinned clip whose history copy was already trimmed is gone; keep
    /// the cursor where it was.
    func testCursorFallsBackWhenTheClipIsGone() {
        let rows = [clip("a"), clip("b")]
        XCTAssertEqual(ClipboardHistoryWindow.row(of: "gone", in: rows, fallback: 1), 1)
    }
}
