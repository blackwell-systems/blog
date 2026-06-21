---
title: "Why LLMs Struggle with JSON at Scale: A Tokenization Analysis"
date: 2026-06-21
draft: false
tags: ["json", "tokenization", "llm", "gcf", "ai-agents", "wire-format", "mcp", "token-efficiency"]
categories: ["ai", "research"]
description: "JSON's structural grammar tokenizes ambiguously across models. Field boundaries merge with content on 4/8 tokenizers, creating model-dependent parsing. GCF's delimiters are always exactly 1 token on every tokenizer. This explains why comprehension degrades at scale."
summary: "We benchmarked 8 tokenizers from 6 providers against JSON and GCF structural patterns. JSON's quote-colon field markers merge with adjacent content on 4/8 tokenizers (GPT-4, GPT-4o, LLaMA, Qwen), creating ambiguous token boundaries at field separators. GCF's pipe delimiter never merges on any tokenizer. At 500 rows, JSON's structural overhead (field names + syntax) consumes 81% of tokens, leaving only 19% for actual data. This structural ambiguity compounds per row and explains model-dependent comprehension failures at scale."
---

Everyone knows JSON is verbose. The common explanation for why LLMs struggle with JSON at scale is "too many tokens." That's incomplete. The real problem is more subtle and more dangerous: JSON's structural grammar tokenizes **ambiguously** across different models, and this ambiguity compounds with every row of data.

We ran a structural variance benchmark across 8 tokenizers from 6 providers. The findings explain a pattern we've observed across 2,400+ LLM evaluations: why JSON comprehension fails at scale, and why it fails *differently* per model.

## The Experiment

8 tokenizers. 6 providers. Same data, two formats (JSON and GCF). We measured two things:

