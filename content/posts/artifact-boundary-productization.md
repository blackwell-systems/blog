---
title: "Artifact-Boundary Productization: Clean OSS/Commercial Separation"
date: 2026-01-28
draft: false
tags: ["architecture", "product-design", "product-engineering", "product-development", "open-source", "platform-engineering", "software-design", "boundaries", "separation-of-concerns", "tooling", "devtools", "infrastructure", "oss", "commercial", "licensing", "control-plane", "intelligence-plane", "observability", "tracing", "analysis", "artifacts"]
categories: ["architecture", "product-design"]
description: "Understanding the execution boundary: why features that provide value after the system stops belong in products, not platforms. A framework for clean OSS/commercial separation."
summary: "The execution boundary determines everything: features that need the system alive belong in the platform (OSS). Features that analyze artifacts after shutdown become the product (commercial). A framework for clean OSS/commercial separation."
---

{{< callout type="success" >}}
This post emerged from repeatedly asking: How do I create quality open source software that can remain open and uncorrupted, and transform that into a clean, trustworthy commercial layer?

The answer isn't about licenses or pricing. It's about **boundaries**.
{{< /callout >}}

You build a feature. It works. Then you realize it doesn't belong in the repo you're building it in.

Not because the code is wrong. Because the **boundary** is wrong.

This happens when a feature-scoped repository grows into a product. The code stays the same, but the framing changes. What started as "a policy generator" becomes "analysis toolchain with policy generation as the first feature."

That transition - from feature to product - has a pattern. Most teams miss it because they're focused on code, not boundaries. But once you see the pattern, it applies everywhere: OSS vs commercial splits, platform vs tooling decisions, monorepo vs multi-repo choices.

The pattern centers on one question: **when does your feature provide value - during execution or after?**

That boundary determines everything.

---

## When Naming Stops Working

You start with a feature. An analysis tool that consumes artifacts produced during system execution and generates insights. The repo is named after what it does. Clear scope, obvious purpose.

The feature matures. You realize the trace format is stable. Multiple analysis features become obvious - summarization, diffing, compliance reports. This isn't one tool anymore. It's becoming an analysis suite.

Suddenly the repo name feels wrong.

{{< callout type="info" >}}
The feature outgrew its domain boundary. It crossed from feature into product. You're no longer building a tool that does one thing. You're building a product that happens to have one feature as its entry point.
{{< /callout >}}

The repo boundary wasn't wrong when you started. It's wrong *now* because the architecture evolved.

**The feature/product boundary seems obvious in retrospect.** But this clarity is the result of post-hoc analysis - a huge amount of thought and organizational work went into preparing and protecting that boundary. It's a case of expertise being mistaken for simplicity.

The specific domain doesn't matter - this pattern appears everywhere: databases, CI systems, observability platforms, compilers, test frameworks.

---

## Key Terms

Before exploring the pattern, let's define the core concepts:

**Platform** - The runtime system that does the work. Emulators, databases, CI runners, service meshes. The platform is trusted, typically open source, and provides value during execution.

**Product** - The analysis tooling that interprets outcomes. Policy generators, compliance reporters, performance analyzers. Products operate on artifacts and provide value after execution.

**Execution** - The period when the system is alive, making decisions, affecting outcomes. Services are running, requests are flowing, authorization decisions are being made, state is mutating. For a database, it's queries running. For a CI system, it's builds executing. The specific domain doesn't matter - the pattern is the same.

**Artifacts** - Stable outputs produced during execution. Logs, traces, test results, build outputs. These files survive after the system stops and serve as the contract between platform and product.

**Data Plane** - The layer that does the actual work. Runs services, processes requests, executes business logic. In a distributed system, this is the application services. In a database, it's the query engine. Pure execution with no governance logic.

**Control Plane** - The layer that makes runtime decisions. Authorization, routing, policy enforcement, resource allocation. In Kubernetes, this is the API server and scheduler. In a distributed system, it's the auth service and API gateway. These components affect whether operations succeed or fail.

**Intelligence Plane** - The layer that analyzes outcomes after execution. Policy generators, compliance reports, performance analyzers, drift detection. This plane operates on artifacts and never participates in runtime decisions. Always post-execution.

