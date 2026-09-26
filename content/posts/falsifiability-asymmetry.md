---
title: "The Falsifiability Asymmetry: Loud Restrictions, Silent Freedoms"
date: 2026-09-25
draft: false
tags: ["invariants", "correctness", "software-architecture", "database-design", "postgresql", "design-by-contract", "type-driven-development", "make-illegal-states-unrepresentable", "least-privilege", "security", "falsifiability", "observability", "adversarial-testing", "decision-records", "schema-design", "constraints", "correctness-by-construction", "data-modeling", "test-driven-development", "software-design"]
categories: ["architecture", "software-design"]
description: "A system tells you when you forbid too much and stays silent when you allow too much. That asymmetry has a direction built in, plus the conditions under which it breaks."
summary: "You can discover an over-restriction because something legitimate breaks and points at the spot. You cannot discover an over-permission the same way, because nothing breaks until it is exploited. Here is the evidence, the conditions under which the asymmetry actually holds, and the method that falls out of it."
---

I shipped a schema that would record a checkout of a tool belonging to a completely different product, and accept it without complaint. The write returned an id like any other row. No error fired. I found it weeks later, not because anything broke, but because I sat down and tried to break it on purpose.

That incident is the whole argument of this post. A system will tell you when you forbid too much. It will not tell you when you allow too much. I call this the **falsifiability asymmetry**, and the short version is: loud restrictions, silent freedoms.

The idea is simple enough to state in a sentence, so most of this post is spent on the two things that make it useful rather than glib: the evidence that it is real, and the conditions under which it stops being true. The payoff is a design method, but the method is downstream of the property, so I want to earn the property first.

{{< callout type="info" >}}
**The claim.** An over-restriction produces an observable event during ordinary operation. An over-permission does not. So you can learn you were too strict for free, and you cannot learn you were too loose the same way. Build in the direction where your errors are the kind you can see.
{{< /callout >}}

## The asymmetry, stated carefully

Treat a design rule as a conjecture about every future state of the system. "A checkout always names a company and a job." "This role can never write to that table." "An item movement always refers to an instance of that same item."

Now ask how each kind of conjecture gets refuted in normal use.

A **restrictive** conjecture is refuted by a counterexample that ordinary operation produces on its own. If "a checkout always names a job" is too strict, then sooner or later someone attempts a real checkout that legitimately has no job, and the rule rejects it. The refutation is loud, located, and immediate: a specific action, at a specific line, in front of a specific person who wanted to do something reasonable. The system just handed you a design question you did not know you had.

A **permissive** conjecture is not refuted by ordinary operation, because ordinary operation never attempts the forbidden thing. If "this role can write to that table" is too loose, every correct workflow keeps running. The over-permission generates no counterexample during normal use. Its refutation arrives only when something abnormal happens: a bug writes where it should not, a compromised credential does what it was permitted to do, two code paths both had write access and the data drifted. The signal comes late, as harm, and it is hard to trace back to the decision that caused it.

The asymmetry is not about which error is worse. It is about which error is **observable**. An over-restriction is a hypothesis that normal operation is constantly trying to falsify, for free. An over-permission is a hypothesis that normal operation never tests at all.

I am borrowing "falsifiability" from Popper as an analogy, and it is worth being precise about the borrow. Popper's concern was demarcating science: a theory that forbids nothing predicts nothing and cannot be tested. The mechanism here is narrower and more concrete. It is the asymmetric observability of two error types under a system's own normal operation. The analogy is a good one, and later I will use the standard objection to naive falsificationism, because that objection turns out to describe exactly the case where this whole thing breaks.

## The evidence

I distrust design essays that only argue, so here is the incident from the top, in full, plus a second one that cost real money in the model.

The system is a multi-company inventory and cost-attribution ledger. Items come in two kinds: consumables tracked by quantity, and serialized equipment tracked as individual instances. A movement in the ledger names an item, and for equipment it also names the specific instance.

