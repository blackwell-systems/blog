---
title: "The Execution Boundary: When Your Feature Becomes a Product"
date: 2026-01-28
draft: false
tags: ["architecture", "product-design", "open-source", "platform-engineering", "software-design", "boundaries", "separation-of-concerns", "tooling", "devtools", "infrastructure", "oss", "commercial", "licensing", "compiler-design", "control-plane", "intelligence-plane", "observability", "tracing", "analysis", "artifacts"]
categories: ["architecture", "product-design"]
description: "Understanding the execution boundary: why features that provide value after the system stops belong in products, not platforms. A framework for clean OSS/commercial separation."
summary: "Most teams blur the line between platform features and analysis tools. Understanding the execution boundary - when the system is alive vs when it's stopped - reveals a clean separation: runtime features stay OSS, post-execution analysis becomes the product."
---

You build a feature. It works. Then you realize it doesn't belong in the repo you're building it in.

Not because the code is wrong. Because the *boundary* is wrong.

This happens when a feature-scoped repository grows into a product. The code stays the same, but the framing changes. What started as "a policy generator" becomes "analysis toolchain with policy generation as the first feature."

That transition - from feature to product - has a pattern. Most teams miss it because they're focused on code, not boundaries. But once you see the pattern, it applies everywhere: OSS vs commercial splits, platform vs tooling decisions, monorepo vs multi-repo choices.

The pattern centers on one question: **when does your feature provide value - during execution or after?**

That boundary determines everything.

---

## The Problem: When Naming Stops Working

You're building a least-privilege policy generator. It analyzes trace files from emulator runs and generates minimal IAM policies. The specific domain doesn't matter - the same pattern appears in databases, CI systems, and compilers.

The repo is named after the feature: `least-privilege-generator`. Clear scope, obvious purpose.

Then you realize:
- The trace format is stable
- Multiple analysis features are obvious (summarization, diffing, compliance reports)
- This isn't "a generator" anymore - it's an analysis suite

Suddenly the repo name feels wrong. But why?

**The insight:** You're no longer building a feature. You're building a product that happens to have policy generation as its first capability.

The repo boundary wasn't wrong when you started. It's wrong *now* because the architecture evolved.

---

## The Execution Boundary

Here's the pattern that resolves the confusion:

**Execution** = the period when the system is alive, making decisions, affecting outcomes.

For a testing/emulator system, execution means services are running, requests are flowing, authorization decisions are being made, tests are executing, and state is mutating. For a database, it's queries running and transactions committing. For a CI system, it's builds executing and tests running. The specific domain doesn't matter - the pattern is the same.

**Execution ends when:**
- The test run finishes
- Services shut down
- No more decisions are being made

After that point, you have **artifacts** (logs, traces, results). The system is stopped, but analysis can continue.

---

## The Rule: Value Timing Determines Placement

{{< callout type="info" >}}
**The Execution Boundary Rule**

If a feature's value depends on the system being alive, it belongs in the platform.

If its value survives after the system stops, it belongs in the product.
{{< /callout >}}

Let's apply this:

**Tracing (platform feature):**
- Collected *during* execution
- Primary value is explaining runtime behavior
- Produced as a platform responsibility
- **Belongs in:** OSS platform

**Policy generation (product feature):**
- Requires execution to have completed
- Operates on trace artifacts
- Can run tomorrow, on a different machine
- Value increases with accumulated traces
- **Belongs in:** Commercial product

**Debug logging (platform feature):**
- Records runtime behavior
- Explains control flow
- Value tied to execution window
- **Belongs in:** OSS platform

**Compliance reports (product feature):**
- Aggregates outcomes after execution
- Used for review and audit
- Generated in separate CI step
- **Belongs in:** Commercial product

---

## Why This Matters: The Three Planes

Systems naturally decompose into three layers:

{{< mermaid >}}
flowchart TB
    subgraph data["Data Plane"]
        services[Service Emulators<br/>Secret Manager, KMS, Pub/Sub]
    end
    
    subgraph control["Control Plane"]
        iam[IAM Emulator]
        proxy[Auth Proxy]
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

**Data Plane:** Does the work (runs services, processes requests)

**Control Plane:** Makes decisions (authorization, routing, policy enforcement)

**Intelligence Plane:** Analyzes outcomes (reports, policies, insights)

The intelligence plane is *always* post-execution. That's why it's the natural commercial boundary.

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
Emulator + tracer → produces trace files
    ↓
Trace files (artifacts)
    ↓
