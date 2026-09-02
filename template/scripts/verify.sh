#!/usr/bin/env bash
# The single definition of "done".
#
# The agent runs this. The pre-merge gate runs this. CI runs THIS FILE, never a
# copy of its steps — that is what stops local green and CI green from drifting
# apart. Add a check here and all three consumers get it at once.
#
#   ./scripts/verify.sh          full run
#   ./scripts/verify.sh --fast   skip the build (inner development loop)
set -uo pipefail

FAST=0
[ "${1:-}" = "--fast" ] && FAST=1

FAILED=()
step() {
  local name=$1; shift
  # A step whose tool is absent is skipped, not failed.
  command -v "${1%% *}" >/dev/null 2>&1 || { printf '  ·  %-12s skipped (not installed)\n' "$name"; return 0; }
  printf '\n──  %s\n' "$name"
  if "$@"; then
    printf '  ok  %s\n' "$name"
  else
    printf '  FAIL  %s\n' "$name"
    FAILED+=("$name")
  fi
}

has_script() {
  [ -f package.json ] && grep -q "\"$1\"[[:space:]]*:" package.json
}

# ---------------------------------------------------------------------------
# /kickoff replaces this block with the real commands for the chosen stack.
# The contract that must survive any rewrite: fail-fast-free (run everything,
# report all failures), and exit non-zero if anything failed.
# ---------------------------------------------------------------------------
if [ -f package.json ]; then
  has_script format:check && step "format"    npm run format:check --silent
  has_script lint         && step "lint"      npm run lint --silent
  has_script typecheck    && step "typecheck" npm run typecheck --silent
  has_script test         && step "test"      npm run test --silent
  if [ "$FAST" -eq 0 ]; then
    has_script build      && step "build"     npm run build --silent
  fi
else
  echo "verify.sh has not been configured for this project yet."
  echo "Run /kickoff, or replace the block in scripts/verify.sh with the real commands."
  exit 1
fi

echo
if [ ${#FAILED[@]} -gt 0 ]; then
  printf 'VERIFY FAILED: %s\n' "${FAILED[*]}"
  exit 1
fi
echo "VERIFY PASSED"
