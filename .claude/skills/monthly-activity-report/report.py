#!/usr/bin/env python3
"""Computes every number in the monthly activity report.

Reads the ActivityLogFeature CSVs (see Sources/Clippy/Features/ActivityLog/)
and prints a fixed block for the agent to interpret. All arithmetic lives
here so the report is deterministic.

Usage: report.py [YYYY-MM | current]   (default: previous complete month)
       report.py --weekly              (all months, ISO weeks, workdays only)
       report.py --json                (same aggregates, for the visualisation)
"""
import csv
import json
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


def load_all():
    rows = []
    for p in sorted(glob.glob(os.path.join(DATA_DIR, "activity-*.csv"))):
        with open(p) as fh:
            rows += [
                (r["date"], int(r["hour"]), float(r["active_seconds"]),
                 float(r["observed_seconds"]), r["had_meeting"] == "true")
                for r in csv.DictReader(fh)
            ]
    if not rows:
        sys.exit("No data in %s." % DATA_DIR)
    return rows


def pct(active, observed):
    return 100 * active / observed if observed else 0.0


def totals_by_day(rows):
    day_total = defaultdict(lambda: [0.0, 0.0, 0])   # date -> [active, observed, meeting_hours]
    for d, h, a, o, m in rows:
        day_total[d][0] += a
        day_total[d][1] += o
        day_total[d][2] += 1 if m else 0
    return day_total


def weekly():
    """Per-ISO-week means across every logged month. Same >=1h workday filter
    as the monthly per-day means, so off days can't drag a week down."""
    day_total = totals_by_day(load_all())
    workdays = sorted(d for d, v in day_total.items() if v[1] >= WORKDAY_MIN_OBSERVED)
    if not workdays:
        sys.exit("No workdays (>=1h observed). Machine was off or logging was disabled.")

    wk = defaultdict(lambda: [0.0, 0.0, 0, 0])   # (iso_year, iso_week) -> [active, observed, n, mtg_h]
    for d in workdays:
        y, w, _ = datetime.date.fromisoformat(d).isocalendar()
        wk[(y, w)][0] += day_total[d][0]
        wk[(y, w)][1] += day_total[d][1]
        wk[(y, w)][2] += 1
        wk[(y, w)][3] += day_total[d][2]

    current = datetime.date.today().isocalendar()[:2]
    print("=" * 62)
    print("WEEKLY ACTIVITY  (workdays only, >=1h observed)")
    print("=" * 62)
    print("span          %s .. %s   %d workdays in %d weeks"
          % (workdays[0], workdays[-1], len(workdays), len(wk)))
    print("\nwk_start      n  obs_h/day  act_h/day  act%  mtg_h  note")
    for key in sorted(wk):
        a, o, n, m = wk[key]
        monday = datetime.date.fromisocalendar(key[0], key[1], 1)
        if tuple(key) == current:
            note = "PARTIAL week in progress"
        elif n <= 2:
            note = "low n - coverage gap, not output"
        else:
            note = ""
        print("%s  %2d  %9.1f  %9.2f  %4.0f%%  %5d  %s"
              % (monday.isoformat(), n, o / 3600 / n, a / 3600 / n, pct(a, o), m, note))
    comparable = [(k, v) for k, v in sorted(wk.items()) if v[2] >= 4 and tuple(k) != current]
    print("\nweeks with >=4 workdays and complete: %d" % len(comparable))
    print("=" * 62)


