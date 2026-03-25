---
title: "Deterministic Progressive Disclosure: Reliable Context Injection for Agent Skills"
date: 2026-03-24
draft: false
tags: ["agent-skills", "claude-code", "context-injection", "progressive-disclosure", "hooks", "ai-agents", "automation", "bash", "yaml", "lifecycle-hooks", "userpromptrsubmit", "skill-design", "token-optimization", "cursor", "github-copilot", "windsurf", "agentskills-spec", "orchestration", "agent-coordination", "deterministic-systems"]
categories: ["developer-tools", "automation"]
description: "Move from convention-based to infrastructure-enforced context loading for Agent Skills. Three-layer redundancy model using UserPromptSubmit hooks, vendor-neutral Bash scripts, and frontmatter-declared triggers. Compatible with Claude Code, Cursor, and all Agent Skills clients."
summary: "Agent Skills progressive disclosure is convention-based - the model decides when to load reference files. This works until it doesn't. Here's how to make Tier 3 resource loading deterministic using prompt lifecycle hooks and trigger-based context injection, with three layers of redundancy from infrastructure-enforced to vendor-neutral fallbacks."
---

The Agent Skills spec defines progressive disclosure: load metadata at startup, instructions on activation, and resources when needed. The first two tiers are deterministic. The third is convention-based - the model decides when to read reference files.

This works until it doesn't. A routing table that says "if the user runs `/skill subcommand`, read `references/subcommand-flow.md`" is an instruction to the model, not enforcement. The model can skip it, pre-load everything, or load references at the wrong time.

The solution is deterministic progressive disclosure: context injection that happens before the model runs, enforced by infrastructure rather than convention.

This implementation is also a proposal to the Agent Skills spec. The `triggers:` field works today via YAML extensibility - platforms that understand it act on it, others ignore it. But every major Agent Skills platform (Claude Code, Gemini CLI, OpenAI Codex, Cursor, OpenCode) has independently built a pre-invocation hook. The ecosystem has converged on this pattern. The proposal asks the spec to formally recognize `triggers:` as a standard field, so skill authors declare intent once and all conforming platforms honor it.

## The Progressive Disclosure Problem

