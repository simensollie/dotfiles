#!/usr/bin/env python3
"""Local review app for Severa time entries.

Stdlib only (http.server + sqlite3). One SQLite file per period.

  python3 server.py init   --db week.db --input proposal.json   # seed rows + phases
  python3 server.py serve  --db week.db [--port 8766] [--host A]  # open http://127.0.0.1:8766; --host repeatable; --db may be a symlink that is repointed while serving
  python3 server.py status --db week.db                         # submitted? how many decided?
  python3 server.py export --db week.db                         # effective rows (edits applied)
  python3 server.py record --db week.db --input results.json    # write log results back

Input schema: see README.md next to this file.
"""
import argparse, json, os, sqlite3, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA = """
CREATE TABLE IF NOT EXISTS review (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  created_at TEXT NOT NULL, meta_json TEXT NOT NULL, submitted_at TEXT, executed_at TEXT
);
CREATE TABLE IF NOT EXISTS rows (
  id TEXT PRIMARY KEY, ord INTEGER NOT NULL, row_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS edits (
  id TEXT PRIMARY KEY REFERENCES rows(id), edit_json TEXT NOT NULL, edited_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS executions (
  id TEXT NOT NULL, executed_at TEXT NOT NULL, result_json TEXT NOT NULL
);
"""
DAYS = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
EDITABLE = ("status", "hours", "phaseGuid", "description", "note")

def now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def db_open(path):
    con = sqlite3.connect(path, check_same_thread=False)
    con.row_factory = sqlite3.Row
    con.executescript(SCHEMA)
    return con

def cmd_init(a):
    spec = json.load(open(a.input))
    if os.path.exists(a.db) and not a.force:
        sys.exit(f"{a.db} exists; use --force to reseed (edits are kept)")
    con = db_open(a.db)
    meta = {k: spec.get(k) for k in ("period", "target", "phases", "days", "questions", "notes")}
    con.execute("INSERT OR REPLACE INTO review(id, created_at, meta_json) VALUES (1,?,?)", (now(), json.dumps(meta)))
    for i, r in enumerate(spec["rows"]):
        con.execute("INSERT OR REPLACE INTO rows(id, ord, row_json) VALUES (?,?,?)", (r["id"], i, json.dumps(r)))
    con.commit()
    print(f"seeded {len(spec['rows'])} rows into {a.db}")

def load_all(con):
    r = con.execute("SELECT * FROM review WHERE id=1").fetchone()
    if not r: return None
    rows = [json.loads(x["row_json"]) for x in con.execute("SELECT row_json FROM rows ORDER BY ord")]
    edits = {x["id"]: json.loads(x["edit_json"]) for x in con.execute("SELECT * FROM edits")}
    execs = {}
    for x in con.execute("SELECT * FROM executions ORDER BY executed_at"):
        execs.setdefault(x["id"], []).append(json.loads(x["result_json"]))
    return {"createdAt": r["created_at"], "submittedAt": r["submitted_at"], "executedAt": r["executed_at"],
            "meta": json.loads(r["meta_json"]), "rows": rows, "edits": edits, "executions": execs}

def effective(row, edit, phases):
    e = {**row, **{k: v for k, v in (edit or {}).items() if k in EDITABLE}}
    e["status"] = (edit or {}).get("status") or "pending"
    e["edited"] = bool(edit) and any(edit.get(k) not in (None, row.get(k)) for k in ("hours", "phaseGuid", "description"))
    e["phasePath"] = next((p["path"] for p in phases if p["guid"] == e["phaseGuid"]), None)
    return e

def cmd_status(a):
    d = load_all(db_open(a.db))
    if not d: sys.exit("empty db")
    st = [effective(r, d["edits"].get(r["id"]), d["meta"]["phases"])["status"] for r in d["rows"]]
    print(json.dumps({"period": d["meta"]["period"], "rows": len(st),
                      "approved": st.count("approve"), "dropped": st.count("drop"), "pending": st.count("pending"),
                      "submittedAt": d["submittedAt"], "executedAt": d["executedAt"]}, indent=2))

def cmd_export(a):
    d = load_all(db_open(a.db))
    if not d: sys.exit("empty db")
    rows = [effective(r, d["edits"].get(r["id"]), d["meta"]["phases"]) for r in d["rows"]]
    for r in rows: r["logged"] = any(x.get("ok") for x in d["executions"].get(r["id"], []))
    print(json.dumps({"period": d["meta"]["period"], "submittedAt": d["submittedAt"], "rows": rows}, indent=2, ensure_ascii=False))

def cmd_record(a):
    con = db_open(a.db)
    res = json.load(open(a.input)); t = now()
    for r in res["results"]:
        con.execute("INSERT INTO executions(id, executed_at, result_json) VALUES (?,?,?)", (r["id"], t, json.dumps(r)))
    con.execute("UPDATE review SET executed_at=? WHERE id=1", (t,))
    con.commit()
    print(f"recorded {len(res['results'])} results")

