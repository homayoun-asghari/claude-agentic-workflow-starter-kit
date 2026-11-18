#!/usr/bin/env bash
# PreToolUse hook (Bash): a pull request is merged only through ./scripts/merge.sh,
# which refuses without a passing verify, green CI and hands-on evidence.
# Exit 2 blocks the command and shows the reason to the agent.
input=$(cat)
cmd=$(printf '%s' "$input" | python3 -I -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("command",""))
except Exception: pass' 2>/dev/null)
[ -n "$cmd" ] || exit 0
if printf '%s' "$cmd" | grep -qE '(^|[;&|[:space:]])gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)|gh[[:space:]]+api[^;&|]*pulls/[0-9]+/merge'; then
  echo "Blocked: never merge blind. Merge with ./scripts/merge.sh from the feature branch — it checks verify.sh, CI, and the hands-on evidence in work/<slug>/evidence/ before it merges." >&2
  exit 2
fi
exit 0