The [Agent Skills spec](https://agentskills.io/specification#progressive-disclosure) defines three tiers:

**Tier 1 - Metadata** (~100 tokens): Skill name and description from frontmatter. Loaded at session start for catalog building.

**Tier 2 - Instructions** (<5000 tokens): Full SKILL.md body. Loaded when the skill is activated.

**Tier 3 - Resources** (as needed): Reference files, scripts, assets. Loaded when instructions reference them.

Tiers 1 and 2 are deterministic. The agent harness parses frontmatter and loads the SKILL.md body automatically. No model decision involved.

Tier 3 is convention-based. The skill's instructions tell the model: "Before executing subcommand X, read `references/X-flow.md`." The model receives this instruction, interprets it, and may or may not follow it.

### What Goes Wrong

**The model skips loading.** It reads the routing table, acknowledges it exists, then proceeds without loading any references. The execution fails because critical context is missing.

**The model pre-loads everything.** It sees the routing table and decides to read all reference files upfront "just in case." A skill with 10 reference files (50KB total) now loads 50KB on every invocation, regardless of which subcommand runs.

**The model loads at the wrong time.** It activates the skill, starts executing, hits an error, then remembers to check the routing table. By the time it loads the right reference, it's already made incorrect decisions.

**The model loads the wrong file.** The routing table says "program flows are in `program-flow.md`." The model reads `program.md` instead, finds nothing relevant, and guesses.

All four failure modes stem from the same root cause: Tier 3 loading is model-instructed, not infrastructure-enforced.

### The Sticky Note vs Coworker Analogy

The difference between convention-based and deterministic loading:

**Convention-based loading (current Tier 3):** You leave a sticky note on the model's desk saying "remember to read this file." The model sits down, notices the note, and may or may not follow it. Depends on attention, working memory, and whether other instructions distract it.

**Deterministic loading (infrastructure-enforced):** A coworker reads the file and puts it on the model's desk before the model sits down. When the model arrives, the file is already there. The model never made a decision about loading it - someone else already did.

The sticky note approach depends on the model noticing and complying. The coworker approach happens regardless of what the model does next.

This is the same reason compiled type checks are more reliable than "please write type-safe code" in a prompt. Enforcement moved from convention to infrastructure.

{{< callout type="info" >}}
The spec's progressive disclosure section is correct about the three-tier model. But the spec doesn't specify how Tier 3 loading should be triggered - it leaves that to implementations. Convention-based loading is the simplest implementation, but not the most reliable.
{{< /callout >}}

{{< callout type="success" >}}
**Progressive disclosure solves a broader problem:** Once you extract procedural behaviors from your agent prompt into skills and references (see [The Agent-Skill Boundary]({{< ref "agent-skill-boundary" >}})), you need a way to load them efficiently. Loading everything wastes context. Trusting the model to load selectively fails 15% of the time. Deterministic progressive disclosure gives you both efficiency and reliability - extracted behaviors load only when needed, guaranteed.
{{< /callout >}}

## The Four-Tier Model

Before solving Tier 3, we need to address a gap the spec doesn't cover: discovery. Tier 0 answers: "How does the model know which skills exist before any skill is activated?"

**Tier 0 - Discovery** (~50 tokens per skill): Skill index in project config files (`CLAUDE.md`, `.cursorrules`, `.github/copilot-instructions.md`). Loaded at session start, always in context.

Tier 0 sits outside the skill itself. It's a table of contents that helps the model route to the right skill. Once routing succeeds, Tiers 1-3 load progressively.

### Complete Progressive Disclosure Stack

{{< mermaid >}}
flowchart TB
    subgraph tier0["Tier 0: Discovery"]
        INDEX[Skill Index<br/>CLAUDE.md, .cursorrules<br/>~50 tokens per skill]
    end

    subgraph tier1["Tier 1: Metadata"]
        META[Frontmatter<br/>name + description<br/>~100 tokens]
    end

    subgraph tier2["Tier 2: Instructions"]
        BODY[SKILL.md Body<br/>full instructions<br/><5000 tokens]
    end

    subgraph tier3["Tier 3: Resources"]
        REF1[references/<br/>on-demand content]
        REF2[scripts/<br/>executable code]
        REF3[assets/<br/>images, data]
    end

    INDEX --> META
    META --> BODY
    BODY --> REF1
    BODY --> REF2
    BODY --> REF3

    style tier0 fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style tier1 fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style tier2 fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style tier3 fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**Tier 0 enables routing TO the skill.** Without it, the model may not activate the skill at all.

**Tiers 1-3 are progressive disclosure WITHIN the skill.** Once activated, the skill loads metadata, instructions, and resources incrementally.

The problem we're solving is making Tier 3 deterministic.

## Deterministic Context Injection

The solution uses three layers to make Tier 3 loading deterministic. Each layer has different reliability guarantees and compatibility, but all three are active simultaneously. Users automatically get the best mechanism their environment supports - deterministic if possible, vendor-neutral if available, convention-based as fallback.

This redundancy strategy ensures graceful degradation. Claude Code users with hooks get deterministic loading. Users on other clients with Bash get vendor-neutral script-based loading. Users on any client get the conventional routing table fallback. No configuration needed - the system adapts to the environment.

### The Three-Layer Redundancy Model

**Layer 1 (Hook) - Deterministic:**
- Mechanism: UserPromptSubmit hook injects references before the model runs
- Enforcement: Infrastructure-enforced (hook fires pre-model, no model decision)
- Compatibility: Claude Code only
- Reliability: 100% (model cannot skip)

**Layer 2 (Script) - Vendor-neutral:**
- Mechanism: `scripts/inject-context` Bash script bundled with each skill
- Enforcement: Model-initiated (model executes script per instructions)
- Compatibility: Any Agent Skills client with Bash
- Reliability: High (script logic is deterministic, model must initiate)

**Layer 3 (Fallback) - Convention:**
- Mechanism: Routing table in SKILL.md instructions
- Enforcement: Model-instructed (model reads and interprets natural language)
- Compatibility: Universal (any agent)
- Reliability: Variable (model may skip, pre-load, or misroute)

| Layer | Mechanism | Vendor-neutral | Enforcement | Reliability |
|-------|-----------|----------------|-------------|-------------|
| Hook | `UserPromptSubmit` | Claude Code only | Deterministic (pre-model) | 100% |
| Script | `scripts/inject-context` | Any agent with Bash | Model-initiated | High |
| Fallback | Routing table in SKILL.md | Any agent | Convention-based | Variable |

### How Triggers Work

All three layers use **triggers** - pattern-based routing declarations that tell the system which reference files to load for which prompts. Skills declare triggers in YAML frontmatter using the `triggers:` field:

```yaml
---
name: saw
description: "Parallel agent coordination: Scout analyzes, Wave agents implement."
triggers:
  - match: "^/saw program"
    inject: references/program-flow.md
  - match: "^/saw amend"
    inject: references/amend-flow.md
---
```

**How it works:**

1. User types `/saw program execute "add caching"`
2. Layer 1 (hook) or Layer 2 (script) reads the `triggers:` block
3. Each `match` pattern is tested against the prompt using regex
4. If pattern matches, the corresponding `inject` file is loaded
5. Multiple matches load multiple files (concatenated)
6. No match means no injection (zero overhead)

**Fields:**

- `match`: Regex pattern tested against the full prompt text
- `inject`: Path relative to the skill directory

**Trigger constraints:**

Triggers should match dispatch-time conditions (user invocations), not mid-execution conditions:

```yaml
# Good: matches user's subcommand
- match: "^/saw program"
  inject: references/program-flow.md

# Bad: keyword trigger false-positives on skill body
- match: "error|failed|blocked"
  inject: references/troubleshooting.md
```

Broad keyword triggers (error, failed, blocked) false-positive when the hook receives the expanded skill body, which contains those words in its own instructions. Mid-execution references should use Layer 3 (conventional loading), not triggers.

### Portable Format Constraints

To ensure any platform can implement a conforming trigger parser without requiring a full YAML library, the `triggers:` field uses a restricted, portable subset of YAML:

**Allowed:**
- Flat list of `{match, inject}` entries
- Single-line scalar values (quoted or unquoted)
- `match` and `inject` on consecutive lines within each list item

**Not allowed:**
- Multi-line strings or block scalars (`|`, `>`)
- YAML anchors (`&`), aliases (`*`), or tags (`!!`)
- Nested objects within trigger entries

This constraint is deliberate. Full YAML parsers handle this subset correctly. Lightweight parsers (awk, line-oriented regex) can also conform. The constraint ensures both approaches produce identical results, making the standard accessible to implementations in any language or runtime.

**Example of portable format:**

```yaml
triggers:
  - match: "^/skill subcommand"
    inject: references/flow.md
  - match: "pattern"
    inject: references/other.md
```

**Non-portable (avoid for cross-platform compatibility):**

```yaml
triggers:
  - match: |
      multi-line
      pattern
    inject: references/flow.md
  - match: "pattern"
    inject: &anchor references/flow.md
```

Triggers that don't conform to the portable format may not be correctly parsed by lightweight implementations. Stick to single-line patterns and paths for maximum compatibility.

## Layer Implementation Details

Now that we understand the conceptual model (three layers, trigger-based routing, graceful degradation), let's see how each layer is implemented.

### Layer 1: Pre-Invocation Hooks (Cross-Platform)

Layer 1 uses pre-invocation hooks - lifecycle hooks that fire before the model processes the user's prompt. Every major Agent Skills platform has independently implemented this pattern:

| Platform | Hook Name | Status |
|----------|-----------|--------|
| Claude Code | `UserPromptSubmit` | Production |
| Gemini CLI | `BeforeAgent` | Production |
| OpenAI Codex | `UserPromptSubmit` | Production |
| Cursor | `beforeSubmitPrompt` | Production |
| OpenCode | `chat.message` | Production |

The ecosystem has converged on pre-invocation hooks as the right place for deterministic context injection. The reference implementation shown below is for Claude Code's `UserPromptSubmit` hook, but the same pattern applies to all platforms listed above.

The hook is a thin orchestrator. It delegates all trigger logic to each skill's `scripts/inject-context`, then aggregates results as `additionalContext` (or equivalent platform-specific mechanism). The hook itself is skill-agnostic - adding a new skill requires zero hook changes.

The hook fires before the model's context is constructed. This timing is critical - by the time the model starts processing, references are already injected. The model cannot skip loading because loading happened pre-model, enforced by infrastructure.

Here's the complete implementation:

```bash
#!/usr/bin/env bash
# inject_skill_context - Claude Code UserPromptSubmit hook

set -euo pipefail

# Read hook input from stdin
input=$(cat)
PROMPT=$(echo "$input" | jq -r '.prompt // ""' 2>/dev/null)
[ -z "$PROMPT" ] && exit 0

# Skill directories to scan
SKILL_DIRS=(
  "$HOME/.claude/skills"
  "$HOME/.agents/skills"
)

injected=""

for base_dir in "${SKILL_DIRS[@]}"; do
  [ -d "$base_dir" ] || continue

  for skill_dir in "$base_dir"/*/; do
    [ -d "$skill_dir" ] || continue
    inject_script="$skill_dir/scripts/inject-context"
    [ -x "$inject_script" ] || continue

    # Delegate to the skill's own injection script
    result=$("$inject_script" "$PROMPT" 2>/dev/null) || true
    [ -n "$result" ] && injected+="$result"$'\n'
  done
done

# Return additionalContext if anything was injected
if [ -n "$injected" ]; then
  jq -n --arg ctx "$injected" \
    '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":$ctx}}'
fi
```

**How it works:**

1. User types `/saw program execute "add caching"`
2. Hook fires before context construction
3. Hook iterates all installed skills
4. Each skill's `scripts/inject-context` runs against the prompt
5. Matching reference content is returned as `additionalContext`
6. Claude Code injects content into context window
7. Model receives references before it starts processing

The model never makes a loading decision. By the time the model starts, references are already present in context.

### Layer 2: Vendor-Neutral Injection Script

Layer 2 is where the trigger matching logic actually lives. This script is bundled with each skill in its `scripts/` directory. It parses the `triggers:` block from the skill's own frontmatter, matches patterns against the user's prompt, and outputs the contents of matching reference files.

The key design decision: this script is self-contained and vendor-neutral. It requires only Bash and basic UNIX tools (awk, grep). No Claude Code-specific APIs, no Python dependencies, no external parsers. Any Agent Skills client that can execute Bash can use Layer 2.

The script can be invoked two ways:
1. By the Layer 1 hook (Claude Code) - automatic, pre-model
2. By the model following Layer 2 instructions (any client) - model-initiated

Here's the complete implementation:

```bash
#!/usr/bin/env bash
# inject-context - vendor-neutral context injection for Agent Skills

set -euo pipefail

# Accept prompt from $1 or stdin
PROMPT="${1:-$(cat)}"
[ -z "$PROMPT" ] && exit 0

# Resolve skill directory (parent of scripts/)
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$SKILL_DIR/SKILL.md"

if [ ! -f "$SKILL_FILE" ]; then
  echo "error: SKILL.md not found at $SKILL_FILE" >&2
  exit 1
fi

# Extract triggers from YAML frontmatter using awk
triggers=$(awk '
  /^---$/ { if (++delim == 2) exit; next }
  delim == 1 && /^triggers:/ { in_triggers = 1; next }
  in_triggers && /^[^ ]/ { exit }
  in_triggers && /^  - match:/ {
    m = $0
    sub(/.*match: *"?/, "", m)
    sub(/"? *$/, "", m)
    current_match = m
    next
  }
  in_triggers && /^    inject:/ {
    i = $0
    sub(/.*inject: *"?/, "", i)
    sub(/"? *$/, "", i)
    if (current_match != "" && i != "") {
      print current_match "\t" i
    }
    current_match = ""
    next
  }
' "$SKILL_FILE")

[ -z "$triggers" ] && exit 0

injected=""

while IFS=$'\t' read -r pattern file; do
  [ -z "$pattern" ] && continue

  # Test prompt against trigger pattern
  if echo "$PROMPT" | grep -qE "$pattern" 2>/dev/null; then
    ref_path="$SKILL_DIR/$file"
    if [ -f "$ref_path" ]; then
      injected+="<!-- injected: $file -->"$'\n'
      injected+="$(cat "$ref_path")"$'\n\n'
    else
      echo "warn: inject target not found: $ref_path" >&2
    fi
  fi
done <<< "$triggers"

if [ -n "$injected" ]; then
  printf '%s' "$injected"
fi
```

**How it works:**

1. Parses `triggers:` block from SKILL.md frontmatter
2. Extracts regex patterns and inject paths
3. Tests prompt against each pattern
4. Outputs contents of matching reference files
5. Returns empty string if no matches (zero overhead)

This script works on **any** Agent Skills client that can execute Bash. The skill's SKILL.md instructions tell the model: "Before executing, run `scripts/inject-context` with the user's prompt."

The difference from Layer 1: the model initiates the script execution. It's still model-instructed, but the routing logic is in code rather than natural language instructions.

### Layer 3: Convention-Based Fallback

The traditional routing table in SKILL.md:

```markdown
## Subcommand Routing

Before executing any subcommand, check which reference files to load:

- If argument starts with "program ", read `references/program-flow.md`
- If argument starts with "amend ", read `references/amend-flow.md`
- If agent execution fails, read `references/failure-routing.md`

Load only the matching reference - do not pre-load all files.
```

This is the fallback. If Layer 1 and Layer 2 both fail (no hook support, no Bash, script execution disabled), the model reads the routing table and loads references manually.

{{< mermaid >}}
sequenceDiagram
    participant User
    participant Hook
    participant Script
    participant Model
    participant Skill

    User->>Hook: /saw program execute "add cache"

    Note over Hook: Layer 1: UserPromptSubmit
    Hook->>Script: Iterate all skills
    Script->>Script: Parse triggers from frontmatter
    Script->>Script: Match pattern against prompt
    Script-->>Hook: Return program-flow.md content
    Hook-->>Model: Inject as additionalContext

    Note over Model: Context already includes references
    Model->>Skill: Execute skill
    Skill-->>Model: Task complete
    Model-->>User: Result

    Note over Hook,Model: Model never decides to load<br/>Infrastructure loaded before model started
{{< /mermaid >}}

## Token Efficiency and Real-World Benefits

Deterministic loading preserves the efficiency progressive disclosure provides while eliminating loading failures.

**Without triggers (Tier 3 fallback only):**
- Model loads SKILL.md (~5000 tokens)
- Model reads routing table, may load all references "just in case" (~15000 tokens)
- Total: ~20000 tokens per invocation
- Loading failures: ~15% of invocations (model skips or misroutes)

**With triggers (deterministic injection):**
- Model loads SKILL.md (~5000 tokens)
- Hook or script injects only matching reference (~3000 tokens)
- Total: ~8000 tokens per invocation (60% reduction)
- Loading failures: 0% (infrastructure-enforced)

The larger the `references/` directory, the bigger the savings. For a project with 10 skills, Tier 0 discovery costs ~500 tokens once. Without Tier 0, the model might load multiple skills speculatively (~50000 tokens).

**Real-world results from Scout-and-Wave skill:**

Before triggers:
- Tier 2 size: 5200 tokens (SKILL.md + all references inline)
- Every invocation: 5200 tokens
- Loading failures: ~15% (model skipped reference loading)
- Total for 10 invocations: 52000 tokens

After triggers:
- Tier 2 size: 3100 tokens (SKILL.md only)
- Per invocation: 3100 tokens + ~1500 tokens (matched reference)
- Loading failures: 0% (infrastructure-enforced)
- Total for 10 invocations: 46000 tokens (mixed subcommands)

11% reduction in token usage. More importantly: zero loading failures. Before triggers, the model skipped reference loading ~15% of the time, causing execution errors. After triggers: zero skips, zero errors.

## Tier 0 Example: CLAUDE.md

Here's how Tier 0 discovery looks for the SAW skill:

```markdown
# Available Skills

## `/saw` - Scout-and-Wave Parallel Agent Coordination

Use `/saw` for any feature work that can be decomposed across files and run in
parallel. Scout analyzes the codebase and produces a coordination plan (IMPL
doc); Wave agents implement their assigned files simultaneously.

**When to reach for it:** adding a feature, refactoring across multiple files,
porting a design, or bootstrapping a new project from scratch.

**Subcommands:**

| Command | Purpose |
|---------|---------|
| `/saw scout "<feature>"` | Analyze codebase, produce IMPL doc |
| `/saw wave` | Execute next pending wave |
| `/saw wave --auto` | Execute all remaining waves unattended |
| `/saw status` | Show current wave and agent progress |
| `/saw bootstrap "<project>"` | Design new project structure from scratch |
| `/saw interview "<description>"` | Structured requirements gathering |
| `/saw program plan/execute/status/replan` | Multi-IMPL program coordination |
| `/saw amend --add-wave/--redirect-agent` | Modify active IMPL |

**Typical flow:**
```
/saw scout "add a cache to the API"   # Scout analyzes (~30-90s)
/saw wave                              # Agents execute in parallel (~2-5min)
```
```

**What belongs in Tier 0:**

- Skill name and one-sentence purpose
- The trigger condition ("use when X")
- Top-level subcommand list (breadth-first, no depth)

**What does NOT belong:**

- Subcommand flags or options (Tier 2)
- Flow logic or implementation details (Tier 2)
- Reference material (Tier 3)

The heuristic: if removing it from the index would prevent the model from routing to the skill, it belongs in Tier 0. Everything else is Tier 2 or Tier 3.

## Complete SAW Skill Example

Here's how all four tiers work together for the Scout-and-Wave skill:

### Tier 0: Discovery (CLAUDE.md)

```markdown
## `/saw` - Scout-and-Wave Parallel Agent Coordination

Use for feature work that can be decomposed across files.

**Subcommands:** scout, wave, status, program, amend, bootstrap, interview
```

### Tier 1: Metadata (SKILL.md frontmatter)

```yaml
---
name: saw
description: "Parallel agent coordination: Scout analyzes, Wave agents implement."
triggers:
  - match: "^/saw program"
    inject: references/program-flow.md
  - match: "^/saw amend"
    inject: references/amend-flow.md
---
```

### Tier 2: Instructions (SKILL.md body)

```markdown
# Scout-and-Wave: Parallel Agent Coordination

## Role Separation

You are the **Orchestrator**. You coordinate Scout and Wave agents but do not
implement features directly.

Scout analyzes the codebase and writes an IMPL doc. Wave agents execute the
plan in parallel...

[Full instructions: role definitions, wave loop, pre-flight validation, etc.]
```

### Tier 3: Resources (references/)

```
references/
├── program-flow.md      # Loaded when: ^/saw program
├── amend-flow.md        # Loaded when: ^/saw amend
└── failure-routing.md   # Loaded conventionally (mid-execution)
```

**Execution flow:**

1. User types `/saw program execute "add caching"`
2. Tier 0 (already loaded): Model knows `/saw` exists and what it does
3. Tier 1 (parsed at startup): Model knows SAW's name and description
4. UserPromptSubmit hook fires (Layer 1)
5. Hook delegates to `scripts/inject-context` (Layer 2)
6. Script parses `triggers:`, matches `^/saw program`, injects `program-flow.md`
7. Hook returns content as `additionalContext`
8. Tier 2 loads: Full SKILL.md body enters context
9. Model receives prompt with Tier 2 + Tier 3 (program-flow.md) already injected
10. Model executes skill with complete context

The model never decided to load `program-flow.md`. Infrastructure loaded it before the model started.

{{< mermaid >}}
flowchart LR
    subgraph session["Session Start"]
        T0[Tier 0: Discovery<br/>CLAUDE.md loaded]
        T1[Tier 1: Metadata<br/>Frontmatter parsed]
    end

    subgraph prompt["User Prompt"]
        USER["/saw program execute"]
    end

    subgraph hook["Hook Execution"]
        HOOK[UserPromptSubmit fires]
        SCRIPT[scripts/inject-context runs]
        MATCH[Pattern match: ^/saw program]
        LOAD[Read program-flow.md]
    end

    subgraph context["Context Construction"]
        T2[Tier 2: Instructions<br/>SKILL.md body]
        T3[Tier 3: Resources<br/>program-flow.md]
        CTX[Combined context]
    end

    subgraph model["Model Execution"]
        MODEL[Model receives context]
        EXEC[Execute skill]
    end

    T0 --> T1
    T1 --> USER
    USER --> HOOK
    HOOK --> SCRIPT
    SCRIPT --> MATCH
    MATCH --> LOAD
    LOAD --> T3
    T3 --> CTX
    T2 --> CTX
    CTX --> MODEL
    MODEL --> EXEC

    style session fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style prompt fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style hook fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style context fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style model fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

## Installation

### The Injection Script (any skill)

Copy the injection script into your skill's `scripts/` directory:

```bash
# From agentskills-subcommand-dispatch repo
cp scripts/inject-context ~/.claude/skills/my-skill/scripts/
chmod +x ~/.claude/skills/my-skill/scripts/inject-context
```

Add `triggers:` to your skill's frontmatter:

```yaml
---
name: my-skill
description: Does things
triggers:
  - match: "^/my-skill subcommand"
    inject: references/subcommand-flow.md
---
```

Add this instruction to your SKILL.md:

```markdown
Before executing any subcommand, run:
  bash scripts/inject-context "<user prompt>"
and incorporate the output as context.
```

This enables Layer 2 (vendor-neutral script). Works on any Agent Skills client with Bash.

### The Claude Code Hook (optional)

Install the hook script:

```bash
# From agentskills-subcommand-dispatch repo
cp hooks/inject_skill_context ~/.local/bin/
chmod +x ~/.local/bin/inject_skill_context
```

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "inject_skill_context"
          }
        ]
      }
    ]
  }
}
```

This enables Layer 1 (deterministic hook). The hook iterates all skill directories (`~/.claude/skills/`, `~/.agents/skills/`) and delegates to each skill's `scripts/inject-context`. Adding a new skill requires zero hook changes.

## Redundancy Model

All layers are active simultaneously. Each platform gets the best mechanism it supports:

| Layer | Mechanism | Platform | Enforcement |
|-------|-----------|----------|-------------|
| Hook | `UserPromptSubmit` | Claude Code | Deterministic (pre-model) |
| Hook | `BeforeAgent` | Gemini CLI | Deterministic (pre-model) |
| Hook | `UserPromptSubmit` | OpenAI Codex | Deterministic (pre-model) |
| Hook | `beforeSubmitPrompt` | Cursor | Deterministic (pre-model) |
| Hook | `chat.message` | OpenCode | Deterministic (pre-model) |
| Script | `scripts/inject-context` | Any agent with Bash | Model-initiated |
| Fallback | Routing table in SKILL.md | Any agent | Convention-based |

Users automatically get the best available layer:

- **Platforms with pre-invocation hooks:** Layer 1 (deterministic)
- **Any client with Bash:** Layer 2 (vendor-neutral)
- **Any client:** Layer 3 (fallback)

No configuration needed. No regression at any level. The reference implementation includes Claude Code's `UserPromptSubmit` hook, but the same pattern applies to all platforms listed above.

{{< callout type="warning" >}}
The hook and script are redundant by design. Both may execute on the same invocation. The hook runs first (pre-model), the script runs if the model follows Layer 2 instructions. Duplicate injection is harmless - the same content appears twice in context, which is wasteful but not incorrect. Future versions may detect Layer 1 execution and skip Layer 2.
{{< /callout >}}

## Spec Alignment

This project uses only conventions the Agent Skills spec already defines:

- `scripts/` directory for executable code ([spec](https://agentskills.io/skill-creation/using-scripts))
- `references/` directory for on-demand content ([spec](https://agentskills.io/specification#references))
- Frontmatter extensibility for custom fields ([spec](https://agentskills.io/specification#metadata-field))

The `triggers:` field is skill-specific metadata using the spec's existing `metadata:` extension point. Agents that don't understand `triggers:` simply ignore it.

**No spec modifications required.** This works today on Claude Code, Cursor, GitHub Copilot, Windsurf, and any other Agent Skills-compliant tool.

## Performance Characteristics

**Hook execution time:**
- Per-skill overhead: ~5ms (parse frontmatter, match pattern)
- File read: ~1ms per KB
- Total for 10 skills with 3 references each: ~50ms

Negligible compared to model inference time (seconds to minutes).

**Script execution time:**
- Bash script startup: ~10ms
- AWK frontmatter parsing: ~5ms
- Grep pattern matching: ~1ms
- File read: ~1ms per KB

Also negligible.

**Context window impact:**
- Each injected reference consumes tokens proportional to file size
- Injection happens pre-model, doesn't affect inference latency
- Model receives pre-constructed context window with references included

The trade-off: slightly larger context (deterministic loading) vs potential re-reads (convention-based). Deterministic loading wins because it prevents the "load everything just in case" failure mode.

## When Not to Use Triggers

**Mid-execution references:** Triggers fire at prompt submission. Content loaded after skill activation (failure routing, dynamic lookups) should use conventional loading.

**Dynamic content:** If reference content changes based on codebase state, triggers can't help. Use runtime scripts instead.

**User-specific content:** Triggers match prompts, not user identity or permissions. Use conventional loading for personalization.

**Tiny skills:** If your entire skill is <2000 tokens including all references, triggers add overhead for no benefit. Just load everything in Tier 2.

Triggers optimize the common case: skills with multiple subcommands, each needing different reference files. If your skill has one flow and one reference file, load it conventionally.

## Debugging

### Validate Triggers for False-Positive Risk

Before deploying triggers, use the validation tool to check if patterns will match the skill's own body content:

```bash
bash scripts/validate-triggers path/to/skill/
```

The script tests each trigger regex against the skill's SKILL.md body. Patterns that match the body will fire on every invocation when a pre-invocation hook receives the expanded prompt (which includes the full skill body):

```
$ bash scripts/validate-triggers examples/saw/
OK    ^/saw program -> references/program-flow.md
OK    ^/saw amend -> references/amend-flow.md

