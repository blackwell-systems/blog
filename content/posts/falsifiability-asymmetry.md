---
title: "The Falsifiability Asymmetry: Loud Restrictions, Silent Freedoms"
date: 2026-09-25
draft: false
tags: ["invariants", "correctness", "software-architecture", "database-design", "postgresql", "design-by-contract", "type-driven-development", "make-illegal-states-unrepresentable", "least-privilege", "security", "falsifiability", "observability", "adversarial-testing", "requirements", "user-acceptance-testing", "qa", "schema-design", "constraints", "correctness-by-construction", "software-design"]
categories: ["architecture", "software-design"]
description: "A system tells you when you forbid too much and stays quiet when you allow too much. That asymmetry has a direction, a lifecycle, and clear conditions under which it breaks."
summary: "You find an over-restriction because something legitimate breaks and points at the spot, and it breaks earlier the earlier you encode the rule. You do not find an over-permission the same way, because nothing legitimate ever exercises it. Here is the asymmetry, a worked example, and where it stops being true."
---

I once built a seat-reservation system that would happily sell you a seat belonging to a different show. Not a seat in the wrong row. A seat that was part of an entirely different event, in a different theater, on a different night, attached by mistake to the reservation you were making. The write succeeded. No error fired. The confirmation email went out.

I found it because I sat down and tried to break the thing on purpose. Ordinary use never would have, because ordinary use never tries to reserve a seat from the wrong show.

That is the whole argument of this post. A system will tell you when you forbid too much. It will not tell you when you allow too much. I call this the **falsifiability asymmetry**, and the short version is: loud restrictions, silent freedoms.

The deepest form of it is a distinction about where the counterevidence comes from. **Restrictions can be falsified by demand. Permissions usually have to be falsified by attack.** The evidence that you forbade too much arrives on its own, carried in by someone who wanted to do the thing. The evidence that you allowed too much has to be manufactured, by someone deliberately probing for what should not be possible. That difference in the source of counterevidence is what everything below turns on.

The idea fits in a sentence, so most of the post is the two things that make it more than a slogan: a worked example of using it, and the conditions under which it breaks.

{{< callout type="info" >}}
**The claim.** An over-restriction produces an observable event during ordinary operation. An over-permission does not. So you can learn you were too strict, often early and cheaply, and you cannot learn you were too loose the same way. Build in the direction where your errors are the kind you can see.
{{< /callout >}}

## The asymmetry

Treat a design rule as a conjecture about every future state of the system. "Every reservation belongs to a customer." "A seat can be held by at most one active reservation." "A reservation's seat belongs to the event the reservation is for."

Now ask how each kind of conjecture gets refuted.

A **restrictive** conjecture is refuted by a counterexample that normal work produces on its own. If "every reservation belongs to a customer" is too strict, then sooner or later someone tries to make a legitimate reservation with no customer, and the rule rejects it. That refutation is loud and located: a specific action, a specific message, in front of a specific person who wanted to do something reasonable.

A **permissive** conjecture is not refuted by normal work, because normal work never attempts the forbidden thing. If "a reservation can reference any seat" is too loose, every correct booking still succeeds. Nobody in the course of ordinary use tries to attach a seat from another show. The refutation arrives only when something abnormal happens: a bug, a bad import, a malicious request, a corner of the UI nobody tested. It comes late, as damage, and it is hard to trace back to the decision that allowed it.

The asymmetry is not about which error is worse. It is about which error is **observable**. An over-restriction is a hypothesis that ordinary operation is constantly trying to falsify. An over-permission is a hypothesis that ordinary operation never tests at all.

I am borrowing "falsifiability" from Popper as an analogy, and the borrow is worth stating precisely. Popper's concern was demarcating science: a theory that forbids nothing predicts nothing and cannot be tested. The mechanism here is narrower and concrete, the asymmetric observability of two error types under a system's own use. Later I will lean on the standard objection to naive falsificationism, because it describes exactly the case where this breaks.

## The lifecycle: where the refutation actually happens

The important correction to make early is that "ordinary use" is not just production. A restriction is a conjecture that gets tested at every stage of the lifecycle, and the earlier you state it, the earlier and cheaper the refutation.

