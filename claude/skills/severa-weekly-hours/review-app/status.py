#!/usr/bin/env python3
"""One JSON line for the bar widget: pending/approved counts and review state of current.db."""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from server import db_open, load_all, effective
D = os.environ.get("PUNCHCARD_STATE", os.path.expanduser("~/.local/state/severa-weekly-hours"))
db = sys.argv[1] if len(sys.argv) > 1 else os.path.join(D, "current.db")
out = {"ok": False, "pending": 0, "approved": 0, "dropped": 0, "rows": 0, "period": None,
       "submittedAt": None, "executedAt": None, "db": os.path.realpath(db) if os.path.exists(db) else None}
if os.path.exists(db):
    d = load_all(db_open(db))
    if d:
        st = [effective(r, d["edits"].get(r["id"]), d["meta"]["phases"])["status"] for r in d["rows"]]
        out.update(ok=True, rows=len(st), approved=st.count("approve"), dropped=st.count("drop"),
                   pending=st.count("pending"), period=d["meta"].get("period"),
                   submittedAt=d["submittedAt"], executedAt=d["executedAt"])
print(json.dumps(out))
