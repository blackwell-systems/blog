---
title: "Adversarial Diligence: Benchmarking Jev, the AI Decision Layer (TypeSafe)"
date: 2026-09-21
draft: false
tags: ["ai", "due-diligence", "technical-due-diligence", "benchmark", "llm", "classification", "constrained-decoding", "discriminative-models", "jev", "typesafe", "decision-layer", "model-evaluation", "calibration", "reproducibility", "build-vs-buy", "vendor-evaluation", "ai-agents", "mlops", "cost-optimization", "independent-verification", "open-source"]
categories: ["ai", "benchmarks", "due-diligence"]
description: "An independent, reproducible benchmark of Jev (TypeSafe AI) against its real peer class. Where the moat is real, where it is a copyable harness, and the one test that settles it."
summary: "Most technical due diligence is demonstrative: the vendor shows you it works. This one is adversarial: define what would prove the claim false, establish independent ground truth, and try. A measured, reproducible evaluation of Jev against the peer class its own benchmarks avoid, run from public materials only."
---

Most technical due diligence is demonstrative: the founder shows you it works. Mine is adversarial: I define what would prove the claim false, establish independent ground truth where I can, and try to break it.

This is a worked example of that method, run entirely from public materials, on Jev, TypeSafe AI's "decision layer" model. The point is not to score Jev. It is to show how you evaluate a technically differentiated AI product when the value depends on a claim being true, and to find the one comparison that actually settles it.

{{< callout type="info" >}}
**Independence and scope.** This was built from public material only: TypeSafe's published workflow evaluations and the public `jev-on-a-laptop` reproduction. No confidential material, no vendor API called, no stake in the company. Every external figure was fetched and verified; the GPU results reproduce from committed raw predictions. Where I state an opinion, I mark it as one.
{{< /callout >}}

## The claim, and why it needs testing

Jev is marketed as a fast, cheap decision layer for AI systems: give it a schema of typed fields with closed value sets, and it returns schema-valid decisions with confidence scores, at a fraction of the cost and latency of calling a frontier model. The published benchmarks show it landing mid-pack on accuracy against generative frontier models while being one to three orders of magnitude cheaper and faster.

Read that sentence again, because the comparison inside it is where diligence starts. Jev is being measured against generative frontier models. That is not its peer class.

## What Jev actually is

Start by classifying the mechanism, not the marketing category. As reproduced publicly in `jev-on-a-laptop`, Jev's mechanism is **parallel constrained decoding**: define a schema where each field has a closed set of allowed values, prefill the context once into a KV cache, broadcast that cache across one batch row per field, run a single forward pass, and for each field take the constrained softmax over its allowed values. The result is a value plus a confidence, assembled programmatically so the output object is schema-valid by construction.

That makes Jev a **discriminative classifier** in the classical sense (Ng and Jordan, 2001): it estimates `P(label | input)` over a fixed label set per field. It is not a generative model. It is a well-engineered classifier with a clean batching trick for doing many fields in one pass.

{{< callout type="success" >}}
**Credit where it is due.** The mechanism is competently engineered and the parallel constrained decoding is real. Nothing here is a claim that the model is bad or the engineering is weak. The concern, developed below, is structural: it is about the comparison class the benchmarks choose and the layer a team is being asked to rent.
{{< /callout >}}

Once you know it is a classifier, the peer class is obvious, and it is not GPT-class generative models. It is other fixed-label classifiers: a small fine-tuned encoder, or the exact same constrained-decoding trick applied to a stock open model. Beating a generalist at a specialist's task is what specialization means. It is not a result. The result would be beating the actual peer class at equal cost.

## The category substitution

Here is the shape of the problem, drawn as the comparison that is made versus the comparison that decides value.

{{< mermaid >}}
flowchart TB
    subgraph Marketed["What the benchmarks compare"]
        J1[Jev: specialized classifier] -->|cheaper, faster, mid-pack accuracy| G[Generative frontier models]
    end
    subgraph Decisive["What actually decides value"]
        J2[Jev: specialized classifier] -->|equal cost, equal task| P[Fixed-label peers:<br/>fine-tuned encoder<br/>stock model, same decoding trick]
    end
    Marketed -.the test the marketing avoids.-> Decisive
{{< /mermaid >}}

A specialized classifier beating a generalist on the generalist's off-task flatters by construction. The comparison that settles Jev's value is Jev against a near-free peer, on the same task, at equal cost and latency, against real ground truth rather than a consensus of other models. If Jev does not beat those peers, its differentiation reduces to a copyable decoding harness. If it does, the trained model itself is the real claim, and that is what should be measured.

