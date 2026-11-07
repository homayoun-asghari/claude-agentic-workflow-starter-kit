#!/usr/bin/env bash
# Version from the merge commit, not from judgment. Run on main right after a merge.
#
#   ./scripts/tag-release.sh                     tag HEAD from its conventional prefix
#   ./scripts/tag-release.sh --release "<name>"  also publish a GitHub release for the
#                                            latest tag (end of a milestone)
#   ./scripts/tag-release.sh --dry-run           print what would happen
#
# SemVer: feat -> minor, fix/perf -> patch, `!` or BREAKING CHANGE -> major
# (minor while still 0.x). docs/chore/test/refactor/ci do not release.
# Idempotent: if HEAD is already tagged it does nothing, so a resumed session
# can run it again safely. Tags are the version — no file on main to commit.
set -euo pipefail

DRY=0; RELEASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY=1; shift ;;
    --release) RELEASE="${2:?--release needs a name}"; shift 2 ;;
    *) echo "tag-release.sh: unknown option $1" >&2; exit 2 ;;
  esac
done

[ "$(git branch --show-current)" = main ] || { echo "tag-release.sh: run on main, after the merge" >&2; exit 1; }
# Highest SemVer tag reachable from HEAD (git describe picks arbitrarily between tags on one commit).
latest_tag() { git tag --merged HEAD --list 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1; }
has_remote() { git remote get-url origin >/dev/null 2>&1; }
run() { if [ "$DRY" -eq 1 ]; then echo "would run: $*"; else "$@"; fi; }

existing=$(git tag --points-at HEAD --list 'v[0-9]*' | head -1)
if [ -n "$existing" ]; then
  echo "HEAD already tagged $existing"
else
  last=$(latest_tag); last=${last:-v0.0.0}
  IFS=. read -r MA MI PA <<< "${last#v}"
  subject=$(git log -1 --format=%s)
  body=$(git log -1 --format=%b)

  bump=none
  if echo "$subject" | grep -qE '^[a-z]+(\([^)]*\))?!:' || echo "$body" | grep -q '^BREAKING CHANGE'; then
    bump=major
  elif echo "$subject" | grep -qE '^feat(\([^)]*\))?:'; then
    bump=minor
  elif echo "$subject" | grep -qE '^(fix|perf)(\([^)]*\))?:'; then
    bump=patch
  fi
  [ "$bump" = major ] && [ "$MA" -eq 0 ] && bump=minor   # 0.x: breaking is a minor bump

  case "$bump" in
    major) next="v$((MA + 1)).0.0" ;;
    minor) next="v$MA.$((MI + 1)).0" ;;
    patch) next="v$MA.$MI.$((PA + 1))" ;;
    none)  next="" ;;
  esac

  if [ -z "$next" ]; then
    echo "no release: '$subject' is not feat/fix/perf (stays at $last)"
  else
    echo "$last -> $next  ($bump: $subject)"
    run git tag -a "$next" -m "$subject"
    has_remote && run git push -q origin "$next"
  fi
fi

if [ -n "$RELEASE" ]; then
  tag=$(latest_tag); [ -n "$tag" ] || { echo "tag-release.sh: no tag to release" >&2; exit 1; }
  if ! has_remote || ! command -v gh >/dev/null 2>&1; then
    echo "no remote or gh: skipped GitHub release for $tag"
  elif gh release view "$tag" >/dev/null 2>&1; then
    echo "GitHub release $tag already exists"
  else
    run gh release create "$tag" --title "$tag — $RELEASE" --generate-notes
  fi
fi
