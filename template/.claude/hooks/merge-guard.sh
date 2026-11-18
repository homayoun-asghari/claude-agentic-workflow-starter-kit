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
    if re.search(r"mergePullRequest|enablePullRequestAutoMerge|/pulls/[^/\s]+/merge\b", c):
        return True
    for part in re.split(r"[;&|\n()`]|\$\(", c):
        try:
            toks = shlex.split(part)
        except ValueError:
            toks = part.split()
        # A quoted script handed to a shell (bash -c "...") is checked too.
        if any(" " in t and blocked(t) for t in toks):
            return True
        # Deny by default: gh anywhere in the segment (not only as its head, so xargs/time -p/
        # unknown wrappers are covered), then its words with flags skipped.
        for i, t in enumerate(toks):
            if t.rsplit("/", 1)[-1] != "gh":
                continue
            rest = toks[i + 1:]
            words, j = [], 0
            while j < len(rest):
                if rest[j].startswith("-"):
                    j += 2 if rest[j] in ("-R", "--repo", "--hostname") else 1
                    continue
                words.append(rest[j]); j += 1
            # "pr" directly followed by "merge" anywhere after gh: unknown flags with values
            # cannot shift it out of view.
            if any(words[k:k + 2] == ["pr", "merge"] for k in range(len(words))):
                return True
            # An alias or extension could rename "pr merge" out of sight.
            if words[:1] in (["alias"], ["extension"], ["ext"]):
                return True
            # GraphQL whose body comes from a file or stdin cannot be inspected: refuse it.
            if words[:2] == ["api", "graphql"] and any(x.startswith("--input") or "=@" in x or x.startswith("@") for x in rest):
                return True
    return False
if blocked(cmd):
    sys.stderr.write("Blocked: never merge blind. Merge with ./scripts/merge.sh from the feature branch - it checks verify.sh, CI, and the hands-on evidence in work/<slug>/evidence/ before it merges.\n")
    sys.exit(2)
'
