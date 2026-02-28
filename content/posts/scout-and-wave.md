---
title: "Scout-and-Wave: A Coordination Pattern for Parallel AI Agents"
date: 2026-02-27
draft: false
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

Before any agent writes a line of code, a scout agent answers three questions:

1. **What are the seams?** Where does the new feature touch existing code? What are the minimal, stable interfaces between pieces?
2. **Who owns what?** Every file that will change gets assigned to exactly one agent. No two agents in the same wave touch the same file. If two tasks need the same file, that file becomes its own seam: extract an interface or create a new file so ownership stays disjoint. This turns a limitation into a design principle.
3. **What's the DAG?** If Agent B needs Agent A's interface, B is in a later wave. If A and B are independent, they're in the same wave.

The scout is throwaway: read-only, no implementation, one-shot. Its entire output is a single document: interface contracts, a file ownership table, and a wave structure. That document is the coordination artifact. For a small feature (3–5 agents), one file is fine. For 10+ agents, split it: an index file with the wave structure, ownership table, and status checklist, and one per-agent file with the full implementation spec. Individual agent prompts stay focused; the index stays readable. Keeping the scout throwaway prevents planner drift; the artifact becomes the single source of truth, not an ongoing conversation with a planner that might change its mind mid-execution.

**Interface contracts are defined before any agent starts. Agents code against the spec, not against each other's in-progress code.**

This is the same thing a tech lead does before a sprint. You're just automating it.

## The Scout Deliverable

The coordination artifact the scout produces looks like this:

```markdown
## Wave structure
Wave 1: [agent A - files], [agent B - files], [agent C - files]
Wave 2: [agent D - files], [agent E - files] - blocked on Wave 1
Wave 3: [agent F - files] - blocked on Wave 2

## Interface contracts
// Exact function signatures agents must implement or may call
func RefreshShims(binaries []string) (added int, removed int, err error)
func RunShimTest(st *store.Store, maxWait time.Duration) error
func EnsurePathEntry(dir string) (added bool, configFile string, err error)
func buildOptPathMap(st *store.Store) (map[string]string, error)

## File ownership
| File                              | Agent | Wave |
|-----------------------------------|-------|------|
| internal/shim/generator.go        | A     | 1    |
| cmd/brewprune-shim/main.go        | B     | 1    |
| internal/app/scan.go              | D     | 2    |
| ...                               | ...   | ...  |

## Status
- [ ] Wave 1 Agent A - [description]
- [ ] Wave 1 Agent B - [description]
```

The status checklist becomes a living artifact: each wave updates it before the next wave launches. Downstream agents consume the actual state of what was built, not stale pre-flight assumptions.

One more thing worth putting in the artifact: **cascade candidates** — files that call code being modified but don't need changes themselves. If Agent K adds a column to a table renderer, and two other files call that renderer, those callers are cascade candidates. Flag them in the IMPL doc. They don't need their own agents, but the post-merge verification gate should watch them explicitly. In practice, naming them upfront is what lets you confidently skip assigning them to agents.

## Wave Execution

Each wave is a set of agents that can run fully in parallel because their file sets don't overlap and they depend only on interfaces already defined in the spec.

When there are no cross-agent dependencies at all — every agent touches disjoint files and no agent's output is another's input — the entire job is a single flat wave. The 11-agent UX audit was this shape: 18 independent findings mapped to 11 disjoint file groups, no cross-cutting interfaces, one wave. The DAG degenerates to a straight line. This is actually the best case: maximum parallelism, no sequencing overhead, the whole job completes in the time it takes the slowest agent.

Every agent in a wave gets three things in its prompt:

1. **File ownership:** "You own these files. Do not touch any others."
2. **Interface contracts:** The exact signatures it must implement and the exact signatures it may call from prior waves.
3. **Verification gate:** Must run the build and tests and report results before finishing.

The gate is a hard contract, not a suggestion. For the brewprune session it looked like this:

```
Gate (Wave N complete when all pass):
- go build ./...          passes
- go vet ./...            passes
- go test ./...           passes
- brewprune doctor        clean
- scout artifact updated: status checkboxes ticked, any signature changes recorded
```

Wave N+1 does not launch until Wave N is verified. Worktrees *can* isolate agents from each other during execution, but in practice with Claude Code Task agents, all agents write to the main working tree — and that's fine, because disjoint file ownership is what actually prevents conflicts, not the worktree mechanism. Worktrees are optional isolation; ownership is the hard constraint. After all agents in a wave complete, their worktrees merge back into the main branch and the verification gate runs against the merged result. Individual agents pass their gates in isolation, but the merged codebase can surface issues none of them saw individually. This post-merge verification is the real gate.

### The Artifact Revises Itself

Most planning systems treat the plan as immutable once execution begins. The scout produces a plan, agents execute it, and if reality diverges from assumptions, you're on your own.

Scout-and-wave treats the coordination artifact as a living document. When an agent discovers that an interface contract needs to change, that a function signature doesn't fit the data it actually encounters, or that a file needs to move to a different agent, it records the deviation directly in the IMPL doc. The agent reports what it actually built, not just whether it succeeded. Status checkboxes get ticked, but more importantly, interface contracts get corrected and ownership changes get recorded.

This matters because downstream agents in Wave N+1 read the artifact before they start. They get the corrected signatures, not the scout's original guesses. A spec written before implementation can't anticipate every detail. An artifact updated by the agents who did the work can. The plan converges toward reality with each wave instead of drifting further from it.

This is what makes the artifact "living" in a meaningful sense. It's not just a checklist that tracks completion. It's a shared document that agents actively revise so the next wave starts with accurate context rather than stale assumptions.

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

### Second run: UX audit (11 agents, 1 wave)

A re-audit of brewprune surfaced 18 UX issues across 11 disjoint files. No cross-agent dependencies: every finding mapped to a single file group. The scout produced a flat single-wave structure with per-agent files instead of one monolithic IMPL doc.

| Wave              | Files | Added | Removed |
|-------------------|-------|-------|---------|
| Wave 1 (11 agents) | 21   | 4,201 | 180     |
| **Total**          | **21** | **4,201** | **180** |

Every agent owned 1–2 files. The post-merge gate passed clean on the first try — no integration failures because there were no cross-agent interfaces to drift.

The shape here is the opposite of the shim feature: instead of a converging DAG (4→2→1), it's a flat fan-out (11→done). Both are valid. The scout tells you which one you have.

The result wasn't luck or model quality. Three things made it work:

- **No two agents touched the same file in a wave.** File clobbering was structurally impossible.
- **All cross-agent calls used predeclared signatures.** Agent E called `RefreshShims` exactly as the scout defined it. Agent A implemented it exactly as defined. They never needed to coordinate.
- **Every wave ended with build and tests green before the next launched.** Integration failures surfaced at wave boundaries, not at the end. Each fix was local and cheap.

## Why It Works

| Problem with naive parallel agents | How scout-and-wave solves it |
|------------------------------------|------------------------------|
| Agents clobber each other's changes | File ownership table enforces disjoint sets |
| Interface drift: agents assume different signatures | Interface contracts defined upfront; agents code against the spec |
| Integration tax: failures surface at the end | Verification gate per wave catches breaks at wave boundaries |
| Context window waste: 7 agents × full feature brief | Scout pays the context cost once; agents carry only their slice |
| Hard to reason about dependencies | Explicit DAG → waves fall out naturally |
| Plan drifts from reality during execution | Agents revise the artifact; downstream waves get corrected context |

## When to Use It

**Good fit:**
- Feature touches 5+ files
- Clear seams exist (or can be designed) between pieces
- You can define stable interfaces before writing implementations
- Work can be chunked so each agent owns 1-3 files

**Poor fit:**
- No clear seams: everything is tightly coupled
- Interface is unknown until you start implementing
- Feature is genuinely one piece of logic with nothing to parallelize

