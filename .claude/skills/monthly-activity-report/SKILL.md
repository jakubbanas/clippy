---
name: monthly-activity-report
description: |
  Generate the monthly activity report from Clippy's ActivityLogFeature CSVs.
  Use when the user says "monthly report", "activity report", "how was last
  month", "analyze my activity data", or asks what the activity log shows for
  a given month.
---

# Monthly Activity Report

`report.py` does all the arithmetic. You interpret its output. Never
recompute a number yourself — if a figure is missing, add it to the script.

## Steps

1. Run the script (default = previous complete month):
   `.claude/skills/monthly-activity-report/report.py [YYYY-MM|current]`
2. If it exits with "No data" or "No workdays", stop and report that —
   logging was off or the machine was idle. Check that `config.json` has
   `"activityLog": {"enabled": true}`; the source default is `false`, so a
   rebuilt app stops logging silently.
3. Write the report using the shape below.

## Report shape

1. **Lead with the actionable finding**, not the headline percentage. Usually
   the peak-hours window from the HOUR OF DAY section. One line.
2. **One line defining "active"** before any percentage appears.
3. **The numbers** — workdays, observed/active per day, active%, peak/weak
   hours, weekday table, focus quality. Tables over prose.
4. **The coverage gap** — the UNOBSERVED figure, stated as a limit.
5. **Two or three actions** the data actually supports.

## Interpretation rules

**Define the metric before quoting it.** `active` = keyboard or mouse input
within `idleThresholdSeconds` (default 30s) of a 15s poll. Reading, thinking,
reviewing a PR, and watching a call all register as idle. So active% is a
floor on real work, never a measure of it. Say this before the first
percentage, every time.

**`observed` is app uptime, not work time.** It accrues only while the app
runs and the machine is awake. Every percentage is conditional on that.

**Never frame month-over-month as progress.** Docking differently or leaving
the lid open changes `observed` with identical behavior, so the noise floor is
bigger than any real effect. Do not propose or run a before/after comparison
on active-h/day. Report each month on its own.

**Only workdays go in per-day means.** The script already filters to
observed >= 1h. If you slice the data another way, filter the same way — off
days at 0.1h observed drag a weekday average down and invent a pattern that
isn't there.

**Meeting hours are overcounted for multi-day events.** `hasMeeting` excludes
all-day events but not multi-day *timed* ones, so a PTO block logs as 19-22
meeting hours a day. A day with near-zero active time and many meeting hours
is time off, not a day of meetings.

**No external baselines.** Do not say "studies show developers code N hours a
day." Those figures measure self-report, IDE telemetry, or commits on another
population. Input-event-seconds per day is not a benchmarked metric. If asked
whether a number is normal, say no comparable baseline exists, then answer
from the data that does discriminate: near-dead hours and focus blocks.

**The unobserved window is a limit, not an absence.** `0 near-dead hours` is a
claim about observed time only. State the unobserved hours plainly: that gap
is exactly where a problem would hide.

**Small n stays small n.** A weekday row with n=2 or n=3 is a hint. Say so.

## Common mistakes

| Mistake | Why it's wrong |
|---|---|
| "You were 58% productive" | It measures input events, not productivity. |
| Comparing this month to last | `observed` isn't stable enough to support it. |
| Averaging h/day over calendar days | Weekends and PTO are in there at ~0. |
| "19 meeting hours on Aug 7" | Multi-day timed event artifact. That was PTO. |
| "Above the industry average" | No such average exists for this metric. |
| Recomputing a total by hand | Edit `report.py` instead. |