1. **Do structural delimiters tokenize consistently across models?** (If not, different models see different field boundaries.)
2. **Do structural characters merge with adjacent content?** (If so, the model can't distinguish where structure ends and data begins.)

### Tokenizers tested

| Tokenizer | Provider | Model Family |
|-----------|----------|-------------|
| Claude tokenizer | Anthropic | Claude 3.5, 4.x |
| cl100k_base | OpenAI | GPT-4 |
| o200k_base | OpenAI | GPT-4o, GPT-5.x |
| LLaMA 3.1 tokenizer | Meta | LLaMA 3.x |
| Qwen 2.5 tokenizer | Alibaba | Qwen 2.5 |
| DeepSeek V3 tokenizer | DeepSeek | DeepSeek V3 |
| Gemma 2 tokenizer | Google | Gemma 2 |
| Mistral Nemo tokenizer | Mistral | Mistral/Ministral |

## Finding 1: JSON Field Boundaries Tokenize Inconsistently

We tested 15 common JSON field-name patterns (the `"fieldName":` sequences that repeat on every row). Four of them tokenize **differently** across tokenizers:

| Pattern | Claude | GPT-4 | GPT-4o | LLaMA | Qwen | DeepSeek | Gemma | Mistral |
|---------|--------|-------|--------|-------|------|----------|-------|---------|
| `"value":` | 3 | **2** | **2** | **2** | **2** | 3 | 3 | 3 |
| `"orderId":` | 4 | **3** | 4 | **3** | **3** | 4 | **3** | 4 |
| `"name":` | 3 | **2** | **2** | **2** | **2** | 3 | 3 | **2** |
| `"tier":` | 3 | 3 | 3 | 3 | 3 | **4** | 3 | **4** |

These are structural tokens. They repeat on **every single row** of JSON array data. At 500 rows, that's 2,000+ positions where different models see different token boundaries.

## Finding 2: JSON Quotes Merge with Field Names

The "why" behind Finding 1. When GPT-4 tokenizes `"value":`, it produces:

```
["value][":"]
```

The opening quote and the field name `value` become **one token**. Claude tokenizes the same string as:

```
["][value][":]
```

Three separate tokens. The quote is distinct from the field name.

This means GPT-4 sees a single opaque token `"value` where Claude sees two distinct tokens `"` + `value`. The structural boundary (where the field name starts) is at a different position in the token sequence depending on which model processes the data.

### The merge pattern at real boundaries

We tested JSON's most structurally critical boundary: the field-to-value transition `"field":"data"`:

```
"value":"hello"

GPT-4, GPT-4o, LLaMA, Qwen:  ["value][":"][hello]["]
Claude, DeepSeek, Gemma:      ["][value][":"][hello]["]
Mistral:                      ["][value][":"][hello]["]
```

On 4 of 8 tokenizers, the **field name absorbs the quote delimiter**. The model receives a merged token that contains both structural markup (`"`) and semantic content (`value`). It must learn to decompose this merged representation to parse the field boundary correctly.

This isn't catastrophic at small scale (models handle it fine at 10 records). But at 500 records, there are 2,000+ of these merged boundaries. The attention mechanism has to decode structural position from ambiguous tokens across 10,000+ positions. That's where comprehension breaks.

## Finding 3: GCF Delimiters Never Merge

We tested all 10 GCF grammar characters against all 8 tokenizers. 80 checks total.

| Character | Purpose | All 8 tokenizers |
|-----------|---------|-----------------|
| `\|` (pipe) | Field delimiter | **Always 1 token** |
| `@` | Symbol ID prefix | **Always 1 token** |
| `<` | Edge direction | **Always 1 token** |
| `##` | Section header | **Always 1 token** |
| `\n` | Row separator | **Always 1 token** |
| `{` | Schema open | **Always 1 token** |
| `}` | Schema close | **Always 1 token** |
| `[` | Count open | **Always 1 token** |
| `]` | Count close | **Always 1 token** |
| `,` | Schema separator | **Always 1 token** |

**Zero exceptions.** 10 characters, 8 tokenizers, 80 checks, no variance.

We then tested whether these delimiters merge with adjacent content:

```
hello|world    → [hello][|][world]       ALL 8 tokenizers
|150|          → [|][150][|]             ALL 8 tokenizers
@0|function    → [@][0][|][function]     ALL 8 tokenizers
```

**Pipe never merges.** The field boundary is always at the same token position regardless of which model processes the data. Every model sees identical structure.

## Finding 4: JSON Overhead is 81%, Growing Linearly

Beyond the structural ambiguity, JSON also burns the majority of its tokens on non-data content. At 500 rows of a simple frequency table (4 fields):

| Category | Tokens | % of total |
|----------|--------|------------|
| Repeated field names (`"field":`, `"value":`, etc.) | 5,500 | **52.4%** |
| Structural characters (`{`, `}`, `[`, `]`, `:`, `,`) | 3,001 | **28.6%** |
| Actual data values | 1,995 | **19.0%** |
| **Total** | **10,496** | |

Over 80% of JSON tokens are overhead. The LLM is processing 5x more noise than signal.

GCF for the same data:

| Category | Tokens | % of total |
|----------|--------|------------|
| Header (field names, declared once) | 10 | **0.2%** |
| Data rows | 6,500 | **99.8%** |
| **Total** | **6,510** | |

### The scaling problem

JSON's overhead grows **linearly** with row count. GCF's overhead is **constant**:

| Rows | JSON overhead | GCF overhead | Ratio |
|------|--------------|--------------|-------|
| 10 | 171 tokens | 10 tokens | 17:1 |
| 100 | 1,701 tokens | 10 tokens | 170:1 |
| 500 | 8,501 tokens | 10 tokens | 850:1 |
| 1,000 | 17,001 tokens | 11 tokens | 1,545:1 |

At 1,000 rows, JSON burns 17,001 tokens on overhead (repeated field names + structural characters). GCF uses 11. The ratio is 1,545:1.

## Finding 5: Cross-Tokenizer Validation

The overhead pattern holds across all 8 tokenizers:

| Tokenizer | JSON tokens | GCF tokens | Savings | JSON field-name overhead |
|-----------|------------|-----------|---------|------------------------|
| Claude (Anthropic) | 10,996 | 7,013 | 36.2% | 54.6% |
| GPT-4 (OpenAI) | 10,494 | 6,508 | 38.0% | 52.4% |
| GPT-4o (OpenAI) | 10,494 | 6,508 | 38.0% | 52.4% |
| LLaMA 3.1 (Meta) | 10,494 | 6,508 | 38.0% | 52.4% |
| Qwen 2.5 (Alibaba) | 13,150 | 9,166 | 30.3% | 41.8% |
| DeepSeek V3 | 10,494 | 6,509 | 38.0% | 57.2% |
| Gemma 2 (Google) | 14,149 | 9,669 | 31.7% | 42.4% |
| Mistral Nemo | 13,649 | 9,167 | 32.8% | 44.0% |

Every tokenizer confirms: JSON spends **42-57% of its tokens on repeated field names alone**.

## Why This Matters for Comprehension

We've observed across [2,400+ LLM evaluations](https://gcformat.com/guide/benchmarks) that JSON comprehension degrades at scale (53.4% accuracy at 500 records) while GCF maintains high accuracy (100% on standard workloads, 91.2% on structurally complex data).

The tokenization analysis explains the mechanism:

**JSON at scale presents the model with:**
1. Ambiguous structural boundaries (field names merge with quotes on 4/8 tokenizers)
2. Overwhelming repetition (52% of tokens are repeated field names carrying zero new information)
3. Low signal-to-noise ratio (only 19% of tokens are actual data)

**GCF at scale presents the model with:**
1. Unambiguous structural boundaries (pipe is always 1 token, never merges)
2. Zero repetition (field names declared once in header)
3. Near-100% signal (99.8% of tokens are actual data)

The model doesn't fail because JSON is "too long." It fails because at 500+ rows, there are thousands of structurally ambiguous token boundaries competing for attention, while 80% of the token positions carry no information. The attention mechanism is spread across noise rather than concentrated on signal.

GCF eliminates both problems. The structure is always unambiguous (pipe is pipe, everywhere, on every model). And nearly every token carries actual data.

## The Structural Variance Hypothesis

This analysis suggests a hypothesis for the model-dependent failures we observe in our evaluations:

- **GPT-5.4 produces deterministic wrong answers** on JSON (always says `edge_count=198` when correct is 200). The merged `"value` tokens on its tokenizer (o200k) may create a consistent parsing offset.
- **Claude Opus never fails on GCF** but fails on JSON distance-filtering. Claude's tokenizer keeps quotes separate from field names, so it should handle JSON better than GPT-4, and it does (96.2% vs 78.0%), but still fails because the attention dilution problem remains.
- **GCF achieves 100% on Claude Sonnet, Gemini Pro, Gemini 3.1 Pro, and Gemini 3.5 Flash.** These models see clean, unambiguous structure with no wasted tokens. There's nothing to confuse.

## Implications

### For format designers

If you're designing a format that LLMs will read, choose delimiters from the "never-merge" category. Our [ASCII delimiter space analysis](https://gcformat.com/guide/tokenizer-analysis#ascii-delimiter-space-analysis) found 74 of 94 printable ASCII characters are safe (always 1 token, never merge with neighbors). The 20 unsafe characters include dots, dashes, underscores, and common lowercase letters (exactly the characters JSON uses in field names).

### For tool builders

If your MCP server or AI tool outputs JSON to LLMs, understand that you're sending data where 80% of tokens are noise and the structural boundaries tokenize differently per model. At 10 records this is fine. At 500+ records, you're in the failure zone.

### For agent architects

If you're building multi-model systems (routing between Claude, GPT, Gemini), JSON's structural ambiguity means each model sees the same data *differently* at the token level. GCF gives every model identical structural input. This matters for consistency in multi-model pipelines.

## Reproduce

All experiments are reproducible:

```bash
git clone https://github.com/blackwell-systems/gcf
cd gcf

# Structural variance benchmark
node eval/structural-variance.mjs

# JSON overhead analysis
node eval/json-tokenization-analysis.mjs

# Full tokenizer variance analysis (8 tokenizers, multiple scales)
node eval/tokenizer-variance.mjs
```

The evaluation framework, all raw logs, and the full comprehension dataset are open source at [github.com/blackwell-systems/gcf](https://github.com/blackwell-systems/gcf).

## Summary

| Metric | JSON | GCF |
|--------|------|-----|
| Structural patterns that vary across tokenizers | 4/15 (27%) | **0/10 (0%)** |
| Delimiter merges with adjacent content | Yes (4/8 tokenizers) | **Never** |
| Tokens spent on overhead (500 rows) | 81% | **0.2%** |
| Overhead growth | Linear (17K at 1000 rows) | **Constant (11 tokens)** |
| Signal-to-noise ratio | 19% signal | **99.8% signal** |
| Comprehension at 500 records | 53.4% | **91.2-100%** |

JSON wasn't designed for LLMs. It was designed in 2001 for human-readable data interchange between web browsers and servers. Its structural choices (quotes around keys, colons as separators, repeated field names) made sense for that era. They're suboptimal for the era of AI agents reading structured data at scale.

The tokenization analysis shows this isn't just about token count. It's about structural ambiguity. Different models see different boundaries. And that ambiguity compounds with every row of data.
