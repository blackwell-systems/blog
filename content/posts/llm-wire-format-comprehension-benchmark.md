---
title: "LLM Wire Format Benchmark: Which Format Can AI Actually Read and Write?"
date: 2026-06-06
draft: false
tags: ["gcf", "toon", "json", "llm", "benchmark", "wire-format", "token-efficiency", "ai-agents", "mcp", "claude", "gpt", "gemini", "open-source"]
categories: ["ai", "benchmarks", "open-source"]
description: "We tested whether LLMs can read and write GCF, TOON, and JSON at 500 symbols. 23 runs, 10 models, 3 providers. GCF is the only format that works for both input and output across every model tested. TOON fails on output. JSON fails on input. Full methodology, failure taxonomy, and reproducible eval."
summary: "23 comprehension runs across 10 models (Claude Opus/Sonnet/Haiku, GPT-5.5/5.4/5.4-mini, Gemini 2.5 Flash/Pro, Gemini 3.1 Pro, Gemini 3.5 Flash). Generation eval across 11 models and 3 providers (Anthropic, OpenAI, Google). GCF wins 22, ties 1, loses 0 on comprehension. GCF achieves 5/5 valid generation on every frontier model with zero prior training. TOON fails 0/5 on generation with Opus, GPT-5.4, GPT-5.4-mini, Gemini 3.1 Pro, and Gemini 3.1 Flash Lite. JSON breaks on input at 500 symbols."
---

Every LLM wire format claims token savings. Nobody proves whether AI models can actually comprehend the format at scale, or produce valid output in it.

We ran 23 comprehension evals across 10 models and 3 providers. We ran generation evals across 11 models. Deterministic ground truth. No LLM judge. Reproducible from one command.

JSON breaks at 500 records. GPT-5.5 returns empty strings. It can't even attempt an answer. Opus miscounts 500 as 356 and then spends 143 lines manually enumerating symbols to verify its own wrong answer. The format designed for "human readability" is incomprehensible to the systems actually reading it.

TOON can't produce valid output. Claude Opus, the most capable model on the planet, scores 0/5 on TOON generation. GPT-5.4: 0/5. GPT-5.4-mini: 0/5. Gemini 3.1 Flash Lite: 0/5. The error is always the same: `toon: cannot assign string to int`. The model writes "target" in the distance column. TOON expects `0`. Every model fails the same way because the format's design forces an unnatural encoding step that models cannot perform unprompted.

GCF wins both dimensions on every model tested. 100% comprehension on Claude Sonnet, Gemini 2.5 Pro, Gemini 3.1 Pro, and Gemini 3.5 Flash. 5/5 valid generation on every frontier model. Zero prior training. The format didn't exist until we built it and every model speaks it natively.

## Comprehension: 500 Symbols, 13 Questions, Zero Instructions

A 500-symbol, 200-edge code graph. Encoded in GCF, TOON, and JSON. 13 structured extraction questions. The model gets the payload and a question. No format instructions. No system prompt. No hints.

### 23 runs. 22 wins. 0 losses.

| Model | Runs | GCF avg | TOON avg | JSON avg | GCF margin |
|-------|------|---------|----------|----------|------------|
| Claude Opus 4.6 | 2 | **96.2%** | 84.6% | 73.1% | +11.6 vs TOON |
| Claude Sonnet 4.6 | 2 | **100%** | 73.1% | 53.8% | +26.9 vs TOON |
| Claude Haiku 4.5 | 2 | **96.2%** | 69.2% | 57.7% | +27.0 vs TOON |
| GPT-5.5 | 5 | **84.1%** | 67.7% | 45.8% | +16.4 vs TOON |
| GPT-5.4 | 4 | **76.4%** | 56.0% | 44.1% | +20.4 vs TOON |
| GPT-5.4-mini | 2 | **71.8%** | 64.1% | 54.2% | +7.7 vs TOON |
| Gemini 2.5 Flash | 3 | **80.6%** | 54.6% | 57.0% | +26.0 vs TOON |
| Gemini 2.5 Pro | 1 | **100%** | 76.9% | 58.3% | +23.1 vs TOON |
| Gemini 3.1 Pro | 1 | **100%** | 76.9% | 46.2% | +23.1 vs TOON |
| Gemini 3.5 Flash | 1 | **100%** | 61.5% | 46.2% | +38.5 vs TOON |

