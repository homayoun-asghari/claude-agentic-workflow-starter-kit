#!/usr/bin/env bash
# Verify the kit itself. The kit ships a workflow; it has to pass its own.
set -uo pipefail
FAILED=()
step() { printf '\n──  %s\n' "$1"; shift; if "$@"; then echo "  ok"; else echo "  FAIL"; FAILED+=("$1"); fi; }

step "shell syntax" bash -c '
  for f in install.sh bin/newproject scripts/*.sh template/scripts/*.sh; do
    sh -n "$f" 2>/dev/null || bash -n "$f" || { echo "syntax error: $f"; exit 1; }
  done'

step "executable bits" bash -c '
  for f in install.sh bin/newproject scripts/*.sh template/scripts/*.sh; do
    [ -x "$f" ] || { echo "not executable: $f"; exit 1; }
  done'

step "template config" bash -c 'cd template && ../scripts/check-config.sh >/dev/null'

step "no orphan skill refs" bash -c '
  grep -q "spec-auditor" template/.claude/skills/ship-it/SKILL.md || { echo "ship-it never dispatches spec-auditor"; exit 1; }
  grep -q "verify.sh" template/.claude/skills/ship-it/SKILL.md    || { echo "ship-it never runs verify"; exit 1; }'

echo
if [ ${#FAILED[@]} -gt 0 ]; then echo "VERIFY FAILED: ${FAILED[*]}"; exit 1; fi
echo "VERIFY PASSED"
