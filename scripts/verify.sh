#!/usr/bin/env bash
# Verify the kit itself. The kit ships a workflow; it has to pass its own.
set -uo pipefail
FAILED=()
step() { local name=$1; printf '\n──  %s\n' "$name"; shift; if "$@"; then echo "  ok"; else echo "  FAIL"; FAILED+=("$name"); fi; }

step "shell syntax" bash -c '
  for f in install.sh bin/newproject scripts/*.sh template/scripts/*.sh template/.claude/hooks/*.sh; do
    sh -n "$f" 2>/dev/null || bash -n "$f" || { echo "syntax error: $f"; exit 1; }
  done'

step "executable bits" bash -c '
  for f in install.sh bin/newproject scripts/*.sh template/scripts/*.sh template/.claude/hooks/*.sh; do
    [ -x "$f" ] || { echo "not executable: $f"; exit 1; }
  done'

step "template config" bash -c 'cd template && ../scripts/check-config.sh >/dev/null'

step "no orphan skill refs" bash -c '
  grep -q "spec-auditor" template/.claude/skills/ship-it/SKILL.md || { echo "ship-it never dispatches spec-auditor"; exit 1; }
  grep -q "verify.sh" template/.claude/skills/ship-it/SKILL.md    || { echo "ship-it never runs verify"; exit 1; }
  for a in security-auditor perf-auditor; do
    grep -q "$a" template/.claude/skills/ship-it/SKILL.md || { echo "ship-it never dispatches $a"; exit 1; }
  done
  grep -q "tag-release.sh" template/.claude/skills/ship-it/SKILL.md || { echo "ship-it never tags a release"; exit 1; }
  grep -q "scripts/merge.sh" template/.claude/skills/ship-it/SKILL.md || { echo "ship-it never merges through the gate"; exit 1; }
  ! grep -qE "^gh pr merge" template/.claude/skills/ship-it/SKILL.md || { echo "ship-it merges around the gate"; exit 1; }
  # newproject tells Claude to run /kickoff, and a resumed session runs /ship-it itself:
  # both must be invocable by the model, not only by a typed slash command.
  ! grep -rq "^disable-model-invocation: true" template/.claude/skills || { echo "a kit skill blocks model invocation"; exit 1; }'

step "tag-release.sh semver" bash scripts/test-release.sh

step "state hook" bash scripts/test-state-hook.sh

step "update keeps project files" bash scripts/test-update.sh

step "adopt, auto-adopt, merge gate" bash scripts/test-adopt.sh

echo
if [ ${#FAILED[@]} -gt 0 ]; then echo "VERIFY FAILED: ${FAILED[*]}"; exit 1; fi
echo "VERIFY PASSED"
