#!/usr/bin/env bash
# Contract test for template/.claude/hooks/state.sh, in a throwaway repo.
set -uo pipefail
HOOK="$(cd "$(dirname "$0")/.." && pwd)/template/.claude/hooks/state.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cd "$T" && git init -q -b main && git config user.email t@t && git config user.name t
export CLAUDE_PROJECT_DIR="$T"
FAIL=0
no()  { echo "  $1"; FAIL=1; }
stop() { local o; o=$(echo "{\"stop_hook_active\":${1:-false}}" | bash "$HOOK" stop); echo "$o"; }

mkdir -p work/signup
cat > work/BOARD.md <<'EOF'
| # | Slug | Slice | PRD | Milestone | Status |
|---|------|-------|-----|-----------|--------|
| 1 | signup | A visitor can sign up | J1 | M1 | doing |
| 2 | projects | A user can create a project | J2 | M1 | todo |
EOF
printf 'Now: 8 review — round 1\n- [x] schema\n- [ ] form\n' > work/signup/plan.md
git add -A && git commit -q -m init && git checkout -q -b feat/signup
printf 'AUDITED: %s\nROUND: 1\nVERDICT: BLOCK\n' "$(git rev-parse HEAD)" > work/signup/audit.md

out=$(bash "$HOOK" session)
echo "$out" | grep -q 'next: signup'          || no "session: wrong next slug"
echo "$out" | grep -q 'Now: 8 review'         || no "session: Now line missing"
echo "$out" | grep -q 'first open step: - \[ \] form' || no "session: open step missing"
echo "$out" | grep -q 'matches HEAD, reuse it' || no "session: audit reuse not detected"
pc=$(bash "$HOOK" precompact); echo "$pc" | grep -q 'keep verbatim' || no "precompact: no instructions"

[ -z "$(stop)" ] || no "stop: blocked without work/.shipping"
touch work/.shipping
stop | grep -q '"decision":"block"' || no "stop: did not block with work left"
touch work/BLOCKED.md; [ -z "$(stop)" ] || no "stop: blocked despite BLOCKED.md"; rm work/BLOCKED.md

# no-progress guard: three forced continuations with no change on disk -> allow stop
stop >/dev/null; stop true >/dev/null; stop true >/dev/null
[ -z "$(stop true)" ] || no "stop: no-progress guard did not release"

# progress resets the guard
echo x > work/signup/notes.md
stop true | grep -q block || no "stop: progress did not reset the guard"

sed -i.bak 's/| doing |/| done |/; s/| todo |/| done |/' work/BOARD.md
stop | grep -q 'milestone gate' || no "stop: board done but marker present should ask for gate"
exit $FAIL
