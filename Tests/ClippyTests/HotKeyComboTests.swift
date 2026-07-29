import Carbon.HIToolbox
import XCTest
@testable import Clippy

final class HotKeyComboTests: XCTestCase {
    func testGlyphModifierAndSpace() {
        let combo = HotKeyCombo.parse("⌥Space")
        XCTAssertEqual(combo?.keyCode, 49)
        XCTAssertEqual(combo?.modifiers, UInt32(optionKey))
    }

    func testWordModifiersAndLetter() {
        let combo = HotKeyCombo.parse("cmd shift r")
        XCTAssertEqual(combo?.keyCode, 15)
        XCTAssertEqual(combo?.modifiers, UInt32(cmdKey) | UInt32(shiftKey))
    }

    func testMoreThanOneKeyIsRejected() {
        XCTAssertNil(HotKeyCombo.parse("a b"))
    }

    func testUnknownKeyIsRejected() {
        XCTAssertNil(HotKeyCombo.parse("banana"))
    }
}
