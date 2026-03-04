---
title: "Scout-and-Wave, Part 4: Trust Is Structural"
date: 2026-03-03
draft: false
series: ["scout-and-wave"]
seriesOrder: 4
tags: ["ai", "multi-agent", "claude-code", "developer-tools", "patterns", "prompt-engineering", "productivity"]
categories: ["ai", "tools"]
description: "v0.6.0 is about restoring guarantees that were silently lost. Two stories, the Scaffold Agent and the worktree isolation failure, both reveal the same principle: something can work perfectly while violating the invariants that make it trustworthy."
summary: "The Scaffold Agent doesn't add capability. It restores a review gate that was cosmetically present but structurally absent. The worktree isolation trip wire catches failures that were invisible until merge time. Neither fixes a bug in the traditional sense. Both fix trust."
---

[Part 1](./scout-and-wave) introduced the pattern. [Part 2](./scout-and-wave-part2) covered what running it taught us about when parallelism actually pays off. [Part 3](./scout-and-wave-part3) covered how a 400-line prompt monolith was decomposed and why prompt files have the same problems as software modules.

This post is about v0.6.0. Not about new features, but restoration. Two specific changes, both driven by production incidents, both addressing the same underlying problem: something worked but violated a structural guarantee.

The Scaffold Agent restores a human review gate that was cosmetically present but structurally bypassed. The worktree isolation trip wire catches failures that three cooperative defense layers missed. Neither fixes a bug in the sense of "agent produced wrong output." Both fix trust in the sense of "the protocol's guarantees must be enforceable, not aspirational."

## Arc 1: Wave 0 to Scout Phase to Scaffold Agent

The story runs chronologically through three protocol versions, each solving a problem the previous one created.

### v0.3.0: Wave 0 Introduced

Bootstrap mode (the design-first architecture variant for new projects with no existing codebase) needed a way to create shared type scaffolds before parallel agents could implement against them. The chicken-and-egg problem was clear: agents can't implement against interfaces that don't exist yet, but you can't define all interfaces before any implementation starts without someone implementing them first.

The solution was Wave 0. A dedicated pre-wave containing exactly one agent: the types agent. Its job was to read the Scout's interface contract specifications from the IMPL doc and materialize them as source files: a `types.go` package in Go, a `types.rs` module in Rust, whatever the language required. Once committed, Wave 1 agents could import from those types and implement in parallel.

Wave 0 ran through full wave machinery: worktree creation, async agent launch, verification gate, merge procedure. The only difference was wave size: one agent instead of N. This worked. Builds passed. Agents got their types. Bootstrap mode shipped.

But it had a structural smell. Wave machinery exists to coordinate parallel execution. Applying it to a single agent produces overhead with no corresponding parallelism benefit. You create one worktree, launch one agent, wait for one completion notification, merge one branch. The merge step can't produce conflicts because there's nothing to conflict with. The coordination artifact is solving a problem that doesn't exist when N=1.

### v0.5.0: Wave 0 Collapsed Into Scout Phase

The simplest answer: Scout already analyzes the codebase and defines interface contracts in the IMPL doc. Why not let it create the scaffold files directly?

v0.5.0 did exactly that. Wave 0 was removed. The Scout gained a new permission: "You may create type scaffold source files in addition to the IMPL doc." The Scout's process became: analyze codebase, define interface contracts, write scaffold files, commit them to HEAD, write IMPL doc, exit. Wave 1 launched with scaffolds already present.

This eliminated the Wave 0 overhead completely. No worktree creation, no solo wave, no merge procedure for one branch. Agents still got their types. The wave structure simplified. Wave 1 was always the first parallel wave.

The change shipped in a three-commit sequence. First commit: update Scout prompt to allow scaffold file creation. Second commit: remove Wave 0 logic from skill files. Third commit: update bootstrap documentation. Clean, small, testable. Builds passed. The brewprune cold-start audit ran a bootstrap session with the new flow. Worked perfectly.

And it had a problem that wouldn't surface until weeks later, during a consistency audit.

### Review Gate Became Cosmetic

The human review checkpoint sits between Scout completion and Wave 1 launch. The user reads the IMPL doc, verifies the suitability verdict makes sense, checks that file ownership is clean, confirms interface contracts look correct. This is the interface freeze window: the point where changing a contract costs nothing because no agent has started implementing yet.

In v0.5.0, by the time the user saw the IMPL doc, scaffold files were already committed to HEAD. Interface contracts were locked in source code. If a type signature looked wrong during review (maybe a function needed an extra parameter, maybe a struct was missing a field) changing it required uncommitting the scaffolds, editing them, re-compiling, re-committing. The review gate was still there in the workflow, but it was cosmetic. The interfaces were already materialized.

