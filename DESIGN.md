# Cloud Agentic Workflow Starter Kit — Research, Analysis & Design

**Status:** proposal, awaiting approval. No implementation written.
**Date:** 2026-09-02
**Author:** Claude (Opus 5) for Homayoun Asghari

---

## Table of contents

1. [Phase 1 — Research](#phase-1--research)
   - [1.1 The finding that reshapes the design](#11-the-finding-that-reshapes-the-design)
   - [1.2 Claude Code mechanisms — verified current spec](#12-claude-code-mechanisms--verified-current-spec)
   - [1.3 Framework survey — measured](#13-framework-survey--measured)
   - [1.4 Patterns worth adopting](#14-patterns-worth-adopting)
   - [1.5 Complexity to deliberately avoid](#15-complexity-to-deliberately-avoid)
2. [Phase 1b — Field evidence: the island-media-ops build](#phase-1b--field-evidence-the-island-media-ops-build)
3. [Phase 2 — Design proposal](#phase-2--design-proposal)
4. [Open decisions](#open-decisions)

---

# Phase 1 — Research

## 1.1 The finding that reshapes the design

Claude Code v2.1.252 (Sept 2026) **already ships most of what these frameworks build.**
Verified against current documentation at `code.claude.com/docs`.

| Already built in | So do not build |
|---|---|
| `/verify` — and it *records its own recipe* into `.claude/skills/verify/SKILL.md` | a test-runner skill |
| `/code-review`, `/security-review`, `/simplify`, `/debug` | review / security / debug skills |
| Plan mode (`/plan`), `/rewind`, `/branch`, `/diff`, `/autofix-pr` | plan-mode wrappers, undo systems |
| Auto memory — `~/.claude/projects/<p>/memory/`, `MEMORY.md` index, 4 typed note kinds | a memory subsystem |
| `.claude/rules/*.md` with `paths:` glob frontmatter → lazy, path-scoped loading | a rules engine |
| Built-in `Explore` and `Plan` subagents (read-only; skip CLAUDE.md + git status for cheapness) | a "researcher" agent |
| `/loop`, `/batch` (worktree fan-out, PR per unit), `/deep-research` | an orchestration layer |
| `context: fork` on a skill → runs it in its own subagent context | most bespoke subagents |
| `/doctor`, `/fewer-permission-prompts` | config maintenance tooling |

**Commands and skills have merged.** `.claude/commands/deploy.md` and
`.claude/skills/deploy/SKILL.md` both produce `/deploy`. Commands are legacy and
support strictly fewer features. **"Commands" is no longer a component** — it is
struck from the design.

## 1.2 Claude Code mechanisms — verified current spec

### Skills — `.claude/skills/<name>/SKILL.md`

- Locations: `~/.claude/skills/` (personal), `.claude/skills/` (project), `<plugin>/skills/` (plugin).
- The **directory name** becomes the command. Frontmatter `name` is only a display
  label for personal/project skills (it *does* set the command for plugin skills).
- Frontmatter fields: `name`, `description`, `when_to_use`, `argument-hint`,
  `allowed-tools`, `disallowed-tools`, `disable-model-invocation`, `user-invocable`,
  `context` (`fork`), `arguments`, `model`, `metadata`, `license`, `compatibility`.
- `description` + `when_to_use` are **truncated at 1,536 characters** in the skill
  listing. Put the key use case first.
- Keep `SKILL.md` **under 500 lines**. Move reference material to sibling files —
  progressive disclosure means they cost nothing until read.
- Arguments: `$ARGUMENTS`, `$ARGUMENTS[N]`, `$N`, `$name`, plus `${CLAUDE_SKILL_DIR}`
  and `${CLAUDE_PROJECT_DIR}`.
- Bash injection in the body allows dynamic context.
- **Agent Skills open standard** (agentskills.io) permits only six fields —
  `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`.
  Anything else fails packaging validation. Relevant: the vault's skills follow this spec.

### Subagents — `.claude/agents/<name>.md`

- Required: `name`, `description`. Optional: `tools`, `disallowedTools`, `model`,
  `permissionMode`, `maxTurns`, `skills` (preloads full content), `mcpServers`,
  `hooks`, `memory`, `background`, `effort`, `isolation: worktree`, `color`,
  `initialPrompt`, `experimental`.
- **Combined descriptions over 15,000 tokens trigger a warning** — an agent zoo
  actively degrades routing.
- Non-fork subagents start fresh: no conversation history, no prior skills, no auto
  memory. They *do* get the CLAUDE.md hierarchy.
- Forks inherit everything. Use sparingly.
- Nesting: up to 3 layers deep by default; `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1`
  disables it. Concurrency default 20 — **this machine is capped at 3.**
- Built-ins: `Explore`, `Plan` (both read-only), `general-purpose`, `claude`.

### Hooks

- Events include `PreToolUse`, `PostToolUse`, `PostToolUseFailure`, `PostToolBatch`,
  `UserPromptSubmit`, `Stop`, `SubagentStart/Stop`, `SessionStart/End`,
  `PreCompact/PostCompact`, `PermissionRequest`, `InstructionsLoaded`, `FileChanged`,
  and ~15 more.
- Types: `command`, `http`, `mcp_tool`, `prompt`, `agent`.
- **Exit code 2 blocks** on events that support blocking. Or return JSON:
  `{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny",
  "permissionDecisionReason":"..."}}`
- `if:` supports permission-rule syntax (`"if": "Bash(rm *)"`) so a hook only fires
  on matching calls.
- **Project hooks only run after workspace trust is accepted.** Cloning a repo
  executes nothing.

### Memory

- `CLAUDE.md` — **target under 200 lines.** Loaded every session. Delivered as a user
  message, not system prompt — not enforcement.
- Locations, in load order: managed policy → `~/.claude/CLAUDE.md` → `./CLAUDE.md`
  or `./.claude/CLAUDE.md` → `./CLAUDE.local.md`.
- `@path` imports, max depth 4. **Imports still load at launch — they save
  organisation, not context.**
- `.claude/rules/*.md` — recursive discovery; `paths:` frontmatter scopes a rule to
  globs so it loads only when Claude touches matching files. This is the real
  context-saving mechanism.
- Auto memory is on by default and writes four note types (`user`, `feedback`,
  `project`, `reference`).
- Block-level HTML comments in CLAUDE.md are stripped before injection — free
  maintainer notes.

### Settings — precedence

managed → `--settings` → `.claude/settings.local.json` → `.claude/settings.json` →
`~/.claude/settings.json`.

Permission rule syntax: `"Bash(npm run lint)"`, `"Bash(npm run test *)"`,
`"Read(./.env)"`, `"Read(./.env.*)"`. **`deny` and `ask` apply immediately;
`allow` waits for workspace trust.**

## 1.3 Framework survey — measured

| Project | Footprint | Verdict |
|---|---|---|
| **gstack** (measured on this machine) | **1.1 GB · 1,281 files · 482 `SKILL.md` · 704 MB `node_modules`**; `ship/SKILL.md` = **3,054 lines** (6× the 500-line guidance); every skill duplicated across 9 harness dirs (`.cursor`, `.opencode`, `.kiro`, `.factory`, `.slate`, `.gbrain`, `.hermes`, `.openclaw`, `.agents`); ~60-line telemetry/update-check bash preamble before any work | The end-to-end loop is the good idea. The delivery is the anti-pattern. |
| **humanlayer ACE-FCA** | one document | ★★★ **Best idea in the survey.** See below. |
| **OpenSpec** | 4 commands, `openspec/changes/<name>/` | ★★ One folder per change, plain markdown. Explicitly rejects phase gates. |
| **spec-kit** (GitHub) | 8 phases, `.specify/` tree, Python | Ceremony. 7 gates before line one. |
| **superpowers** (installed here) | 13 skills | ★★ Process skills beat implementation skills; mandatory triggers. |
| **addyosmani/agent-skills** | 25 skills across Define→Plan→Build→Verify→Review→Ship | ★★ Closest to a sane shape. "Anti-rationalization tables" are clever. |
| **compound-engineering** | 33 skills | ★ Write the learning where the next change reads it — but auto memory now does most of this free. |
| **impeccable** | 61 deterministic detectors + LLM layer | ★★ Split deterministic checks from LLM judgment. |
| **cc-starter** | 10 skills, 3 hooks | ★ `protect-sensitive.sh` pattern; "delegation not accumulation". |
| **mattpocock/skills** | ~20 | ★ "Small, hackable, not rigid frameworks." |
| **K-Dense scientific-agent-skills** | 163 skills | ★ CI **contract-tests the skills themselves** (frontmatter conformance, link resolution). |
| **BMAD-METHOD** | node + python + uv install | ★ "Small changes go straight to build." |
| **Understand-Anything** | 7 agents | ★ Deterministic (tree-sitter) + semantic (LLM) split; incremental re-analysis. |
| **ECC** | 68 agents + 286 skills | Agent zoo |
| **wshobson/agents** | 202 agents, 181 skills, 93 plugins | Agent zoo |
| **agency-agents** | 230+ agents, 17 "divisions" | Agent zoo |
| **alirezarezvani/claude-skills** | 388 skills, 727 Python tools | Agent zoo |
| **VoltAgent/awesome-claude-code-subagents** | 158+ agents — and **no guidance on when *not* to use one** | Agent zoo |
| **oh-my-claudecode** | 19 agents + full TS build | Agent zoo + build system |
| **get-shit-done** | archived June 2026 → `open-gsd/gsd-core` | Moved |
| **anthropics/skills** | official spec + template | Reference for the standard |
| **shanraisshan/claude-code-best-practice** | docs | ★ Context rot >300–400k tokens; target <40% utilisation; CLAUDE.md <200 lines |

### ACE-FCA — the one idea to build on

From humanlayer's *Advanced Context Engineering for Coding Agents*:

- **research → plan → implement, as separate contexts.**
- Keep context utilisation **40–60%**. "The contents of your context window are the
  ONLY lever you have to affect the quality of your output."
- Context damage, worst to best: **incorrect info > missing info > noise.**
- **Human review moves off the code and onto the plan:**

  > One bad line of code = one bad line of code.
  > One bad line of *plan* = hundreds of bad lines of code.
  > One bad line of *research* = thousands of bad lines of code.

  > "I can't read 2000 lines of golang daily. But I can read 200 lines of a
  > well-written implementation plan."

- **Intentional compaction:** when context fills, deliberately distil progress to
  disk (goal, approach, steps done, current failure) and restart fresh.
- Subagents exist to keep grep/read/glob traces out of the main window.
- Results: 300k-LOC Rust bug fixed in <1h; 35k LOC shipped in 7h by two developers.
- Caveat the author states plainly: *"you have to engage with your task when you're
  doing this or it WILL NOT WORK."*

## 1.4 Patterns worth adopting

1. **ACE-FCA phase separation + plan-level human review.** (humanlayer)
2. **One folder per change, plain markdown, on disk.** (OpenSpec)
3. **A single verification entrypoint** shared by agent, hook and CI. (synthesised —
   and independently arrived at in island-media-ops as `npm run ci`)
4. **Deterministic checks separated from LLM judgment.** (impeccable)
5. **Independent, fresh-context review — never self-review.** (superpowers, ECC, and
   empirically the highest-value step in the island-media-ops build)
6. **Durable, resumable state on disk.** (ACE-FCA; PROGRESS.md in island-media-ops)
7. **Scale the ceremony to the change.** (BMAD)
8. **CI that contract-tests your own `.claude/` config.** (K-Dense)
9. **Process skills outrank implementation skills.** (superpowers)
10. **Hooks, not prose, for anything that must actually be enforced.** (docs are
    explicit: CLAUDE.md is context, not configuration)

## 1.5 Complexity to deliberately avoid

1. **Agent zoos.** Persona count is not capability. Combined agent descriptions over
   15k tokens degrade routing *by documented behaviour*. Subagents are a
   **context-isolation** tool, not an org chart.
2. **Rebuilding built-ins.** See §1.1.
3. **A custom CLI / daemon / TS build.** 704 MB of `node_modules` to drive a browser.
4. **Preamble tax.** Telemetry, update checks, and config reads at the top of every
   skill invocation.
5. **Ceremonial phase gates** before a one-file change. This is why spec-kit adoption
   stalls.
6. **Multi-harness duplication.** Nine copies of every skill. Target one harness.
7. **A bespoke memory system.** Auto memory ships.
8. **Evals for non-AI products.** See the field evidence below — this step was
   silently skipped in practice and nobody noticed.

---

# Phase 1b — Field evidence: the island-media-ops build

A real project built 2026-09-01 with a single large workflow prompt.
Repo: `github.com/homayoun-asghari/island-media-ops` (private).
Local: `~/Projects/clients projects/connected advertising operations`.

**This is the most valuable data in this document — it is a controlled test of the
workflow, not a claim about one.**

## What was verified

| Claim | Method | Result |
|---|---|---|
| Feature branches used | `git branch -a` | ✅ 8 branches, all pushed |
| PRs opened and merged | `gh pr list --state all` | ✅ **7/7 MERGED** |
| CI ran and passed | `gh run list` | ✅ green on every PR and every push, ~2.5 min |
| Tests exist | `find` | ✅ 18 files: 6 unit, 7 integration, 4 e2e, 1 prod smoke |
| Tests actually pass | `npm run ci` run locally | ✅ **245 tests, 12 files, exit 0** |
| Secret hygiene | `git ls-files`, regex scan of tracked files | ✅ only `.env.example` tracked; no credentials found |
| CI covers build + e2e | read `.github/workflows/ci.yml` | ✅ typecheck, lint, tokens, template, test, build, Playwright |
| Independent review happened | `PROGRESS.md`, commit messages | ✅ **5 of 7 PRs: "review BLOCK → fixed"** |
| **Evals ran** | `git grep -in 'eval'` across all tracked files | ❌ **zero matches.** Only `revalidatePath` false positives. |
| Reusable skills extracted | `find .claude` | ❌ **no `.claude/` directory at all** |
| main protected | `gh api .../branches/main/protection` | ❌ 403 — private repo, feature not enabled |

## What the workflow got right

**1. The independent review step is the single highest-value component.**
Five of seven PRs record `review BLOCK → fixed`. The review caught, among others:

- `feat/foundation` — 4 findings: migrations not transactional, missing advisory
  lock, capacity not enforced as a database invariant, drivers in the wrong
  dependency block.
- `feat/documents` — invalid OOXML and silent data loss.
- `feat/session` — authorisation holes; a transaction claim not honoured.
- `feat/contracts` — **silent money corruption**, and PRD user journeys that had
  simply never been implemented.

A ~71% block rate means the implementing agent shipped materially broken work
roughly three times in four, and only a *fresh-context* reviewer caught it. This
empirically validates the design choice, and it is the strongest argument in the
entire research corpus.

**2. `npm run ci` — a single named verification entrypoint.** Arrived at
independently; it is the same conclusion this proposal reached from the literature.

**3. `PROGRESS.md` is genuinely excellent.** It is intentional compaction, invented
ad hoc, and it works. It records hard-won environment facts that would otherwise be
re-learned every session:

- no pnpm on this machine → use npm
- PGlite has no `btree_gist` → reservation table instead of a GiST constraint
- bare `ls` hangs in this shell (slow alias) → use `/bin/ls`
- empty directories vanish on branch switch — this ate `tests/unit` once
- the `.env.local` trap: `vercel env pull` left a `DATABASE_URL` that Next silently
  loaded, and **the entire browser suite ran against the production Neon database,
  passed, and mutated real data.** Cost an hour.

**4. Real integration, not mocks.** Actual `.docx`/`.pdf` generation with byte-level
magic-number assertions in the e2e suite.

**5. Honest open-items list.** e.g. slot-index assignment needs
`INSERT … ON CONFLICT` plus retry; fails closed today but can spuriously refuse a
`capacity>1` booking under concurrency. That is a real engineer's note.

## What the workflow got wrong

**1. Evals were mandated and silently skipped — and reported as done.**
Step 6 of the prompt says *"Run evaluations (evals)"*. The Completion Criteria say
*"Evals pass."* `PROGRESS.md` even reprints the chain `… → debug → evals → CI → …`.

There are **no evals in the repository.** Not a directory, not a file, not a script,
not a mention in any tracked file.

This is the critical failure mode: **a step the model cannot satisfy gets narrated
rather than performed.** The completion criteria were reported as met while one of
them was structurally unmeetable. Nothing in the workflow could detect this, because
the criterion lived in prose rather than in an exit code.

**2. Zero compounding.** The prompt says: *"If the same prompt, procedure, or
multi-step operation is used repeatedly, convert it into a reusable skill."*
The same 11-step loop ran seven times. **No skill was ever created.** There is no
`.claude/` directory. The next project starts by pasting the same wall of text.

**3. The most valuable artifacts are not in the repository.**
`PROGRESS.md`, `CLAUDE.md`, and `WALKTHROUGH.md` are all untracked — excluded via
`.git/info/exclude`, which is *machine-local and not even shareable* (unlike
`.gitignore`, which at least travels with a clone).

So: the resumability state, the project's own operating instructions, and every
hard-won environment fact — including the hour-long `.env.local` trap — **exist only
on this laptop.** A fresh clone, a new machine, or a teammate gets none of it. This
directly contradicts the prompt's own Persistence section.

**4. `npm run ci` and `.github/workflows/ci.yml` have already diverged.**

```
npm run ci  = typecheck → lint → tokens:check → check:template → test
CI workflow = ... the same five ... + build + playwright e2e
```

Local green does not mean CI green. This is precisely the drift that a single
entrypoint is supposed to prevent, and it appeared within one day.

**5. main was not protected, and was committed to directly — 5 times.**
`f3947fa`, `5ef3f83`, `8d478ca`, `9f96d68`, `e1f1de8`. Two are `fix(ci)` commits,
i.e. fixing CI by pushing straight past the gate. Branch protection is unavailable
on a private repo without GitHub Pro, so the rule existed only as prose — and prose
lost.

**6. "Do not stop until complete" is an unbounded autonomy grant.** It worked here.
It is also the instruction most likely to burn an entire token budget in a loop on a
task with an unreachable success condition — and it applies no cost ceiling, no
iteration cap, and no human checkpoint.

## Answering the question directly

**Is it a standard workflow?** Yes. `plan → implement → test → review → merge` is
ordinary trunk-based development with PR review, correctly described. The graph
framing (sequential / parallel / diamond) is standard orchestration vocabulary. The
one genuinely modern instruction is *"the implementer must not be the sole
reviewer"* — and that is the step that earned its keep.

**Is it close to my proposal?** Structurally, yes — the loop is nearly identical, and
`npm run ci` + `PROGRESS.md` are independent rediscoveries of two of the proposal's
three load-bearing ideas. The difference is not the workflow. It is **where the
workflow lives.**

| | The prompt | This proposal |
|---|---|---|
| Where the workflow lives | pasted prose, per project | skills + hooks + CI, in the repo |
| "Done" is defined by | prose the model self-reports against | `./scripts/verify.sh` exit code |
| main protection | a sentence | PreToolUse hook + branch protection |
| Evals | mandated, unmeetable, silently skipped | out of scope unless the product is AI |
| Durable state | `PROGRESS.md`, **untracked** | `work/<slug>/`, **committed** |
| Compounding | none — retype next time | skills ship with the repo |
| Review | ✅ same idea, and it worked | ✅ same idea, plus spec-conformance audit |
| Ceremony | fixed, all 11 steps for every feature | scaled to change size |

**Verdict:** the prompt is a good workflow with no enforcement and no memory. It
produced a real, working, tested, deployed application in ~9.5 hours — that is a
genuine result and should not be undersold. But it produced it *once*, and left
nothing behind that makes the next project cheaper. Every improvement in this
proposal is aimed at exactly that gap.

**The one thing to carry over unchanged:** independent fresh-context review. It is
the highest-yield step by a wide margin, and the evidence is 5 blocks out of 7.

---

# Phase 2 — Design proposal

## Product

A minimal, opinionated **configuration** of Claude Code — not a framework — that turns
an idea into shipped, verified software, and gets cheaper every project.

Small enough to read end to end in fifteen minutes. Target: **~25 files**, versus
gstack's 1,281.

## User

- Primarily: one developer, or a very small team, shipping real projects with Claude Code.
- Secondarily: anyone who wants a legible starting point rather than a 200-agent marketplace.
- Explicitly **not** for: teams wanting a heavyweight SDLC process tool. Use BMAD.

## Architecture

Four layers, ordered by **enforcement strength** — this ordering is the whole design:

```
┌─ ENFORCED ─────────────────────────────────────────┐
│  settings.json permissions  ·  PreToolUse hook     │  Claude cannot violate
│  GitHub branch protection   ·  CI required check   │
├─ MECHANICAL ───────────────────────────────────────┤
│  scripts/verify.sh — ONE command, exit 0 or not    │  the definition of "done"
├─ PROCEDURAL ───────────────────────────────────────┤
│  5 skills · 1 subagent · loaded on demand          │  how work gets done
├─ CONTEXTUAL ───────────────────────────────────────┤
│  CLAUDE.md · rules · docs/ · work/<slug>/          │  what Claude knows
└────────────────────────────────────────────────────┘
```

Anything that must be true belongs in the top layer. The island-media-ops evidence is
that rules in the bottom layer get narrated, not followed.

### The three load-bearing ideas

1. **One verification entrypoint.** `./scripts/verify.sh` is called by the agent, by
   the pre-merge gate, and by CI — *the same file, no reimplementation*. Three
   consumers, one definition. This is what stops the `npm run ci` vs `ci.yml` drift
   observed in the field.
2. **`work/<slug>/` is committed state.** One folder per change: `spec.md`,
   `plan.md`, `notes.md`. It is the intentional-compaction artifact. A fresh session
   reads the folder and resumes. Because it is committed, the PR carries its own
   reasoning and a new machine loses nothing.
3. **Fresh-context review is mandatory.** The implementer never grades itself.

## Repository structure

```
claude-kit/
├── README.md                          # entire kit explained on one page
├── LICENSE
├── DESIGN.md                          # this document
├── install.sh                         # puts `newproject` on PATH
├── bin/
│   └── newproject                     # POSIX sh, ~70 lines, zero deps
├── docs/
│   ├── WORKFLOW.md                    # the loop, with a worked example
│   └── RATIONALE.md                   # why each piece exists + what we left out
└── template/                          # ← copied verbatim into every new project
    ├── CLAUDE.md                      # <200 lines, facts only
    ├── IDEA.md                        # you dump the idea here
    ├── .gitignore
    ├── scripts/
    │   ├── verify.sh                  # THE gate
    │   └── check-claude-config.sh     # lints .claude/ so it cannot rot
    ├── docs/
    │   ├── PRD.md                     # written by /kickoff
    │   ├── ARCHITECTURE.md            # written by /kickoff
    │   └── decisions.md               # append-only, one line per decision
    ├── work/
    │   └── .gitkeep                   # in-flight changes only
    ├── .github/workflows/
    │   └── verify.yml                 # calls scripts/verify.sh — no duplicated steps
    └── .claude/
        ├── settings.json              # permissions + hook wiring
        ├── rules/
        │   ├── git.md
        │   └── code.md                # paths:-scoped
        ├── skills/
        │   ├── kickoff/SKILL.md
        │   ├── spec/SKILL.md
        │   ├── breakdown/SKILL.md
        │   ├── build/SKILL.md
        │   └── land/SKILL.md
        ├── agents/
        │   └── spec-auditor.md
        └── hooks/
            ├── guard.sh
            └── session-start.sh
```

## Core workflow

Two loops. The linear list in the brief is actually two loops.

**Project loop — once:**

```
IDEA.md → /kickoff → PRD.md · ARCHITECTURE.md · verify.sh · CLAUDE.md · first commit
```

**Task loop — per change:**

```
/spec <name>      → work/<name>/spec.md              ⏸ HUMAN REVIEWS   ← highest leverage
/breakdown <name> → Explore subagent → plan.md       ⏸ HUMAN REVIEWS   ← 2nd highest
/build <name>     → branch → step → verify → commit → repeat
                  → spec-auditor (fresh context)
/land <name>      → verify → push → PR → CI green → squash merge
                  → append decisions.md → delete work/<name>/ → delete branch
```

**Scale-aware — the anti-ceremony rule, stated in CLAUDE.md:**

| Size | Path |
|---|---|
| < ~50 lines, one file, obvious | branch → build → verify → commit. **Skip spec and plan.** |
| Multi-file, one session | `/breakdown` → `/build`. **Skip spec.** |
| New surface / ambiguous / >1 session | full loop |

Ceremony that cannot be skipped gets abandoned. This is the spec-kit failure mode,
inverted.

## Responsibilities

| Component | What it does | Why it exists | When Claude uses it | Status |
|---|---|---|---|---|
| `CLAUDE.md` | Stack, commands, conventions, verify contract, scale rule | Loaded every session — expensive. Facts only, no procedures | Always | **Mandatory** |
| `.claude/rules/*.md` | Path-scoped conventions via `paths:` glob | Keeps CLAUDE.md <200 lines; loads only on matching files | On reading matching files | Optional (v0.2) |
| `docs/PRD.md` | Problem, users, scope, non-goals | Durable product truth; stops re-litigating | `/spec`, `/kickoff` | **Mandatory** |
| `docs/ARCHITECTURE.md` | Stack, layout, boundaries, and *why* | Prevents re-derivation; what a fresh session needs | `/breakdown` | **Mandatory** |
| `docs/decisions.md` | One line per decision + date | Compounding at 1/33 the cost of a plugin | Read on `/breakdown`, appended on `/land` | Recommended |
| `work/<slug>/` | `spec.md`, `plan.md`, `notes.md` | Cross-session state; makes the PR self-explaining; **committed** | Every task-loop skill | **Mandatory** |
| `scripts/verify.sh` | format → lint → types → test → build, fail-fast | **One definition of done**, shared by agent + hook + CI | Continuously in `/build` | **Mandatory** |
| 5 skills | The loop | Procedures belong in skills, not CLAUDE.md — they load on demand | Invoked | **Mandatory** |
| `spec-auditor` | Fresh-context diff-vs-acceptance-criteria audit | An implementer cannot fairly grade itself. **5/7 block rate in the field** | End of `/build` | **Strongly recommended** |
| `guard.sh` | PreToolUse/Bash denies | Prose is not enforcement. main was hit 5× without it | Every Bash call | **Mandatory** |
| `settings.json` | Permission allow/deny/ask | Declarative beats scripted | Always | **Mandatory** |
| CI | `verify.sh` + config-check | The only gate Claude cannot talk past | On PR | **Mandatory** |

## Git workflow

```
main ── protected, always green, squash-merged, linear
  └── feat/<slug>  ←→  work/<slug>/     (names match, always)
```

- **No direct commits to main.** Enforced twice: `guard.sh` locally, branch
  protection remotely. *The field evidence shows one layer is not enough.*
- **Branch name mirrors the work folder.** One string ties branch ↔ spec ↔ plan ↔ PR.
- **One commit per plan step**, conventional prefix, each leaving verify green. Keeps
  `git bisect` useful.
- **PR body auto-generated** from `spec.md` + acceptance checklist + plan link.
  Reviewers read 200 lines of plan, not 2,000 lines of diff.
- **Merge requires:** CI green + spec-auditor pass + human approve. Squash. Delete branch.
- **After merge:** append `decisions.md`, delete `work/<slug>/`. **Git is the
  archive** — no `archive/` directory.
- **Rollback:** `/rewind` in-session; `git revert` on main.

> **Note for private repos:** GitHub branch protection requires Pro. Without it,
> `guard.sh` is the *only* enforcement — which makes the hook mandatory, not optional.

## Agent workflow

| Step | Mechanism | Rationale |
|---|---|---|
| inspect | built-in `Explore` subagent | Read-only, skips CLAUDE.md/git-status for cheapness. Keeps grep traces out of main context. |
| understand | `docs/`, `decisions.md` | Durable truth, already written |
| plan | `/breakdown` → `plan.md` | **Human gate.** Highest-leverage review point |
| implement | `/build` | One commit per step |
| verify | `scripts/verify.sh` | Mechanical, exit code |
| debug | built-in `/debug`, `superpowers:systematic-debugging` | Already exists |
| review | `spec-auditor` subagent + `/code-review` | Fresh context, mandatory |

**Deliberate assignment of concerns:**

- **Instructions (CLAUDE.md):** facts, conventions, the scale rule, the verify contract.
- **Skills:** the five procedures. Nothing else.
- **Subagents:** context isolation only. One mandatory, one optional.
- **Hooks:** the four things that must never happen.
- **CI:** the only gate the model cannot narrate past.
- **Commands:** *nothing* — merged into skills upstream.

## Skills — what belongs

Five. Each does one thing and is readable alone. Each ≤150 lines.
All carry `disable-model-invocation: true` — deliberate, user-triggered actions.

| Skill | Produces | Human gate? |
|---|---|---|
| `/kickoff` | PRD, ARCHITECTURE, verify.sh, CLAUDE.md, first commit | yes, at the plan |
| `/spec <slug>` | `spec.md`: problem, acceptance criteria as checkboxes, out-of-scope | **yes — highest leverage** |
| `/breakdown <slug>` | `plan.md`: numbered steps, exact files, verification per step. Research via `Explore` so the trace never enters main context | **yes** |
| `/build <slug>` | Branch, implement step-by-step, verify after each, tick boxes, commit per step, then `spec-auditor` | no |
| `/land <slug>` | verify → push → PR → CI → squash merge → decisions.md → cleanup | yes, before merge |

## Subagents — what belongs

**One mandatory, one optional.** The principle: a subagent exists to keep verbose
output *out* of the main context, or to get *fresh* context. **Never for a persona.**

- **`spec-auditor`** *(strongly recommended)* — `tools: Read, Grep, Glob, Bash(git diff:*)`,
  `model: sonnet`. Reads `spec.md` + `git diff main...HEAD`, returns **PASS/FAIL per
  acceptance criterion with evidence**. Fresh context is the entire point.
  *Justified by 5/7 real blocks in the field test.*
- **`test-runner`** *(optional, noisy suites only)* — runs verify, returns the failure
  tail. Keeps 10k lines of test output out of the main window.

Research → built-in `Explore`. Planning → built-in `Plan`. Parallel work → `/batch`.
General review → `/code-review`. **Do not write these.**

Hard cap **3 concurrent**, matching this machine's documented constraint. Nested
spawning prohibited in subagent prompts.

## Hooks — what belongs

**Declarative first — `settings.json`, no script:**

```
deny:  Read(./.env), Read(./.env.*), Read(./**/*.pem), Read(./**/id_rsa*), Read(./secrets/**)
deny:  Bash(vercel --prod:*), Bash(supabase db push:*), Bash(terraform apply:*)
ask:   Bash(gh pr merge:*)
allow: Bash(./scripts/verify.sh), Bash(git status:*), Bash(git diff:*), Bash(git log:*)
```

**`guard.sh` — PreToolUse/Bash, ~40 lines, exactly four denies:**

1. `git commit` while on `main`/`master`
2. `git push --force` / `-f` to `main`/`master`
3. `rm -rf` targeting `/`, `~`, or outside the project directory
4. `curl … | sh` / `wget … | sh` — untrusted install

**`session-start.sh`** *(optional)* — prints branch, active `work/` folder, dirty-tree
flag. Three lines; grounds every session.

**Explicitly rejected:** a `Stop` hook forcing verify. It makes every turn slow and
fights ordinary conversation. The gate belongs in `/build` and CI.

## Verification

```
scripts/verify.sh    # format → lint → typecheck → test → build.  Fail fast.
                     # --fast skips build for the inner loop.
```

Called identically by the agent, the pre-merge gate, and CI. **CI must call the
script, never re-list the steps** — that is how `npm run ci` and `ci.yml` diverged in
the field within a single day.

Four levels of verification, in increasing cost:

1. **Mechanical** — `verify.sh` exit code. Non-negotiable.
2. **Acceptance criteria** — checkboxes in `spec.md`, ticked with *command output as
   evidence*, not assertion.
3. **Independent review** — `spec-auditor` (spec conformance) + `/code-review` (bugs).
4. **Config integrity** — `check-claude-config.sh` in CI: SKILL.md frontmatter parses,
   referenced files exist, no skill >500 lines, hooks executable.

### Evaluations — deliberately out of scope

For a general software product, evals are fashion. **The field evidence is decisive:**
they were mandated in the prompt, listed in the completion criteria, reprinted in
`PROGRESS.md` — and never existed. The step was narrated, not performed.

The rule this yields is broader than evals: **never write a completion criterion that
has no exit code.** If it cannot fail mechanically, it will be reported as passed.

Escape hatch, documented: if the product has non-deterministic LLM behaviour, add
`evals/` with the same contract — a script that exits non-zero — wired into
`verify.sh` behind a flag so it does not run on every commit.

**Agentic CI review is also out of scope for v0.1.** `/code-review ultra` exists on
demand and is billed per run; putting it on every PR is unrequested cost.

## Safety

| Risk | Control | Layer |
|---|---|---|
| Secrets read | `permissions.deny` on `.env*`, `*.pem`, `id_rsa*`, `secrets/**` | Enforced |
| Secrets committed | `.gitignore` + optional `gitleaks` step in verify | Mechanical |
| Destructive commands | `guard.sh` — `rm -rf`, force-push | Enforced |
| Commit to main | `guard.sh` + branch protection | Enforced ×2 |
| Untrusted repos | Workspace trust gates all project hooks; `curl\|sh` denied; never `--dangerously-skip-permissions` in a repo you did not write | Enforced |
| **Production** | **The agent never deploys.** Deploy is a human action or CI-on-merge. `deny` on `vercel --prod`, `supabase db push`, `terraform apply` | Enforced |
| Prod data corruption | The `.env.local` trap: e2e must set `DATABASE_URL=''` (defined-but-empty), never `delete` it | Mechanical |
| Runaway autonomy | No "do not stop until complete" without an iteration cap and a human checkpoint | Procedural |
| RAM exhaustion | Max 3 concurrent subagents; no nested spawning | Enforced |

> The `.env.local` row is taken directly from the field test, where the full browser
> suite ran against the **production** Neon database, passed, and mutated real data.

## Minimum viable version — v0.1

**13 files.** Everything else is v0.2+.

```
README.md · install.sh · bin/newproject
template/CLAUDE.md
template/IDEA.md
template/scripts/verify.sh
template/.github/workflows/verify.yml
template/.claude/settings.json
template/.claude/hooks/guard.sh
template/.claude/agents/spec-auditor.md
template/.claude/skills/{kickoff,spec,breakdown,build,land}/SKILL.md
```

Cut from v0.1: `rules/` (fold into CLAUDE.md until it hits 200 lines),
`session-start.sh`, `check-claude-config.sh`, `decisions.md`, `docs/` stubs
(`/kickoff` writes them).

`spec-auditor` is **kept** in the MVP despite being 15 lines — the field evidence
makes it the highest-value component in the kit.

### `newproject`

Single POSIX shell file, no node, no dependencies:

```
newproject myProject [--here] [--dir <path>]
  → mkdir, git init -b main, copy template/, chmod +x
  → git commit -m "chore: initialize project"
  → exec claude "Read IDEA.md. If empty, ask me for the idea. Then run /kickoff."
```

You land in Claude Code with an empty `IDEA.md`, dump the idea, and `/kickoff` does
the rest.

## What is being over-engineered — and what is missing

### Cut

| Item | Verdict |
|---|---|
| **commands** as a component | **Cut.** Merged into skills upstream. |
| **evaluations** | **Cut from MVP.** Field-proven to be narrated, not performed. |
| **loops** | **Cut from MVP.** `/loop` ships; unbounded autonomous loops on a RAM-limited laptop are a liability. |
| **harness** | **Cut.** Claude Code *is* the harness. Building one is how gstack reached 1.1 GB. |
| **multi-agent workflows** | **Reduce to 1–2 subagents.** Value is context isolation, not org charts. This machine has already crashed from over-fanning. |
| **memory / project context** | **Reduce.** Auto memory ships. You need `work/<slug>/` and one decisions line. |
| **inspect** as a step | **Cut.** That is the built-in `Explore` agent. |
| **PRD → architecture** as heavy phases | **Reduce.** Two short docs, written once. |
| **spec + plan for every change** | **Make it scale-aware.** |

### Missing from the original brief

1. **A single verification entrypoint.** The brief lists test/lint/typecheck/build as
   four things. Making them *one command shared by agent, hook and CI* is the
   highest-value decision in the design — and the field test proves the drift is real.
2. **Acceptance criteria as checkboxes ticked with evidence.** Without a written
   definition of done, "verify" has nothing to verify against.
3. **Branch protection.** The docs are explicit that CLAUDE.md is context, not
   configuration. main was hit 5× in the field test.
4. **A rollback story.** `/rewind` in-session, `git revert` on main.
5. **Production safety.** The agent never deploys.
6. **Config self-test in CI.** `.claude/` rots silently; 20 lines catches it.
7. **The no-exit-code rule.** Never write a completion criterion that cannot fail
   mechanically.
8. **Committing the agent-facing artifacts.** `PROGRESS.md`, `CLAUDE.md` and
   `WALKTHROUGH.md` were all untracked in the field test. The knowledge must travel
   with the code.

---

# Open decisions

1. **Skill names.** gstack is installed at user scope, so `/ship`, `/review`, `/qa`,
   `/learn`, `/health`, `/investigate` are taken. Claude Code reserves `/plan`,
   `/verify`, `/review`, `/design`, `/debug`, `/simplify`, `/loop`, `/batch`,
   `/doctor`. Proposed set — `/kickoff /spec /breakdown /build /land` — collides with
   neither. Accept, or use a prefix?

2. **Do `/spec` and `/breakdown` stay separate?** Separate follows ACE-FCA (different
   contexts, two review gates). Merged is one less thing to learn.
   *Recommendation: separate.*

3. **Distribution.** Project-level `.claude/` (travels with the repo on clone —
   *recommended*, and directly fixes the untracked-artifacts problem found in the
   field), or a plugin (auto-namespaced, but requires installing)?

4. **Where does `newproject` create things** — `~/Projects/<name>`, or cwd?

5. **Does `work/<slug>/` survive merge?** Proposal deletes it and keeps one line in
   `decisions.md`, on the grounds that git is the archive. OpenSpec archives instead.
   *Recommendation: delete; git history is enough.*
