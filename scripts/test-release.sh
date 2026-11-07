#!/usr/bin/env bash
# Contract test for template/scripts/tag-release.sh, in a throwaway repo.
set -uo pipefail
REL="$(cd "$(dirname "$0")/.." && pwd)/template/scripts/tag-release.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
cd "$T" && git init -q -b main && git config user.email t@t && git config user.name t
FAIL=0
commit() { git commit -q --allow-empty -m "$1"; }
expect() { # <commit subject> <expected tag or "-">
  commit "$1"; bash "$REL" >/dev/null 2>&1 || { echo "  tag-release.sh failed on: $1"; FAIL=1; return; }
  got=$(git tag --points-at HEAD | head -1); got=${got:--}
  [ "$got" = "$2" ] || { echo "  '$1': expected $2, got $got"; FAIL=1; }
}
commit "chore: init"
expect "feat(signup): a visitor can sign up (#1)"   v0.1.0
expect "fix(signup): reject empty email (#2)"       v0.1.1
expect "docs: readme"                               -
expect "perf(m1): index projects.owner_id (#4)"     v0.1.2
expect "feat(projects)!: new id format (#5)"        v0.2.0   # breaking stays minor in 0.x
expect "refactor: tidy"                             -
# idempotent: second run on a tagged HEAD changes nothing
commit "feat: x"; bash "$REL" >/dev/null; bash "$REL" >/dev/null
[ "$(git tag --points-at HEAD | wc -l | tr -d ' ')" = 1 ] || { echo "  not idempotent"; FAIL=1; }
# refuses off main
git checkout -q -b feat/y; bash "$REL" >/dev/null 2>&1 && { echo "  ran off main"; FAIL=1; }
git checkout -q main
# 1.x: breaking is a major bump
commit "chore: cut 1.0"; git tag -a v1.0.0 -m one; expect "fix!: drop legacy api" v2.0.0
exit $FAIL