class Handler(BaseHTTPRequestHandler):
    # The db path may be a symlink (current.db) that a scheduled job repoints
    # at a newer review; reopen when the real file behind it changes.
    db_path = None
    on_submit = None   # shell command started (detached) when the review is submitted
    _con = None
    _real = None
    @property
    def con(self):
        real = os.path.realpath(Handler.db_path)
        if Handler._con is None or real != Handler._real:
            Handler._con = db_open(Handler.db_path); Handler._real = real
        return Handler._con
    def _json(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}")
    def _reopen(self):
        self.con.execute("UPDATE review SET submitted_at=NULL WHERE id=1")
    def log_message(self, *args): pass
    def do_GET(self):
        p = urlparse(self.path).path
        if p in ("/", "/index.html"):
            html = open(os.path.join(HERE, "index.html"), "rb").read()
            self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(html))); self.end_headers(); self.wfile.write(html)
        elif p == "/api/review":
            d = load_all(self.con) or {}
            d["loggingHook"] = bool(Handler.on_submit)
            self._json(200, d)
        else:
            self._json(404, {"error": "not found"})
    def do_PUT(self):
        p = urlparse(self.path).path
        if not p.startswith("/api/row/"):
            return self._json(404, {"error": "not found"})
        rid = p.rsplit("/", 1)[1]
        row = self.con.execute("SELECT row_json FROM rows WHERE id=?", (rid,)).fetchone()
        if not row: return self._json(404, {"error": "unknown row"})
        body = self._body()
        old = self.con.execute("SELECT edit_json FROM edits WHERE id=?", (rid,)).fetchone()
        e = {**(json.loads(old["edit_json"]) if old else {}), **{k: body[k] for k in EDITABLE if k in body}}
        if "hours" in e and e["hours"] is not None:
            h = float(e["hours"])
            if h <= 0 or h * 2 != int(h * 2): return self._json(400, {"error": "hours must be a positive multiple of 0.5"})
            e["hours"] = h
        if e.get("status") not in (None, "pending", "approve", "drop"): return self._json(400, {"error": "bad status"})
        self.con.execute("INSERT OR REPLACE INTO edits(id, edit_json, edited_at) VALUES (?,?,?)", (rid, json.dumps(e), now()))
        self._reopen(); self.con.commit(); self._json(200, e)
    def do_POST(self):
        p = urlparse(self.path).path
        if p == "/api/submit":
            t = now(); self.con.execute("UPDATE review SET submitted_at=? WHERE id=1", (t,)); self.con.commit()
            started = False
            if Handler.on_submit:
                import subprocess
                try:
                    subprocess.Popen(Handler.on_submit, shell=True, stdin=subprocess.DEVNULL,
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                    started = True
                except OSError as e:
                    print(f"on-submit hook failed: {e}", file=sys.stderr, flush=True)
            self._json(200, {"submittedAt": t, "loggingStarted": started})
        elif p == "/api/reopen":
            self._reopen(); self.con.commit(); self._json(200, {"ok": True})
        elif p == "/api/approve-remaining":
            d = load_all(self.con); t = now(); n = 0
            for r in d["rows"]:
                e = d["edits"].get(r["id"], {})
                if e.get("status") in ("approve", "drop"): continue
                self.con.execute("INSERT OR REPLACE INTO edits(id, edit_json, edited_at) VALUES (?,?,?)",
                                 (r["id"], json.dumps({**e, "status": "approve"}), t)); n += 1
            self._reopen(); self.con.commit(); self._json(200, {"approved": n})
        elif p == "/api/row":
            # add a new row for a day; id is the next free number for that day
            b = self._body(); date = b.get("date"); day = b.get("day")
            if day not in DAYS or not date: return self._json(400, {"error": "day and date required"})
            ids = [x["id"] for x in self.con.execute("SELECT id FROM rows WHERE id LIKE ?", (day + "-%",))]
            n = max([int(i.split("-")[1]) for i in ids] + [0]) + 1
            ordn = self.con.execute("SELECT COALESCE(MAX(ord),0)+1 FROM rows").fetchone()[0]
            row = {"id": f"{day}-{n}", "day": day, "date": date, "hours": 0.5, "phaseGuid": b.get("phaseGuid", ""),
                   "description": "", "evidence": "Added in review app", "added": True}
            self.con.execute("INSERT INTO rows(id, ord, row_json) VALUES (?,?,?)", (row["id"], ordn, json.dumps(row)))
            self.con.execute("INSERT INTO edits(id, edit_json, edited_at) VALUES (?,?,?)", (row["id"], json.dumps({"status": "pending"}), now()))
            self._reopen(); self.con.commit(); self._json(200, row)
        else:
            self._json(404, {"error": "not found"})

def cmd_serve(a):
    import threading
    Handler.db_path = a.db
    Handler.on_submit = a.on_submit
    hosts = a.host or ["127.0.0.1"]
    servers = [ThreadingHTTPServer((h, a.port), Handler) for h in hosts]
    for h in hosts: print(f"timesheet review: http://{h}:{a.port}  (db: {a.db})  Ctrl-C to stop", flush=True)
    threads = [threading.Thread(target=s.serve_forever, daemon=True) for s in servers]
    for t in threads: t.start()
    try:
        while True: time.sleep(3600)
    except KeyboardInterrupt: pass

def main():
    ap = argparse.ArgumentParser(); sub = ap.add_subparsers(dest="cmd", required=True)
    for name, fn in (("init", cmd_init), ("serve", cmd_serve), ("status", cmd_status), ("export", cmd_export), ("record", cmd_record)):
        s = sub.add_parser(name); s.add_argument("--db", required=True); s.set_defaults(fn=fn)
        if name in ("init", "record"): s.add_argument("--input", required=True)
        if name == "init": s.add_argument("--force", action="store_true")
        if name == "serve":
            s.add_argument("--port", type=int, default=8766)
            s.add_argument("--host", action="append", help="bind address; repeatable (default 127.0.0.1)")
            s.add_argument("--on-submit", help="shell command to start when the review is submitted, e.g. 'systemctl --user start --no-block punchcard-log.service'")
    a = ap.parse_args(); a.fn(a)

if __name__ == "__main__": main()
