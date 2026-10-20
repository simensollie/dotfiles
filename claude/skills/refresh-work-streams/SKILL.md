---
name: refresh-work-streams
description: Refresh the Certain QMS work-streams dashboard (initiatives × developers, time split, PM signals) from GitLab, Linear, Jev and Sift, plus the Workplace Safety and ChemCenter view from Bitbucket and Jira, then republish the artifact. Triggers "refresh work streams", "update the streams dashboard", "who is working on what".
---

# Refresh work streams

Repo: `~/dev/netpower/tools/sift-eval`. Artifact: https://claude.ai/artifact/D4BenXXS1qSn5SrxAYBzH7 (publish to this `url`; read it first in a new session). One page, two views (tabs): Certain QMS (space `qms`, default) and Workplace Safety and ChemCenter (space `ms`). Every pipeline script takes `--space ms` for the second view (`scripts/space.py` resolves `scripts/initiatives-ms.json` and `data/streams-ms/`).

## Certain QMS view (space qms)

1. **Window.** Run `uv run python scripts/set_window.py` (sets `window` in `scripts/initiatives.json` to 14 days ending yesterday; the run day is incomplete and is excluded). `refresh_streams.sh` does this too. If Linear initiatives or team members changed (`list_initiatives`, `list_users team CER`), update `initiatives[]`, `people` and `display` there.
2. **Linear dump.** Remove old `data/streams/linear-issues-p*.json`. Call `mcp__claude_ai_Linear__list_issues` with team `CER`, `updatedAt` `-P21D`, `limit` 250, fields `id,title,status,statusType,priority,estimate,assignee,project,projectId,parentId,labels,createdAt,updatedAt,startedAt,completedAt,url,gitBranchName`. The result overflows the tool output and is saved to a file; parse it with Python (`raw[raw.index('{'):]`), write `data/streams/linear-issues-pN.json`, and continue with the returned `cursor` until the oldest `updatedAt` on a page is before `window.start`. Issues updated after `window.end` are harmless: `build_streams.py` only counts activity inside the window.
3. **Unattended steps.** `scripts/refresh_streams.sh` (GitLab via glab, Jev classification, Sift MR eval, aggregation, page). Takes 5 to 10 minutes; run in the background and wait.
4. **Agent review.** Run the `qms-work-streams` workflow script saved at `scripts/qms-work-streams.workflow.js` with `args` built from `data/streams/wf-args.json` (regenerate it: devs with load >= 20, initiatives with load >= 5 except `other`; base = absolute path of `data/streams`, window string). Wait for completion; outputs land in `data/streams/review/`.

## Workplace Safety and ChemCenter view (space ms)

5. **Window.** `uv run python scripts/set_window.py --space ms` (same 14 days, in `scripts/initiatives-ms.json`).
6. **Jira dump.** Remove old `data/streams-ms/jira-raw-p*.json`. Call `mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql` (cloudId `2f72797b-c36b-4347-8c49-5fd1b2d28165`) with JQL `project in (CHEM, WS) AND updated >= "<window.start>" ORDER BY updated DESC`, fields `summary,status,issuetype,priority,labels,assignee,reporter,parent,created,updated,resolutiondate,statuscategorychangedate,fixVersions,project`, maxResults 100, paging with `nextPageToken`. Each result lands in a tool-results file; parse with Python (`raw[raw.index('{'):]`) and save `issues.nodes` as `data/streams-ms/jira-raw-pN.json` (a small last page comes back inline: write its nodes to a file too).
7. **Unattended steps.** `scripts/refresh_streams_ms.sh` (Bitbucket PRs and diffs with the scoped token in `~/.config/agent-private/bitbucket/env`, Jira conversion, Jev, Sift, stack, aggregation, page). Run in the background and wait.
8. **Agent review.** Same workflow script with `args` from `data/streams-ms/wf-args.json` (regenerate: devs with load >= 10, initiatives with load >= 5 except `other`, base = absolute path of `data/streams-ms`, keep `context` and `tracker` from the existing file). Outputs land in `data/streams-ms/review/`.

## Page and follow-ups

9. **Page.** `uv run python scripts/build_streams_dashboard.py` renders both views into `out/streams.html`; copy it to the scratchpad as `certain-qms-work-streams.html`, publish with the Artifact tool to the artifact URL above (`action: read` it first), label with the window end date.
10. **Hidden streams.** If a view's `data/<space>/review/clusters.json` lists `undeclared_streams` not already present as `h-*` entries in that space's `initiatives*.json`, add them there (`hidden: true`, `desc` from the evidence, `suggested_home`, a `color`), re-run `classify_streams.py` for that space without `--resume`, then `build_streams.py` and the workflow once more. `min_share` (default 0.02) folds small streams.
11. **Plan.** `plan` in `scripts/initiatives.json` holds the six-month plan for Certain QMS (themes, explicitly-out items, planned stream keys, customer and off-plan projects). `initiatives-ms.json` has no plan yet (themes empty): add one when a roadmap exists and the planned-versus-unplanned section fills in by itself.
12. Report: per view, window, counts, unplanned share, top critic findings, hidden streams found; one link.

Do not commit `data/` or `out/` (gitignored, contain diffs). Commit script changes only if asked.
