#!/usr/bin/env bash
# The only way a pull request gets merged. Never merge blind.
#
#   ./scripts/merge.sh          run from the feature branch whose PR you want merged
#
# Refuses unless ALL of these hold:
#   1. You are on a branch that is not main/master, and it has an open PR.
#   2. Someone actually used the change: work/<slug>/evidence/CHECKED.md exists, names
#      the commit that was checked (`CHECKED: <sha>`), and sits next to at least one
#      piece of evidence — screenshots for anything with a screen, a saved terminal
#      transcript (.txt/.log) for CLIs, APIs and libraries.
#   3. Nothing but the evidence itself changed after the checked commit.
#   4. ./scripts/verify.sh passes on HEAD.
#   5. CI on the PR is green.
#
# A PreToolUse hook (.claude/hooks/merge-guard.sh) blocks `gh pr merge` everywhere
# else, so this gate cannot be skipped by typing the merge command directly.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 1

die() { printf 'MERGE REFUSED: %s\n' "$1" >&2; exit 1; }

branch=$(git branch --show-current)
case "$branch" in ""|main|master) die "run this from the feature branch, not '${branch:-detached HEAD}'." ;; esac
slug=${branch#*/}
E="work/$slug/evidence"

# 2. Hands-on check, with proof.
[ -f "$E/CHECKED.md" ] || die "no hands-on check. Run the change the way a user would (start the app,
  click through it / call the endpoint / run the command), save screenshots or the
  terminal transcript in $E/, and write $E/CHECKED.md with what you did, what you saw,
  and a line 'CHECKED: <the commit sha you tested>'."
n=$(find "$E" -type f ! -name CHECKED.md \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' -o -iname '*.txt' -o -iname '*.log' \) | wc -l)
[ "$n" -gt 0 ] || die "$E/CHECKED.md has no evidence beside it (screenshots, or a .txt/.log transcript)."
sha=$(grep -m1 -E '^CHECKED:[[:space:]]*[0-9a-f]{7,40}' "$E/CHECKED.md" | awk '{print $2}')
[ -n "$sha" ] || die "$E/CHECKED.md has no 'CHECKED: <sha>' line."
git cat-file -e "$sha^{commit}" 2>/dev/null || die "CHECKED commit $sha does not exist on this branch."
git merge-base --is-ancestor "$sha" HEAD || die "CHECKED commit $sha is not in this branch's history."

# 3. The code merged is the code that was checked.
changed=$(git diff --name-only "$sha" HEAD | grep -v "^work/$slug/" || true)
[ -z "$changed" ] || die "code changed after the hands-on check ($sha). Check again, then update CHECKED.md:
$(echo "$changed" | sed 's/^/    /')"

# Uncommitted changes would not be in the PR.
[ -z "$(git status --porcelain --untracked-files=no)" ] || die "uncommitted changes. Commit or stash them first."
git push -q 2>/dev/null || true

# 4. The single definition of done.
./scripts/verify.sh >/tmp/merge-verify.$$ 2>&1 || { tail -20 /tmp/merge-verify.$$ >&2; rm -f /tmp/merge-verify.$$; die "./scripts/verify.sh failed."; }
rm -f /tmp/merge-verify.$$

# 1 + 5. An open PR with green checks.
gh pr view --json state -q .state 2>/dev/null | grep -qx OPEN || die "no open PR for $branch. Open one first."
if gh pr checks >/dev/null 2>&1 || [ $? -eq 8 ]; then   # 8 = checks still pending
  gh pr checks --watch >/dev/null 2>&1 || die "CI is red on the PR. Fix it on the branch; never merge red."
fi

gh pr merge --squash --delete-branch || die "gh pr merge failed."
base=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name 2>/dev/null || echo main)
git checkout -q "$base" && git pull -q --ff-only
echo "merged $branch — checked at $sha, evidence in $E/ (now on $base)"