So I measured both.

## The same-task head-to-head

The cleanest test uses the exact dataset Jev was benchmarked on: NPC addressee detection (`wondertwins/jev-benchmark`), the same 79 utterances and 237 strict per-NPC decisions per variant, against the same hand-labeled ground truth. The task: for each NPC present in a scene, is the player speaking to this one? A pragmatic-judgment problem (mention versus address, reported speech, relay, deixis), not topic classification.

The peer arm is Jev's own mechanism, constrained softmax over a closed value set, running on a stock, untrained Qwen2.5-1.5B. Both Jev and the peer are zero-shot on identical items, so this is as clean a head-to-head as exists. I also port Jev's own fuzzy string-matching baseline, which reproduces the upstream numbers to three decimals, confirming the harness is faithful.

The port validates: it reproduces the exact strict decision count and matches the upstream fuzzy baseline to three decimals. So the comparison is genuinely apples-to-apples.

| arm (clean transcripts) | F1 | precision | recall | exact-set | ECE |
|---|---|---|---|---|---|
| constrained (stock Qwen 1.5B, zero-shot) | 0.756 | 0.745 | 0.768 | 0.560 | 0.028 |
| fuzzy baseline (ported) | 0.820 | 0.717 | 0.958 | 0.640 | n/a |
| Jev (published) | 0.962 | 1.000 | 0.926 | 0.920 | n/a |

On this task, Jev wins decisively, and the stock-model mechanism does not reproduce it. Jev's F1 sits far above the zero-shot stock arm with no confidence-interval overlap in any variant. The stock mechanism on a small model does not even beat the fuzzy baseline here. This is the informative outcome: when a peer at equal footing does not match Jev, the win is not the shared decoding harness or the shared schema-validity. It is the model.

That result alone would be too kind, though. It used a 1.5B model. Before crediting Jev's training, you have to rule out the simplest explanation: that a bigger stock model under the same mechanism just catches up.

## The scale test: is it capability, or efficiency?

I reran the identical zero-shot constrained arm at four model sizes across two families, all on the same dataset, every number re-verified locally from raw per-decision predictions.

