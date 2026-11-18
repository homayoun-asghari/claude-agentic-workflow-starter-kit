#!/usr/bin/env bash
# Contract test for `newproject --adopt`, the global auto-adopt hook, the merge guard
# hook and scripts/merge.sh's refusals. Throwaway dirs only, no network.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export HOME="$T/home" CLAUDE_KIT_HOME="$T/kit" BIN_DIR="$T/bin" NEWPROJECT_NO_OPEN=1 CLAUDE_KIT_NO_SHELL_RC=1 \
       NEWPROJECT_DIR="$T/Projects" CLAUDE_KIT_NO_AUTO_ADOPT= GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t \
       GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
mkdir -p "$HOME" "$NEWPROJECT_DIR"
FAIL=0
no() { echo "  $1"; FAIL=1; }
sh "$ROOT/install.sh" >/dev/null
date +%s > "$CLAUDE_KIT_HOME/.last-check"
NP="$CLAUDE_KIT_HOME/bin/newproject"

# ---- adopt: an existing repo with files of its own
P="$NEWPROJECT_DIR/old-app"; mkdir -p "$P/.github/workflows" "$P/.claude" "$P/src"
cd "$P" && git init -q -b main
echo '{"name":"old-app","scripts":{}}' > package.json
echo 'console.log(1)' > src/index.js
echo '# Old app — my own notes' > CLAUDE.md
echo 'name: mine' > .github/workflows/ci.yml
echo '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"node guard.mjs"}]}]}}' > .claude/settings.json
git add -A && git commit -qm init

"$NP" --adopt >/dev/null || no "--adopt failed"
grep -q "my own notes" CLAUDE.md                    || no "adopt overwrote CLAUDE.md"
[ "$(cat .github/workflows/ci.yml)" = "name: mine" ] || no "adopt touched own workflow"
[ -x scripts/verify.sh ] && [ -x scripts/merge.sh ]  || no "verify.sh / merge.sh not added"
[ -f .github/workflows/verify.yml ]                  || no "CI workflow not added"
[ -f .claude/skills/ship-it/SKILL.md ] && [ -x .claude/hooks/merge-guard.sh ] || no "kit harness not added"
[ -f .claude/KIT_VERSION ] && [ -f .claude/KIT_ADOPTED ] || no "adopt markers missing"
python3 -I - .claude/settings.json <<'PY' || FAIL=1
import json, sys
d = json.load(open(sys.argv[1])); pre = d["hooks"]["PreToolUse"]; bad = []
cmds = [h["command"] for g in pre for h in g["hooks"]]
if not any("guard.mjs" in c for c in cmds): bad.append("own PreToolUse hook lost")
if sum("merge-guard.sh" in c for c in cmds) != 1: bad.append("merge-guard not wired exactly once")
for b in bad: print("  settings:", b)
sys.exit(1 if bad else 0)
PY
"$NP" --update --quiet; "$NP" --update --quiet
n=$(grep -c merge-guard.sh .claude/settings.json); [ "$n" = 1 ] || no "update duplicated merge-guard ($n)"
out=$("$NP" --adopt); echo "$out" | grep -q "already on the kit" || no "second adopt not a no-op"

# ---- adopt-hook: only code repos under the projects dir, once
mk() { mkdir -p "$1" && (cd "$1" && git init -q -b main && [ -z "${2:-}" ] || echo "$2" > "$1/main.py"); }
mk "$NEWPROJECT_DIR/py-tool" "print(1)"
out=$(CLAUDE_PROJECT_DIR="$NEWPROJECT_DIR/py-tool" "$NP" --adopt-hook)
echo "$out" | grep -q "Workflow kit: this project was just put" || no "hook did not announce adoption"
[ -f "$NEWPROJECT_DIR/py-tool/.claude/KIT_VERSION" ] || no "hook did not adopt"
out=$(CLAUDE_PROJECT_DIR="$NEWPROJECT_DIR/py-tool" "$NP" --adopt-hook); [ -z "$out" ] || no "hook not silent on a kit project"
mk "$NEWPROJECT_DIR/notes"; echo "# notes" > "$NEWPROJECT_DIR/notes/README.md"
out=$(CLAUDE_PROJECT_DIR="$NEWPROJECT_DIR/notes" "$NP" --adopt-hook); [ -z "$out" ] && [ ! -d "$NEWPROJECT_DIR/notes/.claude" ] || no "hook adopted a repo with no code"
mk "$T/elsewhere" "print(1)"
out=$(CLAUDE_PROJECT_DIR="$T/elsewhere" "$NP" --adopt-hook); [ -z "$out" ] || no "hook adopted outside the projects dir"
mk "$NEWPROJECT_DIR/opted-out" "print(1)"; mkdir -p "$NEWPROJECT_DIR/opted-out/.claude"; touch "$NEWPROJECT_DIR/opted-out/.claude/NO_KIT"
out=$(CLAUDE_PROJECT_DIR="$NEWPROJECT_DIR/opted-out" "$NP" --adopt-hook); [ -z "$out" ] || no "hook ignored .claude/NO_KIT"
mk "$NEWPROJECT_DIR/off" "print(1)"
out=$(CLAUDE_KIT_NO_AUTO_ADOPT=1 CLAUDE_PROJECT_DIR="$NEWPROJECT_DIR/off" "$NP" --adopt-hook); [ -z "$out" ] || no "CLAUDE_KIT_NO_AUTO_ADOPT ignored"
out=$(CLAUDE_PROJECT_DIR="$NEWPROJECT_DIR" "$NP" --adopt-hook); [ -z "$out" ] || no "hook fired outside any repo"

