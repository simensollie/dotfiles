# Project settings templates

Claude Code merges settings **user → project → local** (later wins):

| File | Scope | Git |
|------|-------|-----|
| `~/.claude/settings.json` (symlink to `claude/settings.json`) | every session on this machine | tracked here |
| `<repo>/.claude/settings.json` | that repo, for anyone who clones it | commit |
| `<repo>/.claude/settings.local.json` | that repo, just me | gitignore |

The global file enables **no plugins at all** (`"enabledPlugins": {}`) and carries only
the statusline, hooks, and the `autoMode.environment` facts that hold in every repo.
Plugins are opted into per repo. Since project settings win over user settings, a repo
can enable anything; it can also disable something (`"name@marketplace": false`).

Personal skills in `~/.claude/skills/` (prd-writer, prd-to-plan, qa, grill-me,
llm-council, omarchy, graphify, diagnose-crash) load from the user skills directory and
are **not** affected by plugin settings, they are available everywhere.

## Use

```bash
mkdir -p .claude
cp ~/dev/dotfiles/claude/templates/nextjs.settings.json .claude/settings.json
```

Then edit the `autoMode.environment` lines to name that project's real services,
domains, and protected environments. Keep `"$defaults"` first in each autoMode array -
it inherits Claude Code's built-in entries at that position; omit it and they are
replaced.

## Templates

Each is self-contained (core plugins + stack plugins), so one copy is all a repo needs.

- `core.settings.json`, superpowers, commit-commands, code-review, claude-md-management, security-guidance. For repos with no particular stack (dotfiles, docs, notes).
- `nextjs.settings.json`, core + vercel, typescript-lsp, playwright, frontend-design, feature-dev, code-simplifier. Supabase/Vercel permission rules.
- `expo.settings.json`, core + expo, typescript-lsp, frontend-design, feature-dev, code-simplifier. EAS build/submit/update rules.
- `work-pm.settings.json`, superpowers, claude-md-management, security-guidance, atlassian. Linear-canonical, regulated (ISO 9001/27001/31000/42001, GDPR) context.

## Context cost, measured

Enabled plugins consume context every turn via the skill listing, and some inject prose
at session start (re-paid after each `/clear` and each compaction).

| Plugin | Skill listing | Extra |
|---|---|---|
| vercel | 30 skills, ~2,050 tok | ~1,900 tok injected each SessionStart, MCP server, 3 agents, 5 commands |
| superpowers | 28 skills, ~1,105 tok |, |
| expo | 16 skills, ~1,250 tok |, |
| atlassian | 6 skills, ~780 tok |, |
| skill-creator, claude-code-setup, claude-md-management, frontend-design | ~90 tok each | agents (skill-creator 3, feature-dev 3, code-simplifier 1) |
| typescript-lsp, gopls-lsp, playwright, code-review, commit-commands | none | LSP tool, MCP server (playwright: 25 tools), slash commands |

The raw token count matters less than crowding: `skillListingBudgetFraction` (default
1% of the context window, in chars) and `skillListingMaxDescChars` (default 1536) cap
the whole listing, and descriptions get truncated across the board once it overflows -
which degrades trigger accuracy for the skills that actually matter in that repo.
