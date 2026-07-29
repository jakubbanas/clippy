# TODO — Clippy ADHD productivity features

Feature ideas for helping externalize memory, fight time blindness, and hold routines.
Each is one new file in `Features/` + one line in `Registry.swift` (the extensibility contract).

## Done

- [x] **Quick capture** — global hotkey → tiny input box → reminder pops at a chosen time.
  Kills the #1 ADHD failure: thought vanishes before you act. (`Features/QuickCapture/`)

## Externalize memory (forgetting things)

- [ ] **Meeting action-item catcher** — meeting ends → Clippy pops "what did you commit to?"
  Closes the loop before you forget.
- [ ] **Resurface stale loops** — open PR waiting on you / unread flagged Slack. Clippy nags.
  (GitHub + Slack MCP already available.)

## Time blindness

- [ ] **Heads-down check-in** — "been 90min on one thing, still the right task?" Periodic re-orient.
- [ ] **Focus timer** — start a focus block, Clippy guards it, pops at the end.
- [ ] **Prep-doc surfacing** — extend calendar reminder: "next meeting in 5, here's the doc/link."

## Routines / rituals

- [ ] **Meds + water + break nudges** — recurring health reminders. Meds reminder = big ADHD win,
  trivial build (fixed-time recurrence on top of the quick-capture store).
- [ ] **Daily bookend** — morning "top 3 today?", evening "what's unfinished, carry to tomorrow?"

## Quick-capture follow-ups (deferred from v1)

- [ ] List / edit / cancel pending reminders (v1 is fire-and-forget — can't see or cancel one).
- [ ] Durable snooze — snooze currently lives in the Presenter's memory, lost on restart
  (same tradeoff the calendar feature accepts).
- [ ] Recurrence — one-shot only today; recurring reminders belong to the routines feature above.
