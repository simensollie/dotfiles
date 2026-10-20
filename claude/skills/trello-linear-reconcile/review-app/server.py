#!/usr/bin/env python3
"""Local review app for Trello/Linear reconciliation.

Stdlib only (http.server + sqlite3). One SQLite file per review run.

  python3 server.py init   --db review.db --input review.json   # seed cards + recommendations
  python3 server.py serve  --db review.db [--port 8765] [--on-submit CMD]  # open http://127.0.0.1:8765
                                   # CMD is started detached when Submit is pressed, with POSTMARK_DB set
  python3 server.py status --db review.db                       # submitted? how many decided?
  python3 server.py export --db review.db                       # decisions JSON (effective = decision or recommendation)
  python3 server.py record --db review.db --input results.json  # write execution results back

Input JSON schema: see README.md next to this file.
"""
import argparse, json, os, sqlite3, sys, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA = """
CREATE TABLE IF NOT EXISTS review (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  customer TEXT NOT NULL, board TEXT, created_at TEXT NOT NULL,
  meta_json TEXT NOT NULL, submitted_at TEXT, executed_at TEXT
);
CREATE TABLE IF NOT EXISTS cards (
  short_link TEXT PRIMARY KEY, ord INTEGER NOT NULL, kind TEXT NOT NULL,
  number INTEGER, title TEXT NOT NULL, card_json TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS decisions (
  short_link TEXT PRIMARY KEY REFERENCES cards(short_link),
  decision_json TEXT NOT NULL, decided_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS executions (
  short_link TEXT NOT NULL, executed_at TEXT NOT NULL, result_json TEXT NOT NULL
);
"""

def now(): return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())

def db_open(path):
    con = sqlite3.connect(path, check_same_thread=False)
    con.row_factory = sqlite3.Row
    con.executescript(SCHEMA)
    return con

def cmd_init(a):
    spec = json.load(open(a.input))
    if os.path.exists(a.db) and not a.force:
        sys.exit(f"{a.db} exists; use --force to reseed (decisions are kept)")
    con = db_open(a.db)
    meta = {k: spec.get(k) for k in ("cutoff", "lists", "linearActions", "notes", "reviewedAt", "deployTarget")}
    con.execute("INSERT OR REPLACE INTO review(id, customer, board, created_at, meta_json) VALUES (1,?,?,?,?)",
                (spec["customer"], spec.get("board"), now(), json.dumps(meta)))
    for i, c in enumerate(spec["cards"]):
        con.execute("INSERT OR REPLACE INTO cards(short_link, ord, kind, number, title, card_json) VALUES (?,?,?,?,?,?)",
                    (c["shortLink"], i, c.get("kind", "reconciled"), c.get("number"), c["title"], json.dumps(c)))
    con.commit()
    print(f"seeded {len(spec['cards'])} cards into {a.db}")

def load_all(con):
    r = con.execute("SELECT * FROM review WHERE id=1").fetchone()
    if not r: return None
    cards = [json.loads(x["card_json"]) for x in con.execute("SELECT card_json FROM cards ORDER BY ord")]
    dec = {x["short_link"]: json.loads(x["decision_json"]) for x in con.execute("SELECT * FROM decisions")}
    execs = {}
    for x in con.execute("SELECT * FROM executions ORDER BY executed_at"):
        execs.setdefault(x["short_link"], []).append(json.loads(x["result_json"]))
    return {"customer": r["customer"], "board": r["board"], "createdAt": r["created_at"],
            "submittedAt": r["submitted_at"], "executedAt": r["executed_at"],
            "meta": json.loads(r["meta_json"]), "cards": cards, "decisions": dec, "executions": execs}

def effective(card, dec):
    """Decision if present, else the recommendation, flagged with source."""
    rec = card.get("recommendation", {})
    if dec:
        return {**rec, **dec, "source": "decision"}
    return {**rec, "shortLink": card["shortLink"], "source": "recommendation"}

def cmd_status(a):
    d = load_all(db_open(a.db))
    if not d: sys.exit("empty db")
    print(json.dumps({"customer": d["customer"], "cards": len(d["cards"]), "decided": len(d["decisions"]),
                      "submittedAt": d["submittedAt"], "executedAt": d["executedAt"]}, indent=2))

def cmd_export(a):
    d = load_all(db_open(a.db))
    if not d: sys.exit("empty db")
    out = {"customer": d["customer"], "submittedAt": d["submittedAt"], "meta": d["meta"],
           "decisions": [effective(c, d["decisions"].get(c["shortLink"])) | {"card": c["number"], "title": c["title"], "kind": c["kind"]}
                         for c in d["cards"]]}
    print(json.dumps(out, indent=2, ensure_ascii=False))

