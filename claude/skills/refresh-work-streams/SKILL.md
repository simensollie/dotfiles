---
name: refresh-work-streams
description: Refresh the Certain QMS work-streams dashboard (initiatives × developers, time split, PM signals) from GitLab, Linear, Jev and Sift, then republish the artifact. Triggers "refresh work streams", "update the streams dashboard", "who is working on what".
---

# Refresh work streams

Repo: `~/dev/netpower/tools/sift-eval`. Artifact: https://claude.ai/artifact/D4BenXXS1qSn5SrxAYBzH7 (publish to this `url`; read it first in a new session).

1. **Window.** Run `uv run python scripts/set_window.py` (sets `window` in `scripts/initiatives.json` to 14 days ending yesterday; the run day is incomplete and is excluded). `refresh_streams.sh` does this too. If Linear initiatives or team members changed (`list_initiatives`, `list_users team CER`), update `initiatives[]`, `people` and `display` there.
2. **Linear dump.** Remove old `data/streams/linear-issues-p*.json`. Call `mcp__claude_ai_Linear__list_issues` with team `CER`, `updatedAt` `-P21D`, `limit` 250, fields `id,title,status,statusType,priority,estimate,assignee,project,projectId,parentId,labels,createdAt,updatedAt,startedAt,completedAt,url,gitBranchName`. The result overflows the tool output and is saved to a file; parse it with Python (`raw[raw.index('{'):]`), write `data/streams/linear-issues-pN.json`, and continue with the returned `cursor` until the oldest `updatedAt` on a page is before `window.start`. Issues updated after `window.end` are harmless: `build_streams.py` only counts activity inside the window.
3. **Unattended steps.** `scripts/refresh_streams.sh` (GitLab via glab, Jev classification, Sift MR eval, aggregation, page). Takes 5 to 10 minutes; run in the background and wait.
4. **Agent review.** Run the `qms-work-streams` workflow script saved at `scripts/qms-work-streams.workflow.js` with `args` built from `data/streams/wf-args.json` (regenerate it: devs with load >= 20, initiatives with load >= 5 except `other`; base = absolute path of `data/streams`, window string). Wait for completion; outputs land in `data/streams/review/`.
5. **Page.** `uv run python scripts/build_streams_dashboard.py`, copy `out/streams.html` to the scratchpad as `certain-qms-work-streams.html`, publish with the Artifact tool to the artifact URL above (`action: read` it first), label with the window end date.
6. **Hidden streams.** If the cluster reviewer's `data/streams/review/clusters.json` lists `undeclared_streams` not already present as `h-*` entries in `scripts/initiatives.json`, add them there (`hidden: true`, `desc` from the evidence, `suggested_home`), re-run `classify_streams.py` without `--resume`, then `build_streams.py` and the workflow once more. `min_share` (default 0.02) folds small streams.
7. **Plan.** `plan` in `scripts/initiatives.json` holds the six-month plan (themes, explicitly-out items, planned stream keys, customer and off-plan projects). Update it when the plan changes (new board deck) or when new Linear projects appear that are clearly customer-feedback or off-plan; `classify_streams.py` sends the themes to Jev for the serves-plan question.
8. Report: window, counts, unplanned share, top 5 critic findings, hidden streams found, link.

Do not commit `data/` or `out/` (gitignored, contain diffs). Commit script changes only if asked.
