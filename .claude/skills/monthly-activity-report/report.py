#!/usr/bin/env python3
"""Computes every number in the monthly activity report.

Reads the ActivityLogFeature CSVs (see Sources/Clippy/Features/ActivityLog/)
and prints a fixed block for the agent to interpret. All arithmetic lives
here so the report is deterministic.

Usage: report.py [YYYY-MM | current]   (default: previous complete month)
"""
import csv
import datetime
import glob
import os
import statistics as st
import sys
from collections import defaultdict

DATA_DIR = os.path.expanduser("~/Library/Application Support/com.jbanas.clippy")
WORKDAY_MIN_OBSERVED = 3600   # a day counts as worked at >=1h observed
SUBSTANTIVE_HOUR = 600        # an hour is comparable at >=10min observed
DEEP_HOUR_THRESHOLD = 0.5     # >=50% active counts toward a focus block
WINDOW = range(9, 17)         # the 09:00-17:00 core-hours window


def target_month(arg):
    today = datetime.date.today()
    if arg == "current":
        return today.strftime("%Y-%m")
    if arg:
        try:
            datetime.datetime.strptime(arg, "%Y-%m")
        except ValueError:
            sys.exit("Bad month %r. Expected YYYY-MM or 'current'." % arg)
        return arg
    first = today.replace(day=1)
    return (first - datetime.timedelta(days=1)).strftime("%Y-%m")


def load(month):
    path = os.path.join(DATA_DIR, "activity-%s.csv" % month)
    if not os.path.exists(path):
        available = sorted(
            os.path.basename(p)[9:16]
            for p in glob.glob(os.path.join(DATA_DIR, "activity-*.csv"))
        )
        sys.exit("No data for %s. Available: %s" % (month, ", ".join(available) or "none"))
    with open(path) as fh:
        return [
            (r["date"], int(r["hour"]), float(r["active_seconds"]),
             float(r["observed_seconds"]), r["had_meeting"] == "true")
            for r in csv.DictReader(fh)
        ], path


def pct(active, observed):
    return 100 * active / observed if observed else 0.0