Consider "every reservation belongs to a customer" moving through the pipeline:

- **Requirements.** You propose the rule in a review, and a venue operator says "except house seats and press comps, those have no customer." The rule is refuted in a conversation, before a line is written. That is the cheapest possible refutation.
- **QA.** The rule is a constraint in the schema. A test that books a comp fails, and points at the exact constraint.
- **User acceptance testing.** A real box-office user tries to hold house seats and hits the wall, and files it.
- **Production.** The last line of defense, and the most expensive place to learn it.

{{< mermaid >}}
flowchart LR
    r[Requirements review] --> q[QA / negative tests]
    q --> u[UAT]
    u --> p[Production]

    r -.cheapest.-> cost[Cost of the refutation]
    p -.most expensive.-> cost

    style r fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style q fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style u fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style p fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style cost fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

This is the productive half of the asymmetry, and it is most of what requirements gathering and acceptance testing actually are: a strict proposal ("this must always be true") getting bounced by a real case that contradicts it. Stating the restriction early is what makes the bounce happen early. A rule you only encode as a scattered runtime check does not get tested until code exercises that path; a rule you state as an invariant in the requirements gets tested by a human in the room.

Now hold that thought against the other half. An over-restriction generates its own counterexample from legitimate demand; an over-permission does not, so it surfaces only when someone sets out to generate the counterexample on purpose. Requirements review does not raise it, because nobody proposes "we must be allowed to attach a seat from the wrong show." QA catches it only if someone writes a negative test aimed at the forbidden thing. UAT does not catch it, because acceptance testing exercises the workflows users want, and no user wants to book the wrong show's seat. The happy path is blind to silent freedoms by construction; only deliberately adversarial testing sees them. That is why the wrong-show seat survived all the way to me trying to break it.

