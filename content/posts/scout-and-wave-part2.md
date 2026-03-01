---
title: "Scout-and-Wave, Part 2: What Dogfooding Taught Us"
date: 2026-02-28
draft: false
tags: ["ai", "multi-agent", "claude-code", "developer-tools", "patterns", "prompt-engineering", "productivity"]
categories: ["ai", "tools"]
description: "After shipping the scout-and-wave pattern, we used it to improve itself — and discovered it was the wrong tool for the job. Here's what three rounds of cold-start audits, an honest overhead measurement, and a bootstrap problem taught us about when parallelism actually pays off."
summary: "Scout-and-wave v0.1.0 worked. Then we ran it on documentation agents, measured the overhead honestly, and learned that raw agent count is a bad proxy for when parallelism is worth it. This post covers the audit-fix-audit loop, the dogfooding experiment that confirmed SAW was 88% slower than sequential for that job, SAW Quick mode for small disjoint work, and the bootstrap problem for new projects."
---

Part 1 of this series covered the scout-and-wave pattern: one throwaway scout maps seams and defines interface contracts, then agents execute in waves against that coordination artifact. The pattern [worked well for brewprune's shim management feature](./scout-and-wave) — 7 agents, 3 waves, 1,532 lines, no post-merge integration failures.

Then we started finding the edges.

What happens when you run 4 documentation agents through the full SAW pipeline? What happens when you apply SAW to a codebase that doesn't exist yet? And what actually drives the parallelization math — is it agent count, or something else?

These questions came out of real usage over the following weeks. The answers changed the pattern.

## The Audit-Fix-Audit Loop

After shipping the shim feature, the next project was UX quality on brewprune itself. The approach: AI agents simulate new users in containerized environments, submit findings as structured reports, then SAW processes those findings as a batch of parallel fixes. Findings from one round become the input to the next round's scout.

Part 1 briefly described the 11-agent wave that fixed 18 UX issues. That was Round 2. Rounds 3, 4, and 5 got more interesting.

**Round 3** surfaced 19 findings and a structural problem. 11 agents ran in a single wave. Five of them arrived at files that had already been modified by a previous session — they found work already done and had nothing to implement. That's 45% wasted compute. Two agents also both modified the same out-of-scope file during the same wave, producing a conflict the orchestrator had to resolve manually. The scout hadn't flagged it because the file wasn't in scope for either agent's assigned task — the changes crept in as side effects.

**Round 4** produced an unexpected failure mode: the scout agent refused to write the IMPL doc. The prompt opened with "You are a read-only reconnaissance agent," and the scout interpreted this strictly — it ran its analysis but declined to produce the coordination artifact because writing a file wasn't reconnaissance. The fix was adding "other than the coordination artifact" to the read-only rule, making the exception explicit: "Do not create, modify, or delete any source files other than the coordination artifact." That clause resolved the ambiguity, but it revealed that agents will interpret constraint language literally and conservatively — the permission to write the one file that justified the entire scout phase had to be stated outright.

**Round 5** introduced the pre-implementation status check, which turned out to be the highest-leverage change in this entire cycle. Before assigning agents, the scout now runs a pass over each finding against the current codebase: is this already implemented? If yes, the finding becomes "verify + add tests" instead of "implement." In Round 5, the scout assessed 24 findings and found that 12 of them — exactly half — were "positive findings to preserve": already correct, requiring no implementation at all. Of the remaining 12, 3 were critical fixes and 9 were improvements, all TO-DO. That's approximately 8 minutes of saved agent execution time per run and a 30% reduction in wasted work compared to Round 3.

{{< callout type="info" >}}
The pre-implementation check is now a standard phase in the scout prompt. The scout doesn't just map seams — it audits whether the work still needs doing. For audit-driven workflows where findings accumulate across rounds, this matters more than almost anything else in the prompt.
{{< /callout >}}

Round 5 also introduced **agent self-healing isolation**: if an agent detects it's in the wrong worktree, it attempts a `cd` to the correct location before verifying and proceeding. In Wave 2 of Round 5, 2 of the agents triggered this path. Here is how one of them documented its own recovery:

> **Isolation verification:** SUCCESS (after cd to worktree)
>
> Initial attempt to verify isolation from `/Users/dayna.blackwell/code/gsm` failed as expected. The pre-flight check's self-healing `cd` command successfully moved to the correct worktree location (`/Users/dayna.blackwell/code/brewprune/.claude/worktrees/wave2-agent-F`), and all subsequent verification checks passed.

That's the agent's own completion report — it flagged the failure, executed the recovery, and confirmed the result before proceeding. Both agents completed successfully. The orchestrator added a scan of completion reports for shared out-of-scope file changes before merging — the Round 3 conflict, caught at the source.

## The Dogfooding Experiment

By Round 5, the SAW pattern itself had accumulated a backlog of improvements: the pre-implementation check, the out-of-scope conflict scanner, updates to the self-healing worktree language, and clarified prompt wording from the Round 4 self-limitation incident. Four changes, mostly documentation and prompt files, some light orchestration logic.

The obvious move: run SAW on SAW.

The scout assessed the four tasks, mapped the file ownership, and emitted its verdict: **SUITABLE WITH CAVEATS**. Estimated time: 17 minutes for SAW vs. 12 minutes sequential. The caveats were clear — the work was documentation-heavy, per-agent execution time would be low, and overhead would be proportionally high. The scout flagged it. We ran it anyway.

Here's what actually happened:

| Phase | Time |
|---|---|
| Scout phase | 6 min |
| Agent execution (4 agents in parallel) | 11.5 min |
| Merge phase | 5 min |
| **Total (SAW)** | **22.5 min** |
| Sequential baseline | 12 min |
| **Overhead** | **+10.5 min (+88%)** |

SAW was 88% slower than doing the work sequentially. The scout predicted this and we ignored it.

This is worth sitting with for a moment. The pattern correctly diagnosed its own unsuitability. The suitability gate exists precisely to catch cases like this: tasks where the scout phase alone (6 minutes) costs more than the total sequential execution time minus the parallelization savings. We had the data before we started. We ran it as an experiment, which is fine — but in production, the verdict is the verdict.

The post-mortem insight: documentation edits and prompt file updates have very low per-agent time. Even with 4 agents running in parallel, the 11.5 minutes of agent execution reflects agents finishing their individual tasks in 3-4 minutes each — but because they ran in parallel, the wave completed in the time it took the slowest agent. That's still 11.5 minutes of wall-clock time. Add 6 minutes of scout and 5 minutes of merge and you've paid 22.5 minutes for work that would have taken 12 minutes straight through.

## What the Data Actually Means

The original "When to Use It" guidance in Part 1 mentioned "5+ files" as a rough threshold. That number came from intuition. The dogfooding data shows it's the wrong signal.

File count is a proxy for work volume, but it's a bad one. The variable that actually drives the math is **per-agent execution time** — specifically, whether each agent's independent work takes long enough that running agents in parallel creates meaningful savings after paying the scout + merge overhead.

Three factors determine this:

**Build and test cycle length.** In Go, a `go test ./...` on a medium-sized project can take 30-60 seconds. Each parallel agent runs the build independently, so a 45-second build cycle means each agent spends 45 seconds on verification regardless of what it implemented. For a 5-minute implementation task, a 45-second build is a rounding error. For a 3-minute documentation edit, it's 25% of the agent's total time. But more importantly: when agents run in parallel, you pay that build cost once (wall-clock), not N times. Slow builds amplify the parallelization gain.

**Task complexity.** A documentation edit or a simple find-and-replace has low implementation time — maybe 2-4 minutes per agent. Logic changes with edge cases, error handling, and tests might take 8-15 minutes per agent. SAW's fixed overhead (scout + merge) is roughly constant regardless of task type. Higher per-agent work means the overhead is a smaller fraction of total time.

**Wave structure.** A flat single-wave job (all agents independent) gets maximum parallelization benefit — you pay for the slowest agent, not the sum. A 3-wave job with 2-3 agents per wave gets much less benefit, because you're paying sequential time between waves and only parallelizing within each wave.

The revised heuristic is a simple calculation:

```
SAW worthwhile when:
  (sequential_time - slowest_agent_time) > (scout_time + merge_time)

Where:
  sequential_time  = sum of all agent tasks executed serially
  slowest_agent_time = wall-clock time for longest single agent
  scout_time       ≈ 5-8 min (typical)
  merge_time       ≈ 3-6 min (typical, scales with conflict risk)
```

For the dogfooding experiment: sequential was 12 min, slowest agent was ~4 min, so the parallelization gain was 8 min. Scout + merge was 11 min. The math said no. The scout said no. We ran it anyway.

{{< callout type="info" >}}
The `/saw check` command runs the suitability gate without committing to a full scout. It estimates SAW total vs. sequential baseline and emits a verdict with reasoning. For borderline cases, the estimate is more useful than the verdict — it tells you how close you are to the threshold.
{{< /callout >}}

## SAW Quick Mode

The dogfooding experiment clarified a gap in the pattern: there's a useful middle ground between "fire agents at random" and "full SAW with IMPL doc and scout phase."

For 2-3 agents with truly disjoint file sets and no interface contracts between them, the full scout phase is overhead without corresponding value. The scout's main job is mapping dependencies and defining contracts. If the dependencies are obvious and there are no contracts to define, you don't need a 6-minute scout to tell you that.

SAW Quick mode skips the scout entirely:

- No IMPL doc generated
- No scout phase
- Agent prompts are written inline — three fields: files owned, task description, verification command
- Agents report completion in chat, not to a coordination artifact
- No wave structure (all agents are implicitly Wave 1)

The tradeoff is deliberate: if agents discover mid-execution that they need to touch the same file, Quick mode has no mechanism to catch it. A merge conflict is the signal that you should have used full SAW instead. This isn't a failure state — it's Quick mode telling you the work was more coupled than it looked.

Estimated overhead comparison for a 3-agent job:

| Mode | Scout | Agent execution | Merge | Total |
|---|---|---|---|---|
| Full SAW | 6 min | ~3 min (parallel) | 2 min | ~11 min |
| SAW Quick | 0 min | ~3 min (parallel) | 2 min | ~5 min |
| Sequential | 0 min | ~9 min | 0 min | ~9 min |

For small, clearly disjoint work, Quick mode wins. For anything with interface contracts, dependency ordering, or uncertain file boundaries, pay for the scout.

The decision tree is straightforward:

```
Do agents need to share any interfaces?   → Yes → Full SAW
Will 4+ agents be running?                → Yes → Full SAW
Is the work documentation / trivial edits?
  AND ≤ 3 agents?                         → Yes → SAW Quick
Are the files obviously disjoint?
  AND no sequencing required?             → Yes → SAW Quick
Otherwise                                 → Full SAW
```

## The Bootstrap Problem

Every description of scout-and-wave assumes an existing codebase. The scout reads source files, traces imports, identifies stable seams. It's an analyst reading something that's already there.

What about a new project?

The scout can't read a codebase that doesn't exist. If you're starting from scratch and want to build SAW-compatible architecture — where package boundaries are chosen to enable parallel development from the beginning — the scout has nothing to work with.

The solution is `/saw bootstrap`, which changes the scout's role from analyst to architect. Instead of reading existing code, it gathers requirements: language, project type, and 3-5 key concerns. From those requirements, it designs the package structure with parallel development as a first-class constraint — packages are sized and scoped so that feature work can later be assigned to agents without ownership conflicts. A Go CLI tool might come back with:

```
cmd/
  root.go          (agent A)
internal/
  config/          (agent B)
  store/           (agent C)
  processor/       (agent D)
  output/          (agent E)
```

Each package is a potential agent boundary. The boundaries are chosen to minimize cross-package dependencies during implementation, not just to satisfy Go conventions.

The critical addition is a mandatory **Wave 0** before any parallel implementation begins. Wave 0 is a single agent — not parallel — that defines all shared types, interfaces, and structs. It's the only wave where one agent's output is a direct dependency of every other agent's work. In Go this is usually a `types/` package; in Rust it's typically a `types.rs` or `models.rs`. Wave 0 must complete and merge before any implementation agents launch.

```
Wave 0:  [types/interfaces]    ← 1 agent, solo
              ↓
Wave 1:  [A] [B] [C] [D]      ← 4 agents, fully parallel
              ↓
Wave 2:  [E]                   ← integration agent (optional)
```

The Wave 0 pattern solves the core chicken-and-egg problem of new project parallelism: agents can't implement against interfaces that don't exist yet, but you can't define all interfaces before any implementation starts. Wave 0 carves out the shared contracts as an explicit pre-step. Once they exist, parallel agents implement against them without coordination.

Bootstrap produces an IMPL doc for a project that doesn't exist yet — a coordination artifact in the same format as any other SAW artifact, but with the initial project structure and Wave 0 types as the starting point. The result is a project where the seams were designed for agents, not retrofitted after the fact.

## The Interface Freeze Window

One more thing that emerged from running the pattern repeatedly: there's a specific window in the workflow where interface changes are cheap, and a point after which they become expensive.

The window is between "IMPL doc written" and "worktrees created." This is the natural human review step — you read the scout's output, verify the suitability verdict makes sense, check that file ownership is clean, confirm the interface contracts look right. It's also the only time when changing a contract costs nothing. You edit the IMPL doc. Done.

Once worktrees branch from HEAD, the economics change. If an interface contract needs revision after agents are running, you either accept drift (agents implement against the old spec and you fix the mismatch at merge time) or you stop, remove the worktrees, update the contracts, and recreate them. Either way you've paid extra. The second worktree creation is more expensive than reading the IMPL doc more carefully the first time.

The discipline this implies is treating that review window as an explicit interface freeze checkpoint: don't create worktrees until every type signature in the IMPL doc is final. In practice this means reading the agent prompts before launching, not just the wave structure. The agent prompts contain the contracts agents will actually implement against. If a signature looks wrong in an agent prompt, fix it before the worktree exists.

This is a soft lesson — nothing in the protocol enforces it — but it's the kind of thing you discover by paying the cost once.

## Where This Leaves Things

The audit-fix-audit cycle turned out to be the most durable workflow pattern to emerge from this. A round of cold-start audits produces structured findings. A scout digests the findings, runs the pre-implementation check to filter already-done work, assigns parallel agents to the remainder, and executes in waves. Results merge, tests pass, and the output feeds the next audit round. Three rounds of this on brewprune caught issues that sequential review missed, primarily because the simulated new-user perspective surfaced assumptions baked into the code that a developer working in the codebase doesn't notice.

The dogfooding experiment was worth doing even though the result was "SAW was wrong for this job." It produced the overhead measurement that let us rewrite the "When to Use It" guidance with actual numbers instead of intuition. The scout predicted the overhead correctly. Running it anyway confirmed the prediction and gave us a concrete data point to reason from.

SAW v0.3.0 — with the pre-implementation check, self-healing isolation, Quick mode, and bootstrap — is at [github.com/blackwell-systems/scout-and-wave](https://github.com/blackwell-systems/scout-and-wave).

The thing I keep coming back to: the pattern that emerged from all of this wasn't a better parallelization algorithm. It was a better understanding of when not to parallelize. The scout's suitability verdict is doing real work. Ignoring it costs exactly as much as the math says it will.

---

**Up next:** [Part 3: The Skill Is Software](./scout-and-wave-part3) — How `saw-skill.md` decomposed from a 400-line monolith into focused modules, why version headers matter, and five scout prompt fixes driven by real production failures.
