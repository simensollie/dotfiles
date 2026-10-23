---
name: severa-weekly-hours
description: Draft and log Visma Severa work hours from real activity data. Fetches what is already registered in Severa, then gathers the week's activity from ActivityWatch (simen-beelink, simen-desktop, and the Netpower Mac when reachable), Outlook calendar, sent mail, Teams messages, Linear and ~/pensieve, proposes time entries in an ID'd table, and logs them to Severa on confirmation. Triggers: "suggest time entries", "fill in my hours", "timesheet for this week", "what should I log in Severa", "før timer for uka".
---

# Severa weekly hours

Goal: turn evidence of what the user did into precise Severa entries, get them
confirmed row by row, then log them. Never write to Severa before the user says
"go" (or equivalent).

Default period: Monday of the current week through today (Europe/Oslo). Accept
any other range the user gives.

## Agent portability

Works in Claude Code and Cursor (both load it from their personal skills dir).
Tool names below are Claude Code's. In another agent, use the same MCP server's
equivalent tool. If a source has no connector there (Cursor currently has only
severa, inbox-triage and trello: no Linear, no Teams, no sent-mail search),
skip it and list the skipped sources above the tables so gaps are visible.

## 1. Identity and what is already logged

- Identities (Severa email, Outlook/Teams address) are in `~/.config/agent-private/severa-weekly-hours/conventions.md`
  (private, not in dotfiles). Read it first. `mcp__severa__whoami` confirms the Severa one.
- `mcp__severa__list_hours` with `user_emails: [<Severa email>]` for the
  period. Sum per day. Existing rows are facts: never re-suggest them, and treat
  their descriptions as evidence of what was already covered.

### Which days are missing

A day is complete only when hours + absences for that date reach the workday
target (7.5h). Check every weekday in the period individually:

1. `list_hours` for the range, sum `hours` per date (script it; the output is
   long).
2. `report_registrations` for the same range, add each absence's duration to
   its date (`end` minus `start`, or 7.5h when `is_all_day`).
3. Flag every weekday under 7.5h. Show a per-day table with the registered
   hours, so the user can see short days, not just empty ones.

Do not answer from `report_registrations.missing_days` (it lists only days
with zero entries, and includes weekends) or from period totals; a day with
some entries can still be short, and that is the usual case (flexi, sick
child, half days).

Severa's "day completed" flag is separate from the hours and is not exposed by
the MCP. If the user says a day is missing but it has 7.5h here, say so and
suggest marking the day as completed in the Severa UI.

## 2. Gather activity (run in parallel)

| Source | How | What it gives |
|---|---|---|
| ActivityWatch, all hosts | `~/.claude/skills/severa-weekly-hours/scripts/aw_all.sh START END` | Per host: sessions (start–end), top windows, web tabs, herdr/editor topics |
| Calendar | `mcp__inbox-triage__list_calendar_events` (start/end ISO, count 100) | Meetings with exact times; skip declined/cancelled |
| Sent mail | `mcp__claude_ai_Microsoft_365__outlook_email_search` sender=<Outlook/Teams address>, afterDateTime | Customer/dev communication with timestamps |
| Teams | `mcp__claude_ai_Microsoft_365__chat_message_search` query `*`, sender=<Outlook/Teams address>, afterDateTime; page with `offset` until done | Who the user worked with, on what, when |
| Linear | `list_issues` assignee=me updatedAt=START, and team CER createdAt=START (filter createdBy = Simen Sollie) | Issues created or moved, with times |
| ~/pensieve | `log.md` entries for the period, `raw/` transcripts dated in the period (last timestamp line = real meeting length), `wiki/decisions.md` entries, `output/` files and `git log --since` | Actual meeting durations, topics and decisions, unscheduled calls |

ActivityWatch hosts (configured in `aw_all.sh`):
- `siso@simen-beelink`: main work laptop, required. Runs locally when the skill
  runs on beelink, over ssh from any other machine.