This is subtle. Nothing broke. Agents got correct types. The protocol executed successfully. But a guarantee was silently violated: interface contracts must be reviewable before they're locked in code. The v0.5.0 flow had Scout commit source files, then surface the IMPL doc for review. That's backward.

The problem wasn't caught immediately because most sessions don't require interface revisions during review. When contracts are straightforward, the ordering doesn't matter. You review, see everything looks fine, proceed. The violation only surfaces when you need to change something and discover the change is expensive because the thing you're changing is already committed.

### v0.5.2: I2 Updated to Encode the Problem

The I2 invariant, "Interface contracts precede parallel implementation," was reworded to reflect the v0.5.0 design: "The Scout defines and implements interface contracts."

This was technically accurate. Scout defined contracts in the IMPL doc. Scout implemented them as scaffold files. Scout committed them to HEAD. All true statements.

But encoding "defines and implements" as a single participant's responsibility was encoding the review gate problem into the protocol specification. Defining contracts and implementing them are two distinct jobs with a human checkpoint between them. Collapsing them into one participant made that checkpoint structurally unenforceable.

### v0.6.0: Scaffold Agent

The fix was a fourth participant.

The Scaffold Agent is a single-purpose asynchronous agent that runs after Scout completes and after human review. Its job: read the approved IMPL doc Scaffolds section, create the specified type scaffold files, verify they compile, commit to HEAD, update the scaffold status field to `committed (sha)`, exit.

The flow becomes:

1. Scout analyzes codebase, defines interface contracts, writes IMPL doc (including Scaffolds section), exits.
2. Human reviews IMPL doc. Interface contracts are specifications, not code.
3. If Scaffolds section is non-empty and shows `Status: pending`, Orchestrator launches Scaffold Agent.
4. Scaffold Agent creates files, verifies compilation, commits.
5. Orchestrator creates worktrees for Wave 1.

The review gate is structural again. Changing an interface contract during review is an IMPL doc edit. No source files to uncommit, no compilation required, no git history to rewrite. Once the user approves, the Scaffold Agent materializes the contracts. After that point, E2 (interface freeze) applies, but the freeze happens after review, not before.

### Why Not Alternatives?

Three other options were considered:

**Option A: Spawn Scout twice.** Scout runs once to analyze and write IMPL doc. Human reviews. Scout spawns again to create scaffolds. Rejected because async agents have no pause/resume mechanism. A "Scout continues" design would require two separate Scout invocations with full context re-establishment. The second Scout would need to re-read the IMPL doc, re-establish project context, then execute the scaffolding step. That's more expensive than a dedicated lightweight agent that just reads the Scaffolds section and creates files.

**Option B: Orchestrator creates scaffold files.** After human review, Orchestrator reads the Scaffolds section and writes the files directly. Rejected because it violates I6 (role separation). The Orchestrator's job is coordination and state management, not implementation. Creating source files, even simple type definitions, is implementation work. Assigning it to the Orchestrator pollutes the Orchestrator's context with implementation details and breaks observability. External tools that monitor SAW sessions identify participants by their roles. An Orchestrator performing Wave Agent work is undetectable.

**Option C: Keep v0.5.x behavior.** Accept that scaffolds are committed before review and document the interface revision procedure as a standard path. Rejected because making the review gate cosmetic is worse than removing it entirely. A checkpoint that looks enforceable but isn't creates false confidence. Either enforce it structurally or don't claim it exists.

The Scaffold Agent doesn't add capability. v0.5.0 already created scaffold files. v0.6.0 restores a guarantee that was lost: interface contracts are reviewable as specifications before they're locked as code.

### Solo Wave Semantics

Once the Scaffold Agent exists, a natural question arises: do solo waves need scaffolding?

No.

Scaffolds solve intra-wave coordination: the problem of multiple agents in the same wave needing to compile against shared types they can't see because worktrees isolate them from each other's uncommitted work. One agent can't conflict with itself. A solo wave agent implements its types and uses them in the same commit. There's nothing to coordinate.

Cross-wave coordination doesn't need scaffolds either. Waves execute sequentially. Wave N commits its work to HEAD. Wave N+1 branches from that commit and imports from the committed codebase directly. This is just normal software development: you import from code that's already merged. Scaffolds exist because parallel agents in the same wave can't import from each other's uncommitted code. Later waves don't have that problem.

