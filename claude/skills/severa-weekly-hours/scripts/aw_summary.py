#!/usr/bin/env python3
"""Summarise ActivityWatch activity per day, for drafting Severa time entries.

Runs against the local aw-server (localhost:5600). To read another machine,
pipe it over ssh:  ssh simen-desktop python3 - 2026-09-21 2026-09-25 < aw_summary.py

Usage: aw_summary.py START_DATE END_DATE   (ISO dates, inclusive, Europe/Oslo days)

Per day it prints:
  - AFK watcher totals (afk vs not-afk). Unreliable on some hosts, so also:
  - Sessions built from window-change events (gap > 10 min splits a session;
    a single event longer than 30 min counts as 5 min, it is a parked window).
  - Top window titles and top herdr/editor projects (not AFK filtered, hints only).
"""
import datetime as dt
import json
import sys
import urllib.parse
import urllib.request
from zoneinfo import ZoneInfo

BASE = "http://localhost:5600/api/0"
TZ = ZoneInfo("Europe/Oslo")
GAP = dt.timedelta(minutes=10)
# Lock screens and screensavers are not activity.
IDLE_APPS = {"loginwindow", "screensaver", "org.omarchy.screensaver", "hyprlock"}


def get(path):
    return json.load(urllib.request.urlopen(BASE + path))


def query(start, end, q):
    body = json.dumps({"timeperiods": [f"{start.isoformat()}/{end.isoformat()}"], "query": [q]})
    req = urllib.request.Request(BASE + "/query/", data=body.encode(),
                                 headers={"Content-Type": "application/json"})
    return json.load(urllib.request.urlopen(req))[0]


def events(bucket, start, end):
    qs = f"?start={urllib.parse.quote(start.isoformat())}&end={urllib.parse.quote(end.isoformat())}&limit=100000"
    return get(f"/buckets/{bucket}/events{qs}")


def ts(s):
    return dt.datetime.fromisoformat(s.replace("Z", "+00:00")).astimezone(TZ)


def sessions(evs):
    evs = sorted(evs, key=lambda e: e["timestamp"])
    out, cur = [], None
    for e in evs:
        if e["data"].get("app", "").lower() in IDLE_APPS:
            continue
        t = ts(e["timestamp"])
        d = e["duration"] if e["duration"] <= 1800 else 300
        end = t + dt.timedelta(seconds=d)
        title = f'{e["data"].get("app", "")} | {e["data"].get("title", "")}'[:90]
        if cur and t - cur["end"] <= GAP:
            cur["end"] = max(cur["end"], end)
        else:
            cur = {"start": t, "end": end, "titles": {}}
            out.append(cur)
        cur["titles"][title] = cur["titles"].get(title, 0) + min(d, 300)
    return [s for s in out if (s["end"] - s["start"]).total_seconds() >= 180]


def main():
    start_day = dt.date.fromisoformat(sys.argv[1])
    end_day = dt.date.fromisoformat(sys.argv[2])
    buckets = get("/buckets/")
    window = [b for b in buckets if b.startswith("aw-watcher-window")]
    afk = [b for b in buckets if b.startswith("aw-watcher-afk")]
    hints = [b for b in buckets if any(k in b for k in ("herdr", "neovim", "vscode", "obsidian"))
             and "agents" not in b]
    web = [b for b in buckets if b.startswith("aw-watcher-web")]
    print("buckets:", ", ".join(window + afk + hints + web))

    day = start_day
    while day <= end_day:
        s = dt.datetime.combine(day, dt.time(0), TZ)
        e = s + dt.timedelta(days=1)
        print(f"\n===== {day} ({day:%a})")
        for b in afk:
            # Clip to the day and union overlapping intervals: some hosts store
            # duplicate, overlapping AFK events that would otherwise sum past 24h.
            spans = {}
            for x in events(b, s, e):
                a = max(ts(x["timestamp"]), s)
                z = min(ts(x["timestamp"]) + dt.timedelta(seconds=x["duration"]), e)
                if z > a:
                    spans.setdefault(x["data"].get("status", "?"), []).append((a, z))
            totals = {}
            for st, iv in spans.items():
                iv.sort()
                total, (ca, cz) = 0.0, iv[0]
                for a, z in iv[1:]:
                    if a <= cz:
                        cz = max(cz, z)
                    else:
                        total += (cz - ca).total_seconds()
                        ca, cz = a, z
                totals[st] = total + (cz - ca).total_seconds()
            if totals:
                print(f"  afk {b}: " + ", ".join(f"{k}={v/3600:.2f}h" for k, v in totals.items()))
        for b in window:
            ss = sessions(events(b, s, e))
            if not ss:
                continue
            total = sum((x["end"] - x["start"]).total_seconds() for x in ss) / 3600
            print(f"  sessions {b} (total {total:.2f}h):")
            for x in ss:
                top = sorted(x["titles"].items(), key=lambda k: -k[1])[:6]
                mins = (x["end"] - x["start"]).total_seconds() / 60
                print(f'    {x["start"]:%H:%M}-{x["end"]:%H:%M} ({mins:.0f}m)')
                for title, sec in top:
                    if sec >= 120:
                        print(f"        {sec/60:4.0f}m {title}")
        for b in web:
            try:
                r = query(s, e, f'RETURN=limit_events(sort_by_duration(merge_events_by_keys(query_bucket("{b}"),["title"])),15);')
            except Exception:
                continue
            r = [x for x in r if x["duration"] >= 300]
            if r:
                print(f"  web {b}:")
                for x in r:
                    print(f'        {x["duration"]/60:4.0f}m {x["data"].get("title", "")[:90]}')
        for b in hints:
            keys = '["title"]' if "herdr" in b and "window" in buckets[b].get("type", "") else '["project"]'
            try:
                r = query(s, e, f'RETURN=limit_events(sort_by_duration(merge_events_by_keys(query_bucket("{b}"),{keys})),10);')
            except Exception:
                continue
            r = [x for x in r if x["duration"] >= 300]
            if r:
                print(f"  hints {b} (NOT afk filtered, topic only):")
                for x in r:
                    label = x["data"].get("title") or x["data"].get("project") or json.dumps(x["data"])[:80]
                    print(f"        {x['duration']/60:4.0f}m {label[:90]}")
        day += dt.timedelta(days=1)


if __name__ == "__main__":
    main()