GCF > TOON > JSON on every model from every provider. No exceptions. Four models achieve 100%: Claude Sonnet, Gemini 2.5 Pro, Gemini 3.1 Pro, Gemini 3.5 Flash.

### Token cost for the same payload

| Format | Tokens | vs JSON |
|--------|--------|---------|
| GCF | 11,090 | **79% fewer** |
| TOON | 16,378 | 69% fewer |
| JSON | 53,341 | baseline |

GCF is the cheapest format. It's also the most accurate. Usually you trade cost for quality. Not here.

## How JSON Dies at Scale

At 8 symbols, JSON scores 100%. Everything works. At 500 symbols, it falls apart.

**GPT-5.5 returns empty strings.** Not wrong answers. Nothing. The model receives 53,341 tokens of `{"qualifiedName": "...", "kind": "...", "score": ..., "provenance": "...", "distance": ...}` repeated 500 times and cannot produce any response. Ask "how many symbols?" and it returns `""`. The attention mechanism drowns in 2,500 identical field-name tokens.

**Claude Opus miscounts 500 as 356.** Then it tries to verify by manually listing symbols. 143 lines of chain-of-thought enumeration. Burns output tokens. Still gets the wrong answer. The most capable model in the world cannot count JSON objects because the structural noise overwhelms the signal.

**Every model fails distance filtering.** "How many symbols have distance 0?" requires parsing 500 JSON objects, reading the `distance` field on each, and counting matches. Correct answer: 166. Opus answers 200 (read the edge count instead). GPT-5.4 answers 300-404. GPT-5.4-mini answers 300.

JSON repeats `"qualified_name":`, `"kind":`, `"score":`, `"provenance":`, `"distance":` on every single record. That's 2,500 structurally identical tokens carrying zero semantic content. They exist for human readability. The consumer isn't a human.

## How TOON Fails on Grouping

TOON does better than JSON on counting. It gets symbol_count=500 correct. But it fails on anything that requires filtering by column value.

**Distance grouping fails on every model.** "How many targets (distance 0)?" requires scanning 500 TOON rows and filtering by the last column. Correct answer: 166.

- Opus: 107 (on extended_count)
- Haiku: 100, 200, 214
- GPT-5.4: 169, 229, 200
- GPT-5.4-mini: 26, 28

The answers are wildly inconsistent across runs. The models aren't wrong in a systematic way; they're guessing. TOON has no section headers for distance groups. The only way to answer "how many targets?" is to scan every row and count. At 500 rows, models give up and guess round numbers.

**Attention decays by row 500.** "What kind is the last symbol?" should be trivial. TOON answers "method" instead of "interface" on multiple models. By the time the model reaches row 500 of a flat table, attention has diluted to noise.

## How GCF Solves Both Problems

GCF answers are structural, not computational.

"How many symbols?" Read the header: `symbols=500`. Done.

"How many edges?" Read the section header: `## edges [200]`. Done.

"How many targets?" Count lines in `## targets`. The section boundary gives the grouping for free. No column filtering. No scanning 500 rows.

"What kind is the last symbol?" The last line in `## extended` is the last symbol. The model reads the last line of the last section. No attention decay across 500 flat rows.

GCF median error magnitude: **4** (off-by-one tokenization artifacts).
TOON median error magnitude: **53** (comprehension failure).
JSON median error magnitude: **56** (structural overwhelm).

One design decision creates this gap: hierarchical sections vs flat tabular. GCF groups data by category. TOON and JSON present flat lists and force the model to compute groupings from raw values. At scale, that computation fails.

## Generation: TOON is Broken

