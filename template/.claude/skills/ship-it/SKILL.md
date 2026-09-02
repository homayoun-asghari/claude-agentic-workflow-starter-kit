---
name: ship-it
description: Build every remaining slice on the board autonomously - branch, plan, implement, verify, independent review, PR, merge - and repeat until the board is empty. Resumable after any interruption.
argument-hint: "[slug to start from, or blank for the whole board]"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent
---

# Ship it

Work the board top to bottom, one vertical slice at a time, until it is empty.

Argument: `$ARGUMENTS` — a slug to build only that slice, or blank for the whole board.

**Do not stop after one slice.** Finish the board. Stop only for a condition in
*Stop conditions* below.

---

## Step 0 — Orient (always, even mid-run)

Never resume from memory. Establish the real state:

```bash
git branch --show-current
git status --short
git log --oneline -10
cat work/BOARD.md
```

- On a `feat/*` branch with uncommitted work → you were interrupted mid-slice.
  Read `work/<slug>/plan.md`, find the first unticked step, continue from there.
- On `main` and clean → start the next `todo` slice.
- A slice marked `doing` with a merged PR → it is actually `done`. Fix the board.

## Step 1 — Take the next slice

First `todo` in `work/BOARD.md`. Mark it `doing`. Then:

```bash
git checkout main && git pull --ff-only 2>/dev/null || true
git checkout -b feat/<slug>
mkdir -p work/<slug>
```

Branch name and work folder always share the slug.

## Step 2 — Spec

Write `work/<slug>/spec.md`:

```markdown
# <slug>

## What a user can do when this is done
<one sentence>

## Acceptance criteria
- [ ] <criterion — specific enough that a test can prove it>
- [ ] <...>

## Out of scope
- <...>
```

Every criterion must be **mechanically checkable**. "Handles errors gracefully" is
not a criterion. "Submitting an empty email shows a validation message and does not
create a row" is.

**Never write a criterion that has no possible exit code.** That is how a step gets
reported as passed without being performed.

## Step 3 — Plan

Research first — use the `Explore` subagent for anything beyond a couple of files, so
the search trace stays out of this context.

Write `work/<slug>/plan.md`:

```markdown
# Plan: <slug>

- [ ] 1. <step> — files: <exact paths> — verified by: <command or test name>
- [ ] 2. ...
```

Each step is one commit. Each leaves `verify` green. If a step cannot be verified,
it is not a step — fold it into one that can.

Cover the whole slice: schema, server, UI, and tests. If the plan has no UI step and
no test step, the slice is horizontal — go back to Step 2.

## Step 4 — Implement

For each step, in order:

1. Write the test first where it is natural to.
2. Implement.
3. `./scripts/verify.sh --fast`
4. Tick the step in `plan.md`.
5. `git commit -m "<type>(<slug>): <step>"`

Never move to the next step on a failing verify. Never batch several steps into one
commit — `git bisect` is worth more than a tidy log.

## Step 5 — Verify for real

```bash
./scripts/verify.sh
```

Full run, no `--fast`. Then tick each acceptance criterion in `spec.md`, and paste
**the command output that proves it** beside it. Not an assertion that it works —
the output.

## Step 6 — Independent review

Dispatch the `spec-auditor` subagent. Give it the slug.

It runs in a fresh context because **you cannot fairly grade your own work.** On a
real project this step blocks roughly two changes in three on the first pass. Expect
`BLOCK`. It is the normal outcome, not a failure of the process.

On `BLOCK`:

1. Fix every correctness finding. Do not argue with it.
2. Re-run `./scripts/verify.sh`.
3. Commit: `fix(<slug>): address independent review — <what>`
4. Re-run the auditor.

Three `BLOCK`s on the same slice → stop and ask the user. Something is wrong with the
spec, not the code.

Optionally also run `/code-review` for general bug-hunting. The auditor checks
conformance to the spec; `/code-review` checks the code itself.

## Step 7 — Land

```bash
./scripts/verify.sh
git push -u origin feat/<slug>
gh pr create --title "feat(<slug>): <slice>" --body "$(cat <<'BODY'
<one line: what a user can now do>

## Acceptance criteria
<the ticked checklist from spec.md>

## Plan
<link to work/<slug>/plan.md in the diff>

Independent review: PASS
BODY
)"
```

Wait for CI. `gh run watch` or poll `gh pr checks`.

- CI red → fix on the branch, push, wait again. Never merge red. Never push past the
  gate onto `main`.
- CI green → `gh pr merge --squash --delete-branch`

Then clean up:

```bash
git checkout main && git pull --ff-only
rm -rf work/<slug>            # git history is the archive
```

- Mark the slice `done` in `work/BOARD.md`.
- Append one line to `docs/DECISIONS.md` for any decision made along the way.
- Append anything learned the hard way to `docs/NOTES.md` — environment traps
  especially, phrased so the next session does not re-learn them.
- Commit those on a branch too, or fold them into the next slice's first commit.

## Step 8 — Next

Go to Step 1. Repeat until no `todo` remains.

When the board is empty:

```bash
./scripts/verify.sh
```

Then report: slices shipped, what each PR did, review blocks found and fixed, and
anything left in `docs/NOTES.md` worth acting on.

---

## Stop conditions

Stop and ask the user when any of these hold. Do not push through.

- The same slice has been `BLOCK`ed three times.
- The same test has failed five times without the cause changing.
- A slice needs a credential, an account, or a paid service that is not present.
- Verify cannot be made to pass for a reason outside the slice.
- A slice turns out to need a decision that is not in `docs/`, and no conservative
  default is defensible.
- The work would require deploying, or touching production data.

**Report progress honestly at every stop.** Say what is merged, what is half-built,
and what is untouched. Never describe a step as done when it was skipped — a skipped
step that gets narrated as complete is the single most expensive failure in this
workflow.

## Interruptions

Rate limits, token limits, and tool failures are expected. They are not a reason to
restart.

Before any long stretch of work, make sure the branch holds a meaningful commit. On
resume, run Step 0 and continue from the last verified state. Previous work is on
disk and in git — never assume it was lost because the session ended.
