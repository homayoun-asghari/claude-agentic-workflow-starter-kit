#!/usr/bin/env bash
# Contract test for `newproject --update` and the SessionStart auto-update, against a
# project that has its own skills, hooks, settings and scripts. Throwaway dirs only.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
export CLAUDE_KIT_HOME="$T/kit" BIN_DIR="$T/bin" NEWPROJECT_NO_OPEN=1 CLAUDE_KIT_NO_AUTO_UPDATE= CLAUDE_KIT_NO_SHELL_RC=1
FAIL=0
no() { echo "  $1"; FAIL=1; }
sh "$ROOT/install.sh" >/dev/null
date +%s > "$CLAUDE_KIT_HOME/.last-check"   # suppress the daily git pull: no network in tests
NP="$CLAUDE_KIT_HOME/bin/newproject"

# A project on an old kit, with things of its own.
P="$T/proj"; mkdir -p "$P/.claude/skills/my-skill" "$P/.claude/skills/ship-it" "$P/.claude/hooks" "$P/.claude/agents" "$P/scripts"
cd "$P" && git init -q -b main
echo old > .claude/skills/ship-it/SKILL.md
echo mine > .claude/skills/my-skill/SKILL.md
echo mine > .claude/agents/my-agent.md
echo 'guard' > .claude/hooks/guard.mjs
echo '#!/bin/sh
echo project release' > scripts/release.sh
cat > .claude/settings.json <<'EOF'
{"permissions": {"allow": ["WebSearch"], "deny": ["Read(./.env)"], "ask": ["Bash(git push:*)"]},
 "env": {"MY_VAR": "1"},
 "hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "node guard.mjs"}]}]}}
EOF
echo 0.1.0 > .claude/KIT_VERSION

"$NP" --update >/dev/null || no "--update failed"
"$NP" --update >/dev/null || no "second --update failed"
s=.claude/settings.json
[ "$(cat .claude/skills/my-skill/SKILL.md)" = mine ] || no "own skill lost"
[ -f .claude/agents/my-agent.md ]                   || no "own agent lost"
[ -f .claude/hooks/guard.mjs ]                      || no "own hook lost"
grep -q "project release" scripts/release.sh        || no "project's release.sh overwritten"
grep -q "Ship it" .claude/skills/ship-it/SKILL.md   || no "kit skill not refreshed"
[ -x .claude/hooks/state.sh ] && [ -x scripts/tag-release.sh ] || no "kit files missing"
python3 - "$s" <<'PY' || FAIL=1
import json, sys
d = json.load(open(sys.argv[1])); p = d["permissions"]; bad = []
if p.get("allow") != ["WebSearch"]: bad.append("allow lost")
if p.get("deny") != ["Read(./.env)"]: bad.append("deny lost")
if "ask" in p: bad.append("ask kept (would prompt)")
if p.get("defaultMode") != "bypassPermissions": bad.append("not bypassPermissions")
if d["env"].get("MY_VAR") != "1" or "CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS" not in d["env"]: bad.append("env merge")
if d.get("autoContinueAtUsageLimit") is not True: bad.append("autoContinue missing")
if len(d["hooks"]["PreToolUse"]) != 1: bad.append("own PreToolUse hook lost")
for ev in ("SessionStart", "PreCompact", "Stop"):
    if len(d["hooks"].get(ev, [])) != 1: bad.append(f"{ev}: {len(d['hooks'].get(ev, []))} kit hooks (want 1)")
for b in bad: print("  settings:", b)
sys.exit(1 if bad else 0)
PY
[ "$(cat .claude/KIT_VERSION)" = "$(cat "$CLAUDE_KIT_HOME/VERSION")" ] || no "KIT_VERSION not bumped"

# SessionStart auto-update: an older project updates itself; a newer one is left alone.
echo 0.0.1 > .claude/KIT_VERSION; rm .claude/agents/spec-auditor.md
out=$(CLAUDE_PROJECT_DIR="$P" bash .claude/hooks/state.sh session); echo "$out" | grep -q "kit: this project updated" || no "hook did not auto-update"
[ -f .claude/agents/spec-auditor.md ] || no "auto-update did not restore kit files"
echo 99.0.0 > .claude/KIT_VERSION
out=$(CLAUDE_PROJECT_DIR="$P" bash .claude/hooks/state.sh session); echo "$out" | grep -q "kit:" && no "hook downgraded a newer project"
exit $FAIL