I had a rule in mind: an instance movement must refer to an instance that actually belongs to the movement's item. I had not enforced it. Nothing in the schema said the two had to agree. So I wrote a small adversarial test, building a throwaway database from the schema and calling the real write function with a deliberately mismatched pair: item A, but an instance belonging to item B.

```sql
select record_movement(
  p_item_id          => 'item-A',
  p_movement_type    => 'checkout',
  p_item_instance_id => 'instance-of-B',   -- belongs to a different item
  p_business_unit    => 'company-1',
  p_job_ref          => 'job-1'
);
-- returns a fresh movement id. no error.

select l.item_id as ledger_says, ii.item_id as instance_really_is
from ledger l join item_instance ii on ii.id = l.item_instance_id
where l.id = '<that id>';
--  ledger_says | instance_really_is
--  item-A      | item-B
```

The row was accepted. The ledger now claimed a movement of item A that pointed at an instance of item B. This is a corrupt state that no report would flag, because every individual table was internally consistent. It was a silent freedom: the schema permitted a state that should never exist, and permission makes no sound.

A second one, worse because it touches money. A return of material was allowed to omit the company it credited. When it did, the code that computes what to bill produced a null charge for that return, and the return then dropped out of the billing view entirely. The system would bill a company for material it had returned. Again: no error, no failed constraint, a clean-looking row. I only found it by constructing the exact sequence and reading the billing output.

Neither bug was found by use. Both were found by an adversarial audit, months of ordinary operation would not have surfaced either one, which is the asymmetry stated as a lab result rather than a theory. Freedoms are silent, so you cannot wait for them; you have to hunt them.

The fixes turned each silent freedom into a loud restriction, enforced structurally so it cannot be bypassed by any future caller:

```sql
-- a return must be attributed, same bar as a checkout
alter table ledger add constraint movement_return_attributed
  check (movement_type <> 'return'
         or (business_unit is not null and job_ref is not null));

-- consumption must carry a cost, so it can never post silently at zero dollars
alter table ledger add constraint movement_consumption_has_cost
  check (item_instance_id is not null
         or movement_type not in ('checkout','return')
         or unit_cost is not null);
```

After the fix, the same adversarial calls fail at the door, loudly and specifically:

```
ERROR:  instance belongs to item item-B, not the movement item item-A
ERROR:  new row for relation "ledger" violates check constraint "movement_return_attributed"
```

That is the direction you want your errors pointing. Now the mismatch is impossible to represent, and any code path that ever tries it, including code that does not exist yet, gets the same rejection.

Here is the complement, the loud restriction that taught me something instead of costing me something. Very early I had made attribution mandatory: every checkout must name a company and a job. Then a real workflow bounced off it. Crews pull common supplies that are not for any single job, kept on a truck and drawn down over time. The strict rule rejected that as an unattributed checkout, and the rejection was the discovery. Nobody had raised "truck stock" in any planning conversation. The invariant found the requirement by refusing to represent a state that turned out to be real. That is the same asymmetry running in the productive direction: a too-strict rule interrogates the domain and the domain answers out loud.

{{< callout type="success" >}}
**Two directions, one property.** The silent bugs were over-permissions, invisible to use, found only by hunting. The truck-stock case was an over-restriction, surfaced immediately by use. Same asymmetry: restrictions self-report, freedoms do not. One direction cost me a corruption I had to dig for; the other handed me a requirement for free.
{{< /callout >}}

## Where it breaks

A claim you cannot break is not worth much, so here is where this one does.

**Over-restrictions can be silent too, when the blocked party can route around them.** The whole "loud" argument assumes the person who hits the wall engages with it: complains, files it, asks for the exception. If they have an escape hatch, they take it, and the over-restriction fails as silently as any over-permission. They keep a side spreadsheet. They stop using the feature. They enter a junk value that satisfies the rule and destroys its meaning. On the inventory project this was a live risk: make the capture workflow one notch too strict or too slow, and crews would simply not log, which is a silent failure of over-restriction that shows up only as missing data, not as a rejection you can see.