**Platform Boundary** - The separation line between runtime features and analysis features. Features on the platform side participate in execution - they affect outcomes, make decisions, or enable the system to run. Features on the product side consume artifacts and provide insights after execution completes.

**Product Boundary** - The point where a feature-scoped repository becomes a product. This happens when multiple analysis features share a common artifact format, signaling that you're building an analysis suite rather than a single tool. The product boundary is where you extract the intelligence plane into its own repository with its own identity.

**Bright-Line Rule** - A clear, objective test that produces unambiguous results. The execution boundary is a bright-line rule: if a feature needs the system alive, it's platform; if it works on artifacts after shutdown, it's product. No judgment calls, no gray areas.

---

## Naming the Pattern: Artifact-Boundary Productization

The pattern described in this article is not new, but it is rarely named explicitly.

I'll refer to it as **artifact-boundary productization**.

**Artifact-boundary productization** is the moment a feature becomes a product because its value is realized entirely through artifacts produced by execution, rather than through participation in execution itself.

{{< callout type="info" >}}
When execution produces durable artifacts, and interpretation of those artifacts becomes the primary source of value, a product boundary has emerged.
{{< /callout >}}

This is not a business decision. It is an architectural fact.

The boundary is defined by:
- **Execution** (systems making decisions, mutating state)
- **Artifacts** (immutable records of what happened)
- **Interpretation** (analysis that can occur after execution ends)

When interpretation dominates value, the system has crossed from platform feature into product.

The rest of this article explores how that boundary appears, why it matters, and how to recognize it early. If you don't recognize it early, it results in architectural mistakes that are difficult to back out later.

---

{{< callout type="info" >}}
**When These Rules Apply**

+ These rules are most effective when systems produce durable execution artifacts
+ They are especially powerful for OSS + commercial infrastructure
+ They create a true bright line grounded in architecture, not policy

- They do not apply to consumer apps with continuous execution
- They are not useful where artifacts are ephemeral or irrelevant
- **They are unnecessary in fully proprietary, closed systems**

Artifact-boundary productization applies when interpretation outlives execution.
{{< /callout >}}

---

## The Execution Boundary

Here's the pattern that resolves the confusion:

This is the architectural moment that triggers artifact-boundary productization.

For a distributed system, execution means services are running, requests are flowing, authorization decisions are being made, and state is mutating. For a database, it's queries running and transactions committing. For a CI system, it's builds executing and tests running.

**Execution ends when:**
- The test run finishes
- Services shut down
- No more decisions are being made

After that point, you have artifacts (logs, traces, results). The system is stopped, but analysis can continue.

### Execution Produces Artifacts

Once execution completes, the system's decisions are immutable. A request was allowed or denied. A secret was accessed. A permission was exercised. These facts become artifacts - logs, traces, results written to disk.

You can replay analysis, but you cannot change what happened.

This is why execution demands trust - and why interpretation can be optional.

The intelligence plane reasons about artifacts. The platform creates them.

---

## The Rule: Value Timing Determines Placement

{{< callout type="info" >}}
**The Execution Boundary Rule**

If a feature's value depends on the system being alive, it belongs in the platform.

If its value survives after the system stops, it belongs in the product.
{{< /callout >}}

Let's apply this:

**Tracing** is a platform feature. Traces are collected while the system runs - during service requests, authorization checks, and state mutations. Their primary value is explaining what happened in that specific execution window. When services shut down, trace collection stops. 

This is a platform responsibility: the runtime must emit structured data about its decisions. Tracing belongs in the OSS platform because it's inseparable from execution.

**Policy generation**, by contrast, is a product feature. It requires execution to have already completed. The policy generator operates on trace artifacts - files written to disk that survive after services stop. 

You can run policy generation tomorrow, on a different machine, using last week's traces. Value actually increases with accumulated traces: more execution history produces better policies. This post-execution nature makes it a commercial product boundary.

**Debug logging** follows the platform pattern. It records runtime behavior - function calls, decision branches, state transitions. The logs explain control flow while it's happening. Once execution ends, debug logging stops producing value. Like tracing, it's tied to the execution window and belongs in the OSS platform.

**Compliance reports** show the product pattern. They aggregate outcomes after execution completes - summarizing which permissions were used, which services were called, which policies would grant least privilege. 

These reports are used for review and audit, typically generated in a separate CI step after tests finish. They don't need the system to be alive. Compliance reports belong in the commercial product.

