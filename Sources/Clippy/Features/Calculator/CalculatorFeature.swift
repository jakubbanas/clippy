import AppKit

/// Arithmetic in the launcher: type "1+1", see 2, press Enter to copy it.
///
/// Stateless and purely query-driven, so there is no background work to start or
/// stop. Everything worth testing lives in `Calculator`.
final class CalculatorFeature: Feature {
    let id = "calculator"
    let name = "Calculator"

    func start(context: FeatureContext) {}

    func stop() {}

    func searchItems(query: String) -> [Command] {
        guard let result = Calculator.evaluate(query) else { return [] }
        return [
            Command(
                // Constant, never derived from the expression: the id is the
                // frecency key, and one entry per distinct sum would grow that
                // file forever.
                id: "calculator:result",
                title: result,
                subtitle: "Copy to clipboard",
                // The query, not the result: `LauncherRanking` scores every row
                // against `searchText`, and fuzzy-matching "1+1" against "2"
                // would drop this row entirely. Matching the query against
                // itself always scores highest, so the result stays on top.
                searchText: query,
                icon: Command.symbol("equal.square"),
                section: CommandSection.calculator
            ) {
                // Copy only, like the clipboard rows — LauncherWindow has
                // already restored the previous app, so the user's ⌘V lands there.
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(result, forType: .string)
            },
        ]
    }
}
