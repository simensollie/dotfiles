# Timesheet review app

Local, stdlib-only page for approving Severa time entries. `server.py` serves `index.html`
and a JSON API over one SQLite file. Workflow: see ../SKILL.md ("Review app").
Keep input JSON and the db in `~/.local/state/severa-weekly-hours/`, never in this repo.

## Input (proposal.json)

```json
{
  "period": {"start": "2026-10-05", "end": "2026-10-07"},
  "target": 7.5,
  "notes": "optional subtitle",
  "phases": [{"guid": "…", "group": "Customer or project", "label": "Phase name", "path": "exact find_phase path", "hint": "what work goes here"}],
  "days": [{"day": "MON", "date": "2026-10-05", "label": "Mon 2026-10-05", "inSeveraHours": 0, "note": "optional",
            "existing": [{"hours": 0.5, "phase": "Internal Coordination", "description": "…"}]}],
  "questions": ["TUE-3: …"],
  "rows": [{"id": "MON-1", "day": "MON", "date": "2026-10-05", "hours": 0.5, "phaseGuid": "…",
            "description": "…", "evidence": "…", "question": "optional"}]
}
```

## Export

Each row with edits applied: `status` (`approve | drop | pending`), `hours`, `phaseGuid`,
`phasePath`, `description`, `edited`, `logged`. Only `approve` rows are logged.

## API

`GET /api/review` · `PUT /api/row/<id>` (any of status, hours, phaseGuid, description) ·
`POST /api/row` `{day, date}` adds a row (next free ID) · `POST /api/approve-remaining` ·
`POST /api/submit` · `POST /api/reopen`. Any edit reopens a submitted review.

## Jev (optional)

`jev_assist.py` adds `row.jev` (`phase`, `phaseName`, `phaseConfidence`, `alreadyLogged`, `flag`)
before `init`. The page shows a marker on flagged rows and the details in the evidence panel.