---

## Why This Matters: The Three Planes

Systems naturally decompose into three layers:

{{< mermaid >}}
flowchart TB
    subgraph data["Data Plane"]
        services[Application Services<br/>API, Storage, Messaging]
    end
    
    subgraph control["Control Plane"]
        auth[Auth Service]
        proxy[API Gateway]
        cli[Control CLI]
    end
    
    subgraph intelligence["Intelligence Plane"]
        policy[Policy Generator]
        diff[Trace Diff]
        compliance[Compliance Reports]
        analysis[Drift Analysis]
    end
    
    services -->|emit traces| control
    control -->|produce artifacts| intelligence
    
    style data fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style control fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style intelligence fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**The data plane** does the work - it runs services, processes requests, mutates state. This is where your application logic lives: the emulated services, the database queries, the business logic. 

It's pure execution.

**The control plane** makes decisions. It handles authorization, routing, policy enforcement - all the runtime governance that affects whether operations succeed or fail. 

The auth service sits here, along with API gateways and control CLIs. These components participate in control flow: they affect outcomes while the system is alive.

**The intelligence plane** analyzes outcomes. Policy generators, trace diff tools, compliance reports, drift analysis - all of these operate on what the other planes produced. They don't make runtime decisions. They interpret results, find patterns, generate insights. 

This plane can run hours or days after execution completes.

{{< callout type="info" >}}
The intelligence plane is always post-execution. That's what makes it the natural commercial boundary. It doesn't participate in control flow, so it can't affect the trustworthiness of the platform. It consumes artifacts that the platform produces, making the separation clean and architectural rather than cosmetic.
{{< /callout >}}

Because the intelligence plane cannot affect execution, it cannot compromise correctness - even if it is buggy, slow, or proprietary.

---

## Compiler Architecture as a Model

Another mental model: think like a compiler toolchain.

**GCC analogy:**

```
Source code (C)
    ↓
gcc (compiler) → produces object files
    ↓
Object files (artifacts)
    ↓
Analysis tools:
- objdump (disassembler)
- nm (symbol analyzer)
- gprof (profiler)
- valgrind (memory analyzer)
```

**Your system:**

```
Test execution (runtime)
    ↓
Runtime + tracer → produces trace files
    ↓
Trace files (artifacts)
    ↓
Analysis tools:
- policy generator
- trace summarizer
- compliance reporter
- drift detector
```

Analysis tools are separate products. No one puts `gprof` inside `gcc`.

Crucially, compilers do not call profilers - and profilers cannot influence compilation.

Why this separation works:
- Different release cycles
- Different trust requirements
- Different licensing opportunities
- Clean dependency graph (one direction)

---

## The Artifact Contract

Artifact-boundary productization only works if artifacts are treated as a first-class contract.

What makes this separation work: **a stable artifact schema**.

Clean separation requires four properties in your artifact schema.

Schema stability means traces carry version tags and maintain backward compatibility. When you add fields or change formats, old analysis tools still work with new traces. Version negotiation happens at the schema level, not through runtime coupling. This lets the platform evolve its trace format without breaking every analysis tool.

Self-contained artifacts include all context needed for analysis. A trace file shouldn't require lookups to external services or runtime state. Everything an analysis tool needs - timestamps, resource identifiers, operation results, metadata - must be embedded in the artifact. This ensures analysis tools can operate completely offline.

No callbacks means analysis tools cannot call back into the runtime. They consume artifacts but never invoke platform APIs during analysis. The dependency graph flows one direction: platform produces artifacts, product consumes them. Breaking this rule - adding "just one runtime hook for enrichment" - starts the collapse.

File-based operation means analysis works on files, not live state. You can tar up a directory of traces, copy it somewhere else, and run all your analysis tools. No network calls to running services, no shared memory, no runtime coordination. The filesystem is the only contract.

When you have these properties, the platform and product evolve independently. Platform developers add trace fields without coordinating with product teams. Product developers build new analysis features without touching platform code. The boundary never blurs because the contract is stable and enforced by the artifact schema. Trust is preserved because users can verify the platform produces artifacts without calling product code.

When you don't have these properties, decay begins immediately. Analysis tools need "just one runtime hook" to get extra context. Platform developers add "just one analysis callback" to enable a product feature. Coupling creeps in through convenience functions and shared state. Eventually the separation becomes cosmetic - different repositories with runtime dependencies between them. The artifact contract is what prevents this decay.

