# Claude Preferences

## Writing Style

- Do not use em dashes (—). Use parentheses for asides, or commas for natural pauses.
- When reporting information to me, be extremely concise and sacrifice grammar for the sake of concision.

## How I work

- Prefer subagents for exploration, verification, and large read/research tasks. Fan out (several in parallel) when scanning many files, reviewing skills/PRs, or cross-checking a guide or claim against a codebase.
- Verify before asserting. Check the code (or official docs, e.g. via context7) before claiming how something behaves or filing an issue. Never assume a feature does or doesn't exist, and don't create a tracker issue for something until you've confirmed it isn't already implemented.

## Issue tracking

**Pick the tracker by repo, not by habit:**

- **Personal projects** (any repo whose `origin` is `github.com:simensollie/*`): use **GitHub Issues** via the `gh` CLI. Do NOT create Linear or Jira issues for these. Current personal repos: `velstyrt`, `gatheround`, `gatheround-app`, `gatheround-design`, `giftify`, `tempo`, `plaud-cli`, `aw-watcher-cmux`, `dotfiles`. (List is illustrative; the `simensollie/*` origin is the rule.)
- **Work projects** (Certain QMS / NP365, etc.): use **Linear**, per the section below.

### Linear (work)

The team migrated from Jira to Linear (cutover 2026-06-26). Linear is the canonical issue tracker for work.

- **Default team:** `CER` (Certain QMS). Create new issues here unless the user specifies otherwise.
- **Tooling:** use the Linear MCP tools (e.g. `save_issue`).
- **No custom fields on creation:** Linear has no Visma Timesheet or Fix Version equivalent, so do not set them. (Legacy Jira required both; that rule is retired.)
- **Legacy Jira NK** (`netpower.atlassian.net`, cloud ID `2f72797b-c36b-4347-8c49-5fd1b2d28165`) is read-only, kept for ISO 27001 audit history. You may reference old `NK-####` tickets, but never create new issues there.
