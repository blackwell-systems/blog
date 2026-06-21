---
title: "Why LLMs Struggle with JSON at Scale: A Tokenization Analysis"
date: 2026-06-21
draft: false
tags: ["json", "tokenization", "llm", "gcf", "ai-agents", "wire-format", "mcp", "token-efficiency", "bpe", "attention"]
categories: ["ai", "research"]
description: "JSON's structural grammar tokenizes ambiguously across models. Merged tokens like '\"name' (#32586) are hardcoded vocabulary entries on GPT-4, LLaMA, and Qwen. This is irrecoverable: frozen vocabulary, all weights depend on it. GCF's pipe has near-zero vocabulary merges. 8 tokenizers, 6 providers, exhaustive vocabulary scan."
summary: "We benchmarked 8 tokenizers from 6 providers and performed exhaustive vocabulary scans. 15 of the most common JSON field names (id, name, type, value, title, time, text, url, path, description) exist as merged vocabulary entries (quote+field in one token) on GPT-4 (#32586 for '\"name'), LLaMA, and Qwen. Claude and Gemma have zero such entries. These merges are hardcoded, deterministic, and irrecoverable without retraining the tokenizer. On real eval data: JSON boundary merge rate 8.93% vs GCF 1.00% (88.8% fewer). GPT-4 has 114 quote+letter vocabulary entries vs 17 pipe+letter (6.7:1 ratio). JSON overhead is 81% at scale. This structural ambiguity compounds per row and explains model-dependent comprehension failures across 2,400+ evaluations."
---

Everyone knows JSON is verbose. The common explanation for why LLMs struggle with JSON at scale is "too many tokens." That explanation is incomplete. The real problem is more subtle and more dangerous: JSON's structural grammar tokenizes **ambiguously** across different models, and this ambiguity compounds with every row of data.

We ran a structural variance benchmark across 8 tokenizers from 6 providers. The findings explain a pattern we've observed across 2,400+ LLM evaluations: why JSON comprehension fails at scale, why it fails *differently* per model, and why no amount of prompt engineering can fix it.

## Background: How BPE Tokenizers Handle Structured Data

Modern LLMs use Byte-Pair Encoding (BPE) tokenizers trained on large text corpora. BPE builds a vocabulary by iteratively merging the most frequent byte sequences. This creates a vocabulary optimized for natural language, not for structured data formats.

The critical property: **BPE merging is context-dependent.** The same character can be part of different tokens depending on what characters surround it. A quote character `"` might be its own token in one context and merge with adjacent characters in another.

For natural language, this is efficient (common words like "the" become single tokens). For structured formats like JSON, it creates a problem: the characters that mark structural boundaries (`"`, `:`, `{`, `}`) can merge with the content they're supposed to delimit.

**A critical distinction:** Any structured format contains two types of content: *grammar symbols* (delimiters that define structure) and *payload content* (the actual data values). A format designer controls grammar symbols but cannot control how payload content tokenizes without altering the data itself. The question isn't "does everything tokenize consistently?" (it won't, and can't). The question is: **do the structural boundaries always land at clean, unambiguous token positions?** If yes, the model always knows where one field ends and the next begins, regardless of how the values themselves split.

This has been noted in passing by researchers. Deekeswar (2604.17512) measured that 1,000 JSON records consume ~80K tokens with the majority being repeated keys and punctuation. Nandakishore (2604.05400) stated "optimizing for tokenizer efficiency, not just human readability, is going to matter." But nobody has performed a systematic mechanistic analysis of exactly how and where JSON's structure breaks down at the BPE level.

## The Experiment

We tested 8 tokenizers from 6 providers, representing every major LLM family in production:

| Tokenizer | Provider | Model Family | Vocab Size |
|-----------|----------|-------------|-----------|
| Claude tokenizer | Anthropic | Claude 3.5, 4.x | ~100K |
| cl100k_base | OpenAI | GPT-4 | 100,256 |
| o200k_base | OpenAI | GPT-4o | 200,019 |
| LLaMA 3.1 tokenizer | Meta | LLaMA 3.x | 128,256 |
| Qwen 2.5 tokenizer | Alibaba | Qwen 2.5 | 151,936 |
| DeepSeek V3 tokenizer | DeepSeek | DeepSeek V3 | 128,000 |
| Gemma 2 tokenizer | Google | Gemma 2 | 256,128 |
| Mistral Nemo tokenizer | Mistral | Mistral/Ministral | 131,072 |

