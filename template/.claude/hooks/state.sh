#!/usr/bin/env bash
# Project state, read from disk — never from the model's memory.
#
#   state.sh session      SessionStart hook: print where we are. Runs on startup,
#                         resume and after every context compaction, so the agent
#                         always knows what is being built and which step it is on.
#   state.sh precompact   PreCompact hook: tell the compaction summary what to keep.
#   state.sh stop         Stop hook: while /ship-it is running (work/.shipping exists)
#                         and work remains, do not let the turn end.
#
# Usage limits do not fire Stop (they fire StopFailure), so this never fights the
# automatic continue-at-reset in settings.json.
set -uo pipefail
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0

BOARD=work/BOARD.md
MARKER=work/.shipping

open_rows() { grep -cE '\|[[:space:]]*(todo|doing)[[:space:]]*\|[[:space:]]*$' "$BOARD" 2>/dev/null || true; }
rows()      { grep -cE "\|[[:space:]]*$1[[:space:]]*\|[[:space:]]*\$" "$BOARD" 2>/dev/null || true; }
next_slug() { grep -E '\|[[:space:]]*(doing|todo)[[:space:]]*\|[[:space:]]*$' "$BOARD" 2>/dev/null | head -1 | awk -F'|' '{gsub(/ /,"",$3); print $3}'; }
cur_slug()  { b=$(git branch --show-current 2>/dev/null); case "$b" in */*) echo "${b#*/}";; *) next_slug;; esac; }
signature() { { git rev-parse HEAD; git status --porcelain; } 2>/dev/null | cksum | awk '{print $1}'; }

print_state() {
  [ -f "$BOARD" ] || { echo "No work/BOARD.md yet — /kickoff has not run."; return; }
  local slug head
  slug=$(cur_slug)
  head=$(git log -1 --format='%h %s' 2>/dev/null)
  echo "## Where we are (read from disk — trust this over memory)"
  echo "branch:   $(git branch --show-current 2>/dev/null)   HEAD: $head"
  echo "tag:      $(git describe --tags --abbrev=0 2>/dev/null || echo none)"
  echo "dirty:    $(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') uncommitted file(s)"
  echo "board:    $(rows done) done, $(rows doing) doing, $(rows todo) todo — next: $(next_slug)"
  if [ -n "$slug" ] && [ -f "work/$slug/plan.md" ]; then
    echo "plan:     work/$slug/plan.md"
    grep -m1 -E '^Now:' "work/$slug/plan.md" | sed 's/^/          /'
    grep -m1 -E '^[[:space:]]*- \[ \]' "work/$slug/plan.md" | sed 's/^[[:space:]]*/          first open step: /'
  fi
  if [ -n "$slug" ] && [ -f "work/$slug/audit.md" ]; then
    local sha verdict
    sha=$(grep -m1 '^AUDITED:' "work/$slug/audit.md" | awk '{print $2}')
    verdict=$(grep -E '^VERDICT:' "work/$slug/audit.md" | tail -1)
    if [ "$sha" = "$(git rev-parse HEAD 2>/dev/null)" ]; then
      echo "audit:    work/$slug/audit.md — $verdict — matches HEAD, reuse it"
    else
      echo "audit:    work/$slug/audit.md — $verdict — for an older commit"
    fi
  fi
  ls docs/audits/*.md >/dev/null 2>&1 && echo "audits:   $(ls docs/audits/*.md | tr '\n' ' ')"
  [ -f "$MARKER" ]       && echo "loop:     /ship-it is running (work/.shipping) — keep going"
  [ -f work/BLOCKED.md ] && { echo "BLOCKED:  work/BLOCKED.md —"; sed 's/^/          /' work/BLOCKED.md | head -10; }
}

case "${1:-session}" in
  session)
    print_state
    ;;

  precompact)
    cat <<'EOF'
When summarising, keep verbatim: the user's latest instructions and every decision
they made in this session; the current branch and slug; which /ship-it step (1-11,
or the milestone gate) is in progress; the audit round and any open BLOCKING
findings; anything learned that is not yet written to disk. Drop file contents,
command output and search traces — they are on disk and can be re-read.
EOF
    echo
    print_state
    ;;

  stop)
    input=$(cat)
    [ -f "$MARKER" ] || exit 0           # not in a /ship-it run: never interfere
    [ -f work/BLOCKED.md ] && exit 0     # waiting on the user, by design
    [ -f "$BOARD" ] || exit 0

    # No-progress guard: if three forced continuations in a row change nothing on
    # disk, let it stop instead of burning tokens in a loop.
    sig=$(signature)
    prev=$(sed -n 1p "$MARKER" 2>/dev/null); count=$(sed -n 2p "$MARKER" 2>/dev/null)
    if echo "$input" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && [ "$sig" = "$prev" ]; then
      count=$(( ${count:-0} + 1 ))
    else
      count=0
    fi
    printf '%s\n%s\n' "$sig" "$count" > "$MARKER"
    [ "$count" -ge 3 ] && exit 0

    if [ "$(open_rows)" -gt 0 ]; then
      reason="/ship-it is not finished: $(open_rows) slice(s) on work/BOARD.md are still todo/doing. Continue with the next step now. If you are genuinely blocked on something only the user can provide, write work/BLOCKED.md and stop."
    else
      reason="Every slice is done, but /ship-it has not finished: run any outstanding milestone gate and release, verify the Done checklist, then rm work/.shipping and report."
    fi
    printf '{"decision":"block","reason":"%s"}\n' "$reason"
    ;;
esac
exit 0
