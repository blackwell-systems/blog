---
title: "The Falsifiability Asymmetry: Loud Restrictions, Silent Freedoms"
date: 2026-09-25
draft: false
tags: ["invariants", "correctness", "software-architecture", "database-design", "postgresql", "design-by-contract", "type-driven-development", "make-illegal-states-unrepresentable", "least-privilege", "security", "falsifiability", "decision-records", "adr", "schema-design", "constraints", "event-sourcing", "correctness-by-construction", "stakeholder-discovery", "data-modeling", "test-driven-development"]
categories: ["architecture", "software-design"]
description: "A restriction fails loud and a freedom fails silent, so you can only learn you over-restricted, never that you over-permitted. A design method built on that asymmetry."
summary: "You can discover that a rule was too strict, because something legitimate breaks and tells you where. You cannot discover that a rule was too loose the same way, because nothing breaks until it is exploited. This asymmetry has a direction built into it, and a whole design method falls out of taking it seriously."
---

There is a fact about building systems that took me an embarrassingly long time to state plainly, even though I had been relying on it for years. Here it is.

You can find out that a rule was too strict. Something legitimate stops working, someone hits the wall, and the failure points at the exact place you were wrong. You cannot find out that a rule was too loose in the same way. Nothing stops working when you allow too much. The permission sits there, unused and invisible, until the day something exploits it, and by then the signal arrives as damage rather than as feedback.

I call this the **falsifiability asymmetry**, and the short version is: loud restrictions, silent freedoms.

Once you see it, a surprising amount of good practice stops being a collection of separate rules of thumb ("fail closed," "least privilege," "make illegal states unrepresentable") and starts looking like consequences of one underlying property. This post is about that property, and about the design method I built on top of it while working on a multi-company inventory and cost-attribution system.

{{< callout type="info" >}}
**The claim in one line.** A restriction is falsifiable by ordinary use; a freedom is not. So correctness and access should be loosened only on evidence, and starting strict is not caution, it is a way to make the system teach you what it actually needs.
{{< /callout >}}

## The asymmetry

Treat a design rule as a conjecture. "A checkout always names a company and a job." "This role can never write to that table." "Stock at a location is never negative." Each one is a claim about every future state of the system.

Now ask how each kind of claim gets refuted.

A **restrictive** claim is refuted by a counterexample that shows up in normal operation. If "a checkout always names a job" is too strict, then sooner or later a real, legitimate checkout that genuinely has no job will be attempted, and the rule will reject it. That rejection is loud, located, and immediate. It happens at a specific line, on a specific action, in front of a specific person who was trying to do something reasonable. The system has just handed you a refutation and, with it, a design question you did not know you had.

A **permissive** claim does not work this way. If "this role can write to that table" is too loose, nothing legitimate breaks. Every correct workflow keeps running. The over-permission produces no counterexample during ordinary use, because ordinary use does not try to do the forbidden thing. The refutation only arrives when something abnormal happens: a bug writes where it should not, a compromised credential does what it was allowed to do, data drifts because two paths both had write access. The signal comes late, it comes as harm, and it is hard to trace back to the decision that caused it.

{{< mermaid >}}
flowchart TB
    subgraph strict["Too strict (falsifiable)"]
        s1[Legitimate action attempted] --> s2[Rule rejects it]
        s2 --> s3[Loud, located signal now]
        s3 --> s4[Loosen on evidence]
    end

    subgraph loose["Too loose (not falsifiable by use)"]
        l1[Ordinary use never tries the forbidden thing] --> l2[No signal]
        l2 --> l3[Exploited or drifts later]
        l3 --> l4[Discovered as harm, hard to trace]
    end

    style strict fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style loose fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

The asymmetry is not about how bad the two errors are. It is about which one is *observable*. An over-restriction is a testable hypothesis that ordinary operation is constantly trying to falsify for free. An over-permission is a hypothesis that ordinary operation never tests at all.

## Why the direction matters

If only one of your two possible errors is observable, the safe direction to build in is the one where your errors are the observable kind.

Start strict. Let the system reject things. When it rejects something legitimate, you get a precise, timely, self-reporting signal, and you loosen the rule with evidence in hand: a real workflow that needs the exception. Every relaxation answers a demonstrated need.

