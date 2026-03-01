---
title: "Scout-and-Wave: A Coordination Pattern for Parallel AI Agents"
date: 2026-02-27
draft: false
series: ["scout-and-wave"]
seriesOrder: 1
tags: ["ai", "multi-agent", "claude-code", "developer-tools", "patterns", "prompt-engineering", "productivity", "openclaw", "autogen", "crewai", "langchain", "agent-orchestration"]
categories: ["ai", "tools"]
description: "A pattern for running multiple AI agents in parallel without conflicts — using a throwaway scout agent to map seams and dependencies before any code is written, then executing in waves against a shared coordination artifact."
summary: "Naive parallel agents step on each other. The scout-and-wave pattern solves this by front-loading dependency mapping: one throwaway agent identifies seams and builds a living coordination artifact before any implementation begins. Development then proceeds in waves, each consuming and updating the artifact for the next."
---

The last time I ran a scout-and-wave session on [brewprune](https://github.com/blackwell-systems/brewprune), 11 agents fixed 18 UX issues across 35 files in a single wave. Net: +4,021 lines, all tests green, no post-merge integration failures.

The time before that: 7 agents, 1,532 lines, 16 files, 3 waves — a new shim management subsystem. The feature was complete, building, and passing tests in under an hour.

The first time I tried parallel agents without any coordination structure, I got merge conflicts, contradictory implementations, and an hour of cleanup. The agents had done real work. None of it fit together.

The difference isn't the agents. It's what happens before you launch them.

Scout-and-wave is a methodology for reducing conflict and improving efficiency with parallel AI agents. One read-only scout produces a coordination artifact (seams, ownership, DAG), then implementation proceeds in verified waves that consume and update that artifact.

{{< callout type="info" >}}
**This isn't spec-driven development.** Spec-driven dev, formalized by tools like [GitHub's Spec Kit](https://developer.microsoft.com/blog/spec-driven-development-spec-kit), says write the spec before the code. That's table stakes at this point, and you should be doing it. But spec-driven dev is a human-to-AI handoff: a human writes requirements, architecture, and phased tasks, then hands them to an agent. Scout-and-wave starts where those specs end: when multiple agents need to execute in parallel against a shared codebase. Who owns which files? What are the exact interface contracts across agent boundaries? How do you propagate the actual state of completed work to the next wave? Spec Kit doesn't answer these questions because it assumes one agent executing tasks sequentially. The scout produces that coordination artifact autonomously by reading the codebase. You don't write it by hand.
{{< /callout >}}

## What Goes Wrong With Naive Parallel Agents

The instinct when you discover parallel agents is to split the work and fire them all at once. It feels efficient. Agents make local decisions without global context, and when multiple agents are touching the same codebase, those local decisions collide.

There are four specific failure modes:

**File clobbering.** Two agents are assigned related work. Neither knows the other exists. They both touch the same file, make incompatible changes, and you spend time reconciling their outputs, defeating the parallelism entirely.

**Interface drift.** Agent B is building a feature that depends on a function Agent A is writing. Agent B makes assumptions about that function's signature. Agent A makes different ones. Integration fails.

**Integration tax.** Agents complete their individual tasks successfully. The integration failures surface only when you try to assemble the pieces. By then, rework is expensive.

**Context window waste.** Giving every agent the full picture of a large feature bloats every prompt. Instead of 7 agents each carrying a 20k-token feature brief, you've paid that cost seven times, and each agent is still reasoning over context irrelevant to its slice of the work.

These aren't edge cases. They're the default outcome of uncoordinated parallelism.

## Map First, Execute Second

Dependency mapping needs to be a first-class phase, not something you figure out on the fly.

Before any agent writes a line of code, the scout runs a five-part suitability gate:

1. **File decomposition.** Can the work be assigned to ≥2 agents with disjoint file ownership? If every change funnels through a single file, there's nothing to parallelize.
2. **Investigation-first items.** Does any part of the work require root cause analysis before implementation — a crash whose source is unknown, a race condition that must be reproduced before it can be fixed? If so, those items must be resolved before agents can be written. The scout surfaces this before anyone wastes time.
3. **Interface discoverability.** Can the cross-agent interfaces be defined before implementation starts? If a downstream agent's inputs can't be specified until an upstream agent has already started, the agents will contradict each other.
4. **Pre-implementation status check.** If the work comes from an audit report or findings list, the scout reads source files for each item and classifies it: TO-DO, DONE, or PARTIAL. DONE items are excluded or converted to test-coverage-only agents. In round 5 of the brewprune audit cycle, this check found that 12 of 24 findings had already been implemented and filtered them before any agent launched — roughly 8 minutes of saved compute per run.
5. **Parallelization value.** Does the time saved by running agents in parallel exceed the fixed overhead of the scout and merge phases? Raw agent count isn't the signal — per-agent execution time is. Four agents doing 3-minute documentation edits are slower with SAW than without; four agents doing 15-minute logic changes with a 45-second build cycle are substantially faster. The scout calculates this explicitly and includes the estimate in the verdict.

If any of the first three is a hard blocker, the scout emits NOT SUITABLE and stops — writing only the verdict and reasoning to the IMPL doc. Either way, an honest assessment is useful output before any agent spends time on a job. Run `/saw check` to run just this pre-flight without committing to a full analysis.

If the gate passes, the scout answers three structural questions:

1. **What are the seams?** Where does the new feature touch existing code? What are the minimal, stable interfaces between pieces?
2. **Who owns what?** Every file that will change gets assigned to exactly one agent. No two agents in the same wave touch the same file. If two tasks need the same file, that file becomes its own seam: extract an interface or create a new file so ownership stays disjoint. This turns a limitation into a design principle.
3. **What's the DAG?** If Agent B needs Agent A's interface, B is in a later wave. If A and B are independent, they're in the same wave.

The scout is throwaway: read-only, no implementation, one-shot. Its entire output is a single document: interface contracts, a file ownership table, and a wave structure. That document is the coordination artifact. Keeping the scout throwaway prevents planner drift; the artifact becomes the single source of truth, not an ongoing conversation with a planner that might change its mind mid-execution.

For a small feature (3–5 agents), one file is fine. For 10+ agents, or when the artifact exceeds ~20KB, split it: an index file with the wave structure, ownership table, and status checklist, and one per-agent file with the full implementation spec. Individual agent prompts stay focused; the index stays readable.

**Interface contracts are defined before any agent starts. Agents code against the spec, not against each other's in-progress code.**

This is the same thing a tech lead does before a sprint. You're just automating it.

## The Scout Deliverable

The coordination artifact the scout produces looks like this:

```markdown
### Suitability Assessment

Verdict: SUITABLE

Estimated times:
- Scout phase: ~8 min
- Agent execution: ~12 min (7 agents, accounting for parallelism)
- Merge & verification: ~5 min
Total SAW: ~25 min | Sequential baseline: ~55 min | Savings: ~30 min (55% faster)

### Known Issues

- `TestDoctorHelpIncludesFixNote` — hangs (pre-existing, unrelated to this work)
  Workaround: skip with `-skip TestDoctorHelpIncludesFixNote`

### Interface Contracts

func RefreshShims(binaries []string) (added int, removed int, err error)
func RunShimTest(st *store.Store, maxWait time.Duration) error
func EnsurePathEntry(dir string) (added bool, configFile string, err error)
func buildOptPathMap(st *store.Store) (map[string]string, error)

### File Ownership

| File                              | Agent | Wave |
|-----------------------------------|-------|------|
| internal/shim/generator.go        | A     | 0    |
| cmd/brewprune-shim/main.go        | B     | 1    |
| internal/app/scan.go              | D     | 2    |
| ...                               | ...   | ...  |

### Wave Structure

Wave 0:  [A]               ← prerequisite (solo — gates downstream verification)
              | (A completes, full test suite passes)
Wave 1: [B] [C] [D]        ← 3 parallel agents
              | (B+C+D complete)
Wave 2:   [E] [F]          ← 2 parallel agents

### Cascade Candidates

- `internal/app/doctor.go` — calls RefreshShims; no changes needed but
  post-merge verification should confirm the call site compiles cleanly

### Status

- [ ] Wave 0 Agent A — shim generator (prerequisite)
- [ ] Wave 1 Agent B — shim binary version check
- [ ] Wave 1 Agent C — opt-path disambiguation
```

A few things worth noting in this structure:

**Wave 0** is a solo prerequisite agent — not parallel — for work that gates all downstream verification. When a foundational change must exist before downstream agents can meaningfully test their own output, it becomes Wave 0. A single agent runs it on main, and it must pass the full test suite before Wave 1 launches.

**Known Issues** names pre-existing failures so agents don't mistake them for regressions they caused. Without this, agents hit a hanging test, assume they broke something, and spiral.

**Cascade candidates** are files that call code being modified but don't need changes themselves. If Agent K changes a function signature in a shared module, and three other files call that function, those callers are cascade candidates. They don't get their own agents, but naming them upfront means the post-merge verification gate watches them deliberately rather than discovering failures by accident.

Type renames deserve special attention here: when an interface contract introduces a renamed struct, trait, or type alias — not just new fields, an actual rename — the scout runs a workspace-wide search for the old name and lists every file that references it, even those inside another agent's ownership scope. Syntax-level cascades (import errors, "type not found") are distinct from semantic ones: they cause compilation failures in isolated agent worktrees, and agents under build pressure will self-heal by touching files outside their ownership scope. Naming type rename cascades explicitly prevents that improvisation.

The status checklist becomes a living artifact: each wave updates it before the next wave launches. Downstream agents consume the actual state of what was built, not stale pre-flight assumptions.

The full protocol flow, from feature description to final merge:

{{< mermaid >}}
flowchart TD
    A["/saw scout feature"] --> B["Suitability gate\n5 checks"]
    B -- NOT SUITABLE --> C["Emit verdict · stop"]
    B -- SUITABLE --> D["Scout reads codebase\nmaps seams · defines interfaces · builds DAG"]
    D --> E["Writes IMPL doc\ncontracts · ownership · wave structure"]
    E --> F["Human review\ninterface freeze checkpoint"]
    F -. revise contracts .-> E
    F -- contracts final --> G{"Solo agent\nin wave?"}
    G -- yes --> H["Run on main\nno worktrees needed"]
    G -- no --> I["Pre-create worktrees\nfor each agent"]
    H --> J["Agent executes\nfocused verification gate"]
    I --> K["Agents execute in parallel\nfocused verification each"]
    J & K --> L["Write structured\ncompletion reports"]
    L --> M["Orchestrator: parse reports\npredict conflicts · review deviations"]
    M --> N["Merge worktrees\nunscoped verification gate"]
    N -- FAIL --> O["Fix · re-verify"]
    O --> N
    N -- PASS --> P{"More waves?"}
    P -- yes --> G
    P -- no --> Q["IMPL doc finalized · done"]
{{< /mermaid >}}

## Wave Execution

Each wave is a set of agents that can run fully in parallel because their file sets don't overlap and they depend only on interfaces already defined in the spec.

If a wave has exactly one agent, skip worktree creation entirely. A solo agent cannot conflict with itself, so the isolation overhead is pure waste — and running on main means its output (new types, interfaces) is immediately visible to later waves without waiting for a merge. Worktrees exist to prevent inter-agent conflict; the solo case has none.

For multi-agent waves: don't create worktrees until interface contracts are finalized. The window between "IMPL doc written" and "agents launched" is the right time to revise type signatures or restructure APIs. Once worktrees branch from HEAD, any interface change in the IMPL doc requires removing and recreating them — otherwise agents implement against a stale version of the contracts. Treat that review window as an interface freeze checkpoint.

When contracts are final, the orchestrator pre-creates a worktree for each agent:

```bash
for agent in A B C; do
  git worktree add ".claude/worktrees/wave1-agent-${agent}" -b "wave1-agent-${agent}"
done
```

This is a required step, not optional scaffolding. You cannot rely on the Task tool's `isolation: "worktree"` parameter alone — it doesn't guarantee each agent starts in the correct worktree. Disjoint file ownership is the primary safety mechanism; it's what makes parallel execution *correct*. Worktrees are defense-in-depth: a second layer that prevents an agent from accidentally touching another agent's files even when ownership is right on paper. Both layers are in play.

Each agent in a wave gets three things in its prompt:

1. **File ownership:** "You own these files. Do not touch any others."
2. **Interface contracts:** The exact signatures it must implement and the exact signatures it may call from prior waves.
3. **Verification gate:** Must run the build and tests and report results before finishing. Agent gates use focused test commands (`go test ./pkg -run TestFoo`) to keep iteration fast. The orchestrator's post-merge gate runs unscoped (`go test ./...`) to catch cross-package cascade failures no individual agent could see.

After all agents in a wave complete, the orchestrator:

1. **Parses completion reports** from the IMPL doc. Each agent writes a structured YAML block: files changed, interface deviations, out-of-scope dependencies discovered, verification result.
2. **Predicts conflicts** by cross-referencing all agents' file lists before touching the working tree. If the same file appears in two agents' lists, that's a disjoint ownership violation — flag and resolve before merging.
3. **Reviews interface deviations.** If an agent changed a signature from the spec, downstream agents (in later waves) may depend on the original contract. Deviations that affect downstream agents are flagged in the completion report with `downstream_action_required: true` — the orchestrator updates those agent prompts before launching the next wave. Common examples: a lint suppression attribute that must appear on all stub implementations, a serialization annotation required by a changed type, an API call pattern that differs from the spec. These are caught at deviation review, not discovered mid-wave.
4. **Merges each worktree** in sequence, cleans up worktrees and branches, runs the full unscoped verification gate.
5. **Updates the IMPL doc:** tick status checkboxes, correct interface contracts, queue any out-of-scope dependency fixes for pre-launch cleanup.

Wave N+1 does not launch until Wave N is verified. If verification fails, fix before proceeding.

### The Artifact Revises Itself

Most planning systems treat the plan as immutable once execution begins. The scout produces a plan, agents execute it, and if reality diverges from assumptions, you're on your own.

Scout-and-wave treats the coordination artifact as a living document. When an agent discovers that an interface contract needs to change, that a function signature doesn't fit the data it actually encounters, or that a file needs to move to a different agent, it records the deviation directly in the IMPL doc. The agent reports what it actually built, not just whether it succeeded. Status checkboxes get ticked, but more importantly, interface contracts get corrected and ownership changes get recorded.

This matters because downstream agents in Wave N+1 read the artifact before they start. They get the corrected signatures, not the scout's original guesses. A spec written before implementation can't anticipate every detail. An artifact updated by the agents who did the work can. The plan converges toward reality with each wave instead of drifting further from it.

## Worked Example: brewprune

The feature was shim management for brewprune, a new subsystem touching shim generation, version checking, path disambiguation, self-test, and onboarding. The scout mapped 7 agent slots across 3 waves, with interface contracts for `RefreshShims`, `RunShimTest`, `EnsurePathEntry`, and `buildOptPathMap`.

The DAG showed Wave 2 was blocked on A specifically; B, C, and D had no dependents in later waves. Wave 3 was blocked on E and F. Wave 1 had no internal dependencies.

```
Wave 1:   [A]  [B]  [C]  [D]        ← 4 parallel agents
              |
              ↓  (A completes)

Wave 2:      [E]  [F]               ← 2 parallel agents, unblocked by A
              |
              ↓  (E+F complete)

Wave 3:       [G]                   ← 1 agent, unblocked by E+F
```

**Wave 1 (4 agents in parallel):**
- A: `internal/shim/generator.go`: RefreshShims, WriteShimVersion, ReadShimVersion
- B: `cmd/brewprune-shim/main.go`: version check on startup
- C: `internal/watcher/shim_processor.go`: opt-path disambiguation
- D: Formula + README: brew services stanza, Quick Start updates

**Wave 2 (2 agents, unblocked by A):**
- E: `internal/app/scan.go`: --refresh-shims fast path
- F: `internal/app/doctor.go` + `shimtest.go`: live pipeline self-test

**Wave 3 (1 agent, unblocked by E+F):**
- G: `internal/app/quickstart.go` + `internal/shell/config.go`: onboarding workflow

Results by wave:

| Wave              | Files | Added | Removed |
|-------------------|-------|-------|---------|
| Wave 1 (4 agents) | 6     | 600   | 26      |
| Wave 2 (2 agents) | 7     | 530   | 11      |
| Wave 3 (1 agent)  | 3     | 402   | 23      |
| **Total**         | **16**| **1,532** | **60** |

Notice the shape: maximum parallelism at the start (4 agents), narrowing as work integrates (2, then 1). This isn't a coincidence: it's what a dependency graph looks like. Foundational work fans out; integration work converges. The wave structure falls out naturally from the DAG.

Three things made it work:

- **No two agents touched the same file in a wave.** File clobbering was structurally impossible.
- **All cross-agent calls used predeclared signatures.** Agent E called `RefreshShims` exactly as the scout defined it. Agent A implemented it exactly as defined. They never needed to coordinate.
- **Every wave ended with build and tests green before the next launched.** Integration failures surfaced at wave boundaries, not at the end. Each fix was local and cheap.

### Second run: UX audit (11 agents, 1 wave)

A re-audit of brewprune surfaced 18 UX issues across 11 disjoint files. No cross-agent dependencies: every finding mapped to a single file group. The scout produced a flat single-wave structure with per-agent files instead of one monolithic IMPL doc.

| Wave              | Files | Added | Removed |
|-------------------|-------|-------|---------|
| Wave 1 (11 agents) | 21   | 4,201 | 180     |
| **Total**          | **21** | **4,201** | **180** |

Every agent owned 1–2 files. The post-merge gate passed clean on the first try — no integration failures because there were no cross-agent interfaces to drift.

The shape here is the opposite of the shim feature: instead of a converging DAG (4→2→1), it's a flat fan-out (11→done). When the DAG degenerates to a straight line, you get maximum parallelism with no sequencing overhead — the whole job completes in the time it takes the slowest agent. Both shapes are valid. The scout tells you which one you have.

## Why It Works

| Problem with naive parallel agents | How scout-and-wave solves it |
|------------------------------------|------------------------------|
| Agents clobber each other's changes | File ownership table enforces disjoint sets |
| Interface drift: agents assume different signatures | Interface contracts defined upfront; agents code against the spec |
| Integration tax: failures surface at the end | Verification gate per wave catches breaks at wave boundaries |
| Context window waste: 7 agents × full feature brief | Scout pays the context cost once; agents carry only their slice |
| Hard to reason about dependencies | Explicit DAG → waves fall out naturally |
| Plan drifts from reality during execution | Agents revise the artifact; downstream waves get corrected context |
| Wasted work on already-fixed items | Pre-implementation status check filters DONE items before agents launch |

## When to Use It

**High parallelization value** (SAW pays for itself):
- Build/test cycle >30 seconds — each parallel agent runs independently, amplifying time savings
- Agents own 3+ files each — more implementation time per agent means more to parallelize
- Tasks involve non-trivial logic, tests, and edge cases — not simple find-and-replace
- Agents are fully independent (single wave) — maximum parallelization benefit

**Low parallelization value** (consider alternatives):
- Simple edits, documentation-only, or trivially fast sequential work — SAW overhead dominates
- 2-3 agents with disjoint files and no dependencies — use SAW Quick mode instead
- Note: the IMPL doc has coordination value even when speed gains are marginal (audit trail, interface spec, progress tracking) — the scout flags these as SUITABLE WITH CAVEATS

**Good fit:**
- Clear seams exist between pieces
- Interfaces can be defined before implementation starts
- Work can be chunked so each agent owns 1-3 files

**Poor fit:**
- Tightly coupled code with no clean file boundaries
- Interface cannot be known until you start implementing
- Root cause is unknown (crash, race condition) — investigate first, then use SAW for the fix

Run `/saw check` when you're unsure. The scout runs the full suitability gate with time-to-value estimates (SAW total vs sequential baseline) and will emit a NOT SUITABLE verdict rather than producing a broken IMPL doc with forced decomposition.

## How This Relates to Existing Patterns

The closest named concepts are the Planner-Worker-Judge pattern (Planner maps work, Workers execute, Judge evaluates) and spec-driven development (write the spec before the code). Scout-and-wave borrows from both but differs in two ways.

1. **The scout is throwaway.** It's not a persistent orchestrator that continues to direct execution; it does one job, produces one document, and disappears. This keeps the coordination overhead minimal.

2. **The coordination artifact is living.** A spec describes intended state. The scout artifact tracks actual state as waves complete. Downstream agents get accurate inputs from the previous wave, not stale pre-flight assumptions. This distinction matters in practice: a spec written before implementation can't know what Wave 1 actually built. An artifact updated by Wave 1 can.

Scout-and-wave is also distinct from framework-level solutions. OpenClaw, AutoGen, CrewAI, and LangGraph all provide agent coordination primitives: routing, sub-agents, role-based crews, graph-based workflows. Frameworks can enforce a workflow once you've decided on a decomposition. Scout-and-wave is how you find a decomposition that won't collide in a real codebase. By the time you're dispatching agents in any of these frameworks, you've already either done this work or skipped it.

| Approach | What it solves | What it doesn't solve |
|---|---|---|
| OpenClaw sub-agents | Parallel task dispatch | Dependency mapping, file conflict prevention |
| AutoGen / CrewAI | Agent roles and conversation structure | Pre-flight seam identification |
| LangGraph | Workflow graph execution | Codebase conflict detection before execution |
| Planner-Worker-Judge | Persistent planning + evaluation | Throwaway scout, living artifact, wave handoff |
| Scout-and-wave | Pre-flight dependency mapping + wave coordination | Replaces none of the above; runs before them |

**Run a scout if:**
- 5+ files will change
- 2+ subsystems are involved
- 3+ agents are needed
- You can name the interfaces before you write the implementations

If you can't check those boxes, the feature probably isn't ready for parallelism yet. Run `/saw check` first — it answers the suitability question in seconds, without producing an IMPL doc or committing to a full analysis.

## The Skill

Scout-and-wave ships as a `/saw` skill for [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Install it by copying the skill file to `~/.claude/commands/saw.md`. Six commands:

```
/saw bootstrap <description>   # Design-first architecture for new projects (no existing codebase)
/saw check <description>       # Suitability pre-flight — no files written
/saw scout <description>       # Full scout phase, produces docs/IMPL-<feature>.md
/saw wave                      # Execute next pending wave, pause for review
/saw wave --auto               # Execute all waves; pause only if verification fails
/saw status                    # Show current progress from the IMPL doc
```

The skill routes to focused modules: `saw-merge.md` owns the merge procedure (completion report parsing, conflict prediction, interface deviation review, post-merge verification); `saw-worktree.md` owns the worktree lifecycle (pre-creation, verification, self-healing, cleanup); `saw-bootstrap.md` handles design-first architecture for new projects; `saw-quick.md` covers lightweight 2-3 agent work without a full IMPL doc. All files carry version headers at line 1 (`<!-- saw-skill v0.3.0 -->`) so installed copies can be checked with `head -1 ~/.claude/commands/saw.md`.

The prompts are at [github.com/blackwell-systems/scout-and-wave](https://github.com/blackwell-systems/scout-and-wave).
