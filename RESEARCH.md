# Research

Why this kit is shaped the way it is. Measurements taken September 2026, against
Claude Code v2.1.

---

## 1. What I measured

I read every popular Claude Code framework, agent collection and spec-driven
development kit I could find, then counted what was actually in them.

| Project | Footprint |
|---|---|
| gstack | 1,281 files · 482 skills, one skill 3,054 lines long |
| alirezarezvani/claude-skills | 388 skills, 727 Python tools |
| agency-agents | 230+ agents across 17 "divisions" |
| wshobson/agents | 202 agents, 181 skills, 93 plugins |
| VoltAgent/awesome-claude-code-subagents | 158+ agents |
| K-Dense scientific-agent-skills | 163 skills |
| ECC | 68 agents, 286 skills |
| GitHub spec-kit | six commands before implementation, `.specify/` tree, Python |
| BMAD-METHOD | Node + Python + uv toolchain to install |
| oh-my-claudecode | 19 agents plus a TypeScript build system |
| compound-engineering | 33 skills |
| addyosmani/agent-skills | 25 skills across Define → Plan → Build → Verify → Review → Ship |
| mattpocock/skills | ~20 skills |
| obra/superpowers | 13 skills |
| OpenSpec | 4 core commands |

Two observations that shaped everything:

**Size does not correlate with usefulness.** The leanest projects in this list —
superpowers at 13 skills, OpenSpec at 4 commands — carry more transferable ideas than
the 200-agent marketplaces. Past roughly 25 components, the projects stop adding
capability and start adding surface area.

**Almost none of them say when *not* to use a subagent.** A 158-agent catalogue with
no guidance on restraint is not a toolkit, it is a menu. Subagents are a
context-isolation mechanism; treating them as an org chart is the central mistake of
this genre.

---

## 2. What Claude Code already ships

This is the finding that made most of a starter kit unnecessary. As of v2.1:

| Ships in the box | So do not rebuild it |
|---|---|
| `/code-review`, `/security-review`, `/simplify` | review, security and cleanup skills |
| `/run`, `/verify` — build and drive the actual app | "does it really work" skills |
| Plan mode, `/rewind`, `/diff`, `/autofix-pr` | plan wrappers, undo, CI babysitters |
| Auto memory — `MEMORY.md` plus four typed note kinds | a memory subsystem |
| `.claude/rules/*.md` scoped by `paths:` globs | a rules engine |
| Built-in `Explore` and `Plan` subagents, read-only | a "researcher" agent |
| `/loop`, `/batch` | an orchestration layer |
| `context: fork` on any skill | most bespoke subagents |
| `/doctor`, `/fewer-permission-prompts` | config maintenance tooling |

Mechanism notes worth knowing before you design anything:

- **Custom commands have merged into skills.** `.claude/commands/x.md` and
  `.claude/skills/x/SKILL.md` both produce `/x`. Commands are legacy and support
  strictly fewer features. "Commands" is not a separate component any more.
- **CLAUDE.md is context, not configuration.** It is delivered as a user message and
  there is no guarantee of compliance. Anything that must be true belongs in a
  `PreToolUse` hook or a `permissions` rule. Target under 200 lines.
- **`.claude/rules/*.md` with `paths:` frontmatter** is the real context-saving
  mechanism — rules load only when Claude touches matching files. `@path` imports do
  *not* save context; they load at launch like everything else.
- **Subagent descriptions cost context on every session.** Claude Code warns at
  startup once they total 15,000 tokens. Every agent you add is a permanent tax.
- **Keep a `SKILL.md` under 500 lines.** Move detail to sibling files; they cost
  nothing until read.
- **Project hooks only run after workspace trust is accepted**, so cloning a repo
  executes nothing.

---

## 3. What I took from prior art

- **[humanlayer ACE-FCA](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents)**
  — research → plan → implement as *separate contexts*; keep utilisation 40–60%; and
  the argument that decides where humans should spend attention:

  > One bad line of code = one bad line of code.
  > One bad line of *plan* = hundreds of bad lines of code.
  > One bad line of *research* = thousands of bad lines of code.

  Review the plan, not the diff.
