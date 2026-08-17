---
name: add-feature
description: |
  Scaffold a new Clippy Feature — the extensibility contract that lets a
  capability be added as one new file + one registry line. Use when the user
  says "add a feature", "new feature for X", "add a capability that...".
---

# Add a Clippy Feature

Per `CLAUDE.md`'s extensibility contract: a feature is one new module
implementing `Feature` (see `Sources/Clippy/Core/Feature.swift`) + one line in
`Registry.builtInFeatures()`. Nothing else in the app should need to change.

1. Ask the user for the feature name (used for the id/type name) if not given.
2. Create `Sources/Clippy/Features/<Name>/<Name>Feature.swift`:

```swift
import Foundation

final class <Name>Feature: Feature {
    let id = "<lowercase-name>"
    let name = "<Human-readable name>"

    private var task: Task<Void, Never>?

    func start(context: FeatureContext) {
        guard task == nil else { return }
        // guard context.config.<name>.enabled else { return }  // if config-gated
        task = Task { await run(context) }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func run(_ context: FeatureContext) async {
        // feature logic — push announcements via context.announcer.announce(...)
    }
}
```

3. Add one line to `Sources/Clippy/Core/Registry.swift`'s
   `builtInFeatures()` array: `<Name>Feature()`.
4. If the feature needs its own settings, ask what fields belong on `AppConfig`
   (in `Config.swift`) — don't guess the shape. Add the field with a sensible
   default per that file's existing per-key-default pattern.
5. If the feature contributes a user-triggerable action to the command
   launcher, override `commands()` (see `Feature.swift`) instead of adding a
   separate menu item.
6. Don't write a test stub — add tests once there's real logic to test
   (mention this to the user rather than skipping silently).

Don't touch `AppDelegate.swift`, the presenter, or any other feature's files —
if this scaffold requires touching something beyond the 2-4 files above, stop
and flag it; the contract is broken somewhere.