def dump_json():
    """Same aggregates as the printed report, as JSON for the visualisation.
    Every figure here is computed by this script - the chart never does arithmetic."""
    rows = load_all()
    day_total = totals_by_day(rows)
    workdays = sorted(d for d, v in day_total.items() if v[1] >= WORKDAY_MIN_OBSERVED)
    if not workdays:
        sys.exit("No workdays (>=1h observed). Machine was off or logging was disabled.")
    work = set(workdays)
    current = datetime.date.today().isocalendar()[:2]

    wk = defaultdict(lambda: [0.0, 0.0, 0, 0])
    for d in workdays:
        y, w, _ = datetime.date.fromisoformat(d).isocalendar()
        k = (y, w)
        wk[k][0] += day_total[d][0]
        wk[k][1] += day_total[d][1]
        wk[k][2] += 1
        wk[k][3] += day_total[d][2]
    weeks = []
    for k in sorted(wk):
        a, o, n, m = wk[k]
        weeks.append({
            "start": datetime.date.fromisocalendar(k[0], k[1], 1).isoformat(),
            "n": n, "act_pct": round(pct(a, o), 1),
            "act_h_day": round(a / 3600 / n, 2), "obs_h_day": round(o / 3600 / n, 2),
            "mtg_h": m, "partial": tuple(k) == current, "comparable": n >= 4 and tuple(k) != current,
        })

    hourly = defaultdict(lambda: [0.0, 0.0])
    for d, h, a, o, m in rows:
        hourly[h][0] += a
        hourly[h][1] += o
    hours = [{"hour": h, "obs_h": round(hourly[h][1] / 3600, 2),
              "act_pct": round(pct(*hourly[h]), 1)} for h in sorted(hourly)]

    wd = defaultdict(lambda: [0.0, 0.0, 0])
    for d in workdays:
        k = datetime.date.fromisoformat(d).weekday()
        wd[k][0] += day_total[d][0]
        wd[k][1] += day_total[d][1]
        wd[k][2] += 1
    names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    weekdays = [{"day": names[k], "n": wd[k][2], "act_pct": round(pct(wd[k][0], wd[k][1]), 1),
                 "act_h_day": round(wd[k][0] / 3600 / wd[k][2], 2)} for k in sorted(wd)]

    grid = defaultdict(dict)
    for d, h, a, o, m in rows:
        if d in work and o >= SUBSTANTIVE_HOUR:
            grid[d][h] = round(pct(a, o), 1)

    days = [{"date": d, "dow": datetime.date.fromisoformat(d).strftime("%a"),
             "obs_h": round(day_total[d][1] / 3600, 2), "act_h": round(day_total[d][0] / 3600, 2),
             "act_pct": round(pct(day_total[d][0], day_total[d][1]), 1),
             "mtg_h": day_total[d][2],
             "hours": {str(h): v for h, v in sorted(grid[d].items())}} for d in workdays]

    possible = len(WINDOW) * 3600 * len(workdays)
    by_day = defaultdict(dict)
    for d, h, a, o, m in rows:
        by_day[d][h] = (a, o, m)
    obs = sum(by_day[d].get(h, (0, 0, False))[1] for d in workdays for h in WINDOW)
    act = sum(by_day[d].get(h, (0, 0, False))[0] for d in workdays for h in WINDOW)

    total_active = sum(r[2] for r in rows)
    total_observed = sum(r[3] for r in rows)
    json.dump({
        "generated": datetime.date.today().isoformat(),
        "span": [workdays[0], workdays[-1]],
        "workdays": len(workdays),
        "observed_h": round(total_observed / 3600, 1),
        "active_h": round(total_active / 3600, 1),
        "act_pct": round(pct(total_active, total_observed), 1),
        "act_h_day": round(sum(day_total[d][0] for d in workdays) / 3600 / len(workdays), 2),
        "act_h_day_median": round(st.median(day_total[d][0] / 3600 for d in workdays), 2),
        "idle_threshold_s": 30,
        "window": [WINDOW[0], WINDOW[-1] + 1],
        "coverage": {"possible_h": round(possible / 3600, 1), "observed_h": round(obs / 3600, 1),
                     "active_h": round(act / 3600, 1),
                     "observed_pct": round(100 * obs / possible, 1),
                     "unobserved_h": round((possible - obs) / 3600, 1),
                     "unobserved_pct": round(100 * (possible - obs) / possible, 1)},
        "weeks": weeks, "hours": hours, "weekdays": weekdays, "days": days,
    }, sys.stdout, indent=1)
    print()


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--weekly":
        weekly()
        return
    if len(sys.argv) > 1 and sys.argv[1] == "--json":
        dump_json()
        return

    month = target_month(sys.argv[1] if len(sys.argv) > 1 else None)
    rows, path = load(month)

    by_day = defaultdict(dict)                       # date -> hour -> (active, observed, meeting)
    day_total = totals_by_day(rows)
    for d, h, a, o, m in rows:
        by_day[d][h] = (a, o, m)

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