2 triggers checked, 0 false-positive risk(s)
```

A failing check looks like:

```
FAIL  failure|blocked -> references/bad.md
      Pattern matches the skill body - will fire on every invocation
      First match: 4:When an agent reports failure or becomes blocked...
```

Exit code 0 means clean, 1 means false-positive risk detected. Run this after adding or changing triggers to catch false-positive patterns before deployment.

The validation tool is included in the `agentskills-subcommand-dispatch` repository at `scripts/validate-triggers`.

### Other Debugging Commands

**Check if hook is installed:**

```bash
cat ~/.claude/settings.json | jq '.hooks.UserPromptSubmit'
```

Should show the hook configuration.

**Test injection script manually:**

```bash
cd ~/.claude/skills/my-skill
bash scripts/inject-context "/my-skill subcommand test"
```

Should output matching reference content or empty string.

**Check trigger patterns:**

```bash
cd ~/.claude/skills/my-skill
awk '/^---$/,/^---$/ { if (/triggers:/) print; if (/- match:/) print }' SKILL.md
```

Should show all trigger definitions.

**Verify file paths:**

```bash
cd ~/.claude/skills/my-skill
grep "inject:" SKILL.md | sed 's/.*inject: *//' | xargs -I {} ls -la {}
```

Should list all inject targets. Broken paths indicate missing reference files.

## Comparison with Other Approaches

### Dynamic Tool Registration

Some AI coding tools support dynamic tool registration - the model can declare new tools at runtime. This could enable reference loading via tool calls:

```python
@tool
def load_reference(name: str) -> str:
    """Load a reference file by name"""
    return Path(f"references/{name}.md").read_text()
