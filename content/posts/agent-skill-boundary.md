---
title: "The Agent-Skill Boundary: When Autonomous Behaviors Become Skills"
date: 2026-03-25
draft: false
tags: ["agent-skills", "ai-agents", "skill-design", "progressive-disclosure", "agent-architecture", "claude-code", "hooks", "automation", "orchestration", "context-injection", "token-optimization", "prompt-engineering", "agent-coordination", "deterministic-systems", "lifecycle-hooks", "agentskills-spec", "bash", "yaml", "developer-tools", "software-architecture", "design-patterns"]
categories: ["developer-tools", "architecture"]
description: "How to recognize when an agent's autonomous behaviors should be extracted into skills, hooks, or knowledge trees. A layered model for agent design."
summary: "Agents accumulate autonomous behaviors over time - 'always do X before Y', 'if you see Z then do W'. These instructions eat context budget, drift across invocations, and can't be observed or tested. Here's how to recognize when an autonomous behavior is a skill waiting to be extracted, and the layered model that makes the boundary clear."
---

Every agent prompt grows the same way. You ship it with clear routing logic. Then you add "always check X before running." Then "if you see Y, load Z first." Then "before doing A, make sure B is done." Six months later the prompt is 700 lines of accumulated procedure, and the agent spends half its context budget on instructions that are irrelevant to the current invocation.

The problem is not that the agent has too many capabilities. The problem is that judgment and procedure are mixed together, and every invocation pays the cost of both.

## The Accumulation Pattern

Here is how it happens. An agent starts with a clear job: route user requests to the right action. Then edge cases appear:

```
v1: Route subcommands to the right handler
v2: + "Before running subcommand X, always load reference Y"
v3: + "If the previous run failed, check the failure log first"
v4: + "After completing action Z, run validation W"
v5: + "When launching sub-agents, verify isolation before proceeding"
v6: + "Always check project config before starting any operation"
```

Each addition is reasonable in isolation. Together, they create an agent that is half router, half checklist runner, and bad at both. The routing logic is buried under procedure. The procedure is invisible - there is no way to observe, test, or disable individual behaviors without reading the entire prompt.

{{< mermaid >}}
flowchart TB
    subgraph v1["v1: Clean Router"]
        r1[Parse subcommand] --> r2[Dispatch to handler]
    end

    subgraph v6["v6: Accumulated Behaviors"]
        a1[Check project config] --> a2[Load failure log if needed]
        a2 --> a3[Parse subcommand]
        a3 --> a4[Load reference files]
        a4 --> a5[Verify isolation]
        a5 --> a6[Dispatch to handler]
        a6 --> a7[Run validation]
    end

    style v1 fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style v6 fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

The v6 agent loads every behavior on every invocation. A user who runs a simple status check pays the same context cost as a user who launches a complex multi-agent operation.

## The Extraction Test

Not every behavior should be extracted. The test is: does this behavior require judgment, or is it procedure?

**Procedure** has a fixed trigger and fixed steps. It always runs the same way. It can be described as a numbered list. It does not need to see the rest of the prompt to work correctly.

**Judgment** requires context, interpretation, and decision-making. It depends on what came before and what might come next. It cannot be reduced to a numbered list because the right action changes based on circumstances.

| Signal | Procedure (extract it) | Judgment (keep it) |
|--------|----------------------|-------------------|
| Triggered by a recognizable pattern | + | |
| Same steps every time | + | |
| Could be a script or hook | + | |
| Requires reading runtime state first | | + |
| Different action depending on context | | + |
| Judgment call about whether to act | | + |

{{< callout type="info" >}}
The test applies recursively. Inside a judgment call, there may be procedural steps that can be extracted. Inside a procedure, there may be a judgment call that should stay in the agent.
{{< /callout >}}

As a decision filter:

{{< mermaid >}}
flowchart TB
    start["New behavior to add"] --> q1{"Can a pattern\ntrigger it?"}
    q1 -->|Yes| hook["HOOK\ndeterministic, pre-model"]
    q1 -->|No| q2{"Is it\nnumbered steps?"}
    q2 -->|Yes| skill["SKILL / REFERENCE\nprocedure, on-demand"]
    q2 -->|No| q3{"Does it require\n'it depends'?"}
    q3 -->|Yes| agent["AGENT\njudgment, keep it"]
    q3 -->|No| cut["CUT IT\nprobably redundant"]

    style hook fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style skill fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style agent fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style cut fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style start fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style q1 fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style q2 fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style q3 fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

