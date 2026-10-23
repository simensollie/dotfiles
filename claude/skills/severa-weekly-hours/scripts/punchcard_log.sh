#!/usr/bin/env bash
# Log a submitted review to Severa. Cheap check first; Claude only runs when there is work.
set -uo pipefail
D=${PUNCHCARD_STATE:-$HOME/.local/state/severa-weekly-hours}
SKILL=${PUNCHCARD_SKILL:-$HOME/.claude/skills/severa-weekly-hours}
[ -e "$D/current.db" ] || exit 0
ready=$(python3 "$SKILL/review-app/status.py" 2>/dev/null \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(int(bool(d.get("submittedAt")) and not d.get("executedAt")))' 2>/dev/null || echo 0)
[ "$ready" = "1" ] || exit 0
mkdir -p "$D/logs"; LOG=$D/logs/log-$(date +%F).log
{
  echo "=== $(date -Is) log start"
  claude -p "/severa-weekly-hours log-submitted" --output-format text \
    --permission-mode acceptEdits \
    --allowedTools "Bash(python3:*),Bash(ls:*),Bash(cat:*),Read,Write,ToolSearch,mcp__severa__whoami,mcp__severa__list_hours,mcp__severa__find_phase,mcp__severa__log_hours,mcp__severa__join_phase,mcp__severa__update_hours"
  echo "=== $(date -Is) log end rc=$?"
} >> "$LOG" 2>&1
omarchy-shell -q siso.punchcard refresh 2>/dev/null || true
notify-send -a Punchcard "Timesheet logged" "Submitted entries sent to Severa, see $LOG" 2>/dev/null || true
