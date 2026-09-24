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
  read -r PARAMS
  read -r MAX_MODE
  read -r DIR
  read -r PCT_RAW
  read -r TOKENS
  read -r CTX_SIZE
  read -r WORKTREE
  read -r VIM
} < <(echo "$input" | jq -r '
  (.model.display_name // "—"),
  (.model.param_summary // ""),
  (.model.max_mode // false),
  (.workspace.current_dir // .cwd // ""),
  (.context_window.used_percentage // ""),
  (.context_window.total_input_tokens // ""),
  (.context_window.context_window_size // 200000),
  (.worktree.name // ""),
  (.vim.mode // "")
')

# ─── Effort level (from model param summary) ──────────────────────
EFFORT=$(echo "$PARAMS" | tr '[:upper:]' '[:lower:]' | tr -d '()')
case "$EFFORT" in
  *low*)            EFFORT_SEG="${SUBTEXT}▽ low${RST}" ;;
  *high*)           EFFORT_SEG="${PEACH}▲ high${RST}" ;;
  *max*)            EFFORT_SEG="${FLAMINGO}⬆ max${RST}" ;;
  *med*|*balanced*) EFFORT_SEG="${YELLOW}◆ med${RST}" ;;
  "")               EFFORT_SEG="" ;;
  *)                EFFORT_SEG="${YELLOW}◆ ${EFFORT}${RST}" ;;
esac
[[ "$MAX_MODE" == "true" ]] && EFFORT_SEG="${EFFORT_SEG:+${EFFORT_SEG} }${FLAMINGO}⚡${RST}"
[[ -n "$EFFORT_SEG" ]] && EFFORT_SEG="${SEP}${EFFORT_SEG}"

# ─── Directory (clickable OSC 8) ──────────────────────────────────
DNAME="${DIR##*/}"
DIR_SEG=""
[[ -n "$DIR" ]] && DIR_SEG="${SEP}${BLUE}󰉋 "$'\033]8;;file://'"${DIR}"$'\033\\'"${DNAME}"$'\033]8;;\033\\'"${RST}"

# ─── Git (cached 5s, keyed by dir) ────────────────────────────────
# GNU stat and BSD stat spell mtime differently
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

GIT=""
if [[ -n "$DIR" ]]; then
  CF="/tmp/cursorline-$(echo "$DIR" | cksum | cut -d' ' -f1)"
  BRANCH="" STAGED=0 MODIFIED=0
  if [[ -f "$CF" ]] && (( NOW - $(mtime "$CF") < 5 )); then
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

# ─── Worktree ─────────────────────────────────────────────────────
WT_SEG=""
[[ -n "$WORKTREE" ]] && WT_SEG="${SEP}${SKY}󰙅 ${WORKTREE}${RST}"

# ═══ LINE 1: model │ effort │ dir │ git │ worktree ════════════════
printf '%s\n' "${MAUVE}✦ ${MODEL}${RST}${EFFORT_SEG}${DIR_SEG}${GIT}${WT_SEG}"

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

# ─── Token counts (Cursor has no cost/rate-limit fields) ──────────
TOK_SEG=""
if [[ -n "$TOKENS" && "$TOKENS" != "null" && "$TOKENS" != "0" ]]; then
  TOK_SEG="${SEP}${OVERLAY}$((TOKENS / 1000))k/$((CTX_SIZE / 1000))k${RST}"
fi

# ─── Vim mode ─────────────────────────────────────────────────────
VIM_SEG=""
if [[ -n "$VIM" && "$VIM" != "null" ]]; then
  if [[ "$VIM" == "NORMAL" ]]; then VIM_SEG="${SEP}${LAVENDER}NORMAL${RST}"
  else VIM_SEG="${SEP}${GREEN}${VIM}${RST}"; fi
fi

# ═══ LINE 2: context │ tokens │ vim ══════════════════════════════
printf '%s\n' "${BC}${BAR}${RST} ${PCT}%${TOK_SEG}${VIM_SEG}"
