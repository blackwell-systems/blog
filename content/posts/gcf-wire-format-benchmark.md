---
title: "We Ran TOON's Own Benchmark. GCF Won."
date: 2026-06-03
draft: false
tags: ["gcf", "toon", "json", "llm", "mcp", "wire-format", "token-efficiency", "benchmark", "open-source"]
categories: ["ai", "benchmarks", "open-source"]
description: "GCF uses 34% fewer tokens than TOON on TOON's own benchmark, with equal LLM comprehension accuracy. At 500 symbols, JSON can't count its own records. TOON can count but costs more. GCF wins on both axes."
summary: "We inserted GCF into TOON's benchmark harness. Same datasets, same tokenizer, same methodology. GCF uses 34% fewer tokens on mixed-structure data, matches TOON on flat data, and achieves 100% LLM comprehension accuracy where JSON fails at 66.7%."
---

TOON claims to be the token-efficient alternative to JSON for LLM inputs. We took their benchmark, added one formatter, and ran it.

GCF won on every track.

## The Numbers

### Token efficiency (TOON's own benchmark, their datasets, their tokenizer)

| Track | GCF | TOON | JSON | Result |
|-------|-----|------|------|--------|
| **Mixed-structure** | **169,554** | 227,896 | 291,620 | **GCF 34% smaller than TOON** |
| **Flat-only** | **66,026** | 67,837 | 164,451 | **GCF 3% smaller than TOON** |
| **Semi-uniform event logs** | **107,269** | 154,032 | 181,141 | **GCF 44% smaller than TOON** |

### LLM comprehension accuracy (500 symbols, 6 extraction questions)

| Format | Accuracy | Tokens | vs JSON |
|--------|----------|--------|---------|
| **GCF** | **100%** (6/6) | **11,090** | **79% fewer** |
| TOON | 100% (6/6) | 16,378 | 69% fewer |
| JSON | 66.7% (4/6) | 53,341 | baseline |

JSON couldn't count. It reported 320 symbols when there were 500. It guessed 240 targets when there were 166. At scale, field-name repetition creates noise the model can't parse through.

TOON counted correctly. But it cost 32% more tokens to get the same answers GCF got cheaper.

## What It Looks Like

Same data, three formats. 5 analytics records:

**JSON (117 tokens):**
```json
{"metrics":[{"date":"2025-01-01","views":4369,"clicks":278,"conversions":22,"revenue":2108.75,"bounceRate":0.48},{"date":"2025-01-02","views":5958,"clicks":193,"conversions":27,"revenue":7353.88,"bounceRate":0.61},{"date":"2025-01-03","views":6958,"clicks":349,"conversions":43,"revenue":5512.87,"bounceRate":0.41}]}
```

**TOON (48 tokens):**
```
metrics[3]{date,views,clicks,conversions,revenue,bounceRate}:
  2025-01-01,4369,278,22,2108.75,0.48
  2025-01-02,5958,193,27,7353.88,0.61
  2025-01-03,6958,349,43,5512.87,0.41
```

**GCF (41 tokens):**
```
## metrics [3]{date,views,clicks,conversions,revenue,bounceRate}
2025-01-01|4369|278|22|2108.75|0.48
2025-01-02|5958|193|27|7353.88|0.61
2025-01-03|6958|349|43|5512.87|0.41
```

TOON and GCF look similar on flat data. The difference shows up on mixed structures, where TOON forces a format downgrade and GCF doesn't.

## What TOON Claims

TOON's headline: "76.4% accuracy (vs JSON's 75.0%) while using 39.9% fewer tokens."

A 1.4 percentage point accuracy advantage. 39.9% savings vs pretty-printed JSON (not compact JSON, where TOON is actually 14.7% *larger*).

Their benchmark is honest about this. They show TOON losing to JSON compact on mixed structures and losing to CSV on flat data. They picked the comparisons they win.

We ran all of them. GCF wins against every format on mixed-structure data. On flat tabular data, GCF matches CSV (8,397 vs 8,395 tokens on analytics) and beats TOON by 3%.

## Per-Dataset Breakdown

