---
title: "Provable Determinism for Agent State: The Machine-Checked Proof Behind Bide"
date: 2026-10-01
draft: false
math: true
tags: ["determinism", "distributed-systems", "convergence", "confluence", "formal-verification", "coq", "rocq", "proof-assistant", "ai-agents", "agent-frameworks", "durable-execution", "event-sourcing", "crdt", "eventual-consistency", "invariants", "compensation", "go", "golang", "bide", "gsm", "normalization-confluence", "rewriting-systems"]
categories: ["distributed-systems", "formal-methods", "ai"]
description: "How Bide guarantees agents replaying the same log reach identical state in any order, and the axiom-free Coq/Rocq proof, 67 audited theorems, behind it."
summary: "Agents that share state usually rely on eventual consistency and hope. Bide's shared state rests on a convergence theorem that is machine-checked axiom-free, re-checked on three proof-assistant toolchains, and wired into the engine so a bug in the Go code cannot pass a non-convergent machine. This is what is proven, how it is checked, and exactly where the proof stops."
---

Run two copies of an agent against the same durable log and they will, at some point, see the same events in a different order. A retry lands late. A crash and resume replays a step. Two workers in different processes race. If the state those agents share depends on the order of events, the copies disagree, and nothing in the log tells you which one is right.

Most agent frameworks answer this with eventual consistency, which in practice means the system converges if the operations happen to commute, and hope otherwise. Bide answers it with a theorem: for the governed-state tier, **the order steps replay in cannot change the result**. That claim is machine-checked in Coq/Rocq, axiom-free, and the checker that proves it is also what re-certifies the engine's output on every build.

This post is about what that proof says, how it is checked, and where it stops. The last part matters as much as the first. A determinism guarantee is only useful if you know its exact boundary.

{{< callout type="info" >}}
**The claim.** Given the same set of events, every processor that applies them in any order reaches the same valid state. That is *order-independent convergence of the replay*. It is not "agents always agree on what to do," and it does not cover the external world: a payment or an email is protected by a different mechanism, covered below.
{{< /callout >}}

## Determinism means path-independence

A deterministic system, in the sense that matters for replicated state, is one where the result is a function of the inputs and not of the path taken through them. Thermodynamics calls this a state function. Algebra calls it a canonical form. Database people call it convergence. Everyone who builds replicated systems eventually needs it.

There are three established ways to get it without coordination, and they nest:

{{< mermaid >}}
flowchart LR
    subgraph nc["Normalization confluence"]
        direction LR
        subgraph ic["Invariant confluence"]
            subgraph crdt["CRDTs"]
                c1["operations commute<br/>for every state"]
            end
            i1["every ordering preserves<br/>invariants, no repair"]
        end
        n1["operations may BREAK invariants;<br/>compensation repairs them,<br/>and the repaired results converge"]
    end

    style nc fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style ic fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style crdt fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**CRDTs** buy convergence by restricting operations so they always commute. **Invariant confluence** asks that every ordering preserve the invariants, so nothing ever needs repair. Both are strong requirements, and real business logic violates them constantly: an order ships before its payment clears, two withdrawals race past a balance floor, inventory goes negative for a moment.

**Normalization confluence** is the regime this work identifies. It allows operations that individually break invariants, as long as a compensation step repairs them and the repaired results come out the same in any order. Convergence becomes a property of the whole rewrite system (apply an event, then normalize), not of the operations themselves. CRDTs are the special case where no repair is ever needed, and that inclusion is itself machine-checked and strict: there are convergent governed machines no CRDT can express.

## The theorem, in two conditions

Model a registry as a state, a set of invariants (predicates that define "valid"), and a compensation that repairs a violation. Applying an event and then repairing until valid is a rewrite step. Two conditions make the whole system converge.

**Well-founded compensation (WFC).** Repair always terminates. Formally, there is a potential $\Phi$ that strictly decreases on every repair of an invalid state. Since $\Phi$ lives in a well-founded order, it cannot decrease forever, so every compensation chain is finite. This is a termination measure, the discrete cousin of a Lyapunov function.

**Compensation commutativity (CC).** Repair does not depend on order locally. Two parts:
- **CC1:** two independent events, each followed by repair, commute.
- **CC2:** repairing before an event or after it gives the same normalized result.