---

## Trust and Licensing Implications

Artifact-boundary productization gives you a bright licensing line that does not rely on feature flags or enforcement.

Why separation matters for OSS/commercial splits:

**OSS users must be able to say:**

"I can run the entire platform without touching proprietary code."

**With clean separation:**
- Platform runtime: OSS
- Trace emission: OSS
- Policy generator: Commercial (optional)

Users run OSS, get traces, stop. They can:
- Write their own analysis
- Use OSS tools
- Never install Pro

**With blurred separation:**
- "Free tier" vs "Pro tier"
- Feature flags in OSS code
- Conditional builds
- Trust erosion

The boundary isn't just technical - it's about trust.

---

## Decision Framework

### Step 1: Identify Execution Window

Start by asking when the system needs to be alive for this feature to work. If the feature requires services to be running - during test runs, during service requests, while handling authorization checks - it's a platform feature. It depends on execution being active. If the feature operates after shutdown, consuming files that execution produced, it's a product feature. The execution window tells you which side of the boundary the feature belongs on.

### Step 2: Check Dependencies

Ask whether this feature could run on a different machine with only artifact files. If you could copy trace files, logs, or results to your laptop and run the feature there - completely disconnected from the original system - it belongs in the product layer. It's decoupled from runtime. If the feature requires live access to running services or runtime state, it belongs in the platform layer. This test reveals whether you've achieved true artifact-based separation.

### Step 3: Value Timing

Ask when value increases. Platform features provide value while the system is running - faster requests, better authorization decisions, clearer runtime logs. Product features provide value after the system stops - accumulated analysis, historical trend reports, insights that span multiple executions. If a feature provides value both during and after execution, that's a signal to split it into two features: one that participates in runtime (platform) and one that analyzes outcomes (product).

### Step 4: Control Flow

Ask whether this feature participates in runtime decisions. Does it affect outcomes - authorization results, routing decisions, which services get called? If yes, it's a platform feature. It's part of the control plane and must be trusted. If it only analyzes outcomes - generating reports, suggesting optimizations, finding patterns - it's a product feature. It interprets results but doesn't influence them. Control flow participation is the ultimate test: features that affect execution must stay in the platform.

---

## Common Patterns

### Pattern 1: Emulator + Analysis

The platform provides a database emulator that runs queries and emits request traces. These traces capture query patterns, table access, and performance characteristics during execution. This is OSS: the emulator must be trustworthy and the trace format must be stable.

The product layer analyzes those traces to generate query optimizer suggestions, performance reports, and migration guides. These tools run after the database stops - often as part of CI pipelines or developer workflows. They don't affect query results, so they can be proprietary without eroding platform trust. The boundary is the trace schema: a versioned, stable contract that both sides depend on.

### Pattern 2: CI System + Intelligence

The platform runs tests, executes builds, and stores artifacts. The test runner orchestrates execution, the build system compiles code, and artifact storage preserves outputs (logs, results, coverage data). This is compute infrastructure - it must be reliable and fast. OSS ensures transparency and trust.

The product layer detects flaky tests, optimizes build times, and analyzes failure patterns. These features operate on build artifacts after execution completes. Flaky test detection accumulates results across multiple runs. Build optimization analyzes historical timing data. Failure pattern analysis correlates errors across test suites. None of these require the CI system to be running. The boundary is build artifacts: logs, test results, timing metrics, and coverage reports.

### Pattern 3: Runtime + Post-Mortem

The platform operates the service mesh, collects distributed traces, and gathers metrics during production traffic. This is runtime observability - it must have minimal overhead and must never drop data. The mesh routes requests, the tracer captures spans, the collector aggregates metrics. This layer stays OSS because it's part of the critical path.

The product layer performs root cause analysis, capacity planning, and cost optimization. These tools consume observability data after incidents occur or as part of planning cycles. Root cause analysis correlates traces and metrics to explain outages. Capacity planning projects resource needs based on historical patterns. Cost optimization identifies expensive operations and suggests alternatives. The boundary is observability data: traces, metrics, and logs written to storage systems where analysis tools can consume them independently.

---

## When Separation Doesn't Matter

Not every project needs this distinction.

