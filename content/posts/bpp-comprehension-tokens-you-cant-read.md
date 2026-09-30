---
title: "A Format Can Save Tokens and Still Be Unreadable. We Measured It."
date: 2026-09-30
draft: false
paper: "gcf"
tags: ["gcf", "llm", "tokenization", "comprehension", "wire-format", "benchmark", "json", "toon", "bpp", "token-savings", "mcp", "ai-agents", "structured-data", "openrouter", "eval", "reproducible", "open-source"]
categories: ["ai", "benchmarks", "open-source"]
description: "A whitespace-delimited format called bpp beats GCF on raw token count by ~31%. So we ran an adversarial comprehension study: 8 models, 5 families, ~770,000 records read. Fewer tokens, far more wrong answers. GCF 31% error, JSON 40%, bpp 54%. Full data and reproduction."
summary: "bpp wins on tokens and loses on being read correctly. Across 8 models and ~770K records, mean comprehension error was GCF 31% / JSON 40% / bpp 54%. The failure is mechanical: bpp interns repeated values into a pointer table and models return the pointer instead of the value. The token saving is erased the moment you price the errors."
---

A new wire format showed up in one of our integrations' benchmarks and beat GCF on token count. It is called bpp: whitespace-delimited rows, minimal quoting, and a reference table that interns repeated values. On a flat generic payload it uses about 31% fewer tokens than GCF and about 70% fewer than JSON.

Fewer tokens is the easy number to move. It is a deterministic property of the tokenizer, fixed before the model does any work. The number that actually matters is whether the model can still *read* the structure once it arrives. So we measured that one instead.

## The setup

One question drove the study: does bpp's token win survive comprehension, or does its grammar degrade structural reading at scale?

- **Payload:** nested e-commerce orders (customer, line items, totals), 500 and 1,000 records. The data is shaped to test bpp on its own terms, realistic enough that its compression is fully engaged rather than idle, and large enough to stress it. The exact same data is handed to every format, so the comparison is fair.
- **Questions:** 19 per run. Counting and aggregation (which every format handles) plus deep lookups (the customer email or SKU on a record halfway and all the way down the payload).
- **Formats:** GCF, JSON, and bpp, each presented cold, a format-name label and nothing else. No syntax primer for any of them, including GCF. Whatever the model knows, it infers.
- **Models:** 8, across 5 families (Google, Meta, DeepSeek, Mistral, Cohere), from an 8B up to frontier-class, all at temperature 0.2. Deterministic ground truth, no LLM judge.

Across all runs: **1,311 requests, ~769,500 order-records read by the models, ~13 million field values, 1,159 graded answers.**

## The result

![Comprehension error by format](/images/bpp-comprehension/aggregate-error-dark.png)

Mean per-model-cell error rate, weighting every model equally:

| Format | Comprehension error | Tokens (N=500) |
|---|:---:|:---:|
| **GCF** | **31%** | 44,770 |
| JSON | 40% | 101,482 |
| **bpp** | **54%** | 30,704 |

bpp is the cheapest format and the least correct. It is wrong roughly 1.7 times as often as GCF. And the shape of the trade is the whole story:

![The token/comprehension trade](/images/bpp-comprehension/token-vs-error-dark.png)

GCF is the only format in the sweet spot: cheap *and* correct. It beats JSON on both axes at once, fewer tokens and fewer errors, which almost never happens, you usually trade one for the other. bpp buys its extra token saving by being harder to read. JSON pays the most tokens for middling comprehension.

## Why bpp fails: the structure breaks twice

Two things go wrong, at two different stages.

**First, at the token level: the merge barrier.** bpp separates fields with whitespace. But a space is not a clean boundary to a BPE tokenizer. It merges into the adjacent token most of the time, about 71 percent across the tokenizers in the companion paper, the worst of any structural character. So before the model reads a single field, the boundaries between them have already dissolved into the content. This is not a guess. In a controlled experiment (two identical models, same training data, different tokenizers) the one whose tokenizer treated delimiters as clean, un-mergeable boundaries, a *merge barrier*, was 3 to several hundred times better at reading structured data, with no cost to natural language. GCF uses a delimiter (the pipe) that merges 0.47 percent of the time, effectively a barrier. bpp uses the one character that merges the most.

**Second, at the read level: the pointer table.** Repeated values are hoisted to the top of the payload as `&0`, `&1`, `&2`, and every later occurrence becomes a pointer like `*372`. To answer "what is the SKU on this order," the model has to read `*372`, then resolve it against a dictionary hundreds of rows away.

Models do not do this reliably. They return the pointer.

Asked for a SKU that was interned as `&375`, capable models answered `"375"`, the index. Weaker models answered `"*250"` and `"*372"`, the literal reference token, copied out verbatim. GCF and JSON carry the value in place, so they cannot produce this failure at all. It is not a subtle scoring difference. The model confidently hands back a pointer and calls it an answer.

![Comprehension error by model and format](/images/bpp-comprehension/per-model-error-dark.png)