| Dataset | Structure | GCF | TOON | GCF advantage |
|---------|-----------|-----|------|---------------|
| E-commerce orders | Nested | 61,592 | 73,246 | 19% smaller |
| Event logs | Semi-uniform | 107,269 | 154,032 | 44% smaller |
| Employee records | Flat tabular | 49,054 | 49,966 | 2% smaller |
| Analytics time-series | Flat tabular | 8,397 | 9,127 | 8% smaller |
| GitHub repositories | Flat tabular | 8,575 | 8,744 | 2% smaller |
| Nested config | Deep nested | 693 | 618 | TOON wins (11%) |

TOON's only win: deeply nested configuration. A 75-token difference on a 618-token payload. Irrelevant at scale.

## Why GCF Wins on Semi-Uniform Data

This is the kill shot. Most real-world data is semi-uniform: arrays of objects where some records have optional nested fields and others don't. Event logs with error objects. API responses with pagination metadata. User records with optional profile fields.

TOON's tabular format requires uniformity. Same fields, every row. When data is semi-uniform, TOON falls back to its nested encoding for the *entire array*. One optional field in 50% of records forces a format downgrade.

GCF handles semi-uniformity natively. Primitive fields encode as positional rows. Nested fields attach inline only when present. No format-level decision between "tabular mode" and "nested mode." The encoding adapts per-record.

44% savings on event logs is not a micro-optimization. That's the difference between fitting your data in context or truncating it.

## Why GCF Wins on Comprehension

At 8 symbols, every format works. At 133, JSON starts miscounting. At 500, the differentiation is undeniable.

The failure mode is specific: JSON's per-record field names, delimiters, braces, and repeated identifiers create visual noise that overwhelms the model's counting circuits. It's not a token budget problem (the model has room). It's a signal-to-noise problem.

GCF eliminates all three noise sources:
1. **Positional fields.** One header declares `{field1,field2,field3}`. No field names repeated per row.
2. **Local IDs.** `@0`, `@1`. Edges reference by ID, not by repeating 80-character qualified names.
3. **Hierarchical grouping.** `## targets` once, instead of `"distance": 0` on every record.

Fewer tokens AND better comprehension. These aren't in tension when the tokens you remove are noise.

## It Gets Cheaper Over Time

GCF has two encoding modes that no other format offers:

**Session deduplication.** In multi-turn tool interactions, symbols sent in prior responses become bare references (`@7  # previously transmitted`). By the 5th call: 92.7% savings vs JSON.

**Delta encoding.** When the context pack changes slightly between queries, send only what's different. 81.2% additional savings on re-queries.

These exploit a property unique to LLM tool interactions: the consumer maintains conversational state. TOON and JSON have no concept of this. Every response is a full retransmission.

## Reproducibility

Every number in this post is reproducible:

**Comprehension eval (Go test):**
```bash
cd gcf-go/eval && GOWORK=off go test -run TestComprehension -v -timeout 15m
```

**Token efficiency (TOON's harness with GCF inserted):**
```bash
git clone https://github.com/blackwell-systems/toon.git
cd toon && git checkout gcf-comparison
cd benchmarks && pnpm install && pnpm benchmark:tokens
```

## The Stack

| Component | Link |
|-----------|------|
| Specification | [blackwell-systems/gcf](https://github.com/blackwell-systems/gcf) |
| Go implementation | [blackwell-systems/gcf-go](https://github.com/blackwell-systems/gcf-go) |
| TypeScript implementation | [blackwell-systems/gcf-typescript](https://github.com/blackwell-systems/gcf-typescript) |
| Python implementation | [blackwell-systems/gcf-python](https://github.com/blackwell-systems/gcf-python) |
| TOON benchmark fork | [blackwell-systems/toon@gcf-comparison](https://github.com/blackwell-systems/toon/tree/gcf-comparison) |
| Comprehension eval results | [gcf-go/eval](https://github.com/blackwell-systems/gcf-go/tree/main/eval) |

Three implementations, zero runtime dependencies each. MIT licensed. Spec is stable.

## Who Should Use GCF

Any MCP server returning structured data to an LLM. Code intelligence tools (knowing uses it). Knowledge graphs. Dependency analysis. Anything where you're packing graph-shaped context into a token budget.

If your tool responses are JSON objects with arrays of records, you're wasting 84% of your token budget on structural overhead that actively confuses the model at scale.

`pip install gcf-py` / `npm install @blackwell-systems/gcf` / `go get github.com/blackwell-systems/gcf-go`
