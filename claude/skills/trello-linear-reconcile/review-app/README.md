# Review app

Local, stdlib-only review page for a reconciliation run. `server.py` serves `index.html`
and a JSON API over one SQLite file. See SKILL.md for the workflow.

## review.json

```json
{
  "customer": "Example Customer",
  "board": "Example Customer Feedback",
  "deployTarget": "ExampleTest",
  "reviewedAt": "2026-10-06",
  "cutoffNote": "IIS package still the 2026-09-23 build; 09-29 run was k3s-only.",
  "cutoff": [{"slot": ".NET hosts (qms 18492678b8)", "value": "09-23 13:45Z"}],
  "lists": {
    "stay":      {"label": "Leave in current column"},
    "backlog":   {"label": "Move to ✅ Accepted / Backlog", "id": "<listId>"},
    "inprogress":{"label": "Move to 🔨 In Progress", "id": "<listId>"},
    "deploy":    {"label": "Move to 🚀 Fixed – Awaiting Deployment", "id": "<listId>"},
    "resolved":  {"label": "Move to ✔️ Done - Awaiting Test", "id": "<listId>"},
    "wontdo":    {"label": "Move to 🚫 Won't Do", "id": "<listId>"},
    "later":     {"label": "Undecided, revisit"}
  },
  "linearActions": {"none": "No Linear action", "create": "Create a new Linear issue (CER)", "link": "Link to an existing issue"},
  "groupNotes": {"Reconciled": "Cards with a Linear issue.", "New feedback": "Untracked intake cards: board action + Linear action."},
  "notes": {"linearProblems": ["CER-1662 Done but MRs only on an unmerged branch"], "exclusions": "3 cards in Won't Do not reviewed."},
  "cards": [
    {
      "shortLink": "AbCd1234", "number": 73, "kind": "reconciled", "group": "Reconciled",
      "title": "A case can be closed with obligatory fields empty",
      "column": "✅ Accepted / Backlog",
      "verdict": "deploy", "verdictLabel": "Fixed, awaiting deployment", "tone": "info",
      "issue": "CER-2120",
      "evidence": {"Linear": "CER-2120 Done", "Latest MR": "fe!570 2026-10-02 07:14Z, qms!275 2026-10-02 06:19Z", "Cut-off": "FE deviationV3 09-23 11:25Z, hosts 09-23 13:45Z"},
      "why": "Both MRs merged nine days after the deployed build.",
      "customerComment": "<last TWO customer comments, newest last, names scrubbed. One terse comment ('moved back to In Progress') scored 0.21 on 2026-10-06; the previous 'partly fixed' comment carries the signal>",
      "issueText": "<FULL issue description plus comments, not a gist. A one-line summary of CER-1570 scored needs_activation 0.23 although the full text names the config steps>",
      "recommendation": {"action": "deploy", "backlink": true}
    },
    {
      "shortLink": "EfGh5678", "number": 75, "kind": "intake", "group": "New feedback",
      "title": "Assignees on a checklist plan cannot be given to a role",
      "column": "📥 New Feedback", "verdict": "untracked", "verdictLabel": "Untracked", "tone": "",
      "evidence": {"Labels": "Critical", "Related in Linear": "CER-2263 (Todo)"},
      "why": "Roles were possible in the previous module.",
      "recommendation": {"action": "backlog", "linear": "create", "linearIssue": ""}
    }
  ]
}
```

`tone` is one of `info | ok | warn | bad | ""` and only colours the card. `verdict` keys
used by `jev_assist.py`: `deploy`, `done` (merged before cut-off).

## Decision shape (export)

```json
{"shortLink": "…", "card": 73, "kind": "reconciled", "action": "deploy", "targetListId": "…",
 "backlink": true, "linear": "create|link|none", "linearIssue": "CER-…", "note": "…",
 "decidedAt": "…", "source": "decision|recommendation"}
```

## results.json (record)

```json
{"results": [{"shortLink": "AbCd1234", "ok": true, "summary": "moved to Awaiting Deployment; CER-2120 linked both ways", "executedAt": "2026-10-06T18:00:00Z"}]}
```
