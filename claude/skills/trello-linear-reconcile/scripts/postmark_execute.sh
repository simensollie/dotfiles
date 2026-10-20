#!/usr/bin/env bash
# Execute a submitted Postmark review headlessly. Started by postmark-review.service's
# --on-submit hook (POSTMARK_DB set) or manually with the db path as $1.
set -uo pipefail
STATE=${POSTMARK_STATE:-$HOME/.local/state/trello-linear-reconcile}
SKILL=${POSTMARK_SKILL:-$HOME/.claude/skills/trello-linear-reconcile}
DB=${1:-${POSTMARK_DB:-$STATE/current.db}}
[ -e "$DB" ] || exit 0
DB=$(readlink -f "$DB")
ready=$(python3 "$SKILL/review-app/server.py" status --db "$DB" 2>/dev/null \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); print(int(bool(d.get("submittedAt")) and not d.get("executedAt")))' 2>/dev/null || echo 0)
[ "$ready" = "1" ] || exit 0
mkdir -p "$STATE/logs"; LOG=$STATE/logs/execute-$(basename "$DB" .db)-$(date +%F).log
exec 9>"$STATE/.execute-$(basename "$DB" .db).lock"; flock -n 9 || exit 0
{
  echo "=== $(date -Is) execute start db=$DB"
  claude -p "/trello-linear-reconcile execute-submitted --db $DB" --output-format text \
    --permission-mode acceptEdits \
    --allowedTools "Bash(python3:*),Bash(ls:*),Bash(mkdir:*),Read,Write,ToolSearch,mcp__trello__get_card,mcp__trello__get_lists,mcp__trello__get_cards_by_list_id,mcp__trello__move_card,mcp__trello__archive_card,mcp__trello__attach_file_to_card,mcp__trello__set_active_board,mcp__claude_ai_Linear__get_issue,mcp__claude_ai_Linear__list_issues,mcp__claude_ai_Linear__list_customers,mcp__claude_ai_Linear__save_issue,mcp__claude_ai_Linear__save_customer_need" \
    < /dev/null
  echo "=== $(date -Is) execute end rc=$?"
} >> "$LOG" 2>&1
done=$(python3 "$SKILL/review-app/server.py" status --db "$DB" 2>/dev/null | python3 -c 'import json,sys; print(int(bool(json.load(sys.stdin).get("executedAt"))))' 2>/dev/null || echo 0)
if [ "$done" = "1" ]; then
  notify-send -a Postmark "Review executed" "See $LOG"
else
  notify-send -u critical -a Postmark "Review NOT executed" "Check $LOG"
fi