The fourth outcome - "cut it" - is real. If a behavior is not triggered by a pattern, is not a procedure, and does not require judgment, it is probably restating something that already exists elsewhere in the system.

## The Layered Model

Once you can distinguish procedure from judgment, the architecture becomes clear. There are four layers, and each has a different enforcement model:

{{< mermaid >}}
flowchart TB
    subgraph hooks["Hooks (Deterministic)"]
        h1[Pre-invocation triggers]
        h2[Post-execution validation]
    end

    subgraph agent["Agent (Judgment)"]
        a1[Which action?]
        a2[Is the result correct?]
        a3[How to recover?]
    end

    subgraph skills["Skills (Procedure)"]
        s1[Step-by-step execution]
        s2[Defined inputs and outputs]
    end

    subgraph knowledge["Knowledge (On-Demand)"]
        k1[Reference material]
        k2[Examples and templates]
    end

    hooks --> agent
    agent --> skills
    skills --> knowledge

    style hooks fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style agent fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style skills fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style knowledge fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### Layer 1: Hooks (deterministic, pre-model)

Hooks fire before the model runs. No judgment involved. A hook matches a pattern and injects content, blocks an action, or validates output. The model never decides whether the hook should run.

```bash
# UserPromptSubmit hook: if the prompt contains "/saw program",
# inject references/program-flow.md before the model sees it
triggers:
  - match: "^/saw program"
    inject: references/program-flow.md
```

Hooks handle "always do X when you see Y" behaviors. If a behavior has a recognizable trigger and a fixed response, it is a hook, not an agent instruction.

### Layer 2: Agent (judgment, irreducible)

The agent decides which skill to invoke, whether the result is correct, and how to recover from failure. This is the irreducible core - the part that cannot be a script or hook because it requires interpretation.

Good agent prompts are short. They define the agent's role, the decisions it makes, and the tools it can use. They do not contain step-by-step procedures for every possible action.

```markdown
You are the Orchestrator. You route user requests to the appropriate
skill, verify results, and handle failures.

Decisions you make:
- Is this a new operation or a resume of a previous one?
- Which skill handles this subcommand?
- Did the skill produce a valid result?
- How should failures be recovered?
```

### Layer 3: Skills (procedure, on-demand)

Skills contain the step-by-step logic for a specific operation. They load only when invoked. They have defined inputs and outputs. They can be tested independently.

