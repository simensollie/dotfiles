#!/usr/bin/env bash
# Daily headless run: ask Claude Code for timesheet suggestions (yesterday evening + today)
# and seed the review at http://punchcard.local. Never logs hours.
# Needs: claude CLI with the severa, M365, inbox-triage and Linear MCP servers connected.
set -uo pipefail
D=${PUNCHCARD_STATE:-$HOME/.local/state/severa-weekly-hours}
SKILL=${PUNCHCARD_SKILL:-$HOME/.claude/skills/severa-weekly-hours}
mkdir -p "$D/logs"
LOG=$D/logs/daily-$(date +%F).log
{
  echo "=== $(date -Is) daily start"
  claude -p "/severa-weekly-hours daily" --output-format text \
    --permission-mode acceptEdits \
    --allowedTools "Bash(python3:*),Bash(ssh:*),Bash(ln:*),Bash(ls:*),Bash(cat:*),Bash(head:*),Bash(tail:*),Bash(grep:*),Bash(awk:*),Bash(sed:*),Bash(find:*),Bash(mkdir:*),Bash(date:*),Bash(git log:*),Bash(git show:*),Bash($SKILL/scripts/*),Read,Write,Edit,ToolSearch,mcp__severa__whoami,mcp__severa__list_hours,mcp__severa__report_registrations,mcp__severa__find_phase,mcp__inbox-triage__list_calendar_events,mcp__claude_ai_Microsoft_365__outlook_email_search,mcp__claude_ai_Microsoft_365__chat_message_search,mcp__claude_ai_Linear__list_issues"
  rc=$?
  echo "=== $(date -Is) daily end rc=$rc"
} >> "$LOG" 2>&1
# Tell the bar and the user.
pending=$(python3 "$SKILL/review-app/status.py" 2>/dev/null \
  | python3 -c 'import json,sys; print(json.load(sys.stdin).get("pending",0))' 2>/dev/null || echo "?")
omarchy-shell -q siso.punchcard refresh 2>/dev/null || true
if [ "$pending" != "0" ] && [ "$pending" != "?" ]; then
  notify-send -a Punchcard "Timesheet suggestions ready" "$pending entries to review at punchcard.local" 2>/dev/null || true
fi