Start permissive and you get no such education. The system runs smoothly while being wrong, and you find out how wrong at the worst possible time. "We will lock it down later" fails because "later" has no trigger. Nothing tells you the freedom was a mistake until the mistake is realized.

This reframes a practice that usually gets sold as discipline or paranoia. Least privilege is not mainly about assuming a bad actor. It is about choosing the error you can see. Default-deny is the same move: it makes your access model falsifiable, so the denials become your requirements-gathering. Every time a legitimate action is denied, someone tells you exactly which grant is actually needed. You build the access model out of real, evidenced needs instead of a guessed-at set of permissions you can never later prove you should not have handed out.

{{< callout type="warning" >}}
**The trap in "we will restrict it later."** Loosening has a natural trigger (something legitimate breaks). Tightening does not. There is no event in normal operation that says "you granted too much." So a system that starts loose tends to stay loose until an incident forces the question, which is the most expensive way to learn it.
{{< /callout >}}

## Invariants as a discovery instrument

The usual way to talk about invariants is defensive: they forbid bad states, they protect the data, they are guardrails. That framing is correct and it undersells them.

An invariant is also a probe. Because a strict rule is falsifiable by use, encoding one makes the domain's real exceptions announce themselves. The rule you were not sure about becomes an experiment the system runs continuously on your behalf.

A concrete case. In the inventory system, one of the earliest invariants was that every checkout of material must be attributed: it must name the consuming company and the job it is for. That is the whole point of the system, so it went in as a hard rule at the point of write. Then a real workflow hit it and bounced: material pulled not for any specific job, but as general truck stock, common supplies kept on a vehicle and drawn down over time. The strict rule rejected a legitimate action, and that rejection was the discovery. Nobody had raised truck stock in any planning conversation. The invariant found it, by refusing to represent a state that turned out to be real.

That inverts the usual order. We tend to assume discovery produces the rules: you learn the domain, then you encode what you learned. But a strict invariant produces discovery. It interrogates the domain by forbidding things, and every legitimate thing it wrongly forbids is a requirement you had not captured yet.

So the counterintuitive practice is: when you are unsure whether a rule holds, encode it as an invariant anyway, at the strict end, and let the violations enumerate the cases you missed. This only works because of the asymmetry. If you resolve your uncertainty by allowing the questionable case "to be safe," you learn nothing, because permission is silent. If you resolve it by forbidding the case, the domain corrects you out loud.

## Construction beats verification

There is a second choice hiding inside "encode it as an invariant," and it decides whether the asymmetry pays off or not: *how* the invariant is enforced.

Two options.

**Verification** means the invalid state is representable, and something checks for it at runtime and raises. A guard at the top of a function. A validation layer. A test that runs in CI. The claim you get is "no known violations," which is an empirical claim: correct because a check ran and passed, this time, on the paths that were exercised.

**Construction** means the invalid state cannot be represented at all. A CHECK constraint, a foreign key, a unique index, a derived view, a withheld privilege, a type that does not admit the bad case. The claim you get is "this class of violation cannot exist," which is categorical. Nothing has to run at the right moment, because the shape of the data or the privileges of the identity is the rule.

| | Verification | Construction |
|---|---|---|
| Invalid state | representable, caught at runtime | cannot be represented |
| Claim | "no known violations" | "this cannot exist" |
| Depends on | the check running on every path | nothing, it is structural |
| New code paths | must re-invoke the guard | covered automatically |
| Threat model | needs one | irrelevant, stops accidents and attacks alike |

Two consequences make construction the right default, and both are what let you build fast and refactor freely later.

It is **threat-independent**. A construction stops a careless write exactly as it stops a malicious one. You do not need to assume an adversary, only that people make mistakes, which they do.

It **closes the whole class, including code that does not exist yet**. A construction holds across every future write path, every new caller, every adapter you have not written. A runtime guard has to be re-invoked by every caller, forever, and the day a new path forgets it, you have a silent hole, exactly the silent-freedom failure from the asymmetry.