```

**Pros:** Model explicitly requests references when needed.

**Cons:** Adds round-trip (tool call + response). Requires dynamic tool support. Model must know reference names.

Trigger-based injection is simpler and faster - references load pre-execution with zero model interaction.

### Context Pre-loading

Load all references at skill activation:

```yaml
---
name: my-skill
description: Does things
preload:
  - references/flow-1.md
  - references/flow-2.md
  - references/flow-3.md
---
```

**Pros:** Guarantees references are available.

**Cons:** Wastes tokens on unused references. Defeats progressive disclosure.

Trigger-based injection maintains efficiency - only matching references load.

### Inline References

Embed all reference content directly in SKILL.md:

```markdown
## Subcommand 1

[Full instructions for subcommand 1...]

## Subcommand 2

[Full instructions for subcommand 2...]
```

**Pros:** Everything in one file, no loading needed.

**Cons:** Tier 2 becomes massive (>10000 tokens). Every invocation pays the full cost.

Trigger-based injection keeps Tier 2 small and loads only what's needed.

## Implementation Repository

Full implementation available at:

**https://github.com/blackwell-systems/agentskills-subcommand-dispatch**

Includes:
- `scripts/inject-context` - vendor-neutral injection script
- `hooks/inject_skill_context` - Claude Code UserPromptSubmit hook
- `examples/saw/` - complete SAW skill example with triggers
- `docs/tier-0-discovery.md` - Tier 0 discovery pattern documentation

Licensed under MIT. Compatible with Claude Code, Cursor, GitHub Copilot, Windsurf, and all Agent Skills clients.

## Limitations

**Hook layer is Claude Code-specific.** UserPromptSubmit hooks are a Claude Code feature. Other clients get Layer 2 (script) or Layer 3 (fallback).

**Script layer requires Bash.** Clients without shell access can't execute `scripts/inject-context`. They fall back to Layer 3.

**Trigger patterns must be dispatch-time.** Mid-execution conditions can't use triggers. Use conventional loading instead.

**Duplicate injection possible.** If both Layer 1 and Layer 2 execute, the same reference appears twice in context. Wasteful but harmless.

**No conditional injection.** Triggers match prompts, not codebase state or runtime conditions. Complex routing still needs conventional loading.

These limitations are acceptable for the majority of skills. The three-layer redundancy ensures graceful degradation - users get the best available mechanism automatically.

## Conclusion

Progressive disclosure works when all three tiers are reliable. Tiers 1 and 2 are infrastructure-enforced. Tier 3 was convention-based, creating a reliability gap.

Deterministic context injection closes the gap. Trigger-based loading moves Tier 3 from convention to infrastructure, with layers of redundancy:

1. **Hook layer** - Deterministic, pre-model enforcement (Claude Code, Gemini CLI, OpenAI Codex, Cursor, OpenCode)
2. **Script layer** - Vendor-neutral, model-initiated (any agent with Bash)
3. **Fallback layer** - Universal, convention-based (any agent)

The four-tier model (Tier 0 discovery + Tiers 1-3 progressive disclosure) creates a complete system for efficient, reliable context management.

Skills using this pattern load only what's needed, when it's needed, with infrastructure guarantees that loading happens correctly. No model guessing. No token waste. No loading failures.

**Spec proposal status:** This implementation works today via YAML extensibility. The `triggers:` field is proposed for formal recognition in the Agent Skills spec, based on convergent evidence - every major platform has independently built pre-invocation hooks. The proposal asks the spec to standardize the declaration so skill authors write intent once and all conforming platforms honor it.

**Production usage:** This implementation has been in production use in the Scout-and-Wave protocol across 16+ repositories, demonstrating real-world viability at scale.

The implementation uses only existing Agent Skills spec conventions - `scripts/` directory, `references/` directory, and YAML extensibility. No spec modifications required to use it today. Works on Claude Code, Gemini CLI, OpenAI Codex, Cursor, OpenCode, and any Agent Skills-compliant tool.

Start with Tier 0 discovery in CLAUDE.md. Add `triggers:` to your skill's frontmatter. Bundle `scripts/inject-context`. Optionally install the pre-invocation hook for deterministic loading. Use `scripts/validate-triggers` to check for false-positive patterns before deployment.

Build skills that scale reliably without token bloat or routing failures.

---

**Implementation:** [github.com/blackwell-systems/agentskills-subcommand-dispatch](https://github.com/blackwell-systems/agentskills-subcommand-dispatch)

**Agent Skills Spec:** [agentskills.io/specification](https://agentskills.io/specification)
