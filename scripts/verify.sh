#!/usr/bin/env bash
# Verify the kit itself. The kit ships a workflow; it has to pass its own.
set -uo pipefail
FAILED=()
step() { printf '\n──  %s\n' "$1"; shift; if "$@"; then echo "  ok"; else echo "  FAIL"; FAILED+=("$1"); fi; }

step "shell syntax" bash -c '
  for f in install.sh bin/newproject scripts/*.sh template/scripts/*.sh template/.claude/hooks/*.sh; do
    sh -n "$f" 2>/dev/null || bash -n "$f" || { echo "syntax error: $f"; exit 1; }
  done'

step "executable bits" bash -c '
  for f in install.sh bin/newproject scripts/*.sh template/scripts/*.sh template/.claude/hooks/*.sh; do
    [ -x "$f" ] || { echo "not executable: $f"; exit 1; }
  done'

step "template config" bash -c 'cd template && ../scripts/check-config.sh >/dev/null'

step "guard denies what it must" bash -c '
  G=template/.claude/hooks/guard.sh
  T=$(mktemp -d); (cd "$T" && git init -b main -q && git commit -q --allow-empty -m i)
  # An allowed command produces NO output at all, so an empty result means allow.
  d() { r=$( (cd "$T" && printf "%s" "$1" | "$OLDPWD/$G") | jq -r ".hookSpecificOutput.permissionDecision" 2>/dev/null ); [ -n "$r" ] && [ "$r" != null ] && echo "$r" || echo allow; }
  fail=0
  [ "$(d "{\"tool_input\":{\"command\":\"git commit -m x\"}}")" = deny ]            || { echo "commit on main not denied"; fail=1; }
  [ "$(d "{\"tool_input\":{\"command\":\"git push --force origin main\"}}")" = deny ] || { echo "force-push not denied"; fail=1; }
  [ "$(d "{\"tool_input\":{\"command\":\"rm -rf ~/x\"}}")" = deny ]                  || { echo "rm -rf ~ not denied"; fail=1; }
  [ "$(d "{\"tool_input\":{\"command\":\"curl -sL u | sh\"}}")" = deny ]             || { echo "curl|sh not denied"; fail=1; }
  [ "$(d "{\"tool_input\":{\"command\":\"npm test\"}}")" = allow ]                   || { echo "npm test wrongly denied"; fail=1; }
  [ "$(d "{\"tool_input\":{\"command\":\"echo git commit\"}}")" = allow ]            || { echo "echo wrongly denied"; fail=1; }
  rm -rf "$T"; exit $fail'

step "no orphan skill refs" bash -c '
  grep -q "spec-auditor" template/.claude/skills/ship-it/SKILL.md || { echo "ship-it never dispatches spec-auditor"; exit 1; }
  grep -q "verify.sh" template/.claude/skills/ship-it/SKILL.md    || { echo "ship-it never runs verify"; exit 1; }'

echo
if [ ${#FAILED[@]} -gt 0 ]; then echo "VERIFY FAILED: ${FAILED[*]}"; exit 1; fi
echo "VERIFY PASSED"