def main():
    month = target_month(sys.argv[1] if len(sys.argv) > 1 else None)
    rows, path = load(month)

    by_day = defaultdict(dict)                       # date -> hour -> (active, observed, meeting)
    day_total = defaultdict(lambda: [0.0, 0.0, 0])   # date -> [active, observed, meeting_hours]
    for d, h, a, o, m in rows:
        by_day[d][h] = (a, o, m)
        day_total[d][0] += a
        day_total[d][1] += o
        day_total[d][2] += 1 if m else 0

    workdays = sorted(d for d, v in day_total.items() if v[1] >= WORKDAY_MIN_OBSERVED)
    if not workdays:
        sys.exit("No workdays (>=1h observed) in %s. Machine was off or logging was disabled." % month)

    total_active = sum(r[2] for r in rows)
    total_observed = sum(r[3] for r in rows)
    substantive = [r for r in rows if r[3] >= SUBSTANTIVE_HOUR]
    sub_active = sum(r[2] for r in substantive)
    sub_observed = sum(r[3] for r in substantive)

    print("=" * 62)
    print("ACTIVITY REPORT  %s" % month)
    print("=" * 62)
    print("source        %s (%d hourly rows)" % (os.path.basename(path), len(rows)))
    print("calendar days %d with any data" % len(day_total))
    print("workdays      %d (>=1h observed)" % len(workdays))
    print("observed      %.1f h   active %.1f h   active%% %.0f%%"
          % (total_observed / 3600, total_active / 3600, pct(total_active, total_observed)))
    print("on comparable hours (>=10min observed): active%% %.0f%% over %.1f h"
          % (pct(sub_active, sub_observed), sub_observed / 3600))
    print("per workday   %.1f h observed, %.2f h active (median %.2f h)"
          % (sum(day_total[d][1] for d in workdays) / 3600 / len(workdays),
             sum(day_total[d][0] for d in workdays) / 3600 / len(workdays),
             st.median(day_total[d][0] / 3600 for d in workdays)))

    print("\n-- PER WORKDAY " + "-" * 47)
    print("date        day   obs_h  act_h  act%  mtg_h")
    for d in workdays:
        a, o, m = day_total[d]
        print("%s %s  %5.1f  %5.2f  %4.0f%%  %4d"
              % (d, datetime.date.fromisoformat(d).strftime("%a"),
                 o / 3600, a / 3600, pct(a, o), m))
    best = max(workdays, key=lambda d: day_total[d][0])
    worst = min(workdays, key=lambda d: day_total[d][0])
    print("best  %s (%.2f active h)" % (best, day_total[best][0] / 3600))
    print("worst %s (%.2f active h)" % (worst, day_total[worst][0] / 3600))

    print("\n-- HOUR OF DAY " + "-" * 47)
    print("hour   obs_h   act%  profile")
    hourly = defaultdict(lambda: [0.0, 0.0])
    for d, h, a, o, m in rows:
        hourly[h][0] += a
        hourly[h][1] += o
    for h in sorted(hourly):
        a, o = hourly[h]
        p = pct(a, o)
        print("%02d:00 %6.1f  %5.0f%%  %s" % (h, o / 3600, p, "#" * int(p / 4)))
    ranked = sorted(((pct(a, o), h) for h, (a, o) in hourly.items() if o >= 3600), reverse=True)
    if ranked:
        print("peak hours: %s" % ", ".join("%02d:00 (%.0f%%)" % (h, p) for p, h in ranked[:3]))
        print("weakest:    %s" % ", ".join("%02d:00 (%.0f%%)" % (h, p) for p, h in ranked[-3:]))

    print("\n-- WEEKDAY (workdays only) " + "-" * 35)
    print("day  n   obs_h/day  act_h/day  act%")
    wd = defaultdict(lambda: [0.0, 0.0, 0])
    for d in workdays:
        k = datetime.date.fromisoformat(d).weekday()
        wd[k][0] += day_total[d][0]
        wd[k][1] += day_total[d][1]
        wd[k][2] += 1
    names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    for k in range(7):
        if k not in wd:
            continue
        a, o, n = wd[k]
        print("%s  %d   %8.1f  %9.2f  %4.0f%%" % (names[k], n, o / 3600 / n, a / 3600 / n, pct(a, o)))

    print("\n-- FOCUS QUALITY " + "-" * 45)
    blocks = []
    for d in workdays:
        best_run = cur = 0
        for h in range(24):
            a, o, _ = by_day[d].get(h, (0, 0, False))
            if o >= SUBSTANTIVE_HOUR and a / o >= DEEP_HOUR_THRESHOLD:
                cur += 1
                best_run = max(best_run, cur)
            else:
                cur = 0
        blocks.append(best_run)
    print("longest daily block of consecutive hours >=%d%% active:" % (DEEP_HOUR_THRESHOLD * 100))
    print("  median %.0f h   max %d h   days with >=3h block: %d/%d"
          % (st.median(blocks), max(blocks), sum(1 for b in blocks if b >= 3), len(blocks)))
    intense = [r for r in substantive if r[2] / r[3] >= 0.8]
    print("hours at >=80%% active: %d total = %.1f per workday" % (len(intense), len(intense) / len(workdays)))
    dead = [(d, h) for d, h, a, o, m in rows
            if d in set(workdays) and h in WINDOW and o >= 1800 and a / o < 0.1]
    print("near-dead hours (>=30min observed, <10%% active) inside %02d:00-%02d:00: %d"
          % (WINDOW[0], WINDOW[-1] + 1, len(dead)))
    for d, h in dead:
        print("  %s %02d:00" % (d, h))

    print("\n-- COVERAGE " + "-" * 50)
    possible = len(WINDOW) * 3600 * len(workdays)
    obs = sum(by_day[d].get(h, (0, 0, False))[1] for d in workdays for h in WINDOW)
    act = sum(by_day[d].get(h, (0, 0, False))[0] for d in workdays for h in WINDOW)
    print("%02d:00-%02d:00 across %d workdays = %.0f h possible"
          % (WINDOW[0], WINDOW[-1] + 1, len(workdays), possible / 3600))
    print("observed %.1f h (%.0f%% of window)   active %.1f h (%.0f%% of window)"
          % (obs / 3600, 100 * obs / possible, act / 3600, 100 * act / possible))
    print("UNOBSERVED %.1f h (%.0f%%) - app not running, machine asleep, or away."
          % ((possible - obs) / 3600, 100 * (possible - obs) / possible))
    print("=" * 62)


if __name__ == "__main__":
    main()
