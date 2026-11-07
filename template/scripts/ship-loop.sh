#!/usr/bin/env bash
# Unattended /ship-it: run it headless, again and again, until the board is done.
#
#   ./scripts/ship-loop.sh
#
# You do not need this in an interactive session — settings.json turns on
# autoContinueAtUsageLimit (the session waits for the reset and carries on) and the
# Stop hook keeps the loop from ending early. Use this when the run must outlive a
# terminal or a crashed session, e.g. inside tmux or `nohup`. Headless mode does not
# wait for usage resets on its own; this script does.
#
# Every run starts in a fresh context and resumes from disk (branch, plan, audit
# reports), which is exactly what /ship-it's "Before you start" section is for.
#
# Stops when: the board is done and /ship-it removed work/.shipping (exit 0),
# work/BLOCKED.md appears (exit 2), or three runs in a row change nothing (exit 3).
set -uo pipefail
cd "$(dirname "$0")/.."

WAIT=${SHIP_LOOP_WAIT:-900}        # seconds between retries while rate limited
MAX_IDLE=${SHIP_LOOP_MAX_IDLE:-3}
BOARD=work/BOARD.md
LOG=work/.ship-loop.log

[ -f "$BOARD" ] || { echo "ship-loop: no $BOARD — run /kickoff first" >&2; exit 1; }
command -v claude >/dev/null 2>&1 || { echo "ship-loop: claude not on PATH" >&2; exit 1; }

open_rows() { grep -cE '\|[[:space:]]*(todo|doing)[[:space:]]*\|[[:space:]]*$' "$BOARD" || true; }
signature() { { git rev-parse HEAD; git status --porcelain; cat "$BOARD"; } 2>/dev/null | cksum; }

idle=0; run=0
while :; do
  [ -f work/BLOCKED.md ] && { echo "ship-loop: blocked — see work/BLOCKED.md"; exit 2; }
  if [ "$(open_rows)" -eq 0 ] && [ ! -f work/.shipping ] && [ "$run" -gt 0 ]; then
    echo "ship-loop: board done"; exit 0
  fi

  run=$((run + 1))
  before=$(signature)
  echo "── ship-loop run $run  $(date '+%F %T')" | tee -a "$LOG"
  out=$(mktemp)
  # Never prompts: bypassPermissions, same as .claude/settings.json.
  claude -p "/ship-it" --permission-mode "${SHIP_LOOP_PERMISSION_MODE:-bypassPermissions}" 2>&1 | tee "$out" | tee -a "$LOG"

  # Only the tail is checked: the agent's own prose may mention limits.
  if tail -5 "$out" | grep -qiE "hit your [a-z ]*limit|usage limit|rate.?limit"; then
    rm -f "$out"
    echo "ship-loop: usage limit — retrying in $((WAIT / 60)) min" | tee -a "$LOG"
    sleep "$WAIT"; continue
  fi
  rm -f "$out"

  if [ "$(signature)" = "$before" ]; then
    idle=$((idle + 1))
    if [ "$idle" -ge "$MAX_IDLE" ]; then
      echo "ship-loop: $MAX_IDLE runs with no progress — stopping. See $LOG" | tee -a "$LOG"
      exit 3
    fi
    sleep 60
  else
    idle=0
  fi
done