Skip separation when you're building a single-purpose tool with one clear feature and no obvious follow-ons. If there's no commercial intent and the scope is limited, adding architectural boundaries creates unnecessary complexity. The code stays simpler, the deployment stays simpler, and you avoid premature abstraction.

Homogeneous teams with full access don't need trust boundaries. If everyone can see and modify everything, and the team values simplicity over isolation, keeping everything in one repo makes collaboration easier. The overhead of separate repositories and deployment patterns doesn't pay for itself.

Early-stage projects - MVPs and prototypes - shouldn't separate until the architecture settles. When you're still figuring out what the system should do, rigid boundaries slow down iteration. It's premature to split before you understand where the natural seams are. Get the feature working first, then extract boundaries when they become obvious.

Separation matters when you're mixing OSS and commercial code. Users must trust the OSS core, which means they need a clear licensing boundary. Commercial features must be genuinely optional - not feature flags in the OSS codebase, but separate products that consume platform artifacts. This architectural separation preserves trust: users can audit the platform and verify it doesn't contain proprietary dependencies.

Multiple analysis features sharing a common artifact format signal that a product boundary is emerging. When you find yourself building a second or third tool that operates on the same traces or logs, that's the moment to extract the analysis suite. The shared artifact format becomes the contract, and the product boundary becomes architecturally obvious.

Multi-tenant or security-critical systems need explicit trust boundaries and architectural isolation. When different teams or customers share infrastructure, blast radius must be contained. Compromising one namespace shouldn't expose another namespace's secrets. Architectural separation enforces isolation that configuration-based approaches can't guarantee.

### Not Every Post-Execution Feature Should Be a Product

Not every post-execution feature justifies productization.

Artifact-boundary productization identifies where a boundary exists, not whether it is worth exploiting. Some analysis features are trivial, commodity, or tightly coupled to a single workflow. In those cases, extracting a product adds overhead without leverage.

The pattern identifies architectural possibility, not commercial necessity.

---

## Practical: Repository Structure Evolution

### Phase 0: Feature Repository

```
least-privilege-generator/
├── cmd/generate/
├── internal/parser/
└── README.md
```

**When this works:** Single feature, clear scope, fast iteration.

**When it breaks:** Second feature arrives, repo name is now wrong.

---

### Phase 1: Product Repository

```
pro-suite/
├── cmd/
│   └── main.go
├── internal/
│   ├── policygen/     ← first feature
│   ├── summarize/     ← second feature
│   ├── compliance/    ← third feature
│   └── shared/
└── README.md
```

**Structure:**
```bash
pro-suite policy generate <trace-file>
pro-suite trace summarize <trace-file>
pro-suite compliance report <trace-file>
```

One CLI, multiple subcommands, shared infrastructure.

---


## When Teams Violate the Execution Boundary

Most systems that blur the execution boundary follow predictable patterns. These violations look different but share a common failure: interpretation leaks into execution, and trust collapses.

### What Boundary Violations Look Like

**Premium tracing that only works when enabled at runtime.** The platform emits basic traces for free users, but detailed traces require a license key checked during execution. Now the tracing system participates in commercial decisions - it must validate licenses, phone home for verification, or gate features based on subscription tier. Execution behavior differs based on payment status. Trust erodes because users can't verify the platform's behavior without a commercial relationship.

**Licensed "enforcement modes" that change authorization behavior.** The OSS version allows everything. The paid version enforces policies. This makes policy enforcement a commercial feature, which means execution correctness depends on payment. Users can't trust test results from the free tier because production uses different authorization logic. The platform's core promise - accurate testing - becomes pay-gated.

**Analysis tools that require live API access.** The analysis tool doesn't consume artifact files. Instead, it queries the running platform for additional context, metadata, or enrichment data. This prevents offline analysis and creates runtime dependencies between the intelligence layer and the platform. The tool can't run in air-gapped environments. It can't analyze historical traces after the platform is gone. The separation is cosmetic.

In all cases, interpretation leaks into execution - and trust collapses.

---

## Common Mistakes

### Mistake 1: Premium Features in OSS Repository

Teams create a monorepo with `core/` (OSS), `premium/` (commercial), and `enterprise/` (commercial) directories. This creates mixed licensing within a single codebase.

