---
name: ship-it
description: Build the whole project. For every feature on the board - branch, plan, implement, test, debug, evals, CI, independent review, commit, PR, merge, version tag - with a security and performance gate after each milestone, and keep going until the board is empty and the project works end to end.
argument-hint: "[optional: a single slug to build]"
disable-model-invocation: true
---

# Ship it

**Do not stop until you have delivered the complete, working project described in the
PRD and the rest of the project documentation.**

Argument: `$ARGUMENTS` — a single slug to build only that, or blank for the whole board.

Work the board in order. Finish a feature completely, merge it, then start the next
one. Do not pause between features to check in. Keep going.

---

## Before you start (and after any interruption)

Never resume from memory. Establish the real state:

```bash
touch work/.shipping        # tells the Stop hook a run is in progress
.claude/hooks/state.sh      # branch, board, current step, audits, blockers
git branch --show-current
git status --short
git log --oneline -10
cat work/BOARD.md
```

The same state is injected automatically at session start and after every context
compaction. If it disagrees with what you remember, **the disk is right.**

- Mid-feature on a `feat/*` branch → read `work/<slug>/plan.md`, find its `Now:` line
  and the first unticked step, continue from there.
- An audit report (`work/<slug>/audit.md`, `docs/audits/*`) whose `AUDITED:` equals
  HEAD → that review already ran. Act on it; do not dispatch it again.
- On `main` and clean → start the next `todo` on the board.
- Board says `doing` but the PR is merged → it is `done`. Fix the board and move on.

---

## The loop, for every feature

**Size it first**, using the "Scale the ceremony" table in `CLAUDE.md`. A board slice
is normally the middle or large tier. For the small tier (< ~50 lines, one file,
obvious): skip the plan (2) and evals (6), and run one audit round only. Branch, test,
verify, independent review, PR and merge are never skipped.

### 1. Feature branch — always, first, no exceptions

```bash
git checkout main && git pull --ff-only 2>/dev/null || true
git checkout -b feat/<slug>
mkdir -p work/<slug>
```

**A feature never gets implemented on `main`.** If you find yourself editing files on
`main`, branch first and carry the changes over. The branch name always matches the
`work/<slug>/` folder.

### 2. Plan

Write `work/<slug>/plan.md`:

- The PRD requirements and acceptance criteria this feature covers.
- Dependencies, edge cases, implementation risks.
- The testing and evaluation strategy for this feature.
- Numbered steps as `- [ ]` checkboxes, each with the exact files it touches and how
  it gets verified. Tick each one as it lands, not at the end.
- A `Now:` line at the top — the loop step (1–11) in progress and the next action,
  e.g. `Now: 8 review — round 1 BLOCK, fixing finding 2 of 3`. Update it whenever you
  move to a new step. It is what lets a resumed or compacted session pick up exactly.

Use the `Explore` subagent for research so the search trace stays out of this context.

### 3. Implement

Work the steps in order. One commit per step, each leaving the tests green.

### 4. Test

- Unit tests where appropriate.
- Integration tests where appropriate.
- End-to-end tests for critical user flows.
- Regression tests for existing behaviour this change touches.

### 5. Debug

Investigate and fix everything that fails. Re-run the relevant suite after each fix.
Root cause, not symptom.

### 6. Evals

Run the evaluations for this feature and confirm it satisfies the intended behaviour
and the acceptance criteria.

**If this project has no evals, say so in the PR body and move on.** Do not report
this step as passed when nothing ran. A step that cannot be performed gets reported
as skipped, never as done.

### 7. CI checks

```bash
./scripts/verify.sh
```

Build, lint, type check, tests, and any project-specific checks. All of them pass
before you go further.

### 8. Independent review

Dispatch the `spec-auditor` subagent with the slug and `round 1`. **The agent that
wrote the code is never the only one to judge it.**

The auditor writes its report to `work/<slug>/audit.md`. **If that file already exists
and its `AUDITED:` line equals `git rev-parse HEAD`, the audit already ran — use it,
do not dispatch again.** That is how a finished review survives a usage limit.

**At most two rounds.** This is the step that burns the most time and tokens when it
is allowed to loop.

1. **Round 1** — full audit. `PASS` → step 9.
2. `BLOCK` → fix the **BLOCKING** findings only, re-run `./scripts/verify.sh`, commit
   as `fix(<slug>): address independent review`. NOTES are not fixed here — they go in
   the PR body.
3. **Round 2** — dispatch with `round 2`. It re-checks only the round-1 findings.
4. Still `BLOCK` after round 2 → fix what it names, verify, and list each one in the PR
   body under **Fixed after final audit round — not re-audited**. Then go on. There is
   no round 3.

Do not add other reviewers to this step — no `/review`, `/code-review`, `/codex`,
`/autoplan`, CodeRabbit or similar skills inside the loop. One independent reviewer,
two rounds. Security and performance get their own pass at the milestone gate.

### 9. Commit

Clear, meaningful message. Conventional prefix.

### 10. Pull request — always, no exceptions