def cmd_record(a):
    con = db_open(a.db)
    res = json.load(open(a.input))
    t = now()
    for r in res["results"]:
        con.execute("INSERT INTO executions(short_link, executed_at, result_json) VALUES (?,?,?)",
                    (r["shortLink"], t, json.dumps(r)))
    con.execute("UPDATE review SET executed_at=? WHERE id=1", (t,))
    con.commit()
    print(f"recorded {len(res['results'])} results")

class Handler(BaseHTTPRequestHandler):
    con = None
    db_path = None
    on_submit = None
    def _json(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode()
        self.send_response(code); self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body))); self.end_headers(); self.wfile.write(body)
    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        return json.loads(self.rfile.read(n) or b"{}")
    def log_message(self, *args): pass
    def do_GET(self):
        p = urlparse(self.path).path
        if p in ("/", "/index.html"):
            html = open(os.path.join(HERE, "index.html"), "rb").read()
            self.send_response(200); self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(html))); self.end_headers(); self.wfile.write(html)
        elif p == "/api/review":
            d = load_all(self.con)
            if d is not None: d["executeHook"] = bool(Handler.on_submit)
            self._json(200, d)
        else:
            self._json(404, {"error": "not found"})
    def do_PUT(self):
        p = urlparse(self.path).path
        if p.startswith("/api/decision/"):
            sl = p.rsplit("/", 1)[1]
            if not self.con.execute("SELECT 1 FROM cards WHERE short_link=?", (sl,)).fetchone():
                return self._json(404, {"error": "unknown card"})
            d = self._body(); d["shortLink"] = sl; d["decidedAt"] = now()
            self.con.execute("INSERT OR REPLACE INTO decisions(short_link, decision_json, decided_at) VALUES (?,?,?)",
                             (sl, json.dumps(d), d["decidedAt"]))
            # any change after submit reopens the review
            self.con.execute("UPDATE review SET submitted_at=NULL WHERE id=1 AND executed_at IS NULL")
            self.con.commit(); self._json(200, d)
        else:
            self._json(404, {"error": "not found"})
    def do_POST(self):
        p = urlparse(self.path).path
        if p == "/api/submit":
            t = now(); self.con.execute("UPDATE review SET submitted_at=? WHERE id=1", (t,)); self.con.commit()
            started = False
            if Handler.on_submit:
                import subprocess
                try:
                    env = {**os.environ, "POSTMARK_DB": os.path.realpath(Handler.db_path)}
                    subprocess.Popen(Handler.on_submit, shell=True, env=env, stdin=subprocess.DEVNULL,
                                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
                    started = True
                except Exception as e:
                    print(f"on-submit hook failed: {e}", file=sys.stderr, flush=True)
            self._json(200, {"submittedAt": t, "executionStarted": started})
        elif p == "/api/reopen":
            self.con.execute("UPDATE review SET submitted_at=NULL WHERE id=1"); self.con.commit()
            self._json(200, {"ok": True})
        elif p == "/api/accept-all":
            # persist the recommendation as a decision for every undecided card
            d = load_all(self.con); t = now(); n = 0
            for c in d["cards"]:
                if c["shortLink"] in d["decisions"]: continue
                dec = {**c.get("recommendation", {}), "shortLink": c["shortLink"], "decidedAt": t, "acceptedDefault": True}
                self.con.execute("INSERT INTO decisions(short_link, decision_json, decided_at) VALUES (?,?,?)",
                                 (c["shortLink"], json.dumps(dec), t)); n += 1
            self.con.commit(); self._json(200, {"accepted": n})
        else:
            self._json(404, {"error": "not found"})

def cmd_serve(a):
    Handler.con = db_open(a.db)
    Handler.db_path = a.db
    Handler.on_submit = a.on_submit
    srv = ThreadingHTTPServer(("127.0.0.1", a.port), Handler)
    print(f"review app: http://127.0.0.1:{a.port}  (db: {a.db})  Ctrl-C to stop", flush=True)
    try: srv.serve_forever()
    except KeyboardInterrupt: pass

def main():
    ap = argparse.ArgumentParser(); sub = ap.add_subparsers(dest="cmd", required=True)
    for name, fn in (("init", cmd_init), ("serve", cmd_serve), ("status", cmd_status), ("export", cmd_export), ("record", cmd_record)):
        s = sub.add_parser(name); s.add_argument("--db", required=True); s.set_defaults(fn=fn)
        if name in ("init", "record"): s.add_argument("--input", required=True)
        if name == "init": s.add_argument("--force", action="store_true")
        if name == "serve":
            s.add_argument("--port", type=int, default=8765)
            s.add_argument("--on-submit", help="shell command started detached when the review is submitted "
                           "(POSTMARK_DB env = db path), e.g. 'systemctl --user start --no-block postmark-execute.service'")
    a = ap.parse_args(); a.fn(a)

if __name__ == "__main__": main()
