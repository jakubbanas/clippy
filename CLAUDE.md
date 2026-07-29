# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Clippy — a macOS-only menu-bar app that pops up the classic Microsoft Office assistant to remind you of upcoming calendar meetings (a personal, Clippy-themed recreation of the Birdie app). Native Swift + AppKit, no Xcode project — built via Swift Package Manager and a manual bundling script. Personal-use project; Clippy's sprite assets are Microsoft IP and are never redistributed.

## Commands

This environment has no Bash tool available to Claude — all shell commands must be run by the user (prefixed with `!` in the CLI) or delegated to a subagent.

```bash
swift test                          # build + run all unit tests
swift build                         # debug build only, no tests
Support/build-app.sh [debug|release]  # build + assemble dist/Clippy.app (ad-hoc codesigned)
open dist/Clippy.app                # launch after building
```

To run a single test: `swift test --filter ClippyTests.CalendarFeatureTests/testFiresLeadReminderOneMinuteBefore` (or any `TestClass/testMethod` / `TestClass` substring).

There is no linter configured.

Because EventKit permission (TCC) requires a properly identified app bundle, calendar-related behavior (permission prompt, event reads) only works from the built `dist/Clippy.app`, not from the raw `swift build` binary. `tccutil reset Calendar com.jbanas.clippy` re-triggers the permission prompt for testing.

## Architecture

### Extensibility contract (the core design constraint)

The app is built around one rule: **adding a new capability should mean writing one new file and adding one line to a registry** — nothing else in the app should need to change. This is why the code is split the way it is:

- **`Core/Feature.swift`** — the `Feature` protocol (`id`, `name`, `start(context:)`, `stop()`) that every capability implements, plus `FeatureContext` (an `Announcer` + the loaded `AppConfig`) and `Announcer` (a thread-safe closure wrapper that hops announcements to the main thread).
- **`Core/Announcement.swift`** — the `Announcement` value type (animation name, title, body lines, `AnnouncementAction`s, optional timeout) that is the *only* thing a feature can hand to the presentation layer. Actions are `openURL`, `dismiss`, `snooze(TimeInterval)`, or `callback(() -> Void)` for feature-specific behavior that doesn't need new core cases.
- **`Core/Registry.swift`** — `Registry.builtInFeatures()` is the single hardcoded list of active features. This is the one line that changes when a feature is added.
- **`Presenter/Presenter.swift`** — owns the single Clippy window and serializes announcements one at a time (queue, show → await action or timeout → dismiss → next). It knows nothing about *why* an announcement was requested, only how to display it and run its actions.

A feature (see `Features/Calendar/CalendarFeature.swift` for the only current example) is expected to:
1. Own its background work as a stored `Task`, spawned in `start(context:)`, guarded against double-start, cancelled in `stop()`.
2. Read whatever config it needs from `context.config` (add a field to `AppConfig` in `Config.swift` if needed).
3. Push `Announcement`s through `context.announcer.announce(...)` whenever it decides Clippy should appear — the feature owns all "when" and "why" logic; the presenter owns all "how".

`AppDelegate.swift` wires this together: builds the `Presenter`, builds the `Announcer` closure that forwards to it, calls `Registry.builtInFeatures()`, and calls `start(context:)` on each. The tray's "Reload Config" menu item calls `stop()` on every feature then re-runs `start(context:)` with freshly-loaded config — this is how config changes take effect without relaunching the app.

### Calendar feature internals

`Features/Calendar/` reads from EventKit and decides when to remind:
- `EventKitClient.swift` wraps `EKEventStore` — permission request (`requestFullAccessToEvents`) and event queries, always returning plain `EventInfo` structs (never raw `EKEvent`) so nothing outside this file touches EventKit types.
- `CalendarFeature.swift` polls every 15s (not change-notification-driven) and computes due reminders via the pure static function `CalendarFeature.dueReminders(...)` — this separation is what makes the scheduling logic unit-testable without EventKit or timers involved (see `CalendarFeatureTests.swift`). Key behaviors baked into that logic: a lead-time reminder ("in N minutes") is suppressed once the meeting has actually started; a grace window (90s) allows a missed reminder to still fire after sleep/wake or app relaunch; reminders are deduplicated by `eventID:leadSeconds:startTimestamp`, so an edited/moved event's changed start time produces a new key and reminds again.
- `MeetingLinks.swift` extracts a Zoom/Meet/Teams URL from an event's `url`/`location`/`notes` fields via regex. Notes from Google-synced events arrive as HTML with the link inside an `href` attribute — do not strip HTML tags before matching, only decode entities (`&amp;` etc.), or the URL is destroyed along with the tag.

### Presentation layer

`Presenter/` renders Clippy using vendored classic sprite-sheet assets (`Sources/Clippy/Resources/clippy/map.png` + `agent.json`, sourced from the discontinued `pi0/clippyjs` project's pre-rewrite commit). `AgentData.swift` decodes the animation JSON; `SpriteView.swift` is a `CALayer`-based player that steps frames by their authored durations (playback is linear — branching/looping animation data in the source JSON is intentionally ignored, capped at 120 frames per play). `ClippyWindow.swift` is a borderless, non-activating `NSPanel` positioned in the bottom-right corner of the screen, shown only while an announcement is active (there is no persistent overlay window — Tauri/other frameworks' lack of per-pixel click-through was the reason for this "corner popup" approach rather than a full-screen assistant that wanders the display). `BubbleView.swift` renders the retro yellow speech bubble and action buttons.

### App shell

`main.swift` sets `NSApplication.shared.setActivationPolicy(.accessory)` so the app has no Dock icon (also backed by `LSUIElement` in `Support/Info.plist`). `AppDelegate.swift` owns the status-bar item and its menu (Test Clippy, Dump Next Events, Open/Reload Config, Start at Login via `SMAppService`, Quit). `Config.swift` loads/saves `~/Library/Application Support/com.jbanas.clippy/config.json`, writing sensible defaults on first run if the file is missing or partially specified (each `Codable` type has a custom `init(from:)` that fills in defaults per-key rather than failing the whole decode).