The scout itself will surface this: if you can't assign file ownership cleanly during mapping, that's a signal the work isn't parallelizable, which is still useful information before you start.

The pattern has overhead. The scout phase takes time. For a two-file change, it's not worth it. For anything where you'd otherwise context-switch between a half-dozen related tasks, it pays for itself quickly.

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

If you can't check those boxes, the feature probably isn't ready for parallelism yet, and the scout will tell you that too.

## Reference: The Prompts

Everything above describes the pattern. Below are the actual prompts that implement it: the scout prompt that produces the coordination artifact, and the agent prompt template that gets stamped per-agent from the scout's output. The prompts and a Claude Code `/saw` skill are available at [github.com/blackwell-systems/scout-and-wave](https://github.com/blackwell-systems/scout-and-wave).

### Scout Prompt

The scout is a read-only reconnaissance agent. It analyzes the codebase and produces a coordination artifact. It does not write any implementation code.

````markdown
# Scout Agent: Pre-Flight Dependency Mapping

You are a read-only reconnaissance agent. Your job is to analyze the codebase
and produce a coordination artifact that enables parallel development agents
to work without conflicts. You do not write any implementation code.

## Your Task

Given a feature description, analyze the codebase and produce a planning
document with six sections: dependency graph, interface contracts, file
ownership table, wave structure, agent prompts, and status checklist.

Write the document to `docs/IMPL-<feature-slug>.md`. This file is the single
source of truth for all downstream agents and for tracking progress between
waves.

## Process

1. **Read the project first.** Examine the build system (Makefile, go.mod,
   package.json, pyproject.toml), test patterns, naming conventions, and
   directory structure. The verification gates and test expectations you emit
   must match the project's actual toolchain.

2. **Identify every file that will change or be created.** Trace call paths,
   imports, and type dependencies. Do not guess; read the actual source.

3. **Map the dependency graph.** For each file, determine what it depends on
   and what depends on it. Identify the leaf nodes (files whose changes block
   nothing else) and the root nodes (files that must exist before downstream
   work can begin). Draw the full DAG.

4. **Define interface contracts.** For every function, method, or type that
   will be called across agent boundaries, write the exact signature.
   Language-specific, fully typed, no pseudocode. These signatures are binding
   contracts. Agents will implement against them without seeing each other's
   code. If you cannot determine a signature, flag it as a blocker that must
   be resolved before launching agents.

5. **Assign file ownership.** Every file that will change gets assigned to
   exactly one agent. No two agents in the same wave may touch the same file.
   If two tasks need the same file, resolve the conflict now: extract an
   interface, split the file, or create a new file so ownership is disjoint.
   This is a hard constraint, not a preference.

6. **Structure waves from the DAG.** Group agents into waves:
   - Wave 1: Agents whose files have no dependencies on other new work.
     These are the foundation. Maximize parallelism here.
   - Wave N+1: Agents whose files depend on interfaces delivered in Wave N.
   - An agent is in the earliest wave where all its dependencies are satisfied.
   - Annotate each wave transition with the *specific* agent(s) that unblock
     it, not "blocked on Wave 1" but "blocked on Agent A completing."

7. **Write agent prompts.** For each agent, produce a complete prompt using
   the standard 8-field format (see Agent Prompt Template below). The prompt
   must be self-contained: an agent receiving it should need nothing beyond
   the prompt and the existing codebase to do its work.

8. **Determine verification gates from the build system.** Read the Makefile,
   CI config, or build scripts. Emit the exact commands each agent must run
   (e.g., `go build ./...`, `npm test`, `pytest -x`). Do not use generic
   placeholders.

## Output Format

Write the following to `docs/IMPL-<feature-slug>.md`:

### Dependency Graph

[Description of the DAG. Which files/modules are roots, which are leaves,
which have cross-dependencies. Call out any files that were split or
extracted to resolve ownership conflicts.]

### Interface Contracts

[Exact function/method/type signatures that cross agent boundaries.]

