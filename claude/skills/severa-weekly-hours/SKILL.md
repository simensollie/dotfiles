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

## 6. Afterwards

If the user gave new conventions (a new customer phase, a different category),
update the private conventions file, not this skill.