Then a classical result does the rest. **Newman's Lemma** says a rewrite system that terminates and is *locally* confluent is *globally* confluent, and a confluent terminating system has a unique normal form. WFC is termination. CC is local confluence. Unique normal form is exactly "same events, any order, same final state."

{{< mermaid >}}
flowchart TB
    s["state s with<br/>pending events e1, e2"]
    a["apply e1, then repair"]
    b["apply e2, then repair"]
    j["one normal form"]
    s --> a
    s --> b
    a -->|"apply e2, repair"| j
    b -->|"apply e1, repair"| j

    style s fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style a fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style b fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style j fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

The diamond above is the shape of local confluence: any two diverging single steps can be rejoined. Newman's Lemma lifts that local diamond to the whole system, so every divergence of any length rejoins.

## What it looks like in code

The reference implementation is [gsm](https://github.com/blackwell-systems/gsm), a Go library. You declare variables, invariants with their repairs, and events. `Build` verifies WFC and CC before it gives you a machine, and refuses to build one that could diverge.

```go
r := gsm.NewRegistry("order_fulfillment")

status := r.Enum("status", "pending", "paid", "shipped", "cancelled")
paid := r.Bool("paid")
inventory := r.Int("inventory", 0, 5)

// Invariant: can't ship unpaid orders
r.Invariant("no_ship_unpaid").
    Watches(status, paid).
    Holds(func(s gsm.State) bool {
        return s.Get(status) != "shipped" || s.GetBool(paid)
    }).
    Repair(func(s gsm.State) gsm.State {
        return s.Set(status, "pending")
    }).
    Add()

// ... events: process_payment, ship_item, restock

machine, report, err := r.Build() // verifies convergence, or refuses
if err != nil {
    panic(fmt.Sprintf("convergence not guaranteed: %v\n%s", err, report))
}

// Runtime: O(1) table lookups, compensation precomputed
s := machine.NewState()
s = machine.Apply(s, "ship_item")       // arrives before payment
s = machine.Apply(s, "process_payment") // arrives after shipment
// repaired automatically, same final state as the other order
```

`ship_item` arriving before `process_payment` violates an invariant. Compensation repairs it. Whichever order the two events arrive in, the machine lands on the same valid state, and `Build` already proved that before the first event ran.

Two verification paths exist. For small machines, `Build` enumerates the finite state space and checks every pair. For large ones, events that write disjoint variables commute without enumeration (a footprint argument), and `BuildCompositional` certifies machines whose global state space is too large to enumerate.

## How the proof is checked

A convergence claim in a README is easy to write. The point of this work is that the claim is checked by a machine and can be checked again by anyone. Four layers stack up.

{{< mermaid >}}
flowchart TB
    subgraph proof["Coq/Rocq development (axiom-free)"]
        nw["Newman's Lemma"]
        gov["Convergence theorem<br/>from WFC + CC"]
        snd["Soundness of gsm's checks<br/>(termination, footprint CC)"]
        def["Non-vacuity and<br/>discrimination checks"]
    end
    subgraph ci["CI gate, every change"]
        tc["Coq 8.18 + Coq 8.20 + Rocq 9.3"]
        pa["Print Assumptions on 67 theorems:<br/>Closed under the global context"]
    end
    subgraph engine["gsm build"]
        go["Go verifier: WFC + CC"]
        tables["emitted step tables + rules"]
    end
    subgraph oracles["Extracted OCaml oracles"]
        o1["table oracle: re-checks<br/>the emitted tables"]
        o2["rules oracle: recomputes<br/>convergence from the rules"]
    end
    proof --> ci
    proof -->|"extraction"| oracles
    go --> tables
    tables --> o1
    tables --> o2

    style proof fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style ci fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style engine fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style oracles fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**1. The theorem is proven, not tested.** Newman's Lemma is mechanized from scratch with no library dependencies. The convergence theorem takes WFC and CC as hypotheses and proves termination (a lexicographic measure over the pending events and the potential), local confluence (all three critical-pair cases), and unique normal forms.

**2. "Axiom-free" is checked, not asserted.** A proof assistant will happily accept a proof that leans on an unstated axiom or an admitted lemma. The CI gate compiles the development and runs `Print Assumptions` on 67 named theorems. Every one must report *Closed under the global context*: no axioms, no admits. The gate runs on three toolchains, Coq 8.18, Coq 8.20, and Rocq 9.3, so the result does not depend on one version's quirks.

**3. The proof is defended against being empty.** A proof that compiles can still be weak in two ways a compiler will not catch. Its hypotheses could be unsatisfiable, in which case the theorem is about nothing. Or the property it proves could be true of everything, in which case proving it says nothing. The development rules out both: a concrete registry discharges every hypothesis of the convergence theorem with no axioms (so the result holds unconditionally for a real system), and a concrete relation is proven *not* confluent (so "confluent" actually discriminates).

**4. The proof checks the engine.** gsm's verifier is ordinary Go, and ordinary Go has bugs. So two checkers are extracted from the proof to OCaml and run against gsm's real output in differential tests. One re-checks the step tables gsm emits. The other ignores those tables and recomputes convergence directly from the declared rules, which are inspectable combinator data rather than opaque closures. If gsm's Go verifier ever passed a non-convergent machine, the rules oracle would reject it.

{{< callout type="success" >}}
**Reproduce it yourself.** Nothing here depends on trusting a badge.

    git clone https://github.com/blackwell-systems/normalization-confluence
    cd normalization-confluence/coq
    ./verify.sh

The script builds every module and fails unless all 67 audited theorems are closed under the global context.
{{< /callout >}}

## Where this lives in Bide

[Bide](https://github.com/bide-ai/bide) is a Go library for durable AI agents. Its pitch is four guarantees derived from one append-only journal, and convergent shared state is the fourth:

| Guarantee | Mechanism |
|---|---|
| Side effects fire at most once, even across a crash | attempt markers written before non-idempotent calls, and a halt when an outcome is unknown |
| Thousands of concurrent durable runs in one process | a library over a store you already run, not a cluster |
| A cryptographically verifiable audit trail | RFC 6962 Merkle proofs, checkable offline |
| **Provably convergent shared state** | **gsm, backed by the proof above** |

The governed-state tier is how independent agents share state without a single writer. Each agent's actions become governed events; gsm proves, at build time, that every interleaving of them reaches the same valid state. At runtime that is a table lookup.

The integration test that exercises it at scale drives up to **10,000,000 governed agents, 2,048 at a time**, through random, invariant-violating orders. Every run breaches a capped invariant and is compensated, and the test asserts that every agent converges to the same valid normal form and produces an audit proof that verifies offline. It runs in one process with a flat live heap of about 3 MB, at roughly 12,500 agents per second. It is a framework-level test (stub model, in-memory store), so it measures the governance and audit machinery, not a live model or a production database.

The first guarantee is the one people usually mean by "deterministic agents," and it is measured rather than proven. Bide's chaos benchmark drives a non-idempotent `charge` through every crash point and counts how many times it actually executes:

| Framework | maxFired | Result |
|---|---|---|
| Bide | 1 | at-most-once held |
| trpc-agent-go | 6 | double-charged |
| adk-go | 4 | double-charged |
| langchaingo | 64 | double-charged |
| eino | 64 | double-charged |

The two guarantees cover different territory, and the boundary between them is exact. Confluence governs the **internal** state that replays from the log. It says nothing about a charge that already left the process. That is what the journal's attempt markers handle: if a side effect's outcome was never recorded, the resumed run stops for a human or a reconciler instead of guessing. Determinism inside, at-most-once at the edge.

## Many registries, and where coordination is actually needed

One registry is rarely the whole story. Real systems connect several: a manufacturer's specifications constrain a supplier, a policy registry constrains a workflow. The federated results extend convergence across a network of registries connected by morphisms, where one registry's normal form fixes part of another's state.

The structure is clean, and it is mechanized:

- **Acyclic networks converge.** Authority flows from sources to targets, and the federated normal form is the same for every topological order of the registries. That order-independence is proven directly, for arbitrary acyclic federations.
- **Monotone cycles converge.** When repair only moves values up a lattice, even a cyclic network reaches a least fixed point, and every fair asynchronous schedule reaches the same one.
- **Other cycles need coordination, and the theory says exactly where.** For cycles whose morphisms relabel values losslessly, the obstruction is the *holonomy* of each cycle: the composite of the relabelings going around it. Pick a spanning tree of the network. A consistent global state exists if and only if every fundamental cycle has trivial holonomy, and the edges that must be coordinated are exactly the ones whose cycles do not.

That last result refines the CALM theorem, which tells you whether coordination can be avoided for a whole problem. This one tells you *where*: put consensus on the obstructing cycles only and run everything else coordination-free. It holds for any group of relabelings, abelian or not, and the non-abelian case matters. A parity-style check can call a cycle consistent when a three-way relabeling around it is not, and the development proves a concrete case where sizing coordination by an abelian invariant under-provisions.

{{< callout type="warning" >}}
**Roadmap, not shipped.** gsm today rejects non-monotone cycles and, when asked, plans coordination that breaks every cycle. The holonomy result says lossless round-trips (a copy loop, an exact unit conversion, a bijective schema map in both directions) need no coordination at all. A design for that sharper plan is in [gsm's design notes](https://github.com/blackwell-systems/gsm/blob/main/HOLONOMY-COORDINATION-DESIGN.md); the theorems it rests on are proven, the feature is not built yet.
{{< /callout >}}

## Exactly where the proof stops

A determinism guarantee you cannot bound is a liability, because someone will apply it where it does not hold. Here is the boundary.

| Status | What |
|---|---|
| **Machine-checked, axiom-free** | Newman's Lemma; the single-registry convergence theorem; soundness of gsm's termination and footprint checks; both extracted oracles; CRDTs as the strict compensation-free subset; federation as a limit, its normalizer as the retraction onto it, compositionality, and full order-independence for acyclic networks; monotone-cycle convergence (least fixed point and asynchronous chaotic iteration, finite-height lattices); the cohomological completion on arbitrary graphs, the cycle-basis criterion, $H^1$ as tuples of fundamental holonomies modulo simultaneous conjugation with rank $\lvert E \rvert - \lvert V \rvert + 1$, and the $S_3$ separation |
| **Proven on paper, not mechanized** | the rank of the obstruction on the full nerve of overlaps, where triple overlaps add relations that can lower it; the non-invertible case, where the obstruction is a dynamical fixed-point condition rather than group cohomology |
| **Cited, not claimed** | the complexity of the global minimum coordination (the group feedback edge set problem: NP-hard in general, fixed-parameter tractable in the size of the coordinated core) |
| **Outside the guarantee** | external side effects (handled by the journal, not by confluence); delivery (the theorem assumes every replica eventually sees the same event set); continuous state, where convergence needs a different argument entirely |

The last row is not a footnote. The theory is about discrete state. It extends to infinite discrete domains, but continuous dynamics (physical systems, optimization landscapes) can have many attracting states, and no amount of local confluence makes a multi-basin landscape converge to one answer. If someone tells you their continuous system "converges deterministically" by analogy to results like these, the analogy is the part to check.

## Why this matters now

Agents are moving from assistants you watch to workers you leave running. An unattended worker that touches money, records, or anything under audit has to be safe to crash, safe to replay, and explainable after the fact. Replay safety comes down to determinism, and determinism has usually been an empirical property: tested, believed, occasionally violated in production.

It does not have to be. For the class of systems this covers, convergence is a theorem you can check on your own machine in one command, and the same proof certifies the engine that enforces it. That is the standard I think agent infrastructure should be held to wherever the stakes are real: claims you can verify, with the edges written down.

**Further reading**

- [Normalization Confluence for Registry-Governed Stream Processing](https://doi.org/10.5281/zenodo.18671870) (the core paper)
- [Normalization Confluence in Federated Registry Networks](https://doi.org/10.5281/zenodo.18677400) (federation and cycles)
- [normalization-confluence](https://github.com/blackwell-systems/normalization-confluence): the papers and the Coq/Rocq development
- [gsm](https://github.com/blackwell-systems/gsm): the Go engine
- [Bide](https://github.com/bide-ai/bide): durable agents in Go
