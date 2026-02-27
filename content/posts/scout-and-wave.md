---
title: "Scout-and-Wave: A Coordination Pattern for Parallel AI Agents"
date: 2026-02-27
draft: true
tags: ["ai", "multi-agent", "claude-code", "developer-tools", "patterns", "prompt-engineering", "productivity"]
categories: ["ai", "tools"]
description: "A pattern for running multiple AI agents in parallel without conflicts — using a throwaway scout agent to map seams and dependencies before any code is written, then executing in waves against a shared coordination artifact."
summary: "Naive parallel agents step on each other. The scout-and-wave pattern solves this by front-loading dependency mapping: one throwaway agent identifies seams and builds a living coordination artifact before any implementation begins. Development then proceeds in waves, each consuming and updating the artifact for the next."
---

The last time I ran a scout-and-wave session on brewprune, 7 agents produced 1,532 lines of new code across 16 files in 3 waves. The feature was complete, building, and passing tests in under an hour.

The first time I tried parallel agents without any coordination structure, I got merge conflicts, contradictory implementations, and an hour of cleanup. The agents had done real work. None of it fit together.

The difference isn't the agents. It's what happens before you launch them.

## What Goes Wrong With Naive Parallel Agents

The instinct when you discover parallel agents is to split the work and fire them all at once. It feels efficient. Agents make local decisions without global context, and when multiple agents are touching the same codebase, those local decisions collide.

There are four specific failure modes:

**File clobbering.** Two agents are assigned related work. Neither knows the other exists. They both touch the same file, make incompatible changes, and you spend time reconciling their outputs — defeating the parallelism entirely.

**Calling code that doesn't exist yet.** Agent B is building a feature that depends on a function Agent A is writing. Agent B makes assumptions about that function's signature. Agent A makes different ones. Integration fails.

**Late conflict discovery.** Agents complete their individual tasks successfully. The integration failures surface only when you try to assemble the pieces. By then, rework is expensive.

**Context window waste.** Giving every agent the full picture of a large feature bloats every prompt. Each agent spends its context on information irrelevant to its specific task.

These aren't edge cases. They're the default outcome of uncoordinated parallelism.

## Map First, Execute Second

Dependency mapping needs to be a first-class phase, not something you figure out on the fly.

Before any agent writes a line of code, a scout agent answers three questions:

1. **What are the seams?** Where does the new feature touch existing code? What are the minimal, stable interfaces between pieces?
2. **Who owns what?** Every file that will change gets assigned to exactly one agent. No two agents in the same wave touch the same file.
3. **What's the DAG?** If Agent B needs Agent A's interface, B is in a later wave. If A and B are independent, they're in the same wave.

The scout is throwaway — read-only, no implementation, one-shot. Its entire output is a single document: interface contracts, a file ownership table, and a wave structure. That document is the coordination artifact.

**Interface contracts are defined before any agent starts. Agents code against the spec, not against each other's in-progress code.**

This is the same thing a tech lead does before a sprint. You're just automating it.

## The Scout Deliverable

The coordination artifact the scout produces looks like this:

```markdown
## Wave structure
Wave 1: [agent A — files], [agent B — files], [agent C — files]
Wave 2: [agent D — files], [agent E — files] — blocked on Wave 1
Wave 3: [agent F — files] — blocked on Wave 2

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
- [ ] Wave 1 Agent A — shim generator
- [ ] Wave 1 Agent B — version check on startup
```

The status checklist becomes a living artifact: each wave updates it before the next wave launches. Downstream agents consume the actual state of what was built, not stale pre-flight assumptions.

## Wave Execution

Each wave is a set of agents that can run fully in parallel because their file sets don't overlap and they depend only on interfaces already defined in the spec.

Every agent in a wave gets three things in its prompt:

1. **File ownership** — "You own these files. Do not touch any others."
2. **Interface contracts** — The exact signatures it must implement and the exact signatures it may call from prior waves.
3. **Verification gate** — Must run the build and tests and report results before finishing.

Wave N+1 does not launch until Wave N is verified: build green, tests passing. Worktrees isolate agents from each other during execution so there are no mid-flight merge conflicts.

After each wave: review outputs, fix any compiler errors, commit, update the status checklist.

## Worked Example: brewprune