We asked every model to produce structured output in each format. 3-line primer in the prompt. Output validated through the real decoder. No hand-holding.

### 11 models. 3 providers. GCF is the only format that works everywhere.

| Model | GCF | TOON (natural) | JSON |
|-------|-----|----------------|------|
| Claude Opus 4.6 | **5/5** | 0/5 | 5/5 |
| Claude Sonnet 4.6 | **5/5** | 2-3/5 | 5/5 |
| Claude Haiku 4.5 | **5/5** | 1-3/5 | 5/5 |
| GPT-5.5 | **4-5/5** | 1-2/5 | 5/5 |
| GPT-5.4 | **5/5** | 0/5 | 5/5 |
| GPT-5.4-mini | **5/5** | 0/5 | 5/5 |
| Gemini 2.5 Pro | **5/5** | 1/5 | 5/5 |
| Gemini 3.1 Pro | **5/5** | 0/5 | 5/5 |
| Gemini 3.1 Flash Lite | **4-5/5** | 0/5 | 4/5 |
| Gemini 3.5 Flash | 3/5 | 1/5 | 3/5 |
| Gemini 2.5 Flash | 2-3/5 | 0-4/5 | 0-3/5 |

No model has ever been trained on GCF. It didn't exist before we built it. Yet every frontier model (Opus, Sonnet, GPT-5.5, Gemini 2.5 Pro, Gemini 3.1 Pro) produces valid, decoder-parseable output on first exposure with a 3-line primer.

TOON has been published for months. It has documentation, examples, a playground, SDK implementations. And Claude Opus scores 0/5. Gemini 3.1 Pro scores 0/5. GPT-5.4 scores 0/5.

### The exact failure

Every TOON generation failure produces the same error:

```
INVALID: symbols: index 0: distance: toon: cannot assign string to int
```

The model writes:
```
symbols[5]{name,kind,score,provenance,distance}:
  pkg/api.HandleRequest,function,0.95,lsp_resolved,target
```

TOON expects:
```
symbols[5]{name,kind,score,provenance,distance}:
  pkg/api.HandleRequest,function,0.95,lsp_resolved,0
```

The model is told "this symbol is a target." It writes `target`. TOON's decoder rejects it because it expects the integer `0`. The model would need to know, unprompted, that "target" maps to 0, "related" maps to 1, "extended" maps to 2. No model does this.

This isn't a training problem. This is a design flaw. TOON's flat tabular format encodes semantic categories as integers. The model has to perform a mapping step that has no structural cue in the format itself. When does a column value need to be an integer? When is a string acceptable? TOON gives no signal. The model guesses wrong.

### GCF never has this problem

GCF expresses distance through section placement:

```
## targets
@0 fn pkg.HandleRequest 0.95 lsp_resolved
## related
@1 type pkg.ProcessResponse 0.74 ast_inferred
## extended
@2 method pkg.ValidateConfig 0.52 structural
```

The model is told "this symbol is a target." It writes it in `## targets`. No integer mapping. No encoding step. The format aligns with how the model naturally expresses grouped data. Sections are categories. That's how markdown works. That's how every model already thinks.

### Even with hand-holding, GCF wins

When we explicitly pre-encode distances as integers in the prompt ("distance 0" instead of "target"), TOON passes. But this means the caller must know TOON's internal encoding and pre-process every field before the model can write valid output.

| Format | Prompt style | Valid | 100 sym output |
|--------|-------------|-------|----------------|
| **GCF** | natural labels | **5/5** | **5,984 B** |
| TOON | hand-held (integers) | 5/5 | 8,336 B |
| TOON | natural labels | 0/5 | invalid |
| JSON | natural labels | 5/5 | 16,121 B |

GCF works with natural language. TOON requires a preprocessing step. And even with that step, GCF output is 28% smaller.

## GCF Works Without Training

No model has seen GCF before. The format is days old. And yet:

- Claude Opus 4.6: 5/5 valid (zero variance across 2 runs)
- Claude Sonnet 4.6: 5/5 valid (zero variance across 2 runs)
- Claude Haiku 4.5: 5/5 valid (2 runs)
- GPT-5.5: 4-5/5 valid
- GPT-5.4: 5/5 valid
- GPT-5.4-mini: 5/5 valid (zero variance across 2 runs)
- Gemini 2.5 Pro: 5/5 valid (zero variance across 2 runs)
- Gemini 3.1 Pro: 5/5 valid
- Gemini 3.1 Flash Lite: 4-5/5 valid (zero variance across 3 runs)

This happens because GCF is aligned with patterns LLMs already understand:

- `## section_name` is a markdown header. Every model knows this.
- `@0 fn pkg.Auth 0.78 lsp_resolved` is positional. One token per field. No ambiguity.
- `@1<@0 calls` is 4 tokens. Self-contained. No nested objects.

The format was designed for the machine's native expression patterns. TOON was designed for human readability. JSON was designed for human readability. Neither format was designed for the reader that's actually doing the work.

## TOON's Own Benchmark: GCF Wins All 6 Datasets

We forked TOON's benchmark repository, added a GCF formatter, and ran their datasets with their tokenizer and their methodology.

| Dataset | GCF | TOON | Result |
|---------|-----|------|--------|
| Semi-uniform event logs | 108,158 | 154,032 | **GCF 42% smaller** |
| E-commerce orders | 61,593 | 73,246 | **GCF 19% smaller** |
| Deeply nested config | 616 | 618 | **GCF 0.3% smaller** |
| Employee records | 49,055 | 49,966 | **GCF 2% smaller** |
| Analytics time-series | 8,398 | 9,127 | **GCF 8% smaller** |
| GitHub repos | 8,576 | 8,744 | **GCF 2% smaller** |

TOON's home turf. TOON's datasets. TOON's methodology. GCF wins every single one.

Even on flat tabular employee records, the dataset TOON was literally designed for, GCF is smaller. The gap is small (2%) but it exists. On semi-uniform data where structures vary, the gap blows open to 42%.

## Session Statefulness: The Compounding Advantage

GCF has a feature no other format supports: session statefulness. Symbols seen in prior tool calls are referenced by ID instead of re-serialized.

First call: full payload. Second call: only new symbols, plus `@ref` IDs for previously-seen ones. By the 5th call in a conversation: **92.7% token savings.**

TOON and JSON re-serialize everything on every call. There is no mechanism for cross-call deduplication. Every tool response pays full price regardless of what the model already knows.

This is where GCF's advantage compounds over a session. The per-call savings (32-79% vs TOON) multiply across 5-10 tool calls in a typical agent interaction.

## Reproduce Everything

The eval is open source. Every result is committed. Every log file is in the repository.

```bash
# Comprehension (any provider)
cd gcf-go/eval
GOWORK=off EVAL_BACKEND=openai OPENAI_API_KEY=... EVAL_MODEL=gpt-5.5 \
  go test -run TestComprehension -v -timeout 0

# Generation
cd gcf/eval
python3 generation_gcf_eval.py
python3 generation_toon_eval.py

# Token efficiency (TOON's benchmark)
cd toon && git checkout gcf-comparison && cd benchmarks && pnpm install && pnpm benchmark:tokens
```

Run it yourself. The numbers don't change.

---

- [GCF Spec](https://github.com/blackwell-systems/gcf)
- [GCF Playground](https://blackwell-systems.github.io/gcf/playground.html)
- [GCF Go](https://github.com/blackwell-systems/gcf-go) (includes comprehension eval)
- [GCF Python](https://github.com/blackwell-systems/gcf-python)
- [GCF TypeScript](https://github.com/blackwell-systems/gcf-typescript)
- [GCF Proxy](https://github.com/blackwell-systems/gcf-proxy) (drop-in MCP proxy, zero server changes)
- [TOON benchmark fork](https://github.com/blackwell-systems/toon-benchmark)
- [knowing](https://github.com/blackwell-systems/knowing) (the code intelligence engine GCF was extracted from)