- `siso@simen-desktop`: home office days, optional.
- `simensollie@simens-netpowermac`: optional.
Optional hosts are often offline; if the script prints `SKIPPED` for one,
disregard it silently (one line in the report at most). If beelink is skipped,
say so, because that day's evidence is incomplete.

~/pensieve lives on simen-beelink. When the skill runs on another machine and
`~/pensieve` does not exist locally, read it with `ssh siso@simen-beelink`.

ActivityWatch caveats:
- AFK watchers are unreliable (the desktop can report a whole worked day as
  AFK). Use the window-event sessions, not the AFK totals, for span.
- herdr / agent buckets are not AFK filtered and agents run unattended; use them
  for *topic*, never for duration.
- Personal projects are not work: tinget, tinget-web, munin, gatheround*, velstyrt,
  giftify, tempo, dotfiles and anything under `simensollie/*`. Exclude that time.
- A session that starts 00:00 and lasts a few minutes is spillover from the
  previous day; ignore it.

Late-evening Linear/Trello work is real work time; include it.

## 3. Map work to phases

Always resolve phases with `mcp__severa__find_phase` and use the returned `path`
verbatim in the table. Keep the `guid` for logging.

The work → phase mapping (internal categories and customer projects, billing
rules, locked phases) lives in the private conventions file above. Rules that
always apply:
- For work that matches no row there, run `find_phase` and ask if more than one
  phase fits. Never guess; add the answer to the private file afterwards.

## 4. Present suggestions

One table per day. Header line: `## Mon 2026-09-21 (in Severa: 4.5h, suggested +2.5h → 7.0h)`.
List already-registered rows only as a one-line total, not as table rows.

| ID | h | Phase (exact Severa path) | Description (as it will be logged) | Evidence |
|---|---|---|---|---|
| MON-1 | 0.5 | Company AS > Internal project 2026 > Internal Coordination | Design clarification | cal 13:30–14:00, Plaud 13:31 |

- **ID**: `<DAY>-<n>` (MON, TUE, WED, THU, FRI, SAT, SUN), numbered per day,
  stable for the whole conversation. Never renumber after the user has seen
  the table; new rows get the next free number, removed rows leave a gap.
- **h**: multiples of 0.5, minimum 0.5 (Severa rounds anyway).
- **Phase**: the full `path` from `find_phase`, exactly. No abbreviations.
- **Description**: short, English or the meeting's own title; this is the text
  that goes into Severa.
- **Evidence**: compact source refs with times (cal, mail, Teams, Linear IDs,
  AW session, Plaud/pensieve).
- Target about 7.5h per full workday; say so when a day is under or over, and do
  not pad a day with guesses.

After the tables, list only the open questions (numbered), each tied to row
IDs, for example "TUE-7: which customer phase?". Then: "Reply `go`, or edit by ID
(e.g. `TUE-3 1.5h`, `drop WED-2`, `MON-4 → R&D`)."

Apply edits by ID and re-show only the changed rows, unless the user asks for
the full table.

### Review app

Same rows, approved in a local page (`review-app/`, stdlib Python + SQLite) where the user
can approve/drop each row and edit hours, phase (dropdown of resolved phases) and
description. State lives outside the dotfiles repo, one file per ISO week:

```bash
APP=~/.claude/skills/severa-weekly-hours/review-app; D=~/.local/state/severa-weekly-hours
python3 $APP/jev_assist.py --input $D/<YYYY-Www>.json --output $D/<YYYY-Www>.json   # optional, needs TYPESAFE_API_KEY
python3 $APP/server.py init   --db $D/<YYYY-Www>.db --input $D/<YYYY-Www>.json
python3 $APP/server.py serve  --db $D/<YYYY-Www>.db --port 8766   # run_in_background; give http://127.0.0.1:8766
python3 $APP/server.py export --db $D/<YYYY-Www>.db               # on "go": log rows with status approve only
python3 $APP/server.py record --db $D/<YYYY-Www>.db --input results.json
```

