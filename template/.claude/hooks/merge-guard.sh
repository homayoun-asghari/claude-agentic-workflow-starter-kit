#!/usr/bin/env bash
# PreToolUse hook (Bash): a pull request is merged only through ./scripts/merge.sh,
# which refuses without a passing verify, green CI and hands-on evidence.
# Exit 2 blocks the command and shows the reason to the agent.
# This guards against the agent's own shortcuts. Branch protection on GitHub (required
# checks) is the server-side backstop.
python3 -I -c '
import json, re, shlex, sys
try:
    cmd = json.load(sys.stdin).get("tool_input", {}).get("command", "") or ""
except Exception:
    sys.exit(0)
WRAP = {"sudo", "env", "command", "exec", "time", "nohup", "nice"}
def blocked(c):
    if re.search(r"mergePullRequest|enablePullRequestAutoMerge|/pulls/[0-9]+/merge\b", c):
        return True
    for part in re.split(r"[;&|\n()`]|\$\(", c):
        try:
            toks = shlex.split(part)
        except ValueError:
            toks = part.split()
        # A quoted script handed to a shell (bash -c "...") is checked too.
        if any(" " in t and blocked(t) for t in toks):
            return True
        i = 0
        while i < len(toks) and ("=" in toks[i] and not toks[i].startswith("-") or toks[i] in WRAP):
            i += 1
        if i < len(toks) and toks[i].rsplit("/", 1)[-1] == "gh":
            rest = toks[i + 1:]
            j = 0
            while j < len(rest) and rest[j].startswith("-"):      # gh global flags
                j += 2 if rest[j] in ("-R", "--repo", "--hostname") else 1
            if rest[j:j + 2] == ["pr", "merge"]:
                return True
    return False
if blocked(cmd):
    sys.stderr.write("Blocked: never merge blind. Merge with ./scripts/merge.sh from the feature branch - it checks verify.sh, CI, and the hands-on evidence in work/<slug>/evidence/ before it merges.\n")
    sys.exit(2)
'
