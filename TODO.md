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

## Body-doubling / mirroring (from HCI "12 Dimensions" research)

- [ ] **Git-aware companion states** — poll local repo(s); commit → Clippy reacts (happy/fed),
  long dry spell → drifts to idle/sleepy animation. Behavioral mirror, zero manual input.
  Fits: new `Features/GitPulse/` polling `git log`, like calendar's 15s poll.
- [ ] **Build/test watcher** — long `swift build`/`swift test` running → Clippy shifts to
  "waiting/watching" anim so compile time isn't doomscroll time. Needs a shell-hook or
  process watch; smaller scope than git-aware.
- [ ] **Ambient ↔ accountability slider** — one config knob: silent-presence at one end,
  active goal check-ins at the other. Reframes existing Nudges/Focus intensity, not a new
  feature file. (Ambient end needs persistent-Clippy — see conflict note below.)

## Anti-shame UX (cross-cutting, not a feature file)

- [ ] **Matter-of-fact failure tone** — audit all announcement copy. No "Uh oh" / "There's a
  problem". State cause + fix, flat tone. RSD-aware. Touches every feature's strings + a
  house-style note in CLAUDE.md.
- [ ] **Gentle streak language** — any future streak/goal feature uses "building momentum",
  never punishment for a missed day.

## One-task triage (time-blindness / choice-tax)

- [ ] **Brain-dump → one action** — capture a messy list, Clippy surfaces exactly ONE next
  action, rest hidden. Kills task-initiation freeze. Extends Quick Capture; needs the
  list-store the quick-capture follow-ups already want.

## Out of scope for current architecture (research ideas that fight the design)

- Camera posture / fatigue / screen-distance alerts (Baymin-style): needs AVFoundation
  camera access, always-on CV, TCC camera prompt, privacy cost. Big dep for a personal app.
- Persistent on-screen "working" avatar (FocusCat/Ducky ambient double): current design is a
  corner popup only shown during an announcement — no persistent overlay (per CLAUDE.md,
  chosen over full-screen wander). Ambient mode = revisit that decision, already deferred
  under Focus below.

## Nudge / focus follow-ups (deferred)

- [ ] Configurable idle threshold (hardcoded 5 min in `NudgesFeature`).
- [ ] Focus: audio "focus jam" loop; persistent ambient Clippy; extract shared input-panel
  from `CaptureWindow` / `FocusStartWindow`.

## Quick-capture follow-ups (deferred from v1)

- [ ] List / edit / cancel pending reminders (v1 is fire-and-forget — can't see or cancel one).
- [ ] Durable snooze — snooze currently lives in the Presenter's memory, lost on restart
  (same tradeoff the calendar feature accepts).
- [ ] Recurrence — one-shot only today; recurring reminders belong to the routines feature above.
