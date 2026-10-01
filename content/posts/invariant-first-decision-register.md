---
title: "Invariant-First, Decision-Register-Driven Development"
date: 2026-09-25
draft: false
math: true
tags: ["invariants", "decision-records", "architecture-decision-records", "requirements", "schema-design", "correctness-by-construction", "postgresql", "design-by-contract", "type-driven-development", "make-illegal-states-unrepresentable", "least-privilege", "database-design", "constraints", "software-architecture", "software-design"]
categories: ["architecture", "software-design"]
description: "A method for building a system correctly while discovery is still incomplete: anchor correctness in invariants enforced by construction, and track every open choice as a numbered, classified decision you build ahead of."
summary: "You rarely know everything before you have to start building. This is the workflow I use to build the parts that are settled, hold the parts that are not as defaulted decisions with known reversal costs, and never paint into a corner. Two anchors carry it: invariants made unrepresentable, and a decision register threaded through the code as a greppable ID."
---

Most methods assume you know the requirements before you build. You rarely do. Discovery runs for weeks, stakeholders answer in weeks, and the hard questions, the ones that change the shape of a table, are often the last ones answered. So the real problem is not "how do I build this correctly" in the abstract. It is "how do I build this correctly *now*, with half the decisions still open, without building something I have to tear out when the other half lands."

This is the method I use for that. Two structures carry the whole thing:

1. **Invariants.** The correctness properties the system must always hold, enforced by construction (a CHECK, a foreign key, a privilege, a derived view) so an invalid state cannot be represented, not merely caught when some guard happens to run.
2. **A decision register.** Every open or consequential design choice, each with a number, an owner, a reasoned default, and a classification. Discovery fills it in; the schema is built against it.

Everything else is how those two interact: how the invariants surface the decisions you missed, and how the register lets you build at full speed while questions are still open.

{{< callout type="info" >}}
**The on-ramp is small.** Write down the few invariants you already know and enforce each in the strongest form it reaches. Keep a numbered list of the open decisions. Invariants you enforce plus decisions you track is most of the value, and it fits on a page. The rest of this is the reasoning and the refinements, adopt them when you feel the need, not as ceremony up front. The method scales down to a habit.
{{< /callout >}}

This piece is the workflow. Its epistemic backbone, why starting strict is the correct bet rather than merely a cautious one, is a companion post: [the falsifiability asymmetry](/posts/falsifiability-asymmetry/). I will lean on it where the reasoning needs it and not re-derive it here.

## The process

I will use a seat-reservation system as the running example, the same domain as the companion post, because it is small enough to hold in your head and has at least one real fork in it.

### 1. Start from invariants, and keep them revisable

Read the core invariants off the shape of the problem before writing a feature. For a reservation system that is: a seat has at most one active reservation; a reservation's seat belongs to the event the reservation is for; every reservation is attributed to an order. These anchor the design, and nothing may violate them.

The set is not frozen. As decisions resolve, invariants get added, extended, or relaxed. Settling the cost or pricing model might add a new invariant; a new invariant might open a decision nobody had raised. So invariants and decisions co-evolve. The upfront core comes from the problem; the rest accrete as discovery lands.

### 2. Map discovery to a decision register

During discovery, every choice that could change the design gets a number. Each entry records the question, the options, a reasoned default, the owner, and, once it lands, the answer stored **verbatim and dated**. The register is the single place where "decided versus open" lives; code and docs point back to it, and the verbatim answer means you are acting on what the stakeholder said, not a paraphrase that drifted.

### 3. Classify each decision by impact

Tag every decision as one of two kinds. This single tag is the build scheduler.

| Kind | What it means | What you do |
|---|---|---|
| **fork** | changes the primary key or grain of a core table | settle it before that table hardens, or run on a default that dominates |
| **additive** | the schema can absorb it later with a new column, view, or table | defer it, it blocks nothing |

A fork cannot sit open under a hardened schema, because the schema was built assuming one answer. An additive decision can wait indefinitely, because whatever it resolves to is a later column or table. Knowing which is which is what tells you where you may proceed and where you must stop.

### 4. Build against the settled and defaulted set, and work ahead

Start the schema from what discovery has settled. For an open fork, pick a reasoned default, build on it, and record its **flip-cost**: exactly what changes if the answer differs. Because every open question is enumerated, owned, and classified, you are never blocked. You build everything not gated by an open fork, and you hold each open fork as a default whose reversal cost you can already see. You are working ahead of the answers, not waiting on them.

### 5. Thread each decision through the code as a greppable anchor

Comment the line a decision touches with its number, and carry the same number in the register and the docs. The number becomes a join key across four artifacts:

    stakeholder answer  ↔  register entry  ↔  schema  ↔  docs

`grep D1` then returns the decision, its default, and its enforcement in one command. When an answer finally lands, you grep its number, every place it reaches is in front of you at once, you apply the change and update the register in the same pass. "Find exactly what to change when a decision settles" stops being an excavation and becomes one command. Apply it to every fork-touched line, not just some, or the join key has holes.