Analysis tools:
- policy generator
- trace summarizer
- compliance reporter
- drift detector
```

**Key insight:** Analysis tools are separate products. No one puts `gprof` inside `gcc`.

Why?
- Different release cycles
- Different trust requirements
- Different licensing opportunities
- Clean dependency graph (one direction)

---

## The Artifact Contract

What makes this separation work: **a stable artifact schema**.

In your case: the trace format (JSONL with versioned schema).

**Requirements for clean separation:**

1. **Schema stability:** Traces have version tags, backward compatibility
2. **Self-contained:** Trace files include all context needed for analysis
3. **No callbacks:** Analysis tools can't call back into runtime
4. **File-based:** Analysis operates on files, not live state

**When you have this:**
- Platform evolves independently
- Product evolves independently
- Boundary never blurs
- Trust is preserved

**When you don't:**
- Analysis needs "just one runtime hook"
- Platform needs "just one analysis callback"
- Coupling creeps in
- Separation collapses

The artifact contract is what prevents decay.

---

## Trust and Licensing Implications

Why separation matters for OSS/commercial splits:

**OSS users must be able to say:**

"I can run the entire platform without touching proprietary code."

**With clean separation:**
- Emulators: OSS
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

**Ask:** When does the system need to be alive for this feature to work?

- During test runs → Platform feature
- During service requests → Platform feature
- After shutdown, operating on files → Product feature

### Step 2: Check Dependencies

**Ask:** Could this run on a different machine with only artifact files?

- Yes → Product boundary
- No → Platform boundary

### Step 3: Value Timing

**Ask:** When does value increase?

- While running → Platform
- After running → Product
- Both → Split into two features

### Step 4: Control Flow

**Ask:** Does this participate in decisions?

- Yes (affects outcomes) → Platform
- No (analyzes outcomes) → Product

---

## Common Patterns

### Pattern 1: Emulator + Analysis

**Platform (OSS):**
- Database emulator
- Request trace emission

**Product (Commercial):**
- Query optimizer suggestions
- Performance reports
- Migration guides

**Boundary:** Trace schema

---

### Pattern 2: CI System + Intelligence

**Platform (OSS):**
- Test runner
- Build system
- Artifact storage

**Product (Commercial):**
- Flaky test detection
- Build time optimization
- Failure pattern analysis

**Boundary:** Build artifacts (logs, results, metrics)

---

### Pattern 3: Runtime + Post-Mortem

**Platform (OSS):**
- Service mesh
- Distributed tracing
- Metric collection

**Product (Commercial):**
- Root cause analysis
- Capacity planning
- Cost optimization

**Boundary:** Observability data

---

## When Separation Doesn't Matter

Not every project needs this distinction.

**Skip separation when:**

**1. Single-purpose tool:**
- One clear feature
- No obvious follow-ons
- No commercial intent

**2. Homogeneous team:**
- Everyone has full access
- No trust boundaries needed
- Simplicity > isolation

**3. Early stage:**
- MVP / prototype
- Architecture not settled
- Premature to split

**When separation matters:**

**1. OSS + commercial mix:**
- Need clear licensing boundary
- Users must trust OSS core
- Commercial features are optional

**2. Multiple analysis features:**
- Shared artifact format
- Analysis suite emerges
- Product boundary becomes obvious

**3. Multi-tenant or security-critical:**
- Trust boundaries are explicit
- Isolation is architectural
- Blast radius must be contained

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

## The Migration Path (Zero Drama)

**Step 1: Rename repository**
```bash
least-privilege-generator → pro-suite
```

**Step 2: Reframe as product**
- README: "Analysis suite for emulator traces"
- Not: "Policy generator"

**Step 3: Restructure (minimal):**
```bash
mkdir internal/policygen
mv internal/parser internal/policygen/
mv cmd/generate cmd/policy
```

**Step 4: Update binary name**
```go
// main.go
fmt.Println("pro-suite v1.0.0")
// Subcommands: policy, trace, compliance
```

**Impact:** You've promoted a feature into a product. Future features slot in naturally.

---

## Why Most Teams Get This Wrong

**Common mistake 1: Premium features in OSS repo**

```
my-oss-tool/
├── core/           (OSS)
├── premium/        (Commercial) ← mixed licensing
└── enterprise/     (Commercial) ← trust erosion
```

Problem: Users must audit entire codebase, unclear boundaries, feature flags everywhere.

**Common mistake 2: Analysis in runtime**

```go
// In the hot path
if config.EnableAnalysis {
    generateReport()  // ← post-execution feature in execution path
}
```

Problem: Performance coupling, trust issues, architectural debt.

**Common mistake 3: No artifact contract**

```
Analysis tool calls back into runtime APIs
→ Can't run offline
→ Can't run on different machine
→ Boundary collapses
```

Problem: Separation is cosmetic, not architectural.

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

Ask these questions about any feature:

**1. Air-gap test:**
"Could this run on a different machine with only artifact files?"
- Yes → Product
- No → Platform

**2. Shutdown test:**
"If execution stopped forever, could this still produce new value?"
- Yes → Product
- No → Platform

**3. Control flow test:**
"Does this affect runtime decisions or outcomes?"
- Yes → Platform
- No → Product

**4. Trust test:**
"If this were proprietary, would users trust the platform?"
- Yes (independent) → Good separation
- No (coupled) → Bad separation

---

## Conclusion

The execution boundary is the line between making decisions and analyzing them.

Platform features participate in control flow. They must be fast, trusted, and deterministic. They provide value while the system is alive.

Product features interpret outcomes. They can be slow, opinionated, and licensed. They provide value after the system stops.

The handoff point is artifacts: traces, logs, results, files. When you have stable artifact schemas, the separation becomes architectural. When you don't, it's cosmetic.

**The decision rule:**

If a feature's value depends on the system being alive, it belongs in the platform.

If its value survives after the system stops, it belongs in the product.

This isn't just about OSS vs commercial licensing. It's about clean architecture: separate observation from control, analysis from enforcement, interpretation from execution.

Most teams blur this boundary and end up with premium logging, gated debuggers, and licensed enforcement paths. That creates trust erosion and architectural debt.

The execution boundary prevents that. It's not just cleaner code - it's a different trust model.

When you see a feature that provides more value after execution completes, you've found your product boundary.

---

## Further Reading

**Platform Engineering:** [Kubernetes Architecture](https://kubernetes.io/docs/concepts/architecture/), [Terraform State and Plans](https://developer.hashicorp.com/terraform/language/state)

**Compiler Design:** [Engineering a Compiler](https://www.elsevier.com/books/engineering-a-compiler/cooper/978-0-12-088478-0), [LLVM Architecture](https://llvm.org/docs/)

**Related Articles:** [API Communication Patterns](/posts/api-communication-patterns-guide/), [Kubernetes Secrets: State Separation](/posts/kubernetes-secrets-state-separation/)