{{< callout type="warning" >}}
**Two blind spots, one cause.** Requirements, QA-by-example, and UAT are all built around what people are trying to do. They are excellent at catching over-restrictions (a legitimate goal is blocked) and nearly useless at catching over-permissions (nobody's goal is the forbidden action). Over-permissions need a different activity: negative testing and adversarial review, aimed at what should be impossible. In a phrase: over-restrictions are falsified by demand, over-permissions only by attack.
{{< /callout >}}

## Where it breaks

A claim you cannot break is not worth much, so here is where this one does.

**Over-restrictions can be silent too, when the blocked person can route around them.** The "loud" argument assumes the person who hits the wall engages with it: complains, files it, asks for the exception. If they have an escape hatch, they take it, and the over-restriction fails as silently as any over-permission. They keep a side spreadsheet. They stop using the feature. They type a junk value that satisfies the rule and voids its meaning (a placeholder customer named "WALK-IN" that swallows every unattributed booking). A rule that is easy to bypass converts its own refutations into workarounds, and you never hear them.

This is the software version of the Duhem-Quine objection to naive falsificationism: a hypothesis is never tested in isolation, and a refutation can always be deflected elsewhere rather than accepted. Here the "elsewhere" is human. The asymmetry holds only when the restriction sits on a path the actor cannot route around.

**Some over-permissions are loud.** A too-loose type that admits a nonsense value can crash immediately downstream. That is the lucky case. The dangerous over-permissions are the ones that do not crash: the security hole, the slow drift, the corrupt-but-well-formed row. So the precise phrasing is that restriction errors are *reliably* observable when the restriction is unavoidable, and permission errors are *not reliably* observable at all.

Together those give two conditions, so the asymmetry is a tendency, not a law:

{{< mermaid >}}
flowchart TB
    subgraph holds["Asymmetry is strong"]
        h1[Restriction sits on an<br/>unavoidable path]
        h2[Over-permission enables a state<br/>that does not crash immediately]
    end

    subgraph weak["Asymmetry is weak or reversed"]
        w1[Blocked actor can route around:<br/>over-restriction goes silent]
        w2[Over-permission crashes at once:<br/>permission self-reports]
    end

    style holds fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style weak fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

This is why the pattern is strongest in systems of record, access control, and data integrity, and weakest in throwaway UIs and stateless transforms. A booking store with a single mandatory write path is close to the ideal case. A prototype nobody depends on is the worst: friction is expensive, reversibility is cheap, and there is no persistent state to corrupt.

## The prescription, and what it costs

If your two possible errors differ in observability, build in the direction where your errors are the observable kind. State restrictions early and strictly, so their refutations happen early in the lifecycle where they are cheap. Loosen on evidence: a real case that contradicts the rule, whether it shows up in a requirements review or in production.

This reframes least privilege as an epistemic choice rather than a security ritual. Default-deny is attractive because it makes your access model falsifiable: the denials become requirements-gathering. Each denied legitimate action tells you exactly which grant is genuinely needed, so you build access out of evidenced needs instead of a guessed-at set you can never later prove you should not have granted.

The cost is real and worth stating, because a rule with no downside is being oversold. Strict-first has a friction cost: every false rejection is a legitimate action interrupted, and if the actor can route around, that friction becomes the silent-abandonment failure above. It has a velocity cost in exploration: when you are still learning the domain and most rules are guesses, aggressive strictness rejects things faster than you can adjudicate. So the boundary is: start strict when state is persistent and shared, the write path is unavoidable, and a wrong freedom is expensive to reverse. Start loose when you are prototyping, reversibility is cheap, and interrupting legitimate work costs more than a freedom you can clean up later.

## Why the strict rules have to be structural

One failure mode defeats the whole approach: enforcing restrictions with runtime guards instead of structure. If "strict" means a check at the top of one function, a new code path that forgets it reintroduces the silent freedom, and your loud rule is only loud on the paths that remember it.

The distinction is verification versus construction.

| | Verification | Construction |
|---|---|---|
| Invalid state | representable, caught at runtime | cannot be represented |
| Claim it supports | "no known violations" | "this cannot exist" |
| Depends on | the check running on every path | nothing, it is structural |
| New code paths | must re-invoke the guard | covered automatically |
| Threat model | needs one | irrelevant, stops accident and attack alike |

The wrong-show seat is a good illustration of the fix. The bad state was a reservation whose seat and event disagreed. Made unrepresentable with a composite foreign key:

```sql
-- a seat is unique within its event
alter table seats add constraint seats_id_event unique (id, event_id);

-- a reservation can only point at a seat whose event matches its own
alter table reservations
  add constraint reservation_seat_in_event
  foreign key (seat_id, event_id) references seats (id, event_id);
```

Now a reservation that names a seat from another event has no valid row to reference. It is not caught at runtime; it cannot be written, by any code path, present or future. That is what makes the restriction reliably loud, which is the precondition for trusting it as a signal. Push every restriction to the strongest form it can reach, fall back to a runtime guard only when construction is genuinely impossible, and keep those exceptions few and named.

## The method, worked

The machinery below is in service of the asymmetry, not a rival to it. Fork-versus-additive classification, dominance defaults, flip-costs, and greppable decision IDs are almost enough for their own article, and they earn their place here only as the concrete way you act on both halves of the property: get an over-restriction's refutation to arrive early and cheap, and go hunting for the silent freedoms that demand will never bring you. Here is the process end to end on the reservation system, small enough to follow.

**1. Write the invariants you can read from the shape of the problem, and make each unrepresentable.**

| Invariant | Enforcement |
|---|---|
| A seat has at most one active reservation | partial unique index on `reservations (seat_id) where status = 'active'` |
| A reservation's seat belongs to its event | the composite foreign key above |
| Every reservation is attributed | `order_id` NOT NULL (see D1, this one moved) |

These are the strict rules, and by the earlier argument they are also the discovery instrument.

**2. Put everything you have not settled in a decision register, each with a number, an owner, a default, and a classification.** The classification is the useful part: a **fork** changes the primary key or grain of a core table and must settle before that table hardens; an **additive** decision can be absorbed later with a new column or table, so you defer it.

| ID | Question | Kind | Default | Flip-cost |
|---|---|---|---|---|
| D1 | Assigned seats or general admission? | fork (changes reservation grain) | assigned; model GA as one pooled section | swap per-seat rows for a capacity counter |
| D2 | Waitlist when sold out? | additive | none in v1 | add a waitlist table |
| D3 | Temporary holds during checkout? | additive | 10-minute hold via status + expiry | none structural |

D1 is a fork because assigned seating wants one row per seat while general admission wants a single decrementing count, a different grain. You cannot leave that open and harden the schema on top of it, so you settle it or you choose a default that dominates. Assigned seating dominates (you can model general admission as one big pooled section), so you build on that and record what a reversal would cost. D2 and D3 are additive, so they wait without blocking anything.

Thread each number through the code as a comment on the line it touches, so `grep D1` later returns the decision, its default, and its enforcement at once.

**3. Let the strict rules surface the decisions you missed.** In the requirements review, the attribution invariant ("every reservation has a customer") gets bounced: house seats and comps have no customer. That refutation, in a conversation, is worth more than the rule was. It becomes a new decision:

| ID | Question | Kind | Resolution |
|---|---|---|---|
| D4 | How are house seats / comps attributed? | additive | a `reservation_kind` of `comp`, attributed to a house account; the NOT NULL stays |

The rule was not wrong to encode strictly. Encoding it strictly is what surfaced D4 at the cheapest possible moment.

**4. Because freedoms are silent, run an assumption audit.** The register only holds decisions you noticed making. So read the schema against the domain and ask, at every column, "could this have gone another way, and where is its number?" On this system the audit finds an unregistered fork hiding in the word "seat": the schema treats a seat as a physical chair, but a recurring show reuses the same chair across many nights. Is a seat the chair, or the (chair, night) pair? Nobody decided that; the schema just assumed one. It becomes D5, promoted from a silent assumption to a tracked decision with a flip-cost, whatever its answer.

That audit is the same move as the adversarial test that found the wrong-show seat: since a missing restriction makes no sound, you go looking for what the system wrongly permits instead of waiting for it to tell you.

## Relation to prior work

The pieces have clear ancestry and naming it is the honest thing to do. Enforcing correctness as invariants is design by contract (Meyer). Making invalid states impossible to represent is type-driven development, and at its limit correct-by-construction from formal methods. Numbering decisions is the tradition of architecture decision records. Constraints as invariants in a database are ordinary practice. The stance is close to test-driven development in spirit, specify correctness first and let it drive the build, though it sits a level up: the specification is a universal invariant enforced by construction rather than an example checked at runtime, and a failing rule surfaces a missing requirement rather than a missing line of code. The epistemic frame is Popper's, with the Duhem-Quine objection doing real work rather than being waved off.

What I would claim as original is the falsifiability asymmetry itself, stated with its conditions and its lifecycle: a restriction is reliably observable when it is unavoidable and a permission is not, the refutation of an over-restriction lands earlier the earlier you encode it, and the happy path is blind to over-permissions unless someone sets out to generate the counterexample. "Fail closed," "least privilege," "shift left," and "tests drive design" are folklore I inherited; connecting them into one claim about why strictness is epistemically privileged, and being exact about when the privilege lapses, is the part I have not seen written down.

The decision-register machinery around it is not a second theory, and I do not want to sell it as one. Fork-versus-additive, dominance defaults, flip-costs, and greppable IDs are mostly assembled from architecture decision records, with one wrinkle I find underused: treating a decision as a live thread you build ahead of rather than a note you write after the fact. It is in this post as the way you act on the asymmetry, and it could carry its own article, but here it stays subordinate.

## Where to start

You do not need the machinery to get the value. Two habits carry most of it.

Write the invariants you can already read from the problem, state them early enough that a human can refute them in a review, and enforce each in the strongest form it can reach: unrepresentable if possible, a bounded guard if not. Then, because freedoms are silent, schedule an adversarial pass: negative tests that try to do the impossible, and a reading of the schema for the choices you made without noticing.

The one idea to keep even if you keep nothing else: when you are unsure, and the path is one people cannot route around, restrict. You can always see what a restriction is costing you. You usually cannot see what a freedom is costing you until it is too late.