bpp is the tallest error bar in almost every cell.

## "Just use a frontier model" does not fix it

The tempting objection is that this is a small-model problem. It is not, and the reason is mechanical.

The delimiter merge and the pointer indirection are properties of the *encoding*. They are applied identically to every model, before inference begins. A frontier model receives exactly the same degraded structure a small model does. What differs is reserve capacity: a strong model can spend some of its budget reconstructing the smeared boundaries and chasing the pointers.

But spending capacity is not the same as being unaffected. On a comfortable 500-record payload, a strong flagship model still lost 21 points to bpp versus GCF. Push the payload to 1,000 records and the masking erodes further. And scaling the model does not close the gap: going from an 8B to a 70B lifted GCF's mean accuracy 26 points, from 48 to 74 percent, and barely moved bpp, from 39 to 42, with the 70B still returning raw pointers (`*256`, `*322`, `*372`) for the exact lookups it should have resolved.

There is no frontier-safe regime for a format like this. There is only a frontier-*masked* one, where a large model pays a tax you imposed at encode time, capacity it could have spent on the actual task.

## The token saving is erased once you price the errors

The saving is booked once, upfront, and unconditionally. The error cost is paid later, and only in the cases where it matters.

bpp saves about 13,000 tokens per call versus GCF on this payload. One wrong answer that gets retried re-sends the payload, about 27,000 tokens, roughly twice the saving. bpp's extra error rate works out to about one extra wrong answer every five calls, which eats 40 to 50 percent of the saving in retries alone.

And that is the optimistic case, where the error is caught. bpp's signature failure is silent: the model returns a confident, wrong value with no indication anything went wrong.

{{< callout type="warning" >}}
A silent error is never retried. It costs zero tokens, and instead costs a wrong action. The saving there is not eroded. It is spent on being wrong.
{{< /callout >}}

## This is the trade GCF was built to refuse

I built GCF, so I am not going to pretend to survey the field and arrive at it as a surprise. The point of running this was the opposite: to try to break the design decision GCF is built on, with a format engineered to beat it on the one number that is easy to move.

GCF's grammar was reverse-engineered from tokenization and attention research, and then every component of it was chosen by measuring its effect on comprehension directly, one delimiter and one structural decision at a time, iterating slowly toward the most legible shape and balancing each choice against the tokens it cost. The research said where the boundaries mattered; the measurement confirmed which shapes the models actually read back. The whole point of that process was to bank savings only where they do not damage the model's ability to reconstruct the structure.

bpp makes the opposite bet: whitespace delimiters and an interned pointer table, tuned for token count, the shape that measurement rejects. This study is a test of GCF's bet, run on bpp's strongest ground, a payload where its token win is largest. The bet held. The format that spends a few tokens to keep a boundary the model can see is wrong about half as often, and still uses 56 to 59 percent fewer tokens than JSON.

The specifics of *why* a delimiter merges into adjacent content, and how badly, measured across dozens of tokenizers (a plain space merges about 71 percent of the time, the worst of any structural boundary; the pipe GCF uses, 0.47 percent), come from the companion tokenization paper this study builds on:

{{< cite "json-tokenization" >}}

And the controlled proof that clean, un-mergeable delimiters (merge barriers) cause the comprehension gain, two identical models, same data, tokenizer the only variable, is in the attention-coupling paper:

{{< cite "tokenizer-attention-coupling" >}}

The practical takeaway, whatever format you reach for: on anything serving unknown models or non-trivial payloads, an MCP server, an agent tool, any pipeline where you do not control which model reads the output, the compact-but-unreadable format is a liability. Fewer tokens on the wire is not the same as fewer tokens spent, once retries and silent wrong answers enter the ledger. And when you do need more savings, the safe lever is the protocol layer (session dedup, delta, streaming), which cuts tokens across turns without ever degrading a single payload's readability.

## Caveats

- Run counts are uneven (one weak model has eight repeats, one midsize five, the rest one to two). The headline uses mean-of-cells so no model is over-weighted; the pooled-by-datapoint number tells the same story.
- Some cheap providers rejected the largest JSON payloads (context caps, empty responses). Those cells are marked not-available and excluded from the rates, not counted against JSON.
- One 12B model was run and then dropped: it failed even basic counting on *all three* formats, so it measured incompetence, not legibility. That is a stated exclusion criterion, not a quiet drop, and it happened to be a run where GCF scored low.
- Where repeated, bpp's error rate is extremely stable (identical to the point across five runs on one model), so the gap is not run-to-run noise.

## Reproduce it

Everything is open: the full writeup, per-run logs (expected versus got for every one of the 1,159 answers), the exact payloads, the chart scripts, and the harness. It lives in the GCF repo at [`eval/bpp-comprehension/`](https://github.com/blackwell-systems/gcf/tree/main/eval/bpp-comprehension). The adversarial harness is in `gcf-go/eval` behind an `EVAL_ADV` flag; the charts regenerate from `results.csv` with one command.

Fewer tokens on one payload is not a finding. Whether the model can still read them is.