| model (stock, zero-shot, Jev's mechanism) | clean F1 | stt F1 | misheard F1 | clean precision |
|---|---|---|---|---|
| Qwen2.5-1.5B | 0.764 | 0.739 | 0.616 | 0.745 |
| Qwen2.5-7B | 0.795 | 0.718 | 0.629 | 0.895 |
| Llama-3.1-8B | 0.504 | 0.387 | 0.376 | 1.000 |
| Qwen2.5-72B (4-bit) | 0.902 | 0.862 | 0.769 | 1.000 |
| fuzzy baseline | 0.820 | 0.820 | 0.786 | 0.717 |
| **Jev (published)** | **0.962** | **0.944** | **0.927** | **1.000** |

Read the clean-F1 column top down and it forms a ladder. The 1.5B and 7B are both well short of Jev and barely different from each other: a 5x jump in size buys four points. The Llama-3.1-8B is worse, not better, its recall collapses because it plays safe and stays silent, so size alone is not the lever, the model also has to be good at the task. The 72B is the size that finally moves: its confidence interval overlaps Jev's 0.962 and it matches Jev's precision of 1.000. On clean text, a large enough stock model essentially catches Jev.

That single finding rewrites what Jev's advantage is.

{{< callout type="warning" >}}
**The moat is efficiency and noise-tolerance, not raw capability.** A 72B stock model reaches Jev's clean-transcript neighborhood, so Jev is not doing something scale cannot reach. It is delivering roughly 72B-class judgment at a serving cost and latency far below a 72B. That is a real and defensible advantage (specialized distillation). It is a different claim from beating the frontier.
{{< /callout >}}

The noisy column tells the other half, and it is the place Jev's training clearly earns its number. On misheard speech-to-text, even the 72B falls to 0.769, below the simple fuzzy baseline and far below Jev's 0.927. Scale buys clean-transcript judgment but not resilience to garbled input. That residual does not come from size. It comes from training.

So the accurate picture is neither marketing nor dismissal:

- On fixed-label classification, the constrained mechanism on a commodity model matches Jev. There the harness is the contribution, not the model, and the harness is copyable.
- On pragmatic judgment with clean input, a large commodity model matches Jev. There Jev sells efficiency, not capability.
- On degraded input, no stock model up to 72B comes close. There Jev's training earns its keep.

## From measurement to decision

A benchmark that stops at F1 is not diligence. The buyer's question is build or buy, so the analysis has to reach a decision with the economics and the risks attached.

**The economics.** Renting is per decision (roughly $0.00008 to $0.0004 depending on context size). Building is one-time: label a few hundred examples, train and calibrate a small model, wrap it behind the existing interface. Estimate one to three engineer-weeks and near-zero serving, since a small trained model answers in single-digit milliseconds on CPU.

| per-decision price | monthly volume where building pays back within a year |
|---|---|
| $0.0004 (large states) | about 2 million decisions per month |
| $0.00008 (small states) | about 10 million decisions per month |

Above roughly single-digit millions of decisions a month, owning is cheaper on the bill alone. Below that, renting is cheaper on the invoice, and the case for building rests on the strategic reasons, owning the data and the model, setting thresholds on your own distribution, and not putting a metered third party on the path every request takes.

{{< callout type="danger" >}}
**Renting the decision layer is the specific anti-pattern.** The decision layer is where an agent meets its own logic, and it is the layer most within reach of ownership. It is the cheapest layer to own and the most strategically yours, which makes it the worst layer in the stack to rent. Switching cost concentrates exactly there.
{{< /callout >}}

**When each choice is right.**

- Cold start, before labels exist, still exploring: rent as a bridge, or use the frontier API already in your stack with structured outputs. Capture outcomes from day one.
- Scaled product, stable fields, real volume: build and own. It pays back on cost and it is the strategic default.
- Regulated or data-egress-sensitive: build and own. A hosted decision layer may be a non-starter regardless of price.
- ML-mature org: build and own. This is beneath the capability already in the building.

## The method, generalized

Strip out Jev and this is a repeatable procedure for any AI product whose value rests on a technical claim.

{{< mermaid >}}
flowchart TB
    A[Classify the mechanism,<br/>not the marketing category] --> B[Name the real peer class<br/>the benchmarks avoid]
    B --> C[Define what would falsify<br/>the claim]
    C --> D[Establish independent ground truth]
    D --> E[Run the same-task, equal-cost<br/>head-to-head]
    E --> F[Isolate scaling behavior,<br/>do not curate benchmark wins]
    F --> G[Find the boundary: where the<br/>advantage holds, degrades, or is unknown]
    G --> H[Carry it to a decision:<br/>economics + risk + recommendation]
{{< /mermaid >}}

1. **Classify the mechanism.** A model that returns a value from a closed set is a classifier, whatever it is branded. The mechanism determines the peer class.
2. **Name the peer class the benchmarks avoid.** Vendors benchmark against an impressive but off-task comparison. Write the ranked list of systems that actually do this job, and compare against those.
3. **Define what would falsify the claim.** State it before you run anything, so you cannot rationalize afterward.
4. **Establish independent ground truth.** Real labels, not a consensus of other models grading each other.
5. **Run the same-task, equal-cost head-to-head.** The decisive test is the product against a near-free peer, on the same task, at equal cost.
6. **Isolate scaling behavior.** Sweep the variable (here, model size) instead of curating one favorable configuration. That is what separated capability from efficiency.
7. **Find the boundary.** The deliverable is not a score. It is the line where the advantage holds, where it degrades, and where it becomes unknown.

## What survives

Jev is a competently engineered classifier that delivers large-model-class judgment at commodity cost, and holds up on degraded input where even a 72B model does not. That is a real, narrow, defensible advantage. It is not the frontier-beating result the generative-model comparison implies, and on plain fixed-label classification the differentiator is a decoding harness that a team can reproduce on a stock model.

For a buyer, that resolves cleanly: rent Jev as a bridge at cold start or when you have no ML capacity yet, capture outcomes so you can exit, and build and own the decision layer once you have volume and labels, because that is the layer you least want to rent.

The broader point is about the method, not the vendor. When a technical claim carries real money, the demonstrative version, watching it work in a demo, is not enough. You define what would prove it wrong, you find the comparison the marketing avoids, and you measure it against a competent baseline at equal footing. Most of the time the truth is narrower and more interesting than either the pitch or the dismissal. That is the finding worth paying for.

{{< callout type="info" >}}
**Reproducibility.** The peer arms, the dataset port, and the scale-test harness were built to reproduce from committed raw predictions. Independent verification, not acceptance on authority, is the entire point.
{{< /callout >}}

---

*This is the kind of independent, adversarial evaluation I run through [Blackwell Systems](https://blackwell-systems.com) for founders, investors, and acquirers weighing a technically differentiated AI, software, or compute company. If a claim's truth decides something you are about to commit to, that is exactly the work.*
