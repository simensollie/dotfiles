#!/usr/bin/env python3
"""Optional Jev (TypeSafe System One) pre-pass for reconciliation.

Adds advisory judgments to a review.json so recommendations start from better
defaults. Pure stdlib. Key: TYPESAFE_API_KEY in the environment, or a line
TYPESAFE_API_KEY=... in ~/.config/agent-private/trello-linear-reconcile/env (mode 600).
Without a key it exits 0 and leaves the file untouched, so the skill never depends on it.

  python3 jev_assist.py --input review.json --output review.json [--candidates candidates.json]

Judgments (all advisory, shown on the card as "Jev: ..."):
  customer_rejects   Noul   latest customer comment says the fix is missing or incomplete
  needs_activation   Noul   issue text mentions a tenant flag, config key, DB upgrade or job
                            that must be switched on before the change is live
  issue_match        Choice for intake cards: which candidate Linear issue covers the card,
                            or "none"  (candidates.json: {shortLink: [{id, title, summary}]})

What stays in code: the timestamp comparison against the deploy cut-off, the
first-match verdict table, and every write. Jev only proposes; the human decides.
"""
import argparse, json, os, sys, urllib.request

API = "https://api.typesafe.ai/v1/systemone"
MODEL = "jev-latest"

ENV_FILE = os.path.expanduser("~/.config/agent-private/trello-linear-reconcile/env")

def api_key():
    """TYPESAFE_API_KEY from the environment, else from the private env file (KEY=value lines).
    The file is read by this script only; never cat or source it from a shell command."""
    k = os.environ.get("TYPESAFE_API_KEY")
    if k: return k
    try:
        for line in open(ENV_FILE):
            line = line.strip()
            if line.startswith("TYPESAFE_API_KEY="):
                return line.split("=", 1)[1].strip().strip('"').strip("'")
    except OSError:
        pass
    return None

def ask(state, questions):
    key = api_key()
    req = urllib.request.Request(API, data=json.dumps({"state": state, "model": MODEL, "questions": questions}).encode(),
                                 headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)["answers"]

def questions_for(card, candidates):
    q = {}
    if card.get("customerComment"):
        q["customer_rejects"] = {"type": "noul",
            "instructions": "Read `customerComment`, the customer's latest comment on this card. Does the customer say the reported problem is still present, only partly fixed, or that something they asked for is still missing?",
            "criteria": {"true": "The customer reports the problem persists, is partly fixed, or asks for more", "false": "The customer accepts the fix, says thanks, asks an unrelated question, or gives no verdict"}}
    if card.get("issueText"):
        q["needs_activation"] = {"type": "noul",
            "instructions": "Read `issueText`, the Linear issue description and comments. Does it say the change only takes effect after a per-tenant feature flag, an appsettings or configuration key, a database upgrade script, or a background job is switched on or run?",
            "criteria": {"true": "An explicit activation step on the tenant is required beyond deploying the code", "false": "Deploying the code is enough, or no activation step is mentioned"}}
    cands = candidates.get(card["shortLink"]) or []
    if cands:
        crit = {c["id"]: f"{c['title']} - {c.get('summary', '')}".strip(" -") for c in cands}
        crit["none"] = "No candidate covers the same problem; a new issue is needed"
        q["issue_match"] = {"type": "choice",
            "instructions": "Read `card` (a customer feedback card) and the candidate Linear issues in the criteria. Which single candidate tracks the same problem or request as the card? Pick none when every candidate is only adjacent or related.",
            "criteria": crit}
    return q

def main():
    ap = argparse.ArgumentParser(); ap.add_argument("--input", required=True); ap.add_argument("--output", required=True)
    ap.add_argument("--candidates"); ap.add_argument("--reject-threshold", type=float, default=0.7)
    ap.add_argument("--match-confidence", type=float, default=0.6)
    a = ap.parse_args()
    spec = json.load(open(a.input))
    if not api_key():
        print(f"TYPESAFE_API_KEY not set (env or {ENV_FILE}); skipping Jev pre-pass", file=sys.stderr)
        if a.output != a.input: json.dump(spec, open(a.output, "w"), indent=2, ensure_ascii=False)
        return
    candidates = json.load(open(a.candidates)) if a.candidates else {}
    n = 0
    for card in spec["cards"]:
        qs = questions_for(card, candidates)
        if not qs: continue
        state = {"card": {"title": card["title"], "description": card.get("description", ""), "labels": card.get("labels", "")},
                 "customerComment": card.get("customerComment", ""), "issueText": card.get("issueText", "")}
        try:
            ans = ask(state, qs)
        except Exception as e:
            card.setdefault("jev", {})["error"] = str(e)[:120]; continue
        j = card.setdefault("jev", {})
        rec = card.setdefault("recommendation", {})
        if "customer_rejects" in ans:
            j["customer_rejects"] = ans["customer_rejects"]["noul"]
        if "needs_activation" in ans:
            j["needs_activation"] = ans["needs_activation"]["noul"]
        if "issue_match" in ans:
            m = ans["issue_match"]; j["issue_match"] = f"{m['choice']} ({m.get('confidence', 0):.2f})"
            if m["choice"] != "none" and m.get("confidence", 0) >= a.match_confidence and not rec.get("linearIssue"):
                rec["linear"] = "link"; rec["linearIssue"] = m["choice"]
        # Advisory only: a strong "customer rejects" on a merged-before-cutoff card is the
        # misfiling the skill warns about. Mark it; the human keeps the final say.
        if j.get("customer_rejects", 0) >= a.reject_threshold and card.get("verdict") in ("done", "deploy"):
            j["flag"] = "customer says not fixed; check for inert flag or partial fix before Awaiting Deployment"
        n += 1
    json.dump(spec, open(a.output, "w"), indent=2, ensure_ascii=False)
    print(f"Jev annotated {n} cards -> {a.output}", file=sys.stderr)

if __name__ == "__main__": main()
