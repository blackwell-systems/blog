---
title: "Scout-and-Wave, Part 3: Five Failures, Five Fixes"
date: 2026-02-28
draft: false
series: ["scout-and-wave"]
seriesOrder: 3
tags: ["ai", "multi-agent", "claude-code", "developer-tools", "patterns", "prompt-engineering", "productivity"]
categories: ["ai", "tools"]
description: "How the scout-and-wave skill file itself evolved through two major versions — decomposing a 400-line monolith into focused modules, adding version headers so installed copies don't go stale, and iterating the scout prompt through five behavior-changing fixes. Prompt engineering as software engineering."
summary: "A 400-line prompt that handles routing, worktree creation, merge logic, and conflict detection has the same problems as a monolithic codebase. This post covers how saw-skill.md evolved from a single-file monolith to a thin router delegating to focused modules, why version headers matter when users copy prompts to ~/.claude/commands/, and how five specific failures drove five specific changes to the scout prompt's behavior."
---

[Part 1](./scout-and-wave) covered the pattern. [Part 2](./scout-and-wave-part2) covered what we learned from running it. This post is about the skill file itself — how `saw-skill.md` evolved, why it needed refactoring, and what that refactoring looks like in practice.

The thesis is simple: a prompt file has the same problems as a software module. A 400-line file that handles routing, worktree creation, merge logic, and conflict detection is a monolith. It breaks in the same ways. It's hard to debug for the same reasons. It needs decomposition for the same reasons you'd decompose a large class or package.

## The Original Monolith

The v0.1.0 `saw-skill.md` was a single file that did everything. Routing decisions, scout invocation, worktree creation, agent launching, merge logic, conflict detection, progress reporting — all interleaved in one prompt.

In the brewprune v0.1 monolith (preserved at `docs/scout-and-wave-prompt.md`), the structure looked like this: two major sections (scout prompt, agent template), plus inline wave execution instructions woven between them. When an agent failed to write the IMPL doc, you read the entire file to find the relevant constraint. When merge behavior needed updating, you edited around agent-launching logic. When the worktree creation procedure changed, you tracked down every place in the prompt where worktree state was mentioned.

The file had no concept of separation of concerns. Worktree creation failure paths lived in the same section as merge procedures. The read-only constraint and the IMPL doc write permission sat pages apart.

Here's a concrete example of what debugging looked like. In Round 4, a scout agent refused to write the IMPL doc. The agent had run its full analysis — codebase read, seams mapped, interface contracts drafted — and then returned the IMPL content as text instead of writing the file. To diagnose this, you had to read the scout prompt section of the monolith to find the `Rules` block, then trace back through the orchestration logic to understand how the scout phase was invoked, then cross-reference the constraint language against what the agent actually did.

The offending text was in the `Rules` section:

```
You are read-only. Do not create, modify, or delete any source files
other than the coordination artifact at `docs/IMPL-<feature-slug>.md`.
```

The fix was obvious in retrospect — the exception needed to be explicit, not implied. But finding it required reading through an entire orchestration document. That's the monolith problem.

## The Decomposition

v0.2.0 split `saw-skill.md` into three files.

`saw-skill.md` became a thin router — 57 lines as of v0.3.0, almost entirely delegation. It reads arguments, determines which path to take, and tells you which module to read next. There is essentially no logic in the router beyond the routing decisions themselves.

The two extracted modules each own a single concern:

