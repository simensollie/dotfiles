#!/usr/bin/env python3
"""Optional Jev (TypeSafe System One) pre-pass for Severa time entries.

Adds advisory judgments to a proposal.json before `server.py init`. Pure stdlib.
Key: TYPESAFE_API_KEY in the environment, else a line TYPESAFE_API_KEY=... in
~/.config/agent-private/severa-weekly-hours/env, else the trello-linear-reconcile env file.
Without a key it exits 0 and leaves the file untouched, so the skill never depends on it.

  python3 jev_assist.py --input proposal.json --output proposal.json

Judgments per row (shown in the row's evidence panel, never applied automatically):
  phase           Choice   which phase in meta.phases fits the description + evidence best
  already_logged  Noul     the work is already covered by an entry in days[].existing
                           (only asked when that day has existing Severa entries)

Rows where Jev picks another phase with confidence >= --disagree, or already_logged >=
--dup, get row.jev.flag; the page shows a marker on them. Code keeps the arithmetic and
every write; the human decides.
"""
import argparse, json, os, sys, urllib.request

API = "https://api.typesafe.ai/v1/systemone"
MODEL = "jev-latest"
ENV_FILES = [os.path.expanduser("~/.config/agent-private/severa-weekly-hours/env"),
             os.path.expanduser("~/.config/agent-private/trello-linear-reconcile/env")]

def api_key():
    """TYPESAFE_API_KEY from the environment, else from a private env file (KEY=value lines).
    The files are read by this script only; never cat or source them from a shell command."""
    k = os.environ.get("TYPESAFE_API_KEY")
    if k: return k
    for f in ENV_FILES:
        try:
            for line in open(f):
                line = line.strip()
                if line.startswith("TYPESAFE_API_KEY="):
                    return line.split("=", 1)[1].strip().strip('"').strip("'")
        except OSError:
            pass
    return None

def ask(key, state, questions):
    req = urllib.request.Request(API, data=json.dumps({"state": state, "model": MODEL, "questions": questions}).encode(),
                                 headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)["answers"]

def questions_for(row, phases, existing):
    crit = {p["guid"]: f"{p['path']}" + (f" — {p['hint']}" if p.get("hint") else "") for p in phases}
    q = {"phase": {"type": "choice",
        "instructions": "Read `entry` (a time entry: description and the activity evidence behind it). "
                        "Which single Severa phase in the criteria should this work be logged to? Customer phases are "
                        "only for work done for that customer; internal meetings, planning and team work go to the internal phases.",
        "criteria": crit}}
    if existing:
        q["already_logged"] = {"type": "noul",
            "instructions": "Read `entry` and `existing`, the entries already registered in Severa for the same day. "
                            "Is the work in `entry` already covered by one of the existing entries?",
            "criteria": {"true": "An existing entry describes the same meeting or the same piece of work",
                         "false": "The entry is different work, even if it touches the same customer or topic"}}
    return q

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--input", required=True); ap.add_argument("--output", required=True)
    ap.add_argument("--disagree", type=float, default=0.6); ap.add_argument("--dup", type=float, default=0.7)
    a = ap.parse_args()
    spec = json.load(open(a.input))
    key = api_key()
    if not key:
        print("TYPESAFE_API_KEY not set; skipping Jev pre-pass", file=sys.stderr)
        if a.output != a.input: json.dump(spec, open(a.output, "w"), indent=2, ensure_ascii=False)
        return
    existing = {d["day"]: d.get("existing") or [] for d in spec.get("days", [])}
    phases = spec["phases"]
    names = {p["guid"]: p.get("label") or p["path"].split(" > ")[-1] for p in phases}
    n = flagged = 0
    for row in spec["rows"]:
        ex = existing.get(row["day"], [])
        state = {"entry": {"description": row["description"], "evidence": row.get("evidence", ""), "hours": row["hours"]},
                 "existing": ex}
        try:
            ans = ask(key, state, questions_for(row, phases, ex))
        except Exception as e:
            row["jev"] = {"error": str(e)[:120]}; continue
        j = row["jev"] = {}
        if "phase" in ans:
            m = ans["phase"]; conf = m.get("confidence", 0)
            j["phase"] = m["choice"]; j["phaseName"] = names.get(m["choice"], m["choice"]); j["phaseConfidence"] = round(conf, 2)
            if m["choice"] != row["phaseGuid"] and conf >= a.disagree:
                j["flag"] = f"Jev suggests {j['phaseName']} ({conf:.2f})"
        if "already_logged" in ans:
            j["alreadyLogged"] = round(ans["already_logged"]["noul"], 2)
            if j["alreadyLogged"] >= a.dup:
                j["flag"] = (j.get("flag", "") + "; " if j.get("flag") else "") + f"may already be in Severa ({j['alreadyLogged']:.2f})"
        flagged += bool(j.get("flag")); n += 1
    json.dump(spec, open(a.output, "w"), indent=2, ensure_ascii=False)
    print(f"Jev annotated {n} rows, flagged {flagged} -> {a.output}", file=sys.stderr)

if __name__ == "__main__": main()