{{< callout type="info" >}}
**The payoff of the five steps together.** Correctness is anchored before features exist, so nothing built later can undermine the core. Discovery is traceable: every question has an ID, an owner, a status, and a known impact. Building runs in parallel with unsettled questions without painting into a corner. And one identifier ties interview, decision, schema, and docs into a single thread you can grep.
{{< /callout >}}

## Construction beats verification

Step 1 says invariants are enforced by construction. That choice is doing more work than it looks, and it is the reason the method survives past the first version.

| | Verification (a guard) | Construction |
|---|---|---|
| Invalid state | representable, caught at runtime | cannot be represented |
| Claim it supports | "no known violations" | "this cannot exist" |
| Depends on | the check running on every path | nothing, it is structural |
| New code paths | must re-invoke the guard | covered automatically |
| Threat model | needs one | irrelevant, stops accident and attack alike |

A verified invariant is empirical: it holds because a check ran and passed, so the claim is only "no known violations." A construction is categorical: the bad state cannot be expressed, so the claim is "this class of violation cannot exist." Two properties follow, and both are about the code you have not written yet.

A construction is **threat-independent**: it stops a careless write exactly as it stops a malicious one, so the guarantee holds without positing a bad actor, only that people make mistakes. And it **closes the whole class, including future paths**: it holds across every call site and adapter that will ever touch the data, including the ones that do not exist today. A raising guard has neither property. It must be re-invoked by every caller forever, and the first new path that forgets it is a silent hole reopened.

Construction is also broader than a CHECK or a foreign key. A **withheld privilege** is one: to make a reservation ledger append-only, give the application identity no insert, update, or delete on it and let it call only the governed write functions. History cannot be rewritten by any path, not because a trigger refused the write but because the identity was never able to express it. A derived view, a unique index, a generated column are the same move: encode the rule in the shape of the data or the rights of the actor, so enforcement never depends on a check firing at the right moment.

```sql
-- "a seat belongs to at most one active reservation" by construction,
-- not by a SELECT-then-INSERT guard that a new code path can skip
create unique index one_active_hold
  on reservations (seat_id) where status = 'active';

-- "a reservation's seat belongs to its event" by construction,
-- via a composite key: a mismatched pair has no row to reference
alter table seats add constraint seats_id_event unique (id, event_id);
alter table reservations
  add constraint reservation_seat_in_event
  foreign key (seat_id, event_id) references seats (id, event_id);
```

The rule in practice: push every invariant toward construction, even when it costs more, and fall back to a raising guard only when a pure construction is genuinely impossible, then bound its impact and name it. The genuine exceptions are usually **state transitions**. "A seat moves from held to released only by the holder" is a rule about a change between two rows' states, which a per-row constraint cannot express, so it stays a trigger. That is fine as long as it is the sole write path and the derived state reconciles from the ledger. The test is not "did I avoid every trigger," it is "is every invalid state either unrepresentable or guarded on the one path that can reach it."

## Invariants as a discovery instrument

An invariant is usually sold as a guardrail: it forbids bad states. It is also a probe. Encoding a strict rule makes the domain's exceptions announce themselves, because anything the rule wrongly forbids fails loudly at a specific line.

The attribution invariant is the clean example. "Every reservation is attributed to an order" is a reasonable rule to encode strictly. Put it in as `order_id NOT NULL`, propose it in a requirements review, and a venue operator says: except house seats and press comps, those have no order. The rule just refuted itself, in a conversation, before a line of production code ran. That refutation is the discovery. Nobody had raised comps; the strict rule found them. It becomes a new decision (how are comps attributed?), resolved additively with a `reservation_kind` and a house account, and the NOT NULL stays.

This is why you encode a rule you are unsure of **as an invariant anyway** and let the violations teach you the decisions you missed. The full justification, why a too-strict rule reliably announces itself and a too-loose one does not, is the [falsifiability asymmetry](/posts/falsifiability-asymmetry/): loud restrictions, silent freedoms. The short form:

- A too-strict invariant fails **closed and loud**. A legitimate action is blocked, an immediate, located, self-reporting signal. You loosen it with evidence in hand: the real workflow that needs it.
- A too-loose invariant fails **open and silent**. An illegitimate action is permitted with no signal at all, found only by the harm it causes later, and hard to trace back to its cause.

So the direction is **start strict, relax on evidence**: every relaxation answers a demonstrated need, never a precaution. The same logic makes least privilege a method rather than a slogan. Default-deny, then grant only when a denied legitimate action proves the grant is needed. The denials become your requirements-gathering for access. The application identity holds no write on the ledger and can only call the governed functions; any capability it lacks is added on evidence, not handed over up front to be safe.

## The assumption audit

