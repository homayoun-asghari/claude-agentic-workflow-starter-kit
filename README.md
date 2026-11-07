# Claude Agentic Workflow Starter Kit

**A minimal Claude Code template — the workflow, CLAUDE.md, hooks, skills and review subagent I actually use. Two commands. One reviewer per feature, a security and a performance auditor per milestone. Zero dependencies.**

`idea → PRD → vertical slices → branch → plan → build → verify → independent review → PR → merge → tag`, on a loop, until the project is finished.

![demo](docs/demo.gif)

<sub>Real run, nothing staged. Regenerate with `vhs docs/demo.tape`.</sub>

[![License: MIT](https://img.shields.io/badge/license-MIT-black.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-v2.1%2B-black.svg)](https://claude.com/claude-code)

## Quickstart

```bash
git clone https://github.com/homayoun-asghari/claude-agentic-workflow-starter-kit
cd claude-agentic-workflow-starter-kit && ./install.sh
```

**Requires** Claude Code v2.1+, `git`, and `gh` (it opens and merges PRs).
`install.sh` writes one script to `~/.local/bin/newproject` and copies the template to
`~/.claude-kit`. Nothing global, nothing else. Uninstall: `rm ~/.local/bin/newproject && rm -rf ~/.claude-kit`.

Then, for every project you start from now on:

```bash
newproject my-app     # git repo, .claude/ harness, verify script, CI — ready
                      # claude opens and asks you for the idea
/kickoff              # ≤5 questions → PRD, architecture, decisions, board of vertical slices
/ship-it              # builds every slice until the board is empty
```

Staying current:

```bash
newproject --self-update   # pull the latest kit and reinstall
newproject --update        # inside a project: refresh its skills, agents, hooks, settings and kit scripts
```

`--update` refreshes only the kit's own machinery. Your `CLAUDE.md`, `docs/`, `work/`, `IDEA.md`, `scripts/verify.sh` and CI workflow are never touched.

**Two commands.** That is the whole interface.

`/ship-it` runs autonomously: branch → spec → plan → implement → verify → independent review → PR → CI → merge → version tag → next slice. After each milestone it runs a security audit, then a performance audit, then cuts a release. It is resumable — kill it, come back tomorrow, run it again, and it picks up from the last verified commit.

## The loop

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
│ Commit → PR → Merge → Tag    │
└───────────────┬──────────────┘
                ↓
          Next Feature
                ↓
   Milestone done? Security → Performance → Release
                ↓
        Complete Project
```

- **Workflow** — the overall process from raw idea to finished project.
- **Loop** — the inner steps repeat for **every feature**.
- **Graph** — features can run sequentially, in parallel, or in diamond/DAG paths with subagents.
- **Subagents** — execution nodes inside the workflow, for independent planning, testing and review.
- **Skill** — a reusable procedure, extracted once the same prompt is used repeatedly.

## Claude Code already ships most of this

This is the part that made me delete everything else. As of Claude Code v2.1, in the box:

| Ships in the box | So stop rebuilding it |
|---|---|
| `/code-review`, `/security-review`, `/simplify` | review, security and cleanup skills |
| `/run` and `/verify` — build and drive your actual app | "does it really work" skills |
| Plan mode, `/rewind`, `/diff`, `/autofix-pr` | plan wrappers, undo, CI babysitters |
| Auto memory — `MEMORY.md` plus four typed note kinds | a memory subsystem |
| `.claude/rules/*.md`, scoped by `paths:` globs | a rules engine |
| Built-in `Explore` and `Plan` subagents, both read-only | a "researcher" agent |
| `/loop`, `/batch` | an orchestration layer |
| `context: fork` on any skill | most bespoke subagents |

Custom commands have merged into skills. And a 200-agent marketplace is not capability: every agent's description sits in your context window every session, and Claude Code warns you once they total 15,000 tokens.

<sub>Claude Code's `/verify` builds and drives your running app. This kit's `scripts/verify.sh` is the static gate — lint, types, tests, build. Complementary, not duplicates.</sub>

Everything a starter kit still needs to add fits in sixteen files.

## What is actually in it

| File | Job |
|---|---|
| `scripts/verify.sh` | **The single definition of done.** Agent, merge gate and CI all run *this file* |
| `.claude/settings.json` | Never asks for permission. Continues automatically after a usage limit. Wires the hooks. Caps subagents at 3 |
| `.claude/agents/spec-auditor.md` | Fresh-context audit of the diff against the acceptance criteria. Two rounds, max |
| `.claude/agents/security-auditor.md` | Milestone audit: dependencies, secrets, cross-feature access, injection |
| `.claude/agents/perf-auditor.md` | Milestone audit against written budgets. Measures first, never optimises on a hunch |
| `.claude/hooks/state.sh` | **Enforced.** Re-injects where-we-are after every compaction; stops `/ship-it` quitting early |
| `scripts/release.sh` | SemVer tag from the merge commit's prefix — `feat` minor, `fix`/`perf` patch |
| `scripts/ship-loop.sh` | Unattended `/ship-it` that waits out usage limits and restarts until the board is done |
| `.claude/skills/kickoff/` | Idea → questions → PRD, architecture, decisions, board |
| `.claude/skills/ship-it/` | The autonomous build loop |
| `.github/workflows/verify.yml` | **Enforced.** Calls `verify.sh`. Never re-lists its steps |
| `scripts/check-config.sh` | Contract-tests `.claude/` so the harness cannot rot |
| `CLAUDE.md` | Under 200 lines. Facts only, never procedures |
| `work/<slug>/` | spec, plan, notes — committed, so the PR carries its own reasoning |

Four layers, ordered by how hard they are to violate:

```
ENFORCED    hooks · CI                 ← cannot be talked past
MECHANICAL  verify.sh — exit 0 or not done
PROCEDURAL  2 skills · 3 subagents
CONTEXTUAL  CLAUDE.md · docs/ · work/
```

Anything that must be true goes in the top layer. **Rules written as prose get narrated, not followed.**

## It does not stop until the board is done

- **Usage limits.** `settings.json` turns on `autoContinueAtUsageLimit`: an interactive session waits for the reset and carries on. For a run that must outlive the terminal, `./scripts/ship-loop.sh` runs `/ship-it` headless and restarts it after each reset.
- **Nothing lives only in the conversation.** Every reviewer writes its report to disk, stamped with the commit it audited, before it returns. A limit that lands mid-review loses at most the review in flight; a finished one is reused, never re-run.
- **Context compaction.** A SessionStart hook prints branch, board, the plan's `Now:` line and audit state into context on startup, resume and after every compaction. A PreCompact hook tells the summary what to keep.
- **Quitting early.** While `/ship-it` runs, a Stop hook sends it back to work if the board has slices left — unless it wrote `work/BLOCKED.md`, or three forced continuations changed nothing.

## Three rules this is built on

**1. One definition of done.** `./scripts/verify.sh` — format, lint, types, tests, build. The agent runs it, the merge gate runs it, CI runs *the same file*. On a real project I watched a hand-written `npm run ci` and its GitHub workflow drift apart within a single day.

**2. Never write a completion criterion that has no exit code.** I ran a workflow that mandated "run evals" and listed "evals pass" in its completion criteria. The finished project contained **zero evals**. Nothing caught it, because the criterion lived in prose. If it cannot fail mechanically, it will eventually be reported as passed.

**3. The implementer never reviews its own work.** On a 7-feature build, a fresh-context reviewer **blocked 5 of 7 pull requests** — catching silent money corruption, authorisation holes, non-transactional migrations, and user journeys that were never implemented at all. This is the highest-yield step in agentic coding, and it is one subagent.

## Why this exists

I read every popular Claude Code framework, agent collection and spec-driven development kit I could find. Then I counted what was actually in them.

| Project | Footprint |
|---|---|
| gstack | 1,281 files · 482 skills, one skill 3,054 lines long |
| alirezarezvani/claude-skills | 388 skills, 727 Python tools |
| agency-agents | 230+ agents across 17 "divisions" |
| wshobson/agents | 202 agents, 181 skills, 93 plugins |
| VoltAgent/awesome-claude-code-subagents | 158+ agents |
| ECC | 68 agents, 286 skills |
| oh-my-claudecode | 19 agents plus a TypeScript build system |
| BMAD-METHOD | Node + Python + uv toolchain to install |
| GitHub spec-kit | six commands to run before you write a line |
| **this** | **16 files · 2 commands** |

<sub>Counted September 2026. Numbers move; the pattern does not.</sub>

I got sick of it. None of it made my code better. Most of it was rebuilding things Claude Code already ships, and almost none of it told me when *not* to reach for a subagent — which turns out to be most of the time.

So I deleted everything and wrote down the smallest thing that actually works.

## Two ideas being tested

`/kickoff` asks **at most five** questions before it writes anything, and cuts the work into **vertical slices** on `work/BOARD.md` — every slice crosses the whole stack and ends in something a user can do. Both are labelled **hypotheses** inside the skills, because I have not proven them yet. Reasoning in [RESEARCH.md](RESEARCH.md).

<details>
<summary><strong>Prior art</strong> — good ideas, taken with thanks</summary>

- **[humanlayer ACE-FCA](https://github.com/humanlayer/advanced-context-engineering-for-coding-agents)** — research → plan → implement in separate contexts. Review the plan, not the code: *"one bad line of plan is hundreds of bad lines of code."*
- **[OpenSpec](https://github.com/Fission-AI/OpenSpec)** — one folder per change, plain markdown, no DSL.
- **[superpowers](https://github.com/obra/superpowers)** — process skills beat implementation skills.
- **[impeccable](https://github.com/pbakaus/impeccable)** — deterministic checks kept separate from LLM judgment.
- **[K-Dense](https://github.com/K-Dense-AI/scientific-agent-skills)** — CI that contract-tests your own config.
- **[BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD)** — small changes go straight to build.
- **[addyosmani/agent-skills](https://github.com/addyosmani/agent-skills)** — a sane lifecycle shape.

Full survey, measurements and design rationale: **[RESEARCH.md](RESEARCH.md)**.

MIT. If it saves you a day, star it.

</details>

MIT. If it saves you a day, star it.
