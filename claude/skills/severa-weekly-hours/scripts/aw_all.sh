#!/usr/bin/env bash
# Run aw_summary.py on every ActivityWatch host for START END (ISO dates).
# The current machine runs locally; others over ssh. Optional hosts that are
# unreachable (or have no aw-server) are skipped with one line.
set -u
START=$1; END=$2
DIR=$(cd "$(dirname "$0")" && pwd)
ME=$(hostname -s | tr '[:upper:]' '[:lower:]')
# target|required
HOSTS=(
  "siso@simen-beelink|required"
  "siso@simen-desktop|optional"
  "simensollie@simens-netpowermac|optional"
)
for entry in "${HOSTS[@]}"; do
  target=${entry%%|*}; kind=${entry##*|}; host=${target#*@}
  echo "################ $host ($kind)"
  if [[ "$ME" == "$host" ]]; then
    python3 "$DIR/aw_summary.py" "$START" "$END" 2>&1 || echo "SKIPPED: local aw-server not reachable"
  elif ssh -o ConnectTimeout=5 -o BatchMode=yes "$target" 'curl -sf -m 3 localhost:5600/api/0/info >/dev/null' 2>/dev/null; then
    ssh -o ConnectTimeout=5 -o BatchMode=yes "$target" python3 - "$START" "$END" < "$DIR/aw_summary.py" 2>&1
  else
    echo "SKIPPED: $target unreachable or aw-server down"
  fi
done