The feature was shim management for brewprune, a new subsystem touching shim generation, version checking, path disambiguation, self-test, and onboarding. The scout mapped 7 agent slots across 3 waves, with interface contracts for `RefreshShims`, `RunShimTest`, `EnsurePathEntry`, and `buildOptPathMap`.

The DAG showed Wave 2 was blocked on A specifically — B, C, and D had no dependents in later waves. Wave 3 was blocked on E and F. Wave 1 had no internal dependencies.

```
Wave 1: [A] [B] [C] [D]     ← 4 parallel agents
           ↓ (A completes)
Wave 2:   [E] [F]            ← 2 parallel agents, unblocked by A
           ↓ (E+F complete)
Wave 3:    [G]               ← 1 agent, unblocked by E+F
```

**Wave 1 (4 agents in parallel):**
- A: `internal/shim/generator.go` — RefreshShims, WriteShimVersion, ReadShimVersion
- B: `cmd/brewprune-shim/main.go` — version check on startup
- C: `internal/watcher/shim_processor.go` — opt-path disambiguation
- D: Formula + README — brew services stanza, Quick Start updates

**Wave 2 (2 agents, unblocked by A):**
- E: `internal/app/scan.go` — --refresh-shims fast path
- F: `internal/app/doctor.go` + `shimtest.go` — live pipeline self-test

**Wave 3 (1 agent, unblocked by E+F):**
- G: `internal/app/quickstart.go` + `internal/shell/config.go` — onboarding workflow

Results by wave:

| Wave              | Files | Added | Removed |
|-------------------|-------|-------|---------|
| Wave 1 (4 agents) | 6     | 600   | 26      |
| Wave 2 (2 agents) | 7     | 530   | 11      |
| Wave 3 (1 agent)  | 3     | 402   | 23      |
| **Total**         | **16**| **1,532** | **60** |

Notice the shape: maximum parallelism at the start (4 agents), narrowing as work integrates (2, then 1). This isn't a coincidence — it's what a dependency graph looks like. Foundational work fans out; integration work converges. The wave structure falls out naturally from the DAG.

## Why It Works

| Problem with naive parallel agents | How scout-and-wave solves it |
|------------------------------------|------------------------------|
| Agents clobber each other's changes | File ownership table enforces disjoint sets |
| Agents can't call code that isn't written yet | Interface contracts defined upfront — agents code against the spec |
| Integration failures discovered late | Verification gate per wave catches breaks early |
| Context window blown by a monolithic task | Each agent only sees its own narrow context |
| Hard to reason about dependencies | Explicit DAG → waves fall out naturally |

## When to Use It

**Good fit:**
- Feature touches 5+ files
- Clear seams exist (or can be designed) between pieces
- You can define stable interfaces before writing implementations
- Work can be chunked so each agent owns 1-3 files

**Poor fit:**
- No clear seams — everything is tightly coupled
- Interface is unknown until you start implementing
- Feature is genuinely one piece of logic with nothing to parallelize

The scout itself will surface this — if you can't assign file ownership cleanly during mapping, that's a signal the work isn't parallelizable, which is still useful information before you start.

The pattern has overhead. The scout phase takes time. For a two-file change, it's not worth it. For anything where you'd otherwise context-switch between a half-dozen related tasks, it pays for itself quickly.

## How This Relates to Existing Patterns

The closest named concepts are the Planner-Worker-Judge pattern (Planner maps work, Workers execute, Judge evaluates) and spec-driven development (write the spec before the code). Scout-and-wave borrows from both but differs in two ways.

First, the scout is throwaway. It's not a persistent orchestrator that continues to direct execution — it does one job, produces one document, and disappears. This keeps the coordination overhead minimal.

Second, the coordination artifact is living. A spec describes intended state. The scout artifact tracks actual state as waves complete. Downstream agents get accurate inputs from the previous wave, not stale pre-flight assumptions. This distinction matters in practice: a spec written before implementation can't know what Wave 1 actually built. An artifact updated by Wave 1 can.

I've been running this pattern for a while without a name for it. The coordination artifact from the brewprune session still lives in `docs/IMPL-brew-native.md` if you want to see what the scout actually produced. If you've been doing something similar — or something better — I'd like to hear about it.
