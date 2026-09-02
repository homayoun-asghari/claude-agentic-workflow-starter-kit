---
name: kickoff
description: Turn a raw idea in IDEA.md into a PRD, an architecture, a verify script, CI, and a Kanban of vertical slices. Asks at most five questions first. Run this once, at the start of a project.
argument-hint: "[optional extra context]"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion, Agent(Explore)
---

# Kickoff

Turn `IDEA.md` into everything the build loop needs. Run once. Ends with a merged
`chore/kickoff` PR and a board of vertical slices ready for `/ship-it`.

Extra context from the invocation: `$ARGUMENTS`

---

## Step 0 — Branch

```bash
git rev-parse --abbrev-ref HEAD
git checkout -b chore/kickoff
```

Never work on `main`. The guard hook will block a commit there anyway.

## Step 1 — Read the idea

Read `IDEA.md`. If it is empty or only the template comment, stop and ask the user
to describe the project, then continue with what they say.

Read anything else already in the repo — a README, a client brief, designs, a schema.
Use `Explore` if there is more than a handful of files. Do not skip this: a question
whose answer is already written down is a wasted question.

## Step 2 — Ask at most five questions

> **This step is a hypothesis under test.** It is here because a raw idea dump and
> the agent's reading of it can differ badly, and that divergence is only discovered
> after code exists. Whether five questions is the right dose is not yet established.
> Record what it caught in `docs/DECISIONS.md`.

Ask **at most five** questions in a single `AskUserQuestion` call. Fewer is better.
Zero is correct if `IDEA.md` genuinely leaves nothing material open.

A question earns a slot only if **different answers would produce a different
product** — a different data model, a different primary user journey, a different
architecture, or different acceptance criteria.

Ask about:

- Who the primary user is, when more than one is plausible and they want different things.
- The single most important thing the product must do, when the dump lists many.
- A hard constraint not stated — deadline, budget, stack, hosting, compliance, an
  existing system to integrate with.
- Scale and realism — real users or a demo? Real payments or simulated? Real
  third-party integrations or stubs? *(This one is material surprisingly often.)*
- What is explicitly **out** of scope for v1.

Never ask:

- Anything answerable from `IDEA.md` or from the repository.
- Anything you could pick a sane default for and record as a decision instead.
- Preference questions with no downstream consequence (naming, colours, tabs).
- A follow-up round. **One round, then commit to the answers.** If something is still
  ambiguous afterwards, choose the more conservative reading, write it in
  `docs/DECISIONS.md` as an assumption, and move on.

## Step 3 — Write the durable documents

Create these three. They are the project's memory; everything downstream reads them.

**`docs/PRD.md`** — what and why, not how.
- One-paragraph summary
- The users, and what each needs
- Numbered user journeys, each phrased as something a person can do
- Explicit non-goals
- What "v1 is finished" means

**`docs/ARCHITECTURE.md`** — how, and *why that way*.
- Stack, and the reason for each choice (this is the part worth writing)
- Directory layout
- Data model
- Boundaries: what talks to what, and what must not
- What is real versus simulated, stated plainly

**`docs/DECISIONS.md`** — append-only.
- One line per decision: `YYYY-MM-DD — <decision> — <why>`
- Seed it with every decision from Step 2, and every assumption made in place of a
  sixth question.

## Step 4 — Set up the project

1. Choose the stack. Prefer boring, well-supported defaults; prefer what the user
   already runs. Check what is actually installed rather than assuming.
2. Scaffold with the official non-interactive generator where one exists.
3. **Rewrite `scripts/verify.sh`** with the real commands. Keep the contract: run
   every check, report all failures, exit non-zero if any failed. This file is the
   definition of done for the rest of the project.
4. Update `.github/workflows/verify.yml` with the toolchain setup only. **Do not
   list the checks there** — CI calls `./scripts/verify.sh`, and that is what keeps
   local and CI from drifting apart.
5. Fill in the placeholders in `CLAUDE.md`: what this is, and the command table.
6. Run `./scripts/verify.sh`. It must pass on an empty project before any feature
   is written. If it cannot pass, fix that now — a broken gate is worse than no gate.

## Step 5 — Cut the work into vertical slices

> **This step is a hypothesis under test.** The claim is that explicit, ordered,
> end-to-end slices make autonomous execution more coherent and progress visible.
> Whether the board earns its overhead is not yet established. Record the outcome.

Write `work/BOARD.md`. **It is the single source of truth for what is left to build.**

Every slice must **cross the whole stack and end in something a user can do.**

```
Good:  "A visitor can sign up and land on an empty dashboard"
       schema + server action + UI + tests, all in one slice

Bad:   "Set up the database"        <- cannot be demoed
       "Build the API"              <- cannot be verified end to end
       "Add authentication"         <- too big; not a single journey
```

Rules:

- Each slice traces to at least one PRD journey.
- Each is one sitting of work. If it is more, split it.
- Order by dependency first, then by user value.
- Slice 1 must be shippable on its own. If nothing is shippable alone, the slicing
  is still horizontal — redo it.
- 5–15 slices for a typical v1. More than 20 means they are too small.

Format:

```markdown
# Board

Source of truth for remaining work. `/ship-it` works top to bottom.
Status: `todo` -> `doing` -> `done`

| # | Slug | Slice (what a user can do) | PRD | Status |
|---|------|----------------------------|-----|--------|
| 1 | signup | A visitor can sign up and see an empty dashboard | J1 | todo |
| 2 | create-project | A signed-in user can create a project and see it listed | J2 | todo |
```

Then ask whether to mirror the board to GitHub Issues. If yes:
`gh issue create --title "<slug>: <slice>" --body "<PRD journeys, acceptance criteria>"`
and record the issue number in the table. `work/BOARD.md` stays the source of truth;
the issues are a view of it.

## Step 6 — Land it

```bash
./scripts/verify.sh
git add -A
git commit -m "chore: kickoff — PRD, architecture, decisions, verify, board"
git push -u origin chore/kickoff
gh pr create --fill && gh pr merge --squash --delete-branch
```

If there is no remote, tell the user and stop with the branch in place.

## Step 7 — Hand over

Report, briefly:

- What the product is, in two sentences
- The stack, and the one choice most worth objecting to
- What Step 2 changed about your understanding — **or that it changed nothing**, which
  is evidence about the hypothesis and worth saying out loud
- The slice list
- That `/ship-it` is the next command

Do not start building. `/kickoff` ends here.