The [Agent Skills spec](https://agentskills.io) formalizes this with progressive disclosure: metadata loads at startup (~100 tokens), the skill body loads on activation (<5000 tokens), and reference files load on demand (varies). A well-structured skill pays only for what the current invocation needs.

### Layer 4: Knowledge (reference material, loaded by trigger)

Knowledge is the reference material that skills need at specific points. It is not loaded by default. It loads when a trigger matches (via hooks or skill instructions) or when the agent requests it based on runtime state.

The distinction between skills and knowledge: a skill defines what to do. Knowledge provides the information needed to do it. A skill might say "handle the failure according to the routing table." The routing table is knowledge - a reference file loaded on demand.

## A Worked Example

[Scout-and-Wave](https://github.com/blackwell-systems/scout-and-wave) (SAW) is a parallel agent coordination system. Its orchestrator prompt started at 300 lines, grew to 703 lines, and was refactored back to 310 lines by extracting procedure into skills and knowledge.

Here is what each layer handles:

| Layer | SAW Example | Loaded When |
|-------|------------|-------------|
| Hook | `inject_skill_context` loads `program-flow.md` when it sees `/saw program` | Every `/saw program` invocation (deterministic) |
| Agent | Orchestrator decides: new scout, wave resume, or blocked agent retry? | Every invocation (judgment) |
| Skill | Wave loop steps 1-11: prepare worktrees, launch agents, merge, verify | `/saw wave` invocations only |
| Knowledge | `failure-routing.md`: E7a retry, E19 failure types, E20 stub scanning | Only when an agent reports non-complete status |

{{< mermaid >}}
flowchart LR
    subgraph hook_layer["Hook Layer"]
        trigger["UserPromptSubmit hook"]
        trigger -->|"/saw program"| inject["Inject program-flow.md"]
        trigger -->|"/saw amend"| inject2["Inject amend-flow.md"]
        trigger -->|"/saw wave"| nothing["No injection"]
    end

    subgraph agent_layer["Agent Layer"]
        judge["Orchestrator judgment"]
        judge -->|"new feature"| scout["Launch Scout"]
        judge -->|"wave ready"| wave["Execute wave loop"]
        judge -->|"agent failed"| recover["Load failure routing"]
    end

    subgraph skill_layer["Skill Layer"]
        wave_proc["Wave procedure"]
        wave_proc --> prep["Prepare worktrees"]
        prep --> launch["Launch agents"]
        launch --> merge["Merge and verify"]
    end

    subgraph knowledge_layer["Knowledge Layer"]
        failure["failure-routing.md"]
        program["program-flow.md"]
        amend["amend-flow.md"]
    end

    style hook_layer fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style agent_layer fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style skill_layer fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style knowledge_layer fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

Before extraction, the orchestrator prompt contained all of this inline - 703 lines loaded on every invocation. After extraction, the per-invocation cost depends on what the user asked for:

{{< mermaid >}}
flowchart LR
    subgraph before["Before: Every Invocation"]
        b1["703 lines loaded\nregardless of subcommand"]
    end

    subgraph after["After: Pay for What You Use"]
        a1["Agent core\n310 lines"] --> a2["+ matching skill\n0-250 lines"]
        a2 --> a3["+ knowledge\n0-55 lines"]
    end

    subgraph examples["Cost by Subcommand"]
        e1["/saw status\n310 lines"]
        e2["/saw wave\n310 lines"]
        e3["/saw program execute\n560 lines"]
        e4["/saw wave + failure\n365 lines"]
    end

    style before fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style after fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style examples fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

The core prompt is 310 lines of routing and judgment. The remaining 393 lines load only when needed.

### What Was Extracted

**Program commands** (250 lines) became `references/program-flow.md`. These are step-by-step procedures for `/saw program plan`, `/saw program execute`, and `/saw program status`. They have a clear trigger (`^/saw program`) and fixed steps.

**Failure routing** (55 lines) became `references/failure-routing.md`. This is a decision table for handling agent failures: retry logic, failure type classification, post-merge integration. It loads only when an agent reports non-complete status - a runtime condition, not a dispatch-time trigger, so it is loaded by the agent's judgment rather than a hook.

**Amend flow** (38 lines) became `references/amend-flow.md`. Three variants of the amend subcommand, each with orchestrator steps. Clear trigger, fixed procedure.

### What Was Cut

108 lines of content were removed entirely:
- A catalog of CLI commands that were already named at their point of use
- Example JSON configs that duplicated prose explanations
- Example YAML that restated the same information as surrounding text
- Example output blocks that the model generates on its own

These were not skills or knowledge. They were redundant content that inflated the prompt without adding information.

### What Stayed

The core prompt kept: invocation routing, pre-flight validation, the wave execution loop, and bootstrap flow. These are judgment-heavy - they require reading IMPL doc state, deciding which agents to launch, evaluating completion reports, and choosing between retry, escalation, or progression. They cannot be extracted because the right action depends on context.

## Anti-Patterns

### The 700-line prompt

Every possible action described inline. Every reference loaded on every invocation. The agent cannot distinguish what matters for the current request from what exists for other requests.

The fix: extract procedure into skills, knowledge into references, and deterministic routing into hooks. The core prompt should be judgment and routing only.

### Invisible routing

"If the user mentions failure, load the failure handling guide." This instruction competes with hundreds of other instructions for the model's attention. It might be followed. It might not. There is no way to verify it happened without reading the full conversation.

The fix: if the trigger is recognizable at invocation time, use a hook. If it depends on runtime state, make it an explicit skill invocation rather than a buried instruction.

### The "always do X" instruction

"Always check the project configuration before starting." This runs on every invocation regardless of relevance. A status check does not need project configuration. A wave execution does.

The fix: move conditional prerequisites into the skills that need them. The wave skill checks configuration. The status skill does not. The agent prompt does not mention configuration at all.

### Convention-based loading

"When you need reference X, read file Y." The model decides when it "needs" something. This works until it does not - the model skips the reference, loads it too early, or loads everything at once.

The fix: [deterministic progressive disclosure]({{< ref "deterministic-progressive-disclosure" >}}). Hooks load references based on trigger patterns before the model runs. The model receives the reference in context without deciding to load it.

## The Extraction Checklist

When reviewing an agent prompt, look for these signals:

1. **"Always" or "before"** - "Always check X" or "Before doing Y, run Z." If X or Z has a recognizable trigger, extract it to a hook. If it only applies to some operations, move it into those operations' skill definitions.

2. **Numbered steps** - Any sequence of 3+ steps that runs the same way every time is a skill. Extract it to a reference file and load it on demand.

3. **Decision tables** - "If type is A, do X. If type is B, do Y." If the table is looked up by a known key, it is knowledge. Extract it to a reference file.

4. **Example blocks** - Example outputs, example configs, example YAML. If the model generates its own output, it does not need examples of what that output looks like. Cut them.

5. **Duplicate explanations** - Prose that restates what code or config already says. If a field is named `webhook_url` and the prose says "the URL for the webhook," the prose adds no information. Cut it.

6. **Runtime-conditional blocks** - "If the previous run failed, do X." These cannot be hooks (hooks fire before execution). They are either skill logic (if the skill handles failure) or agent judgment (if recovery requires interpretation).

## The Boundary Principle

An agent that is purely a router is a switch statement. You do not need an LLM for that - a hook or a script handles it deterministically. An agent that is purely procedural is a script. You do not need an LLM for that either.

The agent's value is the judgment layer between routing and procedure: understanding intent, evaluating results, adapting to unexpected states, and deciding what to do when the happy path breaks.

{{< callout type="success" >}}
**Design the layers so that:**
- Hooks handle what is deterministic
- Skills handle what is procedural
- Knowledge loads what is needed
- The agent handles what requires judgment
{{< /callout >}}

The agent's prompt should be short because most of what it does is delegate. The total system can be arbitrarily complex - but the complexity lives in skills and knowledge, loaded on demand, not in the agent's core prompt.

{{< mermaid >}}
flowchart TB
    subgraph complexity["Where Complexity Lives"]
        direction TB
        prompt["Agent Prompt: ~300 lines"]
        skills_total["Skills: ~400 lines across 3 files"]
        knowledge_total["Knowledge: ~100 lines across 3 references"]
        hooks_total["Hooks: 11 scripts, deterministic"]
    end

    subgraph cost["Context Cost Per Invocation"]
        direction TB
        always["Always loaded: ~300 lines (agent prompt)"]
        sometimes["Sometimes loaded: 0-250 lines (matching skill)"]
        rarely["Rarely loaded: 0-55 lines (failure knowledge)"]
        never["Never loaded by model: hooks (pre-model)"]
    end

    style complexity fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style cost fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

The total capability is ~800 lines. The per-invocation cost ranges from 300 (simple status check) to 550 (complex wave with failure). Before extraction, it was 703 lines on every invocation regardless of what the user asked for.

Progressive disclosure is a design principle, not a performance optimization. When the agent sees only what is relevant to the current task, it makes better judgments. When procedure is isolated in skills, it can be tested and versioned independently. When routing is deterministic, it can be observed and debugged without reading the model's internal reasoning.

The boundary between agent and skill is the boundary between judgment and procedure. Find it, enforce it, and both sides get better.

## Quick Reference

Bookmark this section. Come back to it when reviewing an agent prompt.

**The four layers:**

| Layer | Handles | Enforcement | Loaded |
|-------|---------|-------------|--------|
| Hooks | Deterministic routing | Infrastructure (pre-model) | Never by model |
| Agent | Judgment and decisions | Prompt (irreducible) | Always |
| Skills | Step-by-step procedure | On-demand (skill activation) | When matched |
| Knowledge | Reference material | On-demand (trigger or request) | When needed |

**The decision filter:**
1. Can a pattern trigger it? - Make it a **hook**
2. Is it numbered steps? - Make it a **skill** or **reference**
3. Does it require "it depends"? - Keep it in the **agent**
4. None of the above? - **Cut it**

**The extraction checklist:**
- "Always" or "before" instructions - hook or move into skill
- Numbered step sequences (3+) - reference file
- Decision tables - knowledge reference
- Example outputs - cut (model generates its own)
- Duplicate prose - cut
- Runtime-conditional blocks - skill logic or agent judgment

**The test:** If you can write it as a numbered list, it belongs in a skill. If it requires "it depends," it belongs in the agent.