**`saw-worktree.md`** owns the worktree lifecycle: pre-creation (create worktrees before launching agents, do not rely on the Task tool's `isolation` parameter alone), creation verification (check `git worktree list`, count must match N+1), diagnosis of creation failures in a 3-tier order (test basic support, check repo state, check branch name conflicts), agent self-healing (the `cd`-then-verify pattern), and cleanup after wave completion.

**`saw-merge.md`** owns the merge procedure: pre-merge conflict detection (scan all completion reports for out-of-scope file changes before touching anything), handling both committed and uncommitted agent changes, worktree cleanup, post-merge verification against the IMPL doc's gate commands, and IMPL doc updates after verification passes.

The practical difference shows up when something breaks. When merge conflicts occur, you open `saw-merge.md`. When worktree creation fails, you open `saw-worktree.md`. You don't parse the orchestration router to find the relevant section, because the relevant section lives in a file named for exactly that concern.

The router itself is explicit about this:

```
If a `docs/IMPL-*.md` file already exists:
2. **Worktree setup:** Read `prompts/saw-worktree.md` from the scout-and-wave
   repository and follow the pre-creation procedure.
5. **Merge and verify:** Read `prompts/saw-merge.md` from the scout-and-wave
   repository and follow the merge procedure.
```

No logic embedded in the router. Just delegation to the file that owns the concern.

## Version Headers

Every prompt file now opens with a version comment:

```
<!-- saw-skill v0.3.0 -->
<!-- saw-worktree v0.3.0 -->
<!-- saw-merge v0.2.0 -->
```

This is a solved problem in software: packages have versions, installed binaries have versions, dependencies have versions. Prompt files distributed by copy-paste had no equivalent.

The use case is straightforward. The recommended installation is to copy `saw-skill.md` to `~/.claude/commands/saw.md` so Claude Code exposes it as a `/saw` slash command. Users do this once and forget about it. Weeks later, v0.2.0 ships with the module decomposition and the agent count threshold fix. The user's installed copy is stale. Without version headers, there is no way to know.

With version headers:

```bash
head -1 ~/.claude/commands/saw.md
# → <!-- saw-skill v0.1.0 -->
```

One command, immediate answer. Compare against the repo's current version and you know whether your copy needs updating.

The version comment is at line 1, not buried in a footer. The `head -1` check needs to work. That's the only reason it matters where the comment lives.

## The Scout Prompt: A Bug Tracker

The scout prompt went through five meaningful changes between v0.1.0 and the current version. Each change was driven by a specific failure. Reading them in sequence is reading a bug tracker for a prompt's behavior.

### Fix 1: Scout refused to write the IMPL doc

**What broke:** Round 4 scout agent ran its full analysis and returned the IMPL content as chat text instead of writing the file.

**Root cause:** The prompt opened with "You are a read-only reconnaissance agent." The agent interpreted this as a technical constraint — writing a file isn't reconnaissance, so it didn't.

**Before:**
```
You are read-only. Do not create, modify, or delete any source files
other than the coordination artifact at `docs/IMPL-<feature-slug>.md`.
```

**After:**
```
You do NOT write implementation code, but you MUST write the coordination
artifact (IMPL doc) using the Write tool.
```

The key insight from the CHANGELOG: "agents will interpret constraint language literally and conservatively — the permission to write the one file that justified the entire scout phase had to be stated outright." Ambiguous constraints resolve to restriction. Explicit permissions have to be explicit.

### Fix 2: 45% wasted agent compute

**What broke:** Round 3 had 11 parallel agents. Five of them arrived at files that were already modified from a previous session. Those five agents had nothing to implement and spent their entire execution time verifying that.

**Fix:** The scout now runs a pre-implementation status check as a standard phase — step 4 in the process, before any agent prompts are written. For each finding or requirement, the scout checks the current codebase: already done, partially done, or still needed. DONE items become "verify + add tests" instead of "implement." NOT-DONE items get normal agent prompts.

In Round 5, the scout assessed 24 findings and identified 12 as already correct. That's approximately 8 minutes of saved agent execution time per run.

{{< callout type="info" >}}
The pre-implementation check matters most in audit-driven workflows where findings accumulate across rounds. By Round 5, previous rounds had already fixed a meaningful fraction of the open issues. Without the check, agents would re-implement already-complete work — and probably break it.
{{< /callout >}}

### Fix 3: Go-only verification examples

**What broke:** The scout prompt's verification gate examples all used Go toolchain commands: `go build ./...`, `go vet ./...`, `go test ./...`. Users running the pattern on Rust, Node, or Python projects got generic examples that didn't match their actual build systems.

**Fix:** The scout now explicitly reads the project's build system files before emitting verification gate commands — `Makefile`, `go.mod`, `package.json`, `pyproject.toml`, `Cargo.toml`, whatever exists. The scout is instructed to emit exact commands matching the project's actual toolchain, not placeholders. The prompt explicitly states: "Do not use generic placeholders."

This sounds minor. In practice, an agent running a wrong verification command either errors out immediately or silently passes against a stale build. Either way, the wave boundary guarantee breaks.

### Fix 4: Agent count as suitability proxy

**What broke:** The v0.1.x suitability gate used raw agent count as its primary decision criterion: ≤2 agents was NOT SUITABLE, ≥5 was SUITABLE. This came from one data point — the dogfooding experiment (4 documentation-only agents, 88% slower than sequential).

The problem: the threshold didn't generalize. A 2-agent job building a new subsystem with complex logic and a 45-second build cycle benefits substantially from parallelization. A 4-agent job making trivial documentation edits does not. Agent count tells you nothing about per-agent execution time, which is the variable that actually drives the math.

**Fix:** The agent count threshold was replaced with a complexity-based heuristic evaluating four factors:

| Factor | Favors SAW | Doesn't favor SAW |
|---|---|---|
| Build/test cycle | >30 seconds | Fast, trivial |
| Files per agent | ≥3 files | 1 file |
| Wave structure | Single wave | Multiple waves |
| Task type | Logic + tests | Documentation edits |

The CHANGELOG is direct about why the old threshold was wrong: "The previous threshold was based on a single dogfooding data point that didn't generalize."

### Fix 5: No time-to-value estimate in verdict

**What broke:** The suitability verdict was binary — SUITABLE or NOT SUITABLE — with a one-paragraph rationale. Users couldn't assess the magnitude of the overhead before committing. A SUITABLE WITH CAVEATS verdict that estimated 17 minutes for SAW vs. 12 minutes sequential is more useful than one that just says "overhead will be proportionally high."

**Fix:** The `/saw check` command now emits a time-to-value estimate alongside the verdict: estimated SAW total vs. sequential baseline, with the overhead as a percentage. This is what let the dogfooding experiment correctly predict its own outcome before it ran.

The estimate is also what lets you act on a SUITABLE WITH CAVEATS verdict intelligently. If SAW is estimated at 17 minutes vs. 12 minutes sequential, you might run it anyway for the audit trail value, or switch to Quick mode. If SAW is estimated at 3 minutes vs. 24 minutes sequential, the verdict doesn't require much deliberation.

## New Concerns Get New Modules

v0.3.0 added `saw-bootstrap.md` as a dedicated module for the design-first architecture problem. It wasn't folded into `saw-skill.md` as a new routing branch with inline logic, and it wasn't bolted onto the scout prompt as an alternate mode. It got its own file.

The router delegates to it with the same pattern as the other modules:

```
If the argument is `bootstrap <project-description>`:
1. Read `prompts/saw-bootstrap.md` from the scout-and-wave repository
   and follow the bootstrap procedure.
```

New concern, new module. The router stays thin.

This isn't a coincidence — it's the decomposition working as intended. When `saw-bootstrap.md` needs to change (and it will, once the Wave 0 pattern gets more usage), you edit one file. You don't read the router to find the bootstrap section; you open the bootstrap module. The module boundary makes the scope of any given change clear before you start editing.

## Prompts Are Code

The discipline that applies to software applies to the instructions that drive software-writing agents.

A prompt that grew organically to 400 lines without structure is a monolith. It has the same debugging overhead, the same risk that a change in one section breaks something in another, and the same resistance to reasoning about at a glance. The answer is the same answer it always is: find the seams, extract the concerns, keep each module focused.

Version headers are the equivalent of `go.mod` version pins. You need to be able to answer "what version are you running" for anything you install and depend on.

The scout prompt's iteration history is the equivalent of a bug tracker and a changelog. Every change has a root cause. Every root cause came from a real failure in a real run. The prompt's behavior converged toward correctness through the same feedback loop that any software module uses — except the "bugs" are agent behaviors and the "tests" are production runs on actual codebases.

The scout-and-wave prompts are at [github.com/blackwell-systems/scout-and-wave](https://github.com/blackwell-systems/scout-and-wave). The version headers are at line 1 of each file.

