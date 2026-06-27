# Claude Preferences

## Writing Style

- Do not use em dashes (—). Use parentheses for asides, or commas for natural pauses.

## Linear

The team migrated from Jira to Linear (cutover 2026-06-26). Linear is the canonical issue tracker.

- **Default team:** `CER` (Certain QMS). Create new issues here unless the user specifies otherwise.
- **Tooling:** use the Linear MCP tools (e.g. `save_issue`).
- **No custom fields on creation:** Linear has no Visma Timesheet or Fix Version equivalent, so do not set them. (Legacy Jira required both; that rule is retired.)
- **Legacy Jira NK** (`netpower.atlassian.net`, cloud ID `2f72797b-c36b-4347-8c49-5fd1b2d28165`) is read-only, kept for ISO 27001 audit history. You may reference old `NK-####` tickets, but never create new issues there.
# graphify
- **graphify** (`~/.claude/skills/graphify/SKILL.md`) - any input to knowledge graph. Trigger: `/graphify`
When the user types `/graphify`, invoke the Skill tool with `skill: "graphify"` before doing anything else.
