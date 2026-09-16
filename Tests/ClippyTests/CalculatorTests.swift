import XCTest
@testable import Clippy

final class CalculatorTests: XCTestCase {
    func testAddsTwoIntegers() {
        XCTAssertEqual(Calculator.evaluate("1+1"), "2")
    }

    func testHonorsPrecedence() {
        XCTAssertEqual(Calculator.evaluate("1+2*3"), "7")
    }

    func testHonorsParentheses() {
        XCTAssertEqual(Calculator.evaluate("(1+2)*3"), "9")
    }

    func testSubtractsLeftToRight() {
        XCTAssertEqual(Calculator.evaluate("10-3-2"), "5")
    }

    func testIgnoresSpaces() {
        XCTAssertEqual(Calculator.evaluate(" 2 * 3 "), "6")
    }

    func testAppliesUnaryMinus() {
        XCTAssertEqual(Calculator.evaluate("3*-2"), "-6")
    }

    func testFormatsFractionWithoutTrailingZeros() {
        XCTAssertEqual(Calculator.evaluate("1/4"), "0.25")
    }

    func testFormatsWholeDivisionWithoutDecimalPoint() {
        XCTAssertEqual(Calculator.evaluate("10/2"), "5")
    }

    func testRejectsPlainText() {
        XCTAssertNil(Calculator.evaluate("slack"))
    }

    func testRejectsNumberWithoutOperator() {
        XCTAssertNil(Calculator.evaluate("1"))
        XCTAssertNil(Calculator.evaluate("1.2"))
        XCTAssertNil(Calculator.evaluate("-5"))
    }

    func testRejectsEmptyQuery() {
        XCTAssertNil(Calculator.evaluate(""))
    }

    func testRejectsIncompleteExpression() {
        XCTAssertNil(Calculator.evaluate("1+"))
        XCTAssertNil(Calculator.evaluate("(1+2"))
        XCTAssertNil(Calculator.evaluate("1+2)"))
    }

    func testRejectsMalformedNumber() {
        XCTAssertNil(Calculator.evaluate("1.2.3+1"))
    }

    /// Division by zero is infinite, not a result worth showing.
    func testRejectsDivisionByZero() {
        XCTAssertNil(Calculator.evaluate("1/0"))
    }

    /// The length cap is what bounds parser recursion on pasted junk.
    func testRejectsOverlongInput() {
        XCTAssertNil(Calculator.evaluate(String(repeating: "(", count: 200) + "1+1"))
    }

    // MARK: - Launcher row

    func testFeatureOffersOneRowForAnExpression() {
        let rows = CalculatorFeature().searchItems(query: "1+1")
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.title, "2")
    }

    func testFeatureOffersNoRowForPlainText() {
        XCTAssertTrue(CalculatorFeature().searchItems(query: "slack").isEmpty)
    }

    /// The row's `searchText` is the query, so `LauncherRanking` scores it
    /// against what was typed rather than against the result — scoring "1+1"
    /// against the title "2" would drop the row entirely.
    func testResultOutranksApps() {
        let app = Command(
            id: "/Applications/One Password.app",
            title: "One Password",
            section: CommandSection.applications
        ) {}
        let sections = LauncherRanking.sections(
            for: "1+1",
            commands: CalculatorFeature().searchItems(query: "1+1") + [app],
            frecency: [:],
            now: Date()
        )
        XCTAssertEqual(sections.first?.title, CommandSection.calculator)
    }
}