The register captures the decisions you *noticed* were decisions. Its blind spot is the unregistered choice already baked into the schema: an assumption in a column, a grain, or a cardinality that never got a number because no one saw it as a fork. These are the real risk. Not the open fork you are holding with a reasoned default, but the fork you did not know existed.

Because a missing restriction makes no sound, you have to go looking. Read the schema against the domain and ask, at every point, "could this have gone another way, and if so, where is its number?" Each place the design took an arbitrary path without one is an unregistered decision.

The reservation schema has one hiding in the word "seat." The schema treats a seat as a physical chair. But a recurring show reuses the same chair across many nights. Is a seat the chair, or the (chair, night) pair? Nobody decided that; the schema just assumed the first. It becomes a tracked decision with a flip-cost, whatever its answer. The usual hiding spots: a `NOT NULL` that encodes a policy, a single-valued column reality might make multi-valued, an implied cardinality (one seat per chair, one order per reservation), a grain chosen for convenience, a field left out.

{{< callout type="warning" >}}
**Two kinds of discovery.** Stakeholder discovery finds the questions people raise. The assumption audit finds the questions the schema raises and no one asked. Promote each silent assumption to a number even when the answer is "keep the assumption," because now it is tracked, greppable, and carries a flip-cost instead of lurking. Registering an implicit decision converts an unknown unknown into a known default, which is the only form the rest of the method can act on.
{{< /callout >}}

## A decision, end to end

Here is one fork from default through settlement, so the moving parts are concrete.

**D1: assigned seats, or general admission?** This is a fork, because the two answers want different grains. Assigned seating wants one row per seat. General admission wants a single decrementing count. You cannot leave that open and harden the reservation table on top of it.

- **Registered** as a fork, with both options, an owner, and a flip-cost.
- **Defaulted** to assigned seating, because it *dominates*: you can model general admission as one big pooled "section" of assigned seats, but you cannot model assigned seating on top of a bare counter. A dominating default is one you can build on without betting the schema, because the other answer is a special case of it.
- **Anchored** in the code: a `D1` comment on the reservation-grain definition and on the pooled-section shim.
- **Flip-cost recorded**: if the answer were ever "GA only, and we want the counter grain for performance," swap per-seat rows for a capacity counter on those sections. Bounded, and written down.

So you build the whole reservation flow on assigned seating while D1 is still formally open, because the default dominates and its reversal cost is known. If the venue later confirms assigned seating, nothing changes. If they want pure GA, `grep D1` returns the grain definition, the shim, and the register entry at once, and you change exactly those. The default held until the decision landed, and it was never wrong to build on, it was the safe way to work ahead of an open fork.

## Why it works

- Correctness is anchored first, so features cannot undermine the core.
- Discovery is traceable: every question has an ID, an owner, a status, and a known impact.
- Building proceeds in parallel with unsettled questions without painting into a corner.
- One identifier ties interview, decision, schema, and docs into a single greppable thread.
- Answers are evidence, stored verbatim and dated, not paraphrased into assertion.

## Starting a new project with this

1. Write the invariants you can read from the problem shape. Decide how each is enforced by construction.
2. Open a decision register. As discovery raises choices, add a number, options, a default, and an owner for each.
3. Tag every decision fork or additive.
4. Build the schema against the settled and defaulted set; anchor each decision with its number in the code and the register.
5. Iterate: as answers land, grep the number, apply the change, revise invariants if the answer demands it, and keep the register and docs current in the same pass.

## Relation to prior work

The parts have clear ancestry, and it is worth naming them. Enforcing correctness as invariants is design by contract (Meyer). Making invalid states impossible to represent rather than checking for them is type-driven development, and at its limit correct-by-construction from formal methods. Recording decisions is the tradition of architecture decision records and RAID logs. Constraints as invariants in a database are ordinary practice. The stance is close to test-driven development in spirit, specify correctness first and let it drive the build, though it sits one level up: the specification is a universal invariant enforced by construction, not an example checked at runtime, and a failing rule surfaces a missing decision rather than a missing line of code. The epistemic half draws on Popper, applied to invariants and access rather than to scientific theories.

What is original is the composition, plus two claims that lock together. The first is the [falsifiability asymmetry](/posts/falsifiability-asymmetry/), developed in the companion post: a restriction is falsifiable by ordinary use and a freedom is not, so correctness and access should be loosened only on evidence, and over-strictness is a discovery instrument rather than a defect. The second is this post's center: **the decision as a live, classified, greppable thread you build ahead of**, fork-versus-additive by impact, defaulted with a known flip-cost, its number threaded through code and docs, where decision records are retrospective and decision logs never touch the code. The pieces are borrowed. The two claims, and the way the asymmetry justifies the strictness that the register then keeps cheap to revise, are the contribution.

---

Companion piece: [The Falsifiability Asymmetry: Loud Restrictions, Silent Freedoms](/posts/falsifiability-asymmetry/), the epistemic argument for why starting strict is the privileged bet and when that privilege lapses.