This is the software version of the Duhem-Quine objection to naive falsificationism. A hypothesis is never tested in isolation; a refutation can always be deflected somewhere else in the system rather than accepted. Here the "somewhere else" is human: the refuting event (a blocked legitimate action) gets absorbed by a workaround instead of reported as feedback. The asymmetry holds only when the restriction sits on a path the actor cannot bypass.

**Some over-permissions are loud.** A too-loose type that admits a nonsense value can blow up immediately downstream. That is the lucky case. The dangerous over-permissions are precisely the ones that do not crash: the security hole, the slow data drift, the corrupt-but-well-formed row from the evidence section. So the honest phrasing is that permission errors are *not reliably* observable, while restriction errors are *reliably* observable when the restriction is unavoidable.

Putting those together, the asymmetry is a tendency with two conditions, not a law:

{{< mermaid >}}
flowchart TB
    subgraph holds["Asymmetry is strong"]
        h1[Restriction sits on an<br/>unavoidable path]
        h2[Over-permission enables a state<br/>that does not immediately crash]
    end

    subgraph weak["Asymmetry is weak or reversed"]
        w1[Blocked actor can route around<br/>the rule: over-restriction goes silent]
        w2[Over-permission crashes loudly<br/>right away: permission self-reports]
    end

    style holds fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style weak fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

This is why the pattern is strongest in systems of record, access control, and data integrity, and weakest in throwaway UIs and stateless transforms. A ledger with a mandatory write path is the ideal case: the actor cannot route around the constraint, and the bad states it prevents are the quiet, corrupting kind. A prototype nobody depends on is the worst case: friction has a high cost, reversibility is cheap, and there is no persistent state to corrupt.

## The prescription, and what it costs

If your two possible errors are asymmetric in observability, build in the direction where your errors are the observable kind. Start strict. Let the system reject things. When it rejects something legitimate, you get a precise, timely, self-reporting signal, and you loosen the rule with evidence in hand.

This reframes least privilege as an epistemic choice rather than a security ritual. Default-deny is attractive not mainly because it assumes an attacker, but because it makes your access model falsifiable: the denials become requirements-gathering. Each denied legitimate action tells you exactly which grant is genuinely needed, so you build the access model out of evidenced needs instead of a guessed-at set you can never later prove you should not have handed out. Access is lowered on an evidenced basis, which is the direction the asymmetry favors.

The cost is real and worth stating plainly, because a rule with no downside is being oversold.

- Strict-first has **friction cost**. Every false rejection is a legitimate action interrupted. If the actor can route around, that friction converts directly into the silent-abandonment failure above.
- It has a **velocity cost** in exploration. When you are still learning the shape of the problem and most of your rules are guesses, aggressive strictness rejects things faster than you can adjudicate them.

So the honest boundary: start strict when the state is persistent and shared, the write path is unavoidable, and a wrong freedom is expensive to reverse. Start loose when you are prototyping, reversibility is cheap, and the cost of interrupting legitimate work outweighs the cost of a silent freedom you can clean up later. The method below is for the first world, not the second.

## Why the strict rules have to be structural

There is a failure mode that defeats the whole approach: enforcing your restrictions with runtime guards instead of structure. If "strict" means a validation check at the top of one function, then a new code path that forgets the check reintroduces the silent freedom, and now your loud rule is only loud on the paths that remember it. That is the worst of both worlds.

The distinction is between verification and construction.

| | Verification | Construction |
|---|---|---|
| Invalid state | representable, caught at runtime | cannot be represented |
| Claim it supports | "no known violations" | "this cannot exist" |
| Depends on | the check running on every path | nothing, it is structural |
| New code paths | must re-invoke the guard | covered automatically |
| Threat model | needs one | irrelevant, stops accident and attack alike |