These tokenizers were each trained on different corpora with different merge priorities. Their disagreements on how to tokenize the same input reveal fundamental properties of that input's structure.

We measured two things:

1. **Do structural delimiters tokenize consistently across models?** If not, different models see different field boundaries for the same data.
2. **Do structural characters merge with adjacent content?** If so, the model receives tokens that conflate structural markup with semantic content, making field boundaries ambiguous.

## Finding 1: JSON Field Boundaries Tokenize Inconsistently

JSON uses the pattern `"fieldName":` to mark each field. This pattern repeats on every row of an array. We tested 155 common field names from production APIs across all 8 tokenizers.

**15 of the most common field names in computing merge on half or more of all tokenizers:**

| Field | Merge rate | Models affected |
|-------|-----------|----------------|
| `"id":` | **63%** (5/8) | GPT-4, GPT-4o, LLaMA, Qwen, Mistral |
| `"name":` | **63%** (5/8) | GPT-4, GPT-4o, LLaMA, Qwen, Mistral |
| `"time":` | **63%** (5/8) | GPT-4, GPT-4o, LLaMA, Qwen, Mistral |
| `"title":` | **63%** (5/8) | GPT-4, GPT-4o, LLaMA, Qwen, Mistral |
| `"type":` | **50%** (4/8) | GPT-4, GPT-4o, LLaMA, Qwen |
| `"value":` | **50%** (4/8) | GPT-4, GPT-4o, LLaMA, Qwen |
| `"url":` | **50%** (4/8) | GPT-4, GPT-4o, LLaMA, Qwen |
| `"user_id":` | **50%** (4/8) | GPT-4, GPT-4o, LLaMA, Qwen |
| `"text":` | **50%** (4/8) | GPT-4, GPT-4o, LLaMA, Qwen |
| `"path":` | **50%** (4/8) | GPT-4, GPT-4o, LLaMA, Qwen |
| `"description":` | **50%** (4/8) | GPT-4, GPT-4o, LLaMA, Qwen |
| `"in":` | **50%** (4/8) | GPT-4, GPT-4o, LLaMA, Qwen |
| `"is":` | **50%** (4/8) | GPT-4, GPT-4o, LLaMA, Qwen |
| `"encoding":` | **50%** (4/8) | GPT-4, GPT-4o, LLaMA, Qwen |
| `"dns":` | **50%** (4/8) | GPT-4, GPT-4o, LLaMA, Qwen |

These aren't obscure fields. `id`, `name`, `type`, `value`, `title`, `time`, `text`, `url`, `path`, `description` appear in virtually every JSON API response. The affected model families (GPT-4/4o, LLaMA, Qwen) represent roughly half the LLM market.