Why not per-wave scaffolding? Because E2 (interface freeze) makes it unnecessary. All interface contracts are known at the REVIEWED state, before any wave launches. The Scout defines every interface that crosses agent boundaries in the IMPL doc during the scouting phase. Once human review completes, those contracts are frozen. The Scaffold Agent materializes them once, before Wave 1. When Wave 1 completes and Wave 2 begins, there's nothing new to scaffold. Wave 2 agents import from Wave 1's committed work.

The state machine encodes this. The loop-back arc from "more waves?" to WAVE_PENDING bypasses the Scout phase and the Scaffold Agent gate. It goes straight to worktree creation because all contracts are already known and materialized.

## Arc 2: From Loose Spec to Formal Protocol

A brief timeline of the formalization journey, because the Scaffold Agent story and the worktree isolation story both depend on understanding that the protocol evolved from a single prompt into a formal specification with numbered invariants and execution rules.

**v0.1.0:** Everything lived in one 400-line skill file. Routing logic, scout instructions, agent template, merge procedure, all inline. No separation of concerns. No version headers. No numbered rules to reference.

**v0.3.4:** Eight protocol gaps closed in a single pass. The Execution Rules section was added to PROTOCOL.md. These were rules that had been implicit in prompt wording but weren't stated as normative requirements. Making them explicit and numbered meant they could be referenced, audited, and enforced consistently.

**v0.3.5:** Invariants gained I-numbers (I1 through I6). I6 (role separation) was introduced: "The Orchestrator does not perform Scout, Scaffold Agent, or Wave Agent duties." This invariant was implicit in the participant model but not enforced. Giving it a number made violations detectable.

**v0.4.0:** Execution rules numbered E1 through E14. State machine diagram added (replacing ASCII art). Conformance criteria defined: an implementation is conforming if it preserves all six invariants, all fourteen execution rules, state machine transitions including mandatory human checkpoints, message formats, and the five-question suitability gate.

**v0.5.1 through v0.5.3:** Three consecutive consistency passes. v0.5.1 caught the E-rule count mismatch (documentation claimed E1 through E13, but E14 existed in PROTOCOL.md). v0.5.3 fixed 15 issues across 12 files: stale version numbers, missing scaffold commit verification steps, generic examples that leaked implementation details.

Each pass revealed drift: prompt files claiming conformance but using outdated rule definitions, documentation referencing features that had been removed, version headers not matching actual versions. The pattern was the same every time. Something worked correctly but violated the specification.

**E5: Worktree naming convention.** Added as a canonical requirement, not a style choice. Worktrees must be named `.claude/worktrees/wave{N}-agent-{letter}` because external tooling identifies SAW sessions by reading worktree paths. Deviating from the naming scheme breaks observability silently. A protocol whose sessions are undetectable to monitoring tools is unenforceable at the ecosystem level.

The point: a protocol that started as a prompt became a formal specification with numbered invariants, execution rules, state transitions, and conformance criteria. Each version added structure because running the protocol revealed ambiguity. By v0.6.0, the protocol was specific enough that violations could be detected and named.

## Arc 3: The Worktree Isolation Failure

This is the centerpiece incident. It happened during a live brewprune cold-start audit, Wave 1, 6 parallel agents. Everything looked normal during execution. The failure was invisible until merge time.

### What Happened

All six agents committed to main instead of their worktree branches.

The Agent tool's `isolation: "worktree"` parameter failed silently. Field 0 self-verification (the pre-flight check where each agent verifies its working directory and git branch before touching any files) did not catch it. The agents ran to completion, wrote their completion reports to the IMPL doc, and reported success.

The Orchestrator entered the merge phase. For each agent branch, it ran:

```bash
git merge --no-ff wave1-agent-A -m "Merge agent A"
```

Output: `Already up to date`

Same result for all six branches. The Orchestrator saw this and proceeded anyway. It read "Already up to date" as "nothing to merge because the branch matches main" instead of "nothing to merge because the agent never committed to its branch."

Then it found uncommitted changes on main, files the agents had modified but attributed to the wrong branch. The Orchestrator treated these as agent work that needed committing and ran `git commit -m "Wave 1 complete"`, committing changes from six agents in a single merge commit as if that were the expected outcome.

The wave completed. Tests passed. The work was correct. But the merge correctness guarantee was violated. Six agents' work that should have been isolated, verified, and merged branch-by-branch was instead committed as a single undifferentiated blob.

### Why It Happened

The protocol had three defense layers, and all three are cooperative. They depend on the agent or tool behaving correctly:

