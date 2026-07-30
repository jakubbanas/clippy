# TODO — Clippy ADHD productivity features

Feature ideas for helping externalize memory, fight time blindness, and hold routines.
Each is one new file in `Features/` + one line in `Registry.swift` (the extensibility contract).

## Done

- [x] **Quick capture** — launcher menu → tiny input box → reminder pops at a chosen time.
  Kills the #1 ADHD failure: thought vanishes before you act. (`Features/QuickCapture/`)
- [x] **Water + break nudges** — recurring reminders, per-nudge on/off in config, suppressed
  while you're idle (no nagging when away/asleep). (`Features/Nudges/`)
- [x] **Focus sessions** (body-doubling / focus timer) — declare goal + duration, silent block,
  check-out at the end with "Another round". (`Features/Focus/`)
- [x] **Command launcher** — one hotkey → menu of every feature's commands (replaced per-feature
  hotkeys). (`Core/CommandLauncher.swift`)
- [x] **Break tracker** — "Welcome back, away for N min" on return from a break ≥15 min. Shares
  `Core/UserActivity` (idle detection) with nudges. (`Features/BreakTracker/`)

## Externalize memory (forgetting things)

- [ ] **Meeting action-item catcher** — meeting ends → Clippy pops "what did you commit to?"
  Closes the loop before you forget.
- [ ] **Resurface stale loops** — open PR waiting on you / unread flagged Slack. Clippy nags.
  (GitHub + Slack MCP already available.)

## Time blindness

- [ ] **Heads-down check-in** — "been 90min on one thing, still the right task?" Periodic re-orient.
- [ ] **Prep-doc surfacing** — extend calendar reminder: "next meeting in 5, here's the doc/link."

## Routines / rituals

- [ ] **Daily bookend** — morning "top 3 today?", evening "what's unfinished, carry to tomorrow?"

## Nudge / focus follow-ups (deferred)

- [ ] Configurable idle threshold (hardcoded 5 min in `NudgesFeature`).
- [ ] Focus: audio "focus jam" loop; persistent ambient Clippy; extract shared input-panel
  from `CaptureWindow` / `FocusStartWindow`.

## Quick-capture follow-ups (deferred from v1)

- [ ] List / edit / cancel pending reminders (v1 is fire-and-forget — can't see or cancel one).
- [ ] Durable snooze — snooze currently lives in the Presenter's memory, lost on restart
  (same tradeoff the calendar feature accepts).
- [ ] Recurrence — one-shot only today; recurring reminders belong to the routines feature above.
