import Foundation

/// Arithmetic for the launcher's calculator row.
///
/// Hand-written recursive descent rather than `NSExpression`, which raises an
/// ObjC exception on malformed input — uncatchable from Swift, and this runs on
/// every keystroke against half-typed text.
enum Calculator {
    /// Longest input worth parsing. Anything longer is prose, not a sum — and
    /// this also caps how deeply the parser can recurse on pasted junk.
    private static let maxLength = 100
    private static let allowed = Set("0123456789.+-*/() ")

    /// The formatted result, or nil when the input is not an arithmetic
    /// expression — which is most keystrokes, so nil is the normal case.
    static func evaluate(_ input: String) -> String? {
        let text = input.trimmingCharacters(in: .whitespaces)
        guard text.count <= maxLength,
              text.allSatisfy(allowed.contains),
              hasBinaryOperator(text)
        else { return nil }

        var parser = Parser(characters: Array(text))
        guard let value = parser.expression(), parser.atEnd(), value.isFinite else { return nil }
        return format(value)
    }

    /// A lone number is not a calculation, so a bare "1" — or a version string
    /// like "1.2" — produces no row. A leading minus does not count: "-5" is
    /// still just a number.
    private static func hasBinaryOperator(_ text: String) -> Bool {
        text.dropFirst().contains { "+-*/".contains($0) }
    }

    /// Whole results print without a decimal point ("1+1" is 2, not 2.0);
    /// everything else gets at most 10 fraction digits, trailing zeros dropped.
    static func format(_ value: Double) -> String {
        // The magnitude guard is what keeps the Int64 conversion from trapping.
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        var text = String(format: "%.10f", value)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        return text
    }

    // MARK: - Recursive descent

    /// expression = term (("+" | "-") term)*
    /// term       = factor (("*" | "/") factor)*
    /// factor     = "-" factor | "(" expression ")" | number
    private struct Parser {
        let characters: [Character]
        var index = 0

        mutating func expression() -> Double? {
            guard var value = term() else { return nil }
            while let operation = peek(in: "+-") {
                index += 1
                guard let right = term() else { return nil }
                value = operation == "+" ? value + right : value - right
            }
            return value
        }

        mutating func term() -> Double? {
            guard var value = factor() else { return nil }
            while let operation = peek(in: "*/") {
                index += 1
                guard let right = factor() else { return nil }
                value = operation == "*" ? value * right : value / right
            }
            return value
        }

        mutating func factor() -> Double? {
            if peek(in: "-") != nil {
                index += 1
                guard let value = factor() else { return nil }
                return -value
            }
            if peek(in: "(") != nil {
                index += 1
                guard let value = expression(), peek(in: ")") != nil else { return nil }
                index += 1
                return value
            }
            return number()
        }

        mutating func number() -> Double? {
            skipSpaces()
            let start = index
            while index < characters.count,
                  characters[index].isNumber || characters[index] == "." {
                index += 1
            }
            guard start != index else { return nil }
            // nil on "." or "1.2.3", which is how malformed numbers are rejected.
            return Double(String(characters[start..<index]))
        }

        /// The next non-space character, when it is one of `set`. Not consumed.
        mutating func peek(in set: String) -> Character? {
            skipSpaces()
            guard index < characters.count, set.contains(characters[index]) else { return nil }
            return characters[index]
        }

        mutating func atEnd() -> Bool {
            skipSpaces()
            return index == characters.count
        }

        private mutating func skipSpaces() {
            while index < characters.count, characters[index] == " " { index += 1 }
        }
    }
}