**Layer 1: `isolation: "worktree"` parameter.** The Agent tool accepts an `isolation` parameter. When set to `"worktree"`, the tool is supposed to ensure the agent runs in the specified worktree directory. This is tool-level isolation: the execution environment enforces it, not the agent.

In this session, the parameter was set correctly. The tool failed silently. No error, no warning, no indication that the isolation request was ignored. The agents launched and ran in the main working tree.

**Layer 2: Field 0 self-verification.** The agent template's Field 0 is a mandatory pre-flight: verify worktree path, run `pwd`, check `git branch`, confirm you're in the expected location. If verification fails, the agent exits without modifying files. If verification passes but the agent is in the wrong place, the agent attempts `cd` to the correct location and re-verifies.

In this session, Field 0 either didn't execute or was ignored. The agents proceeded to implementation without confirming isolation.

**Layer 3: Prompt instructions.** The agent template includes explicit instructions: "You are running in a git worktree. All commits must be made to your assigned branch. Never commit to main." This is cooperative defense: the agent must follow the instruction.

In this session, the agents committed to main.

All three layers failed simultaneously. The result: six agents working in the same directory, committing to the same branch, producing work that looked correct individually but was structurally wrong as a merge.

### Correctness Belongs in Infrastructure

Correctness guarantees belong in infrastructure, not cooperation.

Asking agents to maintain worktree isolation through prompt instructions is like asking programs to manage their own memory safety. The abstraction boundary is wrong. Agents can cooperate when isolation works, but they can't detect when isolation fails. That's not their job.