```
func RefreshShims(binaries []string) (added int, removed int, err error)
func RunShimTest(st *store.Store, maxWait time.Duration) error
```

### File Ownership

| File | Agent | Wave | Depends On |
|------|-------|------|------------|
| ...  | ...   | ...  | ...        |

### Wave Structure

```
Wave 1: [A] [B] [C] [D]     ← 4 parallel agents
           ↓ (A completes)
Wave 2:   [E] [F]            ← 2 parallel agents
           ↓ (E+F complete)
Wave 3:    [G]               ← 1 agent
```

### Agent Prompts

[Full prompt for each agent, using the 8-field format defined below.]

### Wave Execution Loop

After each wave completes:
1. Review agent outputs for correctness.
2. Merge all agent worktrees back into the main branch.
3. Run the full verification gate (build + test) against the merged result. Individual agents pass their gates in isolation, but the merged codebase can surface issues none of them saw individually. This post-merge verification is the real gate.
4. Fix any compiler errors or integration issues.
5. Update the coordination artifact: tick status checkboxes, correct any interface contracts that changed during implementation, and record any file ownership changes. Downstream agents read this document before they start.
6. Commit the wave's changes.
7. Launch the next wave.

If verification fails, fix before proceeding. Do not launch the next wave
with a broken build.

### Status

- [ ] Wave 1 Agent A - [description]
- [ ] Wave 1 Agent B - [description]
- [ ] Wave 2 Agent C - [description]
- ...

## Rules

- You are read-only. Do not create, modify, or delete any source files
  other than the coordination artifact at `docs/IMPL-<feature-slug>.md`.
- Every signature you define is a binding contract. Agents will implement
  against these signatures without seeing each other's code.
- If you cannot cleanly assign disjoint file ownership, say so. That is a
  signal the work is not ready for parallel execution.
- Prefer more agents with smaller scopes over fewer agents with larger ones.
  An agent owning 1-3 files is ideal. An agent owning 6+ files is a red flag.
- The planning document you produce will be consumed by every downstream
  agent and updated after each wave. Write it for that audience.
````

### Agent Prompt Template

Each agent prompt has 8 fields. The scout fills these in from the coordination artifact. Fields are ordered so the agent reads constraints first, then context, then the work.

````markdown
# Wave {N} Agent {letter}: {short description}

You are Wave {N} Agent {letter}. {One-sentence summary of your task.}

## 1. File Ownership

You own these files. Do not touch any other files.
- `path/to/file` - {create | modify}
- `path/to/file_test` - {create | modify}

## 2. Interfaces You Must Implement

Exact signatures you are responsible for delivering:

```
func YourNewFunction(param Type) (ReturnType, error)
```

## 3. Interfaces You May Call

Signatures from prior waves or existing code that you can depend on.
These are already implemented; code against them directly.

```
func ExistingFunction(param Type) ReturnType
```

## 4. What to Implement

{Functional description of the behavior. Describe *what*, not *how*.
Reference specific files to read first. Describe edge cases, error handling
expectations, and any constraints on the approach.}

## 5. Tests to Write

{Named tests with one-line descriptions. Be specific.}

1. `TestFunctionName_Scenario` - {what it verifies}
2. `TestFunctionName_EdgeCase` - {what it verifies}

## 6. Verification Gate

Run these commands. All must pass before you report completion.

```
cd /path/to/project
<build command>    # e.g., go build ./... | npm run build | make
<lint command>     # e.g., go vet ./... | npm run lint | ruff check
<test command>     # e.g., go test ./... | npm test | pytest -x
```

## 7. Constraints

{Any additional hard rules: non-fatal error handling, stderr vs stdout,
backward compatibility requirements, things to explicitly avoid.}

## 8. Report

When done, report:
- What you implemented (function names, key decisions)
- Test results (pass/fail, count)
- Any deviations from the spec and why
- Any interface contract changes (signature differences from the original spec that downstream agents need to know about)
````

I've been running this pattern for a while without a name for it. If you've been doing something similar, or something better, I'd like to hear about it.
