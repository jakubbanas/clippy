# Clippy

> *"It looks like you have a meeting in 1 minute!"*

## The problem

When you are deep in work, you lose track of time. You miss the meeting
because the calendar banner slid away unseen. You forget to drink water. You
look up and two hours are gone.

## The fix

A small animated paperclip jumps into the corner of your screen. It is hard
to ignore, so you don't miss what matters.

- **Meetings:** Clippy appears 1 minute before and again at the start, with a **Join** button.
- **Water and breaks:** a nudge every 45 and 90 minutes, but only while you are at the computer.
- **Focus timer:** say what you are working on. Clippy stays quiet until time is up, then asks if you finished.
- **Welcome back:** after a long break, Clippy tells you how long you were away.

It also has a quick launcher (`⌥Space`) to open apps, do math, and search
your clipboard history, so you don't have to leave the keyboard.

## Run it

You need macOS 14 or later and Swift (Xcode or the Command Line Tools).

```bash
Support/build-app.sh
open dist/Clippy.app
```

Clippy lives in the menu bar. Click it for settings. Allow calendar access
when macOS asks.

## Privacy

Everything stays on your Mac, in
`~/Library/Application Support/com.jbanas.clippy/`. Nothing is sent over the
network. Clipboard history is saved as plain text. You can turn it off in
Settings.

## How it works

Native Swift and AppKit, built with Swift Package Manager. There is no Xcode
project and there are no dependencies.

```
Features ──Announcement──▶ Announcer ──▶ Presenter ──▶ Clippy window
(when + why)                (main thread)   (queue, one at a time)
```

The app has three parts:

1. **Features** (`Sources/Clippy/Features/`). Each feature decides *when* and
   *why* Clippy appears. Most run a small background loop. For example, the
   calendar feature reads EventKit every 15 seconds.
2. **Announcement** (`Core/Announcement.swift`). This is the only thing a
   feature can send: an animation, a title, some text, buttons, and a
   timeout.
3. **Presenter** (`Presenter/`). It shows one announcement at a time in the
   bottom-right corner and runs the button the user clicks. It does not know
   which feature sent it.

Other parts:

- **Registry** (`Core/Registry.swift`): the list of active features.
- **Launcher** (`⌥Space`): features can also add rows to the search window,
  for example apps, a calculator result, or a command.
- **Settings**: config is a JSON file. When you close the Settings window,
  every feature stops and starts again with the new config. You do not need
  to restart the app.

### Add a feature

1. Write one file in `Sources/Clippy/Features/<Name>/` that conforms to the
   `Feature` protocol (`id`, `name`, `start(context:)`, `stop()`).
2. Add one line to `Registry.builtInFeatures()`.

Nothing else changes. See [CLAUDE.md](CLAUDE.md) for more detail.

### Test

```bash
swift test
```

The scheduling logic is in pure functions (for example
`CalendarFeature.dueReminders`), so tests run without EventKit or timers.
Calendar access only works from the built `dist/Clippy.app`, because macOS
gives the permission to an app bundle.

## Credits

Clippy belongs to Microsoft. The animations come from the old
[clippy.js](https://github.com/pi0/clippyjs) project. This is a personal
project. Do not redistribute the Clippy images.