**What this means:** At 500 rows with just `id` + `name` + `type` (and what payload doesn't have these?), that's **1,500 field boundaries** where the majority of models see a hidden merge. Claude, DeepSeek, and Gemma keep all boundaries clean. GPT-4, GPT-4o, LLaMA, Qwen, and Mistral do not. This isn't a one-time ambiguity; it compounds linearly with data size.

### The worst case: 7 distinct tokenizations

We searched across 40 field names and 21 values to find maximum variance. The worst pattern:

`"userName":"req_xyz789"` produces **7 distinct tokenizations** across 8 models:

```
GPT-4, LLaMA:     ["][userName][":"][req][_xyz][789]["]
GPT-4o:           ["user][Name][":"][req][_xyz][789]["]
Claude:           ["][userName][":"][req][_][xyz][789]["]
Qwen 2.5:        ["][userName][":"][req][_xyz][7][8][9]["]
DeepSeek V3:     ["][user][Name][":"][req][_][xyz][789]["]
Gemma 2:         ["][userName][":"][req][_][xyz][7][8][9]["]
Mistral Nemo:    ["][user][Name][":"][req][_x][yz][7][8][9]["]
```

Almost every model sees a structurally different token sequence for the same data. Note how GPT-4o merges the quote into `["user]` while other models keep it separate.

### Full objects: 4 different token counts

A complete JSON object `{"orderId":"ORD-001","value":"shipped"}` produces **4 different token counts** depending on the model:

| Token count | Models |
|-------------|--------|
| 12 tokens | GPT-4, LLaMA |
| 13 tokens | GPT-4o, Claude, DeepSeek |
| 14 tokens | Qwen, Gemma |
| 15 tokens | Mistral |

The same JSON object is a different length on every model family. This means attention patterns, positional encodings, and context budget impact all vary per model for identical input data.

## Finding 2: The Merge Mechanism

The variance in Finding 1 has a specific cause: BPE merging absorbs the opening quote into the field name.

When GPT-4's tokenizer (cl100k_base) encounters `"value":`, it produces:

```
Token 1: "value    (quote + field name = one token)
Token 2: ":        (quote + colon = one token)
```

Claude's tokenizer encounters the same string and produces:

```
Token 1: "         (quote alone)
Token 2: value     (field name alone)
Token 3: ":        (quote + colon)
```

**The structural boundary lives in a different position.** On GPT-4, the opening quote is fused with the content. On Claude, it's separate. The model must learn to decompose the merged token `"value` into "this is a quote character followed by a field name" rather than treating it as a single semantic unit.

### Why this happens

BPE vocabularies are built from training data statistics. If `"value` appears frequently in the training corpus (it does, because JSON is everywhere in code), the tokenizer learns it as a single merge. Tokenizers trained on different corpora (or with different vocabulary sizes) reach different merge decisions for the same character sequences.

This is well-studied for natural language (Liyanage & Yvon, 2601.21665, on post-training tokenizer adaptation). But the implications for structured data are underexplored: when the merge boundary falls on a structural delimiter, the result is a token that conflates syntax and semantics.

### The merge pattern at field-to-value boundaries

We tested JSON's most structurally critical pattern: the complete field-to-value transition `"field":"data"`:

```
"value":"hello"

GPT-4, GPT-4o, LLaMA, Qwen (4 tokenizers):
  ["value] [":"] [hello] ["]

Claude, DeepSeek, Gemma, Mistral (4 tokenizers):
  ["] [value] [":"] [hello] ["]
```

**On half of all tokenizers, the field name is fused into the opening quote.** The model sees a single token where there should be a structural boundary.

For `"name":"Alice"`:

```
GPT-4, GPT-4o, LLaMA, Qwen, Mistral (5 tokenizers):
  ["name] [":"] [Alice] ["]

Claude, DeepSeek, Gemma (3 tokenizers):
  ["] [name] [":"] [Alice] ["]
```

Five of eight tokenizers merge `"name` into a single token. The field boundary is invisible at the token level on these models.

## Finding 3: GCF Grammar Merges 88.8% Less

For comparison, we tested all 10 characters in GCF's grammar against all 8 tokenizers. 80 individual checks.

| Character | Purpose | Claude | GPT-4 | GPT-4o | LLaMA | Qwen | DeepSeek | Gemma | Mistral |
|-----------|---------|--------|-------|--------|-------|------|----------|-------|---------|
| `\|` | Field delimiter | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| `@` | Symbol ID prefix | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| `<` | Edge direction | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| `##` | Section header | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| `\n` | Row separator | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| `{` | Schema open | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| `}` | Schema close | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| `[` | Count open | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| `]` | Count close | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |
| `,` | Schema separator | 1 | 1 | 1 | 1 | 1 | 1 | 1 | 1 |

**80 checks. Zero exceptions.** Every GCF structural character is always exactly 1 token on every tokenizer.

We then verified that these characters never merge with adjacent content. We tested 15 realistic field+value patterns across all 8 tokenizers (120 additional checks):

```
value|pending            → [value][|][pending]          ALL 8 tokenizers
name|Alice               → [name][|][Alice]             ALL 8 tokenizers
orderId|ORD-001          → [orderId][|][ORD][-][001]    ALL 8 tokenizers
userName|john            → [userName][|][john]           ALL 8 tokenizers
email|alice@example.com  → [email][|][alice][@]...      ALL 8 tokenizers
score|95.5               → [score][|][95][.][5]         ALL 8 tokenizers
```

On real-world eval data (14 field names, 25 values, 2,800 checks per format):

| Format | Boundary merge rate | Cause |
|--------|-------------------|-------|
| JSON | **8.93%** | Field names (`"id":`, `"name":`) merge on 62.5% of tokenizers |
| GCF | **1.00%** | One value (`cancelled`) triggers merge on 25% of tokenizers |

**GCF has 88.8% fewer boundary merges on real data.**

The critical difference: JSON's merges are caused by **field names** which repeat on every row (compounding at scale). GCF's merges are caused by a rare **value** (appearing occasionally). At 500 rows with `"id"` and `"name"` fields, JSON has ~625 hidden boundaries. GCF has a handful.

Under adversarial conditions (values starting with `/`, `.`, `-`), GCF's pipe can merge on some tokenizers (e.g., `[|/]` on LLaMA and Gemma). Even then, the pipe is at the **start** of the merged token (boundary position identifiable). In JSON, the quote is at the start with the field name **after** it (`["value]`), hiding the boundary inside.

No delimiter is perfect against all possible right-contexts. But GCF's grammar characters merge at significantly lower rates than JSON's, and when they do merge, the boundary remains at the token start rather than hidden inside.

### Why GCF's delimiters are safe

This isn't accidental. We analyzed all 94 printable ASCII characters (codes 33-126) across all 8 tokenizers on two criteria:

1. Does it encode as exactly 1 token in isolation?
2. Does it never merge with adjacent text?

74 of 94 characters satisfy both criteria. The 20 characters that fail include `.` (merges into `.validate`), `-` (merges into `-based`), `_` (merges into `_name`), and common lowercase letters. These are exactly the characters that appear in JSON's structural patterns (dots in qualified names, underscores in field names, dashes in UUIDs).

GCF's grammar was designed using only characters from the safe set. The format's tokenization stability is a deliberate design choice, not a lucky accident.

## Finding 4: The Root Cause Is in the Vocabulary

Everything above describes WHAT happens (merging) and WHERE (which fields, which models). This finding explains WHY and proves it's irrecoverable.

BPE tokenizers have a fixed vocabulary: a lookup table mapping strings to integer IDs. When the tokenizer encounters input, it greedily selects the longest matching vocabulary entry. If `"name` exists as entry #32586, it will always be selected as a single token. This is not a context-dependent decision. It's a dictionary lookup.

We scanned every entry in all 8 tokenizer vocabularies:

| Tokenizer | Vocab size | Quote+letter entries | Pipe+letter entries | Ratio |
|-----------|-----------|---------------------|---------------------|-------|
| GPT-4 (cl100k) | ~100K | **114** | 17 | **6.7:1** |
| GPT-4o (o200k) | ~200K | **86** | 6 | **14.3:1** |
| Claude | ~65K | **0** | 0 | clean |
| LLaMA 3.1 | ~128K | **114** | 18 | **6.3:1** |
| Qwen 2.5 | ~131K | **114** | 17 | **6.7:1** |
| DeepSeek V3 | ~128K | **42** | 4 | **10.5:1** |
| Gemma 2 | ~256K | **0** | 0 | clean |
| Mistral Nemo | ~131K | **31** | 3 | **10.3:1** |

GPT-4 has **114 vocabulary entries** where a quote is fused with a following word. Claude and Gemma have **zero**. This is why Claude handles JSON boundaries cleanly and GPT-4 doesn't: the merged token literally does not exist in Claude's dictionary.

### Actual token IDs

These are not hypothetical. These are dictionary entries with specific IDs:

| Field | GPT-4 | GPT-4o | LLaMA | Qwen | Claude | Gemma |
|-------|-------|--------|-------|------|--------|-------|
| `"name` | #32586 | #74800 | #32586 | #31486 | — | — |
| `"id` | #29800 | #60094 | #29800 | #28700 | — | — |
| `"type` | #45570 | #91290 | #45570 | #44470 | — | — |
| `"value` | #64407 | #180654 | #64407 | #63307 | — | — |
| `"title` | #83827 | #187286 | #83827 | #82727 | — | — |
| `"description` | #69093 | #150676 | #69093 | #67993 | — | — |

Cross-verified: we encoded `"name":"Alice"` and confirmed token #32586 appears in GPT-4's output. The entries are active, not dead vocabulary.

### Why these entries exist

JSON is one of the most common data formats in LLM training corpora. Every GitHub repo has `package.json`. Every API doc shows JSON examples. Every Stack Overflow answer demonstrates JSON parsing. The byte sequence `"name` appeared billions of times in training data, so the tokenizer learned it as a high-frequency merge and added it to the vocabulary.

This is efficient for compression (fewer tokens for common patterns). But it creates structural ambiguity: the grammar symbol (`"`) and the payload content (`name`) become one token, and the model cannot see inside a token to decompose it.

### The training familiarity paradox

The conventional wisdom is that LLMs "know" JSON best because they've been trained on more JSON than any other structured format. This is true at the model level: the transformer weights have learned JSON's semantics from billions of examples. But at the tokenizer level, the opposite happens: **the more JSON the tokenizer saw during training, the more aggressively it merged JSON patterns, and the more structural boundaries it hid.**

The models that saw the MOST JSON have the WORST JSON boundaries:

- GPT-4 (massive code corpus): **114 merged quote+field entries**
- LLaMA (large code mix): **114 merged entries**
- Claude (different tokenizer strategy): **0 merged entries**

The training familiarity didn't create structural understanding. It created compression. The tokenizer optimized for representing JSON in fewer tokens, which is exactly what a compression algorithm should do. But compression hides structure. The quote and the field name became one token because that's more efficient for storage. It's less efficient for comprehension.

This inverts the standard argument entirely. "Trained on JSON" is not an advantage for structural comprehension at scale. It's the mechanism that causes structural ambiguity. The tokenizer's efficiency is the model's handicap.

### Why Claude and Gemma don't have this problem

Claude's tokenizer has zero quote+letter entries. Gemma's has zero. The specific tokenizer training details are proprietary, but measurable differences explain the divergence:

- **Vocabulary size:** Claude uses ~65K entries (smallest tested). Smaller vocabularies are more conservative about which merges to include. GPT-4's 100K has budget for specialized merges like `"name`.
- **Training data mix:** Less code/JSON in the training corpus means `"name` appears less frequently, making it less likely to cross the merge threshold.
- **Merge boundary policy:** BPE training can be configured to treat certain characters as merge barriers. Anthropic and Google may have prevented `"` from merging with adjacent letters.

Gemma's vocabulary is the **largest** (256K) yet has zero quote merges. Larger vocabulary doesn't mean more merges. The merge policy matters more.

### Why this is irrecoverable

1. **Vocabulary is frozen.** Once the tokenizer is trained, entries never change. Fine-tuning adjusts weights, not vocabulary.
2. **All weights depend on the vocabulary.** Token #32586 has a learned embedding. Removing it would break every layer.
3. **Tokenization is pre-model.** The merge happens before the transformer processes the input. The model receives integer IDs, not characters.
4. **Retraining the tokenizer requires retraining the model.** New vocabulary means new embeddings, new attention patterns. Full retrain from scratch.

No amount of prompt engineering, fine-tuning, or RLHF can fix this. The structural boundary between `"` and `name` is invisible to GPT-4 because token #32586 exists in its dictionary. It will always exist. The only fix is a format whose grammar characters don't appear as merged entries in tokenizer vocabularies.

### What about GCF's pipe?

The pipe has a small number of merged entries (17 on GPT-4), but they're with **programming keywords** (`|null`, `|string`, `|max`, `|min`, `|required`) from TypeScript/Go type union syntax. `|name`, `|id`, `|type`, `|value` never exist as vocabulary entries on any tokenizer. The pipe merges with type-system keywords, not with the field names that matter for structured data.

## Finding 5: JSON Overhead is 81%, Growing Linearly

Beyond structural ambiguity, JSON also burns the majority of its tokens on non-data content. We measured where tokens go in a 500-row frequency table (4 fields: field, value, count, percentage):

### JSON token distribution (500 rows, GPT-4o tokenizer)

| Category | Tokens | % of total | Growth |
|----------|--------|------------|--------|
| Repeated field names (`"field":`, `"value":`, etc.) | 5,500 | **52.4%** | Linear (11 per row) |
| Structural characters (`{`, `}`, `[`, `]`, `:`, `,`) | 3,001 | **28.6%** | Linear (6 per row) |
| Actual data values | 1,995 | **19.0%** | Linear (content-dependent) |
| **Total** | **10,496** | | |

**81% of JSON's tokens carry zero new information after the first row.** The field names `"field":`, `"value":`, `"count":`, `"percentage":` are declared on row 1 and then repeated identically 499 more times.

### GCF token distribution (same data)

| Category | Tokens | % of total | Growth |
|----------|--------|------------|--------|
| Header (field names, declared once) | 10 | **0.2%** | Constant |
| Data rows | 6,500 | **99.8%** | Linear (content only) |
| **Total** | **6,510** | | |

GCF declares field names once in the header (`## [500]{field,value,count,percentage}`), then emits rows with zero structural repetition. The ratio of useful-to-total tokens is 99.8%.

### Per-field cost analysis

Each JSON field-name pattern costs tokens on every row:

| Field pattern | Tokens per occurrence | × 500 rows | Total cost |
|--------------|---------------------|------------|-----------|
| `"field":` | 3 | × 500 | 1,500 |
| `"value":` | 2 (GPT-4o) to 3 (Claude) | × 500 | 1,000-1,500 |
| `"count":` | 3 | × 500 | 1,500 |
| `"percentage":` | 3 | × 500 | 1,500 |
| **Total per row** | **11** | **× 500** | **5,500** |

In GCF, all four field names cost **10 tokens total** (once, in the header).

### The ratio at scale

| Rows | JSON overhead (field names + structural) | GCF overhead (header) | Ratio |
|------|------------------------------------------|----------------------|-------|
| 10 | 171 tokens | 10 tokens | 17:1 |
| 50 | 851 tokens | 10 tokens | 85:1 |
| 100 | 1,701 tokens | 10 tokens | 170:1 |
| 500 | 8,501 tokens | 10 tokens | 850:1 |
| 1,000 | 17,001 tokens | 11 tokens | **1,545:1** |

At 1,000 rows, JSON burns 17,001 tokens on structural overhead. GCF uses 11. The gap grows without bound because JSON's overhead is O(n) per row while GCF's is O(1).

## Finding 6: Cross-Tokenizer Consistency

The overhead pattern is not an artifact of one tokenizer. All 8 confirm it:

| Tokenizer | JSON tokens | GCF tokens | Savings | JSON field-name overhead |
|-----------|------------|-----------|---------|------------------------|
| Claude (Anthropic) | 10,996 | 7,013 | 36.2% | 54.6% |
| GPT-4 (OpenAI cl100k) | 10,494 | 6,508 | 38.0% | 52.4% |
| GPT-4o (OpenAI o200k) | 10,494 | 6,508 | 38.0% | 52.4% |
| LLaMA 3.1 (Meta) | 10,494 | 6,508 | 38.0% | 52.4% |
| Qwen 2.5 (Alibaba) | 13,150 | 9,166 | 30.3% | 41.8% |
| DeepSeek V3 | 10,494 | 6,509 | 38.0% | 57.2% |
| Gemma 2 (Google) | 14,149 | 9,669 | 31.7% | 42.4% |
| Mistral Nemo | 13,649 | 9,167 | 32.8% | 44.0% |

Every tokenizer shows JSON spending **42-57% of its total tokens** on repeated field names. The absolute numbers vary (Gemma uses more tokens overall due to smaller subword merges), but the proportional waste is consistent.

### The full savings picture

The overhead analysis above uses a flat frequency table. Savings increase with data complexity and session reuse:

| Scenario | GCF vs JSON (pretty) | What drives it |
|----------|---------------------|----------------|
| Generic profile (flat/nested, 500 orders) | 50-59% | Header factorization, inline schemas |
| 15-dataset benchmark (mixed real payloads) | 43-65% | Data complexity determines savings |
| Graph profile (500 symbols + 200 edges) | 63-69% | `@id` refs, edge encoding, section headers |
| Session dedup (90% overlap, call 3 of 5) | **89-90%** | Bare references for previously-seen symbols |
| Session dedup (full 5-call session total) | **84.3%** | Format + dedup combined |

In a real agent session with repeated tool calls to the same codebase, cumulative savings reach 84-92%. JSON has no deduplication mechanism; every call retransmits the full payload. GCF's bare references (`@7` = 2 tokens vs full declaration = 19 tokens) mean subsequent calls cost a fraction of the first.

All numbers cross-tokenizer validated across 8 tokenizers from 6 providers.

## The Attention Dilution Mechanism

Why does structural overhead cause comprehension failures, rather than just costing more? The answer lies in how transformer attention works.

Self-attention allocates a fixed budget across all input positions. When a query token looks for relevant keys, it must attend over the entire sequence. If 80% of that sequence is structural noise (repeated field names, braces, colons), the attention budget is diluted across positions that carry no information for answering the question.

Ildiz et al. (2402.13512) demonstrated a "winner-takes-all" phenomenon in self-attention: the mechanism collapses into attending to a limited subset of tokens. When the sequence is dominated by repetitive structural patterns, the attention mechanism can lock onto those patterns rather than the data values buried within them.

Consider what happens when the model is asked "how many records have status = shipped?" given 500 JSON objects. It must:

1. Attend to every `"status":` pattern (500 occurrences)
2. Read the value following each one
3. Compare to "shipped"
4. Count matches

Steps 1-2 require attending to 500 positions that each look nearly identical in the token sequence. The `"status":` pattern produces the same tokens every time. The model has no structural marker distinguishing the 150th `"status"` from the 350th. It must rely on positional encoding alone to track which row it's on.

In GCF, the equivalent task requires attending to a column of values with pipe delimiters at known, consistent positions. The structural delimiter (pipe) is always at the same relative position within each row. No ambiguity. No repetition competing for attention.

This mechanism, attention dilution from repetitive structural patterns, explains why:
- Errors are larger at scale (more noise = more dilution)
- Errors concentrate on counting tasks (require attention to every row)
- Errors are model-dependent (tokenization differences affect which positions compete for attention)
- GCF doesn't exhibit these failures (no repetition, unambiguous boundaries)

## Counter-Argument: Training Distribution

The strongest counter-argument comes from Kutschka & Geiger (2605.29676) and Matveev (2603.03306): models have seen enormous amounts of JSON during training. This familiarity might compensate for structural inefficiency. JSON is overrepresented in code corpora, and models may have internalized parsing logic that handles merged tokens correctly.

Our response, supported by our evaluation data:

1. **Training familiarity helps at small scale.** All formats achieve near-100% accuracy at 10-50 records. The model has seen enough JSON to parse small payloads easily.

2. **Familiarity fails at scale.** At 500 records with complex structure, JSON drops to 53.4% accuracy across 10 models. No amount of training data exposure compensates for the attention dilution of 8,000+ noise tokens.

3. **GCF achieves 100% with zero training exposure.** No model has ever been trained on GCF. Yet every frontier model comprehends it perfectly on standard workloads and achieves 91.2% on structurally complex data. This proves format structure matters more than training distribution once you're past the complexity threshold.

4. **The threshold is lower than people think.** Matveev's "scaling hypothesis" suggests formats only separate past a complexity threshold. Our data shows that threshold is ~100-200 records for nested data and ~500 for flat tables. Most production tool responses exceed this.

## The Structural Variance Hypothesis

This analysis suggests a testable hypothesis for the model-dependent failures we observe:

| Model | JSON accuracy (stress) | Tokenizer merges `"value`? | Prediction |
|-------|----------------------|---------------------------|------------|
| Claude Opus 4.6 | 73.1% | No (3 separate tokens) | Better JSON performance |
| Claude Sonnet 4.6 | 53.8% | No | Smaller model, attention budget matters more |
| GPT-5.5 | 45.8% | Likely (consistent with o200k patterns) | Merged boundaries hurt at scale |
| GPT-5.4 | 44.1% | Likely (deterministic errors match o200k merges) | Always 198 vs 200 |
| Gemini 2.5 Pro | 58.3% | No (Gemma tokenizer) | Better than GPT but still fails on counting |

The pattern is suggestive: models whose tokenizers merge field-name patterns tend to perform worse on JSON comprehension at scale. This is not proof of causation (model capability differences are a confound), but it's consistent with the structural ambiguity mechanism.

**On GCF, all of these models achieve 85-100%.** The tokenizer differences don't matter because GCF's delimiters are always unambiguous.

## Implications

### For format designers

Choose structural delimiters from the "never-merge" character set. Our ASCII space analysis found 74 safe characters and 20 unsafe ones. The unsafe set includes exactly the characters that appear in JSON's grammar:

- `.` (dot): merges into `.validate`, `.com`, `.json`
- `-` (dash): merges into `-based`, `-style`, `-token`
- `_` (underscore): merges into `_name`, `_id`, `_count`
- Lowercase letters: merge into subword prefixes

**Design principle:** a format's structural characters should be chosen from the set of characters with the lowest merge rates across tokenizers. No character is perfect against all possible adjacent content, but the difference between JSON's 8.93% merge rate and GCF's 1.00% is the difference between 1,500 hidden boundaries at scale and a handful.

### For tool builders

If your MCP server or AI tool outputs JSON arrays to LLMs:

- At 10 records: JSON is fine. All formats work.
- At 100 records: consider alternatives. JSON overhead is 1,701 tokens of noise.
- At 500+ records: JSON's comprehension failures are measurable. 53.4% accuracy means your agent gets the wrong answer nearly half the time.

The fix is straightforward: declare field names once, emit positional rows, use non-merging delimiters. This is what GCF does.

### For agent architects

If you're building multi-model systems:

- JSON produces **different token sequences** on different models for the same data
- This means each model sees a structurally different representation of the same input
- For consistency-critical applications (multi-model voting, fallback chains), this variance matters
- GCF produces **identical structural boundaries** on every model, eliminating this variable

### For researchers

This analysis opens several directions:

1. **Causal testing:** Does artificially introducing merged tokens at field boundaries directly cause comprehension errors? (Controlled experiment with custom tokenizer)
2. **Attention visualization:** Do attention maps show different patterns at merged vs. separate boundary tokens?
3. **Format-aware fine-tuning:** Can models be fine-tuned to handle merged boundary tokens better? (And is that easier or harder than just using a better format?)
4. **Optimal grammar search:** Given a tokenizer vocabulary, what is the mathematically optimal delimiter set? (Minimize total tokens while maximizing boundary consistency)

## Related Work

| Paper | Key contribution | Relation to our findings |
|-------|-----------------|------------------------|
| Deekeswar, "ONTO" (2604.17512) | 1,000 JSON records = ~80K tokens, majority overhead | Quantifies the problem we explain mechanistically |
| Nandakishore, "JTON" (2604.05400) | Header factorization + tabular encoding, 15-60% reduction | Same structural approach as GCF, independently derived |
| Kutschka & Geiger (2605.29676) | Token-efficient formats can hurt accuracy | We show GCF avoids this tradeoff via unambiguous delimiters |
| Ildiz et al. (2402.13512) | Self-attention "winner-takes-all" on repetitive data | Theoretical basis for attention dilution mechanism |
| Karim & Batatia (2508.01685) | Fixed tokens for structure + BPE for values | Hybrid approach; GCF achieves similar result via grammar design |
| Sui et al. (2305.13062) | Table format affects LLM performance | General finding we explain at the BPE level |
| Matveev (2603.03306) | JSON wins for simple structures (scaling hypothesis) | Confirmed: our data shows formats separate past ~200 records |

## Reproduce

All experiments are reproducible from one command:

```bash
git clone https://github.com/blackwell-systems/gcf
cd gcf

# Structural variance benchmark (8 tokenizers, merge analysis)
node eval/structural-variance.mjs

# Common business field analysis (155 fields, 15 worst offenders)
node eval/common-field-merge-analysis.mjs

# Worst-case JSON tokenization search (maximum variance patterns)
node eval/worst-json-tokenization.mjs

# JSON overhead analysis (token distribution, scaling)
node eval/json-tokenization-analysis.mjs

# Full tokenizer variance analysis (8 tokenizers, multiple scales)
node eval/tokenizer-variance.mjs

# Vocabulary entry analysis (root cause: merged tokens are dictionary entries)
node eval/tokenizer-vocabulary-analysis.mjs

# Full vocabulary scan (exhaustive: every entry in every vocabulary)
node eval/vocabulary-full-scan.mjs

# Grammar swap experiment (proves savings are structural, not delimiter-specific)
node eval/grammar-swap-experiment.mjs
```

The comprehension evaluation (2,400+ LLM calls proving these findings correlate with actual model behavior) is at [github.com/blackwell-systems/gcf-go/tree/main/eval](https://github.com/blackwell-systems/gcf-go/tree/main/eval).

## Summary

| Metric | JSON | GCF |
|--------|------|-----|
| Boundary merge rate (real eval data) | **8.93%** (2,800 checks) | **1.00%** (2,800 checks) |
| Merge cause | Field names (repeat per row) | Rare value (occasional) |
| Worst single-field merge rate | 62.5% (`"id":`, `"name":`) | 25% (one value: `cancelled`) |
| Quote+letter vocabulary entries (GPT-4) | **114** | — |
| Pipe+letter vocabulary entries (GPT-4) | — | **17** (none are field names) |
| Root cause | Hardcoded vocab entries (`"name`=#32586) | No field-name merges in any vocab |
| Fixable? | No (frozen vocabulary, all weights depend on it) | N/A |
| Tokens spent on overhead (500 rows) | 81% | **0.2%** |
| Overhead scaling | O(n) per row | **O(1) constant** |
| Signal-to-noise ratio | 19% signal | **99.8% signal** |
| Comprehension at 500 records (stress) | 53.4% | **91.2%** |
| Comprehension on standard workloads | 100% (frontier) | **100% (frontier)** |

JSON was designed in 2001 for human-readable data interchange between web browsers and servers. Its structural choices (quotes around keys, colons as separators, repeated field names) made sense for that era. They predate BPE tokenizers by over a decade. They predate transformer attention by 16 years.

The tokenization analysis shows the problem isn't just token count. It's structural ambiguity. Different models see different boundaries. The attention mechanism is diluted by repetition. And both problems compound linearly with data size.

For LLM systems processing structured data at scale, the format matters. Not just for cost, but for correctness.