Users who want to audit the OSS portions must read through the entire repository to verify which code paths are actually open source. Boundaries become unclear - does the core call premium code? Are there feature flags gating enterprise features? 

Trust erodes because the separation is organizational (directories) rather than architectural (separate artifacts and dependencies). Feature flags proliferate as the team tries to conditionally enable premium features, making the codebase harder to reason about and test.

### Mistake 2: Analysis in the Runtime Hot Path

Developers add a configuration flag that enables report generation during execution - something like `if config.EnableAnalysis { generateReport() }` in the request handler.

This creates performance coupling: the runtime now carries the weight of analysis code even when it's not needed. Users start questioning whether the analysis code affects runtime behavior, creating trust issues. 

Architectural debt accumulates as analysis features need more runtime hooks, more shared state, more coupling. What started as "optional analysis" becomes a mandatory dependency that slows down the platform.

### Mistake 3: No Artifact Contract

Analysis tools call back into runtime APIs to fetch additional context or enrich data.

This prevents offline analysis - you can't run the analysis tool without the platform being alive. You can't run it on a different machine - it needs network access to the original system. 

The boundary collapses because the separation is only cosmetic: separate repositories or separate binaries, but with runtime dependencies between them. This is the worst outcome because it looks like clean separation from the outside while being fully coupled underneath.

---

## The Gold Standard: How This Looks When Done Right

**Examples in the wild:**

**Kubernetes:**
- Platform: kubelet, kube-apiserver, scheduler (OSS)
- Product: GKE, EKS, AKS (Commercial managed control planes)
- Boundary: Kubernetes API

**HashiCorp:**
- Platform: Terraform core, providers (OSS)
- Product: Terraform Cloud (SaaS analysis, state management)
- Boundary: State files and plan artifacts

**Compiler toolchains:**
- Platform: gcc, clang (OSS)
- Products: profilers, analyzers, IDEs (Commercial)
- Boundary: Object files and debug symbols

**Common thread:** Artifact-based separation with stable schemas.

---

## Testing Your Boundary

Test any feature against these questions to verify your boundary is clean.

### The Air-Gap Test

Could the feature run on a different machine with only artifact files?

Imagine copying traces to a laptop with no network access - no connection to the original cluster, no access to running services. If the feature still works, it's a product feature with proper separation. If it fails because it needs runtime access, it's coupled to the platform and belongs there.

### The Shutdown Test

Could the feature produce new value if execution stopped forever?

If you captured one final snapshot of traces and then shut down the entire system permanently, could this feature still generate insights, reports, or recommendations? If yes, it's a product feature - its value survives execution. If no, it's a platform feature whose value depends on the system being alive.

### The Control Flow Test

Does the feature affect runtime decisions or outcomes?

Does it participate in authorization checks, routing logic, or state mutations? Does it influence which operations succeed or fail? If yes, it must be in the platform - it's part of the critical path and must be trusted. If it only observes and analyzes without affecting outcomes, it belongs in the product layer.

### The Trust Test

Would users trust the platform if this feature were proprietary?

Imagine the feature is closed-source and licensed. Would OSS users feel comfortable running the platform? If yes, you have good separation - the feature is genuinely independent and optional. If no, the feature is coupled to platform trust and shouldn't be separated. This test catches features that claim to be "analysis only" but actually have hooks into runtime behavior.

---

## Conclusion

The artifact boundary is the line between making decisions and analyzing them.

Platform features participate in control flow. They must be fast, trusted, and deterministic. They provide value while the system is alive.

Product features interpret outcomes. They can be slow, opinionated, and licensed. They provide value after the system stops.

The handoff point is artifacts: traces, logs, results, files. When you have stable artifact schemas, the separation becomes architectural. When you don't, it's cosmetic.

**The decision rule:**

If a feature's value depends on the system being alive, it belongs in the platform.

If its value survives after the system stops, it belongs in the product.

The pattern applies beyond OSS/commercial splits. Clean architecture demands separating observation from control, analysis from enforcement, interpretation from execution.

When teams blur this boundary, they end up with premium logging, gated debuggers, and licensed enforcement paths. That creates trust erosion and architectural debt.

The artifact boundary prevents that by enforcing architectural separation, which creates a different trust model.

Every system eventually produces artifacts.

When you realize those artifacts are more valuable after execution than during it, you've discovered your product.

