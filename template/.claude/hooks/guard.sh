#!/usr/bin/env bash
# PreToolUse/Bash guard. Four things that must never happen, enforced by the
# harness rather than by prose in CLAUDE.md.
#
# Deny  -> print the JSON decision, exit 0.
# Allow -> exit 0 silently (normal permission flow continues).
set -uo pipefail

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[ -z "$CMD" ] && exit 0

deny() {
  jq -n --arg r "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $r
    }
  }'
  exit 0
}

BRANCH=$(git branch --show-current 2>/dev/null || echo "")

# 1. No commits on the trunk.
case "$BRANCH" in
  main|master)
    # Anchored at a command position (start, or after ; && || |) so that
    # merely mentioning the words -- echo "git commit" -- is not blocked.
    if printf '%s' "$CMD" | grep -qE '(^|[;&|]|&&|\|\|)[[:space:]]*git[[:space:]]+commit'; then
      deny "Blocked: commit on '$BRANCH'. Every change lands via a feature branch and a PR. Run: git checkout -b <type>/<slug>"
    fi
    ;;
esac

# 2. No force-push to the trunk.
if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+push' \
&& printf '%s' "$CMD" | grep -qE '(--force([^-]|$)|--force-with-lease|[[:space:]]-f([[:space:]]|$))' \
&& printf '%s' "$CMD" | grep -qE '(main|master)'; then
  deny "Blocked: force-push to the trunk. Trunk history is append-only."
fi

# 3. No rm -rf outside the project.
if printf '%s' "$CMD" | grep -qE 'rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*[fF]|-[a-zA-Z]*[fF][a-zA-Z]*[rR])'; then
  if printf '%s' "$CMD" | grep -qE 'rm[[:space:]]+-[a-zA-Z]+[[:space:]]+(/|~|\$HOME|\.\.)([[:space:]]|/|$)'; then
    deny "Blocked: recursive delete targeting a path outside the project."
  fi
fi

# 4. No piping a remote script into a shell.
if printf '%s' "$CMD" | grep -qE '(curl|wget)[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba|z|k)?sh'; then
  deny "Blocked: piping a remote script into a shell. Download it, read it, then run it."
fi

exit 0