Input schema is in `review-app/README.md`. Give every phase a `hint` built from the
conventions file's work → phase table (Jev scores far better with it), and put the day's
existing Severa rows in `days[].existing` so the duplicate check and the band's
"in Severa" list work. Jev is advisory: rows it disagrees with (confidence ≥ 0.6) or thinks
are already logged get a marker and a line in the row's evidence panel; never change a
row because of it. Mention flagged rows in the open questions. Offer the app alongside the tables; edits by ID
in chat still work (apply them with `PUT /api/row/<ID>` so the page stays in sync).
On "go", log from `export`, skip rows already `logged`, then `record` per ID
(`{"results":[{"id":"MON-1","ok":true,"summary":"logged 0.5h, guid …"}]}`).

## 5. Log to Severa

On "go":
- One `mcp__severa__log_hours` per row (parallel), with date, phase guid, hours,
  description. No work type.
- `phase_membership_required` → `join_phase`, retry once, tell the user.
- `duplicate_work_hour` → do not retry; show the existing entry and ask.
- Report per ID: logged / adjusted / failed. Then re-read with `list_hours` and
  give day totals. Point out any existing row that differs from what was logged
  (the user may have edited in the Severa UI in the meantime).

Amending: `mcp__severa__update_hours` by entry guid (keep a map ID → guid from
the log responses). If it fails with "patchDocument field is required", the
running severa MCP server predates the JSON Patch fix (severa-mcp ff0d3f6); ask
the user to reconnect it via `/mcp`.

## 6. Headless modes (scheduled, no user in the loop)

State dir `$D=~/.local/state/severa-weekly-hours`, app `$APP=~/.claude/skills/severa-weekly-hours/review-app`.
Never ask questions, never print tables, never write to Severa in `daily` mode. Put a phase
doubt in the row's `question` field (pick the most likely phase) and in `questions[]`.

### `daily` (argument `daily`, run by `punchcard-daily.timer` at 15:45 on workdays)

Goal: a review at http://punchcard.local with today's and last night's suggestions.

1. Period: yesterday 00:00 through now (Europe/Oslo). On Monday, yesterday means Friday.
2. Sections 1 to 3 as usual (all ActivityWatch hosts via `aw_all.sh`, calendar, mail, Teams,
   Linear, notes repo). Evidence after 17:00 yesterday is "last night": suggest it even when
   yesterday already has 7.5h, unless an existing Severa row's description already covers it.
   Skip a day only when it is complete and has no uncovered evening evidence.
3. Carry-over: if `$D/current.db` exists and is not executed, run `server.py export` on it and
   copy every row with status other than `drop` and `logged` false into the new proposal
   unchanged (same id, hours, phase, description, evidence). Treat those rows like Severa rows:
   never re-suggest the same work.
4. Write `$D/daily-<YYYY-MM-DD>.json` (schema in `review-app/README.md`; `period.start` =
   yesterday, `period.end` = today; `days[].existing` filled from `list_hours`), then
   `python3 $APP/server.py init --db $D/daily-<YYYY-MM-DD>.db --input ...` and
   `ln -sfn daily-<YYYY-MM-DD>.db $D/current.db`. The review service follows the symlink.
5. If there is nothing to suggest, write the JSON with `rows: []` anyway and still repoint
   `current.db`, so the bar shows nothing pending.
6. Print one line: `<n> rows, <dates>, <k> open questions`.

### `log-submitted` (argument `log-submitted`, run by `punchcard-log.timer`)

1. `python3 $APP/server.py status --db $D/current.db`. Stop unless `submittedAt` is set and
   `executedAt` is null.
2. Section 5 exactly: `export`, log every `approve` row not yet `logged`, `join_phase` and retry
   once on `phase_membership_required`, never retry a `duplicate_work_hour` (record it as
   `ok:false` with the message), then `record` the results per id.
3. Re-read with `list_hours` and print per-day totals for the period on one line each.

## 7. Afterwards

If the user gave new conventions (a new customer phase, a different category),
update the private conventions file, not this skill.