In the inventory system, this played out in specifics. "Stock never goes negative" became a construction by materializing the balance in a table with a `CHECK (quantity >= 0)` and a locked upsert, rather than summing rows and comparing in application code. "The ledger is append-only" became a construction by privilege: the application role has no `UPDATE`, `DELETE`, or direct `INSERT` on the ledger and can only call a small set of governed write functions, so history cannot be rewritten by any path, present or future. The blocking trigger that used to enforce it was demoted to a backstop.

{{< callout type="success" >}}
**The honest exception.** Not everything can be a pure construction. One invariant, valid custody of a serialized unit, guards a *transition* (available becomes checked-out becomes available), which a per-row constraint cannot express. It stays a trigger. The rule is not "never use runtime enforcement." It is: push every invariant to the strongest form it can reach, fall back only when a construction is genuinely impossible, and then bound the blast radius. Name the exceptions so they stay exceptions.
{{< /callout >}}

Construction is also what makes the asymmetry safe to exploit. If you are going to start strict and loosen later, you want "strict" to fail loudly and structurally, not to depend on a guard some future code path remembers to call. A constructed restriction cannot be silently bypassed. That is the property that lets you treat your invariants as a reliable discovery instrument rather than a hopeful one.

## The other half: a register for what you have not decided

Invariants handle what must always be true. They do not handle what you have not figured out yet, and on any real project that is most of it. This is where the method needs its second structure.

Every open or consequential design choice gets an entry in a decision register, each with an identifier. I number them D1, D2, D3, and so on. An entry records the question, the options, a reasoned default, who owns the answer, and, once it lands, the answer itself, stored verbatim and dated rather than paraphrased into a conclusion.

The register does two things that are easy to underrate.

First, it makes "decided versus open" a visible, single-source fact. Discovery on a cross-functional system is a fog of half-answers from different people at different times. The register is where the fog condenses into a list you can act against.

Second, and this is the part with no equivalent in the invariant world, it lets you **build ahead of your unknowns**. For that, each decision needs one more field.

### Classify by blast radius

Tag every decision as one of two kinds.

A **fork** changes the primary key or the grain of a core table. It must settle before that part of the schema hardens, because getting it wrong means a migration of the shape of your data, not just a new column. Unit of measure was a fork: if the system had needed to buy in one unit and consume in another, the stock table's grain would have changed. Cost method was a fork: average cost and layered FIFO are different shapes, and FIFO would have added a whole reservation concept.

An **additive** decision is one the schema can absorb later with a new column, view, or table. It does not block the core, so you defer it without cost.

