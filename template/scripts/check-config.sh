#!/usr/bin/env bash
# Contract-test the .claude/ directory so the harness config cannot rot silently.
# Runs in CI alongside verify.sh.
set -uo pipefail
FAIL=0
err() { echo "  FAIL  $1"; FAIL=1; }
ok()  { echo "  ok    $1"; }

echo "checking .claude/"

# Every SKILL.md parses and is not oversized.
while IFS= read -r f; do
  [ -z "$f" ] && continue
  head -1 "$f" | grep -q '^---$' || err "$f: frontmatter must start on line 1"
  grep -q '^description:' "$f"   || err "$f: missing description"
  n=$(wc -l < "$f")
  [ "$n" -gt 500 ] && err "$f: $n lines (limit 500 — move detail to a sibling file)"
  [ "$n" -le 500 ] && ok "$f ($n lines)"
done < <(find .claude/skills -name SKILL.md 2>/dev/null)

# Every agent parses.
while IFS= read -r f; do
  [ -z "$f" ] && continue
  head -1 "$f" | grep -q '^---$' || err "$f: frontmatter must start on line 1"
  grep -q '^name:' "$f"          || err "$f: missing name"
  grep -q '^description:' "$f"   || err "$f: missing description"
  ok "$f"
done < <(find .claude/agents -name '*.md' 2>/dev/null)

# settings.json is valid JSON.
if [ -f .claude/settings.json ]; then
  if command -v jq >/dev/null 2>&1; then
    jq empty .claude/settings.json 2>/dev/null && ok ".claude/settings.json" \
      || err ".claude/settings.json: invalid JSON"
  fi
fi

# Hooks are executable.
while IFS= read -r f; do
  [ -z "$f" ] && continue
  [ -x "$f" ] && ok "$f (executable)" || err "$f: not executable — chmod +x"
done < <(find .claude/hooks -name '*.sh' 2>/dev/null)

# CI must call verify.sh rather than re-listing its steps.
if [ -f .github/workflows/verify.yml ]; then
  grep -q 'scripts/verify.sh' .github/workflows/verify.yml \
    && ok "CI calls scripts/verify.sh" \
    || err "CI does not call scripts/verify.sh — local and CI will drift"
fi

echo
[ "$FAIL" -eq 0 ] && echo "CONFIG OK" || echo "CONFIG FAILED"
exit $FAIL