mk "$NEWPROJECT_DIR/stranger" "print(1)"; git -C "$NEWPROJECT_DIR/stranger" remote add origin https://github.com/someone-else/x.git
out=$(CLAUDE_PROJECT_DIR="$NEWPROJECT_DIR/stranger" "$NP" --adopt-hook); [ -z "$out" ] || no "hook adopted a repo owned by someone else"
out=$(CLAUDE_KIT_ADOPT_OWNERS=someone-else CLAUDE_PROJECT_DIR="$NEWPROJECT_DIR/stranger" "$NP" --adopt-hook)
echo "$out" | grep -q "Workflow kit" || no "CLAUDE_KIT_ADOPT_OWNERS not honoured"
mk "$NEWPROJECT_DIR/linky" "print(1)"; mkdir -p "$T/outside"; ln -s "$T/outside" "$NEWPROJECT_DIR/linky/scripts"
(cd "$NEWPROJECT_DIR/linky" && "$NP" --adopt >/dev/null 2>&1) && no "adopt wrote through a symlink"
[ -z "$(ls -A "$T/outside")" ] || no "files written outside the repo via symlink"

# ---- enable-auto-adopt: one global hook, idempotent, keeps existing settings
mkdir -p "$HOME/.claude"
echo '{"model":"x","hooks":{"SessionStart":[{"hooks":[{"type":"command","command":"mine.sh"}]}]}}' > "$HOME/.claude/settings.json"
"$NP" --enable-auto-adopt >/dev/null && "$NP" --enable-auto-adopt >/dev/null || no "--enable-auto-adopt failed"
[ "$(grep -c -- --adopt-hook "$HOME/.claude/settings.json")" = 1 ] || no "global hook not added exactly once"
grep -q mine.sh "$HOME/.claude/settings.json" && grep -q '"model": "x"' "$HOME/.claude/settings.json" || no "global settings lost"

# ---- merge-guard hook
G="$P/.claude/hooks/merge-guard.sh"
j() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }
for c in "gh pr merge --squash" "cd x && gh pr merge 12 --admin" "gh api -X PUT repos/o/r/pulls/3/merge" \
         "gh -R o/r pr merge 3" "gh --repo o/r pr merge" "/usr/bin/gh pr merge 1" "echo ok; gh pr merge" \
         "gh api graphql -f query=mutation{mergePullRequest}" "x=\$(gh pr merge 1)" "GH_TOKEN=1 gh pr merge" "bash -c 'gh pr merge 2'"; do
  j "$c" | "$G" 2>/dev/null; [ $? -eq 2 ] || no "guard let through: $c"
done
for c in "./scripts/merge.sh" "gh pr view" "git merge-base --is-ancestor a b" "gh pr create --title merge" \
         "gh pr list --search merge" "echo gh pr merge is blocked > notes.txt"; do
  j "$c" | "$G" 2>/dev/null || no "guard blocked: $c"
done

# ---- merge.sh refusals (stops before any network call)
cd "$P" && git add -A && git commit -qm "chore: adopt kit"
out=$(./scripts/merge.sh 2>&1); echo "$out" | grep -q "not 'main'" || no "merge.sh allowed main"
git checkout -qb feat/thing; echo 'console.log(2)' > src/index.js; git commit -qam "feat: thing"
out=$(./scripts/merge.sh 2>&1); echo "$out" | grep -q "no hands-on check" || no "merge.sh merged without evidence"
mkdir -p work/thing/evidence; printf 'ran it\nCHECKED: %s\n' "$(git rev-parse HEAD)" > work/thing/evidence/CHECKED.md
out=$(./scripts/merge.sh 2>&1); echo "$out" | grep -q "no evidence beside it" || no "merge.sh accepted CHECKED.md alone"
echo "\$ node src/index.js
2" > work/thing/evidence/run.txt; git add -A; git commit -qm "test(thing): hands-on check"
out=$(./scripts/merge.sh 2>&1); echo "$out" | grep -q "no open PR" || no "merge.sh refused good evidence: $out"
# CI result with a fake gh: red or unknown refuses, green merges.
FB="$T/fakebin"; mkdir -p "$FB"
cat > "$FB/gh" <<'GH'
#!/bin/sh
case "$1 $2" in
  "pr view")   echo OPEN ;;
  "pr checks") exit "${FAKE_CHECKS:-0}" ;;
  "pr merge")  echo merged >> "$FAKE_LOG" ;;
  "repo view") echo main ;;
esac
GH
chmod +x "$FB/gh"; export FAKE_LOG="$T/merges"
for rc in 1 4; do
  out=$(FAKE_CHECKS=$rc PATH="$FB:$PATH" ./scripts/merge.sh 2>&1)
  echo "$out" | grep -q "Never merge red" && [ ! -f "$FAKE_LOG" ] || no "merge.sh merged with CI exit $rc"
done
out=$(FAKE_CHECKS=0 PATH="$FB:$PATH" ./scripts/merge.sh 2>&1)
grep -q merged "$FAKE_LOG" 2>/dev/null || no "merge.sh refused green CI + evidence: $out"
git checkout -q feat/thing 2>/dev/null
echo 'console.log(3)' > src/index.js; git commit -qam "fix: later change"
out=$(./scripts/merge.sh 2>&1); echo "$out" | grep -q "code changed after the hands-on check" || no "merge.sh merged code changed after the check"

exit $FAIL
