# Claude Agentic Workflow Starter Kit

**A minimal, opinionated agentic coding workflow for Claude Code. Two commands. Ten files. No framework.**

`idea → PRD → vertical slices → branch → plan → build → verify → independent review → PR → merge`, on a loop, until the project is finished.

[![License: MIT](https://img.shields.io/badge/License-MIT-black.svg)](LICENSE)

---

## Why this exists

I read every popular Claude Code framework, agent collection and spec-driven development kit I could find. Then I measured them.

| Project | Footprint |
|---|---|
| gstack | **1.1 GB · 1,281 files · 482 skills**, one skill 3,054 lines long |
| alirezarezvani/claude-skills | 388 skills, 727 Python tools |
| agency-agents | 230+ agents across 17 "divisions" |
| wshobson/agents | 202 agents, 181 skills, 93 plugins |
| ECC | 68 agents, 286 skills |
| VoltAgent/awesome-claude-code-subagents | 158+ agents — and no guidance on when *not* to use one |
| oh-my-claudecode | 19 agents + a TypeScript build system |
| BMAD-METHOD | Node + Python + uv, just to install it |
| GitHub spec-kit | 7 ceremonial phases before line one |
| **this** | **10 files · 2 commands** |

I got sick of it. None of it made my code better. Most of it was rebuilding things **Claude Code already ships**.

So I deleted everything and wrote down the smallest thing that actually works.

---

## The insight nobody says out loud

Claude Code already has the framework. As of v2.1.252 it ships:

| Ships in the box | So stop rebuilding it |
|---|---|
| `/verify`, `/code-review`, `/security-review`, `/simplify`, `/debug` | test / review / debug skills |
| Plan mode, `/rewind`, `/branch`, `/diff`, `/autofix-pr` | plan wrappers, undo systems |
| Auto memory (`MEMORY.md`, four typed note kinds) | a memory subsystem |
| `.claude/rules/*.md` with `paths:` glob scoping | a rules engine |
| Built-in `Explore` and `Plan` subagents | a "researcher" agent |
| `/loop`, `/batch`, `/deep-research` | an orchestration layer |
| `context: fork` on any skill | most bespoke subagents |

**Custom commands merged into skills.** A 200-agent marketplace is not capability — Claude Code's own docs warn that combined agent descriptions over 15k tokens *degrade* routing.

Everything a starter kit still needs to add fits in ten files.

---

## The workflow

It is primarily a **workflow**, implemented as a **loop**.

- **Workflow** — the overall process from raw idea to finished project.
- **Loop** — the inner steps repeat for **every feature**.
- **Graph** — features can run sequentially, in parallel, or in diamond/DAG paths with subagents.
- **Subagents** — execution nodes inside the workflow, for independent planning, testing and review.
- **Skill** — a reusable procedure, extracted once the same prompt is used repeatedly.

> **An iterative, feature-level software development workflow, orchestrated as a graph, with a mandatory execution loop and specialized subagents.**

```
PRD / Docs
    ↓
Feature
    ↓
┌──────────────────────────────┐
│ Plan                         │
│ ↓                            │
│ Implement                    │
│ ↓                            │
│ Test → Debug → Evals         │
│ ↓                            │
│ CI                           │
│ ↓                            │
│ Independent Review           │
│ ↓                            │
│ Commit → PR → Merge          │
└───────────────┬──────────────┘
                ↓
          Next Feature
                ↓
        Complete Project
```

---

## Use it

```bash
git clone https://github.com/homayoun-asghari/claude-agentic-workflow-starter-kit
cd claude-agentic-workflow-starter-kit && ./install.sh
```

Then, for every project you ever start again:

```bash
newproject my-app          # git repo, .claude/ harness, verify script, CI — ready
                           # paste your idea into IDEA.md
/kickoff                   # ≤5 questions → PRD, architecture, decisions, Kanban of slices
/ship-it                   # builds every slice until the board is empty
```

**Two commands.** That is the whole interface.

`/ship-it` runs autonomously: branch → spec → plan → implement → verify → independent review → PR → CI → merge → next slice. It is resumable — kill it, come back tomorrow, run it again, it picks up from the last verified commit.

---

## What is actually in it

| File | Job | Enforcement |
|---|---|---|
| `scripts/verify.sh` | **The single definition of done.** Agent, pre-merge gate and CI all run *this file* | mechanical |
| `.claude/hooks/guard.sh` | Blocks commits to `main`, force-pushes, `rm -rf` outside the project, `curl \| sh` | **enforced** |
| `.claude/settings.json` | Denies reading `.env`/keys. Denies deploying. Caps subagents at 3 | **enforced** |
| `.claude/agents/spec-auditor.md` | Fresh-context audit of the diff against the acceptance criteria | procedural |
| `.claude/skills/kickoff/` | Idea → questions → PRD, architecture, decisions, board | procedural |
| `.claude/skills/ship-it/` | The autonomous build loop | procedural |
| `.github/workflows/verify.yml` | Calls `verify.sh`. **Never re-lists its steps** | **enforced** |
| `scripts/check-config.sh` | Contract-tests `.claude/` so the harness cannot rot | mechanical |
| `CLAUDE.md` | Under 200 lines. Facts only, never procedures | context |
| `work/<slug>/` | spec, plan, notes — committed, so the PR carries its own reasoning | context |

Four layers, ordered by how hard they are to violate:

```
ENFORCED    permissions · PreToolUse hook · branch protection · CI     ← cannot be talked past
MECHANICAL  scripts/verify.sh — exit 0 or it is not done
PROCEDURAL  2 skills · 1 subagent — loaded on demand
CONTEXTUAL  CLAUDE.md · docs/ · work/<slug>/
```

Anything that must be true goes in the top layer. **Rules written as prose get narrated, not followed.**

---

## Three rules this is built on

**1. One definition of done.** `./scripts/verify.sh` — format, lint, types, tests, build. The agent runs it, the merge gate runs it, CI runs *the same file*. On a real project I watched a hand-written `npm run ci` and its GitHub workflow drift apart **within a single day**. One file, three consumers, no drift.

**2. Never write a completion criterion that has no exit code.** I ran a workflow that mandated "run evals" and listed "evals pass" in its completion criteria. The finished project contained **zero evals**. Nothing caught it, because the criterion lived in prose. If it cannot fail mechanically, it will eventually be reported as passed.

**3. The implementer never reviews its own work.** On a 7-feature build, a fresh-context reviewer **blocked 5 of 7 pull requests** — catching silent money corruption, authorisation holes, non-transactional migrations, and user journeys that were never implemented at all. This is the highest-yield step in agentic coding, and it is one subagent.

---

## Two ideas being tested

Marked honestly, because I have not proven them yet.

**Five questions before building.** `/kickoff` asks **at most five** questions — only ones where different answers change the product. One round, then it commits. Inspired by Matt Pocock's `grill-me`, but bounded: interrogation skills can run for hours and produce compliance, not clarity.

**Vertical slices on a board.** `/kickoff` writes `work/BOARD.md` — every slice crosses the whole stack and ends in something a user can do.

```
Good:  "A visitor can sign up and land on an empty dashboard"   (schema + server + UI + tests)
Bad:   "Set up the database" → "Build the API" → "Build the UI"  (nothing demoable, nothing verifiable)
```

Both are **hypotheses**, labelled as such inside the skills. After a few real projects: did the questions catch anything? Did the board earn its overhead? That is how a methodology gets built — tested, not adopted.

---

## Prior art

Genuinely good ideas, taken with thanks: **[humanlayer's ACE-FCA](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents)** (research → plan → implement in separate contexts; review the plan, not the code — *"one bad line of plan is hundreds of bad lines of code"*), **[OpenSpec](https://github.com/Fission-AI/OpenSpec)** (one folder per change), **[superpowers](https://github.com/obra/superpowers)** (process skills beat implementation skills), **[impeccable](https://github.com/pbakaus/impeccable)** (deterministic checks separate from LLM judgment), **[K-Dense](https://github.com/K-Dense-AI/scientific-agent-skills)** (CI contract-tests your own config), **[BMAD](https://github.com/bmad-code-org/BMAD-METHOD)** (small changes go straight to build), **[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)** (a sane lifecycle shape).

Full research, measurements and design rationale: **[DESIGN.md](DESIGN.md)**.

---

## Keywords

Claude Code starter kit · agentic workflow · AI coding agent workflow · Claude Code skills · Claude Code subagents · Claude Code hooks · CLAUDE.md template · spec-driven development · AI software engineering · autonomous coding agent · Claude Code template · agentic development loop · vertical slice development · AI code review

MIT. If it saves you a day, star it.