{{< mermaid >}}
flowchart LR
    d[Open decision] --> q{Changes a core<br/>table's key or grain?}
    q -->|Yes| f[Fork: settle before<br/>hardening the schema]
    q -->|No| a[Additive: default now,<br/>absorb later]

    style d fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style f fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style a fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

This one tag is what tells you where you can move now and where you have to wait. You build everything not gated by an open fork. For each open fork, you pick a reasoned default, build on it, and write down its flip-cost: what changes if the answer comes back different. Then you keep going. You are never blocked waiting for an answer, and you are never surprised by where an answer lands, because you already recorded what it touches.

### Thread the identifier through the code

The decision identifier is not just a register key. It goes into the code, as a comment on the exact line a decision touches, and into the docs, next to the same number. The cost-basis function carries the cost-method decision's number. The reorder-point table carries the replenishment decision's number.

Now the identifier is a join key across four artifacts:

{{< mermaid >}}
flowchart LR
    a[Stakeholder answer] --- b[Register entry]
    b --- c[Schema code]
    c --- d[Docs]

    style a fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style b fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style c fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style d fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

When an answer finally lands, you grep the number. Everywhere it touches, the decision, its default, its enforcement, its documentation, surfaces at once. "When a decision lands, find exactly what to change" becomes a one-command operation instead of an archaeology project. This is the difference between a decision register that is a retrospective log and one that is a live part of the build.

## The register's blind spot

There is a failure mode the register does not catch, and it is the dangerous one.

The register holds the decisions you *noticed* were decisions. Its blind spot is the choice the schema made silently, an assumption baked into a column, a grain, or a cardinality that never got a number because nobody saw it as a fork. These are the real risk. Not the open question you are holding with a default, but the fork you did not know existed.

The inventory system had two, and both stayed invisible until data exposed them. The schema modeled location as first-class and multi-location-ready, but every workflow assumed a single warehouse. It was never a numbered decision. Separately, the design assumed every item was tracked by quantity, though it also supported serialized units. Neither was a conscious choice on the record. Both surfaced only when I finally profiled a real data export and the shape of the data answered questions I had not asked.

The complement the register needs is an **assumption audit**: periodically read the schema against the domain and, at every point, ask "could this have gone another way, and if so, where is its number?" Every place the design took an arbitrary path without one is an unregistered decision. The usual hiding spots are a `NOT NULL` that encodes a policy, a single-valued column that reality might make multi-valued, an implied cardinality (one location, one company per job), a grain chosen for convenience, a field left out. Promote each to a numbered decision even when the answer is "keep the assumption," because now it is tracked, greppable, and carries a flip-cost instead of lurking.

Discovery finds the questions your stakeholders raise. The assumption audit finds the questions the schema raises and nobody asked. Registering an implicit decision converts an unknown unknown into a known default, which is the only form the rest of the method can act on.

## Invariants are not frozen either

One more correction to the tidy version of this story. It is tempting to say "identify the invariants first, then discover the decisions." Reality is messier and better.

The core invariants are usually readable from the shape of the problem at the start. An inventory-and-attribution system is going to have an append-only record, non-negative stock, and mandatory attribution no matter what the details turn out to be. Those anchor the initial design.

But the invariant set is not fixed. As decisions resolve, invariants get added, extended, or relaxed. Late in the inventory build, a review added two new invariants (consumption must carry a cost; a serialized-unit movement must be self-consistent) and extended an existing one to cover returns as well as checkouts. A different answer on the cost-method fork would have added a reservation invariant. Invariants and decisions co-evolve: resolving a decision can change the invariant set, and encoding a new invariant can open a decision (that is the discovery-instrument effect again). You start with the core you can see, and the rest accrete as the domain corrects you.

## Relation to prior work

The parts of this have clear ancestry, and naming it is the honest thing to do.

Enforcing correctness as invariants is design by contract, from Bertrand Meyer. Making invalid states impossible to represent rather than checking for them is type-driven development, and at its limit correct-by-construction from formal methods. Recording decisions is the tradition of architecture decision records and of RAID logs in project management. Constraints as invariants in a database are ordinary practice for anyone who has written a CHECK. The overall stance is close to test-driven development in spirit, specify correctness first and let it drive the build, though it sits one level up: the specification is a universal invariant enforced by construction, not an example checked at runtime, and a failing rule surfaces a missing decision rather than a missing line of code. The epistemic core is Popper's falsifiability, applied to invariants and access rather than to scientific theories.

What I think is original is the composition, plus two claims that do not come from those sources.

The first is the **falsifiability asymmetry** itself: that a restriction is falsifiable by ordinary use and a freedom is not, so correctness and access should be loosened only on evidence, and over-strictness is a discovery instrument rather than a defect. "Fail closed," "least privilege," and "tests drive design" are all folklore I inherited. I have not seen them connected into a single claim about why strictness is epistemically privileged: only restrictions are self-reporting, so build from restrictions and let use tell you where they are wrong.

The second is the **decision as a live, classified, greppable thread** you build ahead of: fork versus additive by blast radius, defaulted with a known flip-cost, its identifier threaded through code and docs. Architecture decision records are retrospective, and decision logs do not touch the code. Treating a decision as a build-ahead primitive with a physical presence in the schema is the operational piece.

The pieces are borrowed. These two claims, and the way they lock together, are the part I would defend as mine.

## Where to start

You do not need any of the machinery to get the value. The on-ramp is two habits.

Write down the invariants you can already read from the problem, and enforce each in the strongest form it can reach: unrepresentable if possible, a bounded guard if not. Then keep a numbered list of the decisions you have not made, with a default and an owner for each, and tag every one fork or additive so you know what you can build on today.

That is most of it: enforce what must be true, track what you have not decided, and let the strict rules fail loudly enough to teach you the rest. The deeper parts, the assumption audit, threading identifiers into the code, treating invariants as probes, are refinements you adopt when you feel the need, not a ceremony you clear up front.

The one idea I would take even if you take nothing else: when you are unsure, restrict. You can always see what a restriction is costing you. You cannot see what a freedom is costing you until it is too late.