A constructed restriction (a CHECK constraint, a foreign key, a unique index, a withheld privilege, a type that does not admit the bad case) holds across every write path, present and future, with nothing to remember. That is what makes the restriction *reliably* loud, which is the precondition for treating it as a trustworthy signal. In the evidence section, "append-only" was made structural by privilege: the application role has no direct write on the ledger and can only call a small set of governed functions, so history cannot be rewritten by any path. The one honest exception was custody of a serialized unit, which guards a *transition* rather than a state and cannot be a single-row constraint, so it stays a trigger, named and bounded. The rule is to push every restriction to the strongest form it can reach, fall back only when construction is genuinely impossible, and keep the exceptions few and labeled.

## The method, briefly

The rest is scaffolding around the property, and it is mostly assembled from existing parts, so I will keep it short.

**Invariants first, enforced by construction.** Write the correctness properties you can read from the shape of the problem and make each unrepresentable if you can. These are your strict rules, and by the argument above they are also your discovery instrument.

**A decision register for what you have not settled.** Every open design choice gets a number, an owner, a reasoned default, and a classification: does it change the primary key or grain of a core table (a fork, which must settle before that part of the schema hardens) or can the schema absorb it later (additive, which you defer). You build on the settled and defaulted set, hold each open fork as a default with a recorded flip-cost, and thread the decision's number through the code as a comment and through the docs. When an answer lands, you grep the number and every place it touches surfaces at once.

**An assumption audit, because freedoms are silent.** This is the part the asymmetry makes non-optional. A decision register only holds the decisions you noticed you were making. The dangerous ones are the choices the schema made silently: a single-valued column that reality will make multi-valued, an implied cardinality, a `NOT NULL` that encodes a policy nobody debated. On this project, "one location" and "everything is quantity-tracked" were both unexamined defaults that only surfaced when I profiled real data. Since ordinary use will not report an over-permissive assumption, you have to go looking on a schedule: read the schema against the domain and ask, at every point, "could this have gone another way, and where is its number?" Promote each answer to a real decision even when you keep the assumption. The adversarial bug-hunt from the evidence section is the same move applied to invariants: since a missing constraint is silent, you attack the system to find what it wrongly permits.

## Relation to prior work

The pieces have clear ancestry and naming it is the honest thing to do. Enforcing correctness as invariants is design by contract (Meyer). Making invalid states impossible to represent is type-driven development, and at its limit correct-by-construction from formal methods. Numbering decisions is the tradition of architecture decision records and RAID logs. Constraints as invariants in a database are ordinary practice. The stance is close to test-driven development in spirit, specify correctness first and let it drive the build, though it sits a level up: the specification is a universal invariant enforced by construction rather than an example checked at runtime, and a failing rule surfaces a missing decision rather than a missing line of code. The epistemic frame is Popper's, with the Duhem-Quine objection doing real work rather than being waved off.

What I would claim as original is the composition plus two things. First, the falsifiability asymmetry itself, stated with its conditions: a restriction is reliably observable when it is unavoidable, a permission is not, so build strict and loosen on evidence, and treat over-strictness as a discovery instrument rather than a defect. "Fail closed," "least privilege," and "tests drive design" are folklore I inherited; connecting them into a single claim about why strictness is epistemically privileged, and being precise about when that privilege lapses, is the part I have not seen written down. Second, the operational treatment of a decision as a live, classified, greppable thread you build ahead of, which is what turns a retrospective decision log into a working part of the build.

## Where to start

You do not need the machinery to get the value. Two habits carry most of it.

Write the invariants you can already read from the problem, and enforce each in the strongest form it can reach: unrepresentable if possible, a bounded guard if not. Then, because freedoms are silent, put an adversarial pass on the calendar: periodically try to make the system accept a state that should be impossible, and read the schema for the choices you made without noticing.

The one idea to keep even if you keep nothing else: when you are unsure, and the path is one people cannot route around, restrict. You can always see what a restriction is costing you. You usually cannot see what a freedom is costing you until it is too late.