```bash
git push -u origin feat/<slug>
gh pr create --title "feat(<slug>): <what a user can now do>" --body "<what changed, acceptance criteria, test summary, review result>"
```

**Every feature gets a PR.** No exceptions, no "this one was small".

### 11. Merge

Wait for checks, then:

```bash
gh pr checks --watch
gh pr merge --squash --delete-branch
git checkout main && git pull --ff-only
```

If CI is red, fix it on the branch and push again. Never merge red.

Tag the version:

```bash
./scripts/release.sh
```

It reads the squash commit's prefix — `feat` is a minor bump, `fix`/`perf` a patch
(SemVer) — tags it, and pushes the tag. Every merged feature becomes a rollback
point. It is idempotent, so running it again after an interruption is safe. Never
tag by hand.

Then mark the slice `done` in `work/BOARD.md`, append any decision to
`docs/DECISIONS.md`. If that was the last slice of its milestone, run the
**milestone gate** below. Otherwise **go straight to the next feature.**

---

## Milestone gate — after the last slice of each milestone

Slices are grouped by the `Milestone` column on the board. A board without one is a
single milestone, gated after its last slice. Run the gate before starting the next
milestone. Same rules as step 8: each agent writes its report to disk, a report whose
`AUDITED:` equals HEAD is reused, at most two rounds, NOTES never block.

**Base ref:** the previous milestone's release tag, or the first commit.

1. **Security first.** Dispatch `security-auditor` with the milestone, base ref, and
   `round 1`. On `BLOCK`: branch `fix/<milestone>-security`, fix the BLOCKING
   findings, verify, round 2, PR titled `fix(security): <milestone> audit`, merge,
   `./scripts/release.sh` (a patch).
2. **Then performance**, on the code security left behind. Dispatch `perf-auditor` the
   same way. On `BLOCK`: branch `perf/<milestone>`, one fix per commit, re-measure
   after each — a fix that does not move its number gets reverted. PR titled
   `perf(<milestone>): <what got faster>` with before/after numbers, merge,
   `./scripts/release.sh`.
3. **Release the milestone:** `./scripts/release.sh --release "<milestone>"`.

Security goes first because performance work — caching, batching, skipping a check —
is where security regressions come from, and security fixes change performance.
Measure last, on the final code.

Reports under `docs/audits/` are committed on the next branch you open (the fix
branch, or the next feature's) — never directly on `main`.

---

## Orchestration

Use subagents and parallel or DAG execution where they genuinely help:

- **Sequential** when tasks depend on each other.
- **Parallel** when they are independent.
- **Diamond/DAG** when several agents can analyse, implement, test or review different
  aspects and the results get combined.

Do not use subagents for the sake of it. Optimise for correctness, speed, and
independent verification. Max 3 at once. Never let a subagent spawn its own subagents.

## Reusable skills

If you issue the same prompt or run the same multi-step procedure more than twice,
write it to `.claude/skills/<name>/SKILL.md` and use it from then on. Prefer project
tooling and existing skills over repeating instructions.

## Persistence

Rate limits, token limits, context limits and tool failures are expected. They are not
a reason to restart.

- Commit meaningful checkpoints before any long stretch of work.
- Keep implementation, tests, config and docs in the repository.
- Keep `work/<slug>/plan.md` current so any session can pick it up.
- On resume, inspect the repository first and continue from the last verified state.
- Never assume earlier work was lost because the session or the model changed.

**Usage limits.** Nothing that matters may live only in this conversation. Plan
progress is ticked in `plan.md` as it happens, `Now:` is current, commits are per step,
and every reviewer writes its own report to disk before it returns — so a limit that
lands mid-review loses at most the review in flight. Interactive sessions wait for the
reset and continue on their own (`autoContinueAtUsageLimit` in settings). Unattended
runs use `./scripts/ship-loop.sh`, which waits out the limit and restarts `/ship-it`.

**Context compaction.** The SessionStart hook re-injects branch, board, `Now:`, audit
state and blockers after every compaction, and `CLAUDE.md` is re-read from disk. After
a compaction, re-read `work/<slug>/plan.md` before touching code.

**Never stop early.** While `work/.shipping` exists and the board has work left, the
Stop hook sends you back to work. The only legitimate stop before Done is a blocker
from the next section.

The objective is durable progress toward completion, not a reply in this session.

## Done

Keep looping until:

- Every PRD requirement is implemented.
- Every acceptance criterion is satisfied.
- Unit, integration and e2e tests pass.
- Evals pass, or are documented as absent.
- `./scripts/verify.sh` exits 0.
- Independent review findings are resolved.
- Every feature branch is merged.
- Every milestone gate has run and the last milestone is released.
- The project is buildable, testable, and works end to end.

Do not declare it complete because the code is written. Verify the finished system
against the PRD and the project documentation, then `rm work/.shipping` and report
what shipped, with the final version tag.

## When to come back to the user

A missing credential, account, or paid service that cannot be created. Write it to
`work/BLOCKED.md` first — what is needed, why, and the exact step to resume from — then
stop. The Stop hook and `ship-loop.sh` both respect that file. Otherwise, work it out
and keep going.