---
name: ship-it
description: Build the whole project. For every feature on the board - branch, plan, implement, test, debug, evals, CI, independent review, commit, PR, merge - and keep going until the board is empty and the project works end to end.
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
git branch --show-current
git status --short
git log --oneline -10
cat work/BOARD.md
```

- Mid-feature on a `feat/*` branch → read `work/<slug>/plan.md`, find the first
  unticked step, continue from there.
- On `main` and clean → start the next `todo` on the board.
- Board says `doing` but the PR is merged → it is `done`. Fix the board and move on.

---

## The loop, for every feature

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
- Numbered steps, each with the exact files it touches and how it gets verified.

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

Dispatch the `spec-auditor` subagent with the slug. **The agent that wrote the code is
never the only one to judge it.**

Fix every legitimate finding, re-run `./scripts/verify.sh`, commit as
`fix(<slug>): address independent review`, and re-run the auditor until it passes.

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

Then mark the slice `done` in `work/BOARD.md`, append any decision to
`docs/DECISIONS.md`, and **go straight to the next feature.**

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
- The project is buildable, testable, and works end to end.

Do not declare it complete because the code is written. Verify the finished system
against the PRD and the project documentation, then report what shipped.

## When to come back to the user

A missing credential, account, or paid service that cannot be created. Otherwise, work
it out and keep going.