The three layers (tool parameter, self-verification, prompt instructions) are all either tool-level or agent-level. They run during execution. If the execution environment fails silently (Layer 1 doesn't work, no error emitted), the agent has no signal to detect the failure. Field 0 verification depends on the agent being able to see its own working directory. If the tool launched the agent in the wrong place but didn't surface an error, Field 0 might report success because it's verifying the wrong thing.

The missing piece: a deterministic check at merge time, before any `git merge` runs, that verifies each agent branch has commits.

### Layer 4: Merge-Time Trip Wire

Added to `prompts/saw-merge.md` v0.4.5 and `saw-teams/saw-teams-merge.md` v0.1.3:

```bash
base_commit=$(git rev-parse HEAD)

for each agent:
  branch="wave{N}-agent-{letter}"
  commit_count=$(git rev-list ${base_commit}..${branch} --count)

  if commit_count == 0:
    HARD STOP. Present recovery options to user
```

This runs before any merge. It's deterministic. It doesn't depend on agent cooperation or tool behavior. It runs at the orchestrator level, after agents have completed but before any merge operation touches the working tree.

Empty branch means protocol violation. Full stop. The Orchestrator does not proceed. It does not improvise a recovery path. It presents options to the user and waits for explicit direction.

### Recovery Options

When the trip wire fires, the Orchestrator presents three paths:

**1. Re-run wave (safest).** Discard all work from this wave. Remove worktrees. Inspect main to verify no partial state was committed. Reset to the pre-wave base commit if needed. Re-create worktrees from the clean base. Re-launch all agents. This costs compute time (the entire wave runs again) but restores correctness guarantees. Use this when work correctness is uncertain or when you need a clean merge history.

**2. Investigate.** Check main for uncommitted changes. Check the commit history for unexpected commits during the wave execution window. Attempt manual attribution: use the IMPL doc file ownership table to identify which uncommitted files belong to which agent. Manually create commits on agent branches, replaying the work. Expensive, error-prone, requires deep git knowledge. Use this when the work is known to be correct, re-running is prohibitively expensive, and you're confident you can reconstruct the correct branch structure.

**3. Accept as-is.** Run tests against current main. If passing, commit with a message noting the isolation failure. Bypasses merge correctness guarantees entirely. The wave succeeds but the result isn't structured as N independent agent branches merged cleanly. It's one blob commit. Use this when the work is verified correct, the audit trail is less important than forward progress, and you accept that the merge procedure's guarantees do not apply to this wave.

The Orchestrator is explicitly instructed: "Do not choose a recovery path autonomously."

This is critical. Path 1 costs compute time but restores trust. Path 3 costs trust but preserves the work. That tradeoff is a human decision. The trip wire's job is to make the failure visible and force the decision to be explicit, not let the Orchestrator quietly proceed with an invalid merge.

### The 4-Layer Defense Model

Now encoded in E4 of PROTOCOL.md:

| Layer | Mechanism | Type | Catches |
|-------|-----------|------|---------|
| 1 | Manual worktree pre-creation | Deterministic | Primary isolation |
| 2 | `isolation: "worktree"` parameter | Tool-level | Secondary isolation |
| 3 | Field 0 self-verification | Cooperative | Agent in wrong directory |
| 4 | Merge-time trip wire | Deterministic | All isolation failures |

Belt (manual pre-creation) and suspenders (isolation parameter) and trip wire (merge-time check).

Layers 1 and 2 may both fire. That's fine. Redundant isolation is harmless. If both fail, Layer 3 may catch it. If all three fail, Layer 4 catches it before any incorrect merge.

The trip wire doesn't prevent isolation failures. It detects them. That's the boundary between what agents can do and what infrastructure must enforce. Agents can cooperate to maintain isolation. Infrastructure must detect when cooperation fails.

### Why Worktree Isolation and Disjoint Ownership Are Both Required

A common question: if I1 (disjoint file ownership) prevents merge conflicts, why do we also need worktree isolation?

They protect against different failure modes.

**Disjoint file ownership (I1)** prevents merge conflicts. No two agents in the same wave own the same file, so when you merge N branches, there are no conflicting edits to the same file. The merge step is always conflict-free as long as I1 holds.

**Worktree isolation** prevents execution-time interference. Each agent's `go build`, `go test`, and tool-cache writes operate on an independent working tree. Without worktrees, two agents running `go build ./...` simultaneously on the same directory produce flaky failures that look like code bugs but are actually filesystem races on shared build caches, test caches, lock files, or intermediate object files.

Example: Agent A and Agent B both run `go test ./...` at the same time in the same directory. Go caches test results in `.cache/`. Both agents write to the cache simultaneously. One agent's write partially overwrites the other's. The next test run reads corrupted cache state and fails with a non-deterministic error. The test is correct. The code is correct. The failure is a race.

Disjoint ownership without worktrees: merge is safe, but concurrent execution is flaky. Worktrees without disjoint ownership: execution is clean, but merge produces unresolvable conflicts. Both constraints must hold simultaneously for parallel waves to be correct and reproducible.

{{< callout type="info" >}}
The four-layer defense model was developed iteratively. Layer 1 (manual worktree creation) was present from v0.1.0. Layers 2 and 3 (the `isolation: "worktree"` parameter and Field 0 self-verification) were both added in v0.2.0, driven by a brewprune Round 5 incident where 5 agents were launched but 0 worktrees were created. All agents modified main directly; zero conflicts occurred only due to perfect file disjointness. Layer 4 (trip wire) was added in v0.6.0 after all three cooperative layers failed simultaneously in a 6-agent wave. Each layer catches failures the previous layers missed.
{{< /callout >}}

## Closing: Convergence

The protocol is converging.

Early sessions produced structural changes. New participants (Scout, Wave Agent, now Scaffold Agent). New invariants (I1 through I6). New execution rules (E1 through E14). The shape of the protocol was forming.

Recent sessions produce hardening. Failure modes identified. Recovery paths documented. Defense layers added. The shape isn't changing, just the resilience.

Both stories in this post follow the same pattern: something worked but violated a structural guarantee.

The Scaffold Agent restores a review gate that was cosmetically present but structurally absent. v0.5.0 let you review interface contracts after they were committed. v0.6.0 puts the review before the commit. The mechanics changed. The user-facing workflow looks nearly identical. The difference is enforceability.

The worktree isolation trip wire catches failures that were invisible until merge time. Three layers of cooperative defense failed simultaneously. The merge procedure proceeded with invalid state and produced a structurally incorrect result that happened to work. The trip wire doesn't fix the underlying failure (tool isolation silently failed). It detects it before damage occurs and forces human decision-making.

Neither change fixes a bug in the traditional sense. An agent producing wrong output is a bug. An agent producing correct output while bypassing a structural guarantee is a protocol violation. Bugs break functionality. Protocol violations break trust.

The Scaffold Agent is 174 lines. The trip wire is 15 lines of bash. Small changes. But they're not optimizations or features. They're restorations. v0.6.0 took things that worked and made them trustworthy.

A protocol that works is necessary. A protocol you can trust is the goal.

Scout-and-wave v0.6.0 is at [github.com/blackwell-systems/scout-and-wave](https://github.com/blackwell-systems/scout-and-wave). The Scaffold Agent prompt is at `prompts/scaffold-agent.md`. The trip wire is in `prompts/saw-merge.md` Step 1.5. PROTOCOL.md defines all invariants (I1 through I6) and execution rules (E1 through E14) with their enforcement points.
