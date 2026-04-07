#!/bin/bash
input=$(cat)
NOW=$(date +%s)

# ─── Catppuccin Macchiato (true color) ─────────────────────────────
MAUVE=$'\033[38;2;198;160;246m'
BLUE=$'\033[38;2;138;173;244m'
TEAL=$'\033[38;2;139;213;202m'
GREEN=$'\033[38;2;166;218;149m'
YELLOW=$'\033[38;2;238;212;159m'
RED=$'\033[38;2;237;135;150m'
PEACH=$'\033[38;2;245;169;127m'
FLAMINGO=$'\033[38;2;240;198;198m'
LAVENDER=$'\033[38;2;183;189;248m'
SKY=$'\033[38;2;145;215;227m'
OVERLAY=$'\033[38;2;110;115;141m'
SUBTEXT=$'\033[38;2;165;173;203m'
RST=$'\033[0m'
SEP=" ${OVERLAY}│${RST} "

# ─── Parse JSON (single jq call) ──────────────────────────────────
{
  read -r MODEL
  read -r DIR
  read -r PCT_RAW
  read -r CTX_SIZE
  read -r FIVE_PCT
  read -r FIVE_RESET
  read -r SEVEN_PCT
  read -r COST
} < <(echo "$input" | jq -r '
  (.model.display_name // "—"),
  (.workspace.current_dir // ""),
  (.context_window.used_percentage // ""),
  (.context_window.context_window_size // 200000),
  (.rate_limits.five_hour.used_percentage // ""),
  (.rate_limits.five_hour.resets_at // ""),
  (.rate_limits.seven_day.used_percentage // ""),
  (.cost.total_cost_usd // 0)
')

# ─── Effort level ─────────────────────────────────────────────────
EFFORT=$(jq -r '.effortLevel // "medium"' ~/.claude/settings.json 2>/dev/null)
case "$EFFORT" in
  low)    EFFORT_SEG="${SUBTEXT}▽ low${RST}" ;;
  high)   EFFORT_SEG="${PEACH}▲ high${RST}" ;;
  max)    EFFORT_SEG="${FLAMINGO}⬆ max${RST}" ;;
  *)      EFFORT_SEG="${YELLOW}◆ med${RST}" ;;
esac

# ─── Directory (clickable OSC 8) ──────────────────────────────────
DNAME="${DIR##*/}"
DIR_SEG="${BLUE}󰉋 "$'\033]8;;file://'"${DIR}"$'\033\\'"${DNAME}"$'\033]8;;\033\\'"${RST}"

# ─── Git (cached 5s, keyed by dir) ────────────────────────────────
GIT=""
if [[ -n "$DIR" ]]; then
  CF="/tmp/claudeline-$(echo "$DIR" | cksum | cut -d' ' -f1)"
  BRANCH="" STAGED=0 MODIFIED=0
  if [[ -f "$CF" ]] && (( NOW - $(stat -f %m "$CF") < 5 )); then
    IFS=$'\t' read -r BRANCH STAGED MODIFIED < "$CF"
  elif git -C "$DIR" -c gc.auto=0 rev-parse --git-dir >/dev/null 2>&1; then
    BRANCH=$(git -C "$DIR" -c gc.auto=0 branch --show-current 2>/dev/null)
    while IFS= read -r l; do
      [[ "${l:0:1}" != " " && "${l:0:1}" != "?" ]] && ((STAGED++))
      [[ "${l:1:1}" != " " && "${l:1:1}" != "?" ]] && ((MODIFIED++))
    done < <(git -C "$DIR" -c gc.auto=0 status --porcelain 2>/dev/null)
    printf '%s\t%s\t%s' "$BRANCH" "$STAGED" "$MODIFIED" > "$CF"
  fi
  if [[ -n "$BRANCH" ]]; then
    GIT="${SEP}${TEAL}󰘬 ${BRANCH}${RST}"
    (( STAGED > 0 ))   && GIT+=" ${GREEN}+${STAGED}${RST}"
    (( MODIFIED > 0 )) && GIT+=" ${YELLOW}~${MODIFIED}${RST}"
  fi
fi

# ═══ LINE 1: model │ effort │ dir │ git ═══════════════════════════
printf '%s\n' "${MAUVE}✦ ${MODEL}${RST}${SEP}${EFFORT_SEG}${SEP}${DIR_SEG}${GIT}"

# ─── Context bar ──────────────────────────────────────────────────
PCT=0
if [[ -n "$PCT_RAW" && "$PCT_RAW" != "null" ]]; then
  PCT=${PCT_RAW%%.*}
  (( PCT < 0 )) && PCT=0; (( PCT > 100 )) && PCT=100
fi
if   (( PCT >= 60 )); then BC="$RED"
elif (( PCT >= 40 )); then BC="$YELLOW"
else BC="$GREEN"; fi

F=$((PCT / 10)); E=$((10 - F)); BAR=""
for ((i=0; i<F; i++)); do BAR+="█"; done
for ((i=0; i<E; i++)); do BAR+="░"; done

# ─── Detect billing type: rate limits present = subscription ───────
IS_SUB=false
[[ -n "$FIVE_PCT" && "$FIVE_PCT" != "null" ]] && IS_SUB=true

# ─── 5h rate limit with reset countdown (subscription only) ───────
RLIM=""
if $IS_SUB; then
  FI=$(printf '%.0f' "$FIVE_PCT")
  if   (( FI >= 80 )); then RC="$RED"
  elif (( FI >= 50 )); then RC="$YELLOW"
  else RC="$LAVENDER"; fi
  RLIM="${SEP}${RC}󰥔 5h: ${FI}%${RST}"
  if [[ -n "$FIVE_RESET" && "$FIVE_RESET" != "null" ]]; then
    REM=$((FIVE_RESET - NOW))
    (( REM > 0 )) && RLIM+=" ${SUBTEXT}$((REM / 3600))h$(((REM % 3600) / 60))m${RST}"
  fi
fi

# ─── 7d rate limit (subscription only) ────────────────────────────
if $IS_SUB && [[ -n "$SEVEN_PCT" && "$SEVEN_PCT" != "null" ]]; then
  SI=$(printf '%.0f' "$SEVEN_PCT")
  if   (( SI >= 80 )); then SC="$RED"
  elif (( SI >= 50 )); then SC="$YELLOW"
  else SC="$SUBTEXT"; fi
  RLIM+="${SEP}${SC}7d: ${SI}%${RST}"
fi

# ─── Cost (API billing only) ─────────────────────────────────────
COST_SEG=""
if ! $IS_SUB && [[ -n "$COST" && "$COST" != "null" && "$COST" != "0" ]]; then
  COST_FMT=$(printf '$%.2f' "$COST")
  COST_SEG="${SEP}${OVERLAY}${COST_FMT}${RST}"
fi

# ═══ LINE 2: context │ 5h │ 7d │ cost ════════════════════════════
printf '%s\n' "${BC}${BAR}${RST} ${PCT}%${RLIM}${COST_SEG}"
