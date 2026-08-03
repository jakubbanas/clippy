# TODO — Clippy ADHD Features

Ideas to help you:
- Remember things (before they vanish)
- Notice time passing
- Build and keep routines

Adding a feature: one new folder in `Features/` + one line in `Registry.swift`. That's it.

## Done

- [x] **Quick capture** — hotkey → type something → Clippy reminds you later. Fixes the "thought vanishes" problem.
- [x] **Nudges** — water reminders, break reminders. Turn each on/off. Quiet when you're away.
- [x] **Focus sessions** — say what you're doing, set a timer, Clippy stays silent. Says "more rounds?" at the end.
- [x] **Command launcher** — one hotkey opens a menu with all commands.
- [x] **Break tracker** — "you were gone 12 min" when you come back (≥15 min away).

## Remember things (before they slip away)

- [ ] **Action items from meetings** — when meeting ends, Clippy asks "what did you commit to?" Catch it before it's gone.
- [ ] **Stale pull requests & Slack** — nag you about open PRs or flagged messages you haven't touched.

## Notice time passing

- [ ] **Check in on long tasks** — after 90 min on one thing, ask "is this still the right task?"
- [ ] **Meeting prep** — before a meeting, Clippy shows the doc/link you'll need.

## Build routines

- [ ] **Daily bookends** — morning: "what are your top 3?" Evening: "what's left for tomorrow?"

## Clippy reacts to your work (feels like company)

- [ ] **Respond to commits** — Clippy watches your repo. You commit → Clippy gets happy. No commits for a while → Clippy gets sleepy. (Check `git log` every 15s.)
- [ ] **Watch the build** — while you're compiling, Clippy looks "waiting" instead of asleep. Stops the doomscroll.
- [ ] **Presence dial** — one setting: silent company on one end, active check-ins on the other.

## Keep the tone kind (not shame-inducing)

- [ ] **No "Uh oh"** — all messages use flat, calm tone. State what happened + what to do. No blame.
- [ ] **No punishment for missed days** — use "building momentum" language, not "you broke your streak".

## Turn brain-dump into one action

- [ ] **Brain-dump to one task** — dump a messy list → Clippy shows you exactly ONE thing to do next (rest hidden). Breaks the "too many options" freeze.

## Not doing these (conflicts with the design)

- **Camera alerts** (posture, fatigue, screen distance) — needs always-on camera access + AI. Privacy cost too high for a personal app.
- **Persistent Clippy on screen** — current design is corner-popup-only. Making Clippy always visible would be a big redesign.

## Future improvements (could-do, not must-do)

**Nudges/Focus**
- [ ] Change the 5-minute idle wait time (currently hardcoded).
- [ ] Add a "focus music" loop for focus sessions.
- [ ] Let multiple windows share the same input box instead of duplicating code.

**Quick Capture**
- [ ] See and cancel pending reminders (currently fire-and-forget).
- [ ] Snooze persists after restart (currently lost).
- [ ] Repeat reminders instead of one-shot (recurring reminders belong in daily routines instead).