- **[OpenSpec](https://github.com/Fission-AI/OpenSpec)** — one folder per change, plain
  markdown, no DSL, and an explicit rejection of rigid phase gates.
- **[superpowers](https://github.com/obra/superpowers)** — process skills outrank
  implementation skills; a workflow that can be skipped will be.
- **[impeccable](https://github.com/pbakaus/impeccable)** — separate deterministic
  detectors from LLM judgment, so one can run in CI without the other.
- **[K-Dense](https://github.com/K-Dense-AI/scientific-agent-skills)** — CI that
  contract-tests your own config: frontmatter conformance, link resolution, size caps.
- **[BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD)** — small changes go
  straight to build. Ceremony must scale with the change.
- **[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)** — a sane
  lifecycle shape, and "anti-rationalization tables" listing the excuses an agent uses
  to skip a step.
- **[compound-engineering](https://github.com/EveryInc/compound-engineering-plugin)** —
  write the learning where the next change will read it. Auto memory now does most of
  this for free.

## What I deliberately avoided

1. **Agent zoos.** Persona count is not capability.
2. **Rebuilding built-ins.** See §2.
3. **A custom CLI, daemon or build system.** A starter kit should not need `npm install`.
4. **Preamble tax** — telemetry, update checks and config reads at the top of every
   skill invocation, paid on every call.
5. **Ceremonial phase gates** before a one-file change.
6. **Multi-harness duplication** — the same skill copied into nine vendor directories.
7. **A bespoke memory system.** Auto memory ships.
8. **Evals for non-AI products.** See §4.

---

## 4. Field evidence

One real client project, built in a single day in September 2026 with a large
hand-written workflow prompt: seven feature branches, seven merged PRs, CI green on
every run, 245 tests passing, deployed. The workflow itself was ordinary and correct —
`plan → implement → test → review → commit → PR → merge`.

Four things it showed, and all three rules below come from them.

**Independent review is the highest-yield step, by a wide margin.**
Five of seven pull requests were blocked by a fresh-context reviewer before merge. It
caught silent money corruption, authorisation holes on write paths, non-transactional
migrations, an invariant enforced in the service layer but not the database, and user
journeys specified in the PRD that had no implementation at all. A ~71% block rate
means the implementing agent shipped materially broken work roughly three times in
four — and only a reviewer that had *not* written the code caught it.

**A criterion with no exit code gets narrated, not performed.**
The prompt mandated "run evaluations (evals)" as step 6, and listed "evals pass" in its
completion criteria. The finished repository contained **zero evals** — no directory,
no script, no mention anywhere. The step was reported as satisfied because nothing
could mechanically prove otherwise. This generalises well beyond evals, and it is the
single most expensive failure mode in autonomous workflows.

**Two definitions of "done" drift apart immediately.**
The project had a hand-written `npm run ci` script *and* a GitHub Actions workflow
listing its own steps. They diverged within a single day — CI ran a build and a browser
suite that the local command did not. Local green stopped meaning CI green.

**Rules written as prose do not hold.**
"Never commit to main" was in the prompt. The trunk received five direct commits,
two of them fixing CI by pushing straight past the gate. Branch protection was
unavailable on that repository, so the rule existed only as text — and text lost.

---

## 5. The design that came out of it

Four layers, ordered by how hard they are to violate. This ordering *is* the design:

```
ENFORCED    permissions · PreToolUse hook · branch protection · CI
MECHANICAL  scripts/verify.sh — exit 0, or it is not done
PROCEDURAL  2 skills · 1 subagent — loaded on demand
CONTEXTUAL  CLAUDE.md · docs/ · work/<slug>/
```

Anything that must be true goes in the top layer. Everything else is a suggestion.

Three rules follow directly from §4:

1. **One definition of done.** `scripts/verify.sh` is run by the agent, the merge gate
   and CI — the same file, never a copy of its steps.
2. **Never write a completion criterion that has no exit code.**
3. **The implementer never reviews its own work.** One fresh-context subagent,
   auditing the diff against the acceptance criteria that were written before the code.

And one that comes from the survey rather than the field: **ceremony scales with the
change.** A fifty-line fix does not get a spec and a plan. Unskippable process is
abandoned process.

---

## 6. Two hypotheses, not conclusions

Both of these are in `/kickoff`, and both are labelled as hypotheses inside the skill
itself. I have not tested either yet.

**A bounded five-question clarification pass.**
The problem: a raw idea dump and the agent's reading of it can diverge badly, and the
divergence is only discovered after code exists. The proposed fix is *at most* five
questions, asked in one round, and only where different answers would change the
product, the data model, a primary user journey, or the acceptance criteria.

The bound is the point. Open-ended interrogation skills can run for hours and produce
compliance rather than clarity. One round, then commit to the answers; anything still
ambiguous takes the conservative reading and is recorded as an assumption.

**Vertical slices on a board.**
`/kickoff` writes `work/BOARD.md`, and every slice must cross the whole stack and end
in something a user can do.

```
Good:  "A visitor can sign up and land on an empty dashboard"   schema + server + UI + tests
Bad:   "Set up the database" → "Build the API" → "Build the UI"
```

A horizontal slice cannot be demoed, cannot be verified end to end, and cannot be
merged safely on its own. The claim is that explicit ordered slices make autonomous
execution more coherent and progress legible.

**How they get tested.** After a few real projects: did the questions surface anything
that was not in the idea dump? Did they prevent rework, or just add a round trip? Were
five too many or too few? Did the board make execution clearer, or become bureaucracy
the agent ignored?

Then there is evidence, and they stop being someone else's advice.
