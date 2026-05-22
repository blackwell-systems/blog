---
title: "Your AI Agent's Code Search Hits 2% of the Time. We Benchmarked It."
date: 2026-05-22
draft: false
tags: ["ai", "mcp", "code-intelligence", "ai-agents", "context-window", "token-savings", "benchmark", "knowledge-graph", "code-search", "grep", "developer-tools", "ai-coding", "model-context-protocol", "content-addressing", "merkle-tree", "retrieval", "precision", "open-source", "knowing", "gitnexus", "codegraphcontext", "repomix"]
categories: ["ai", "tools", "open-source", "benchmarks"]
description: "We benchmarked 5 code retrieval systems across 107 tasks, 5 codebases (3.5M LOC to 15K LOC), and 5 languages. grep hits 2% precision. The best competitor hits 7.6%. knowing hits 23%. Statistical proof: p<0.0001, d=0.92 (very large effect). Full methodology and reproduction instructions."
summary: "Rigorous benchmark of AI agent code retrieval: 107 tasks, 5 repos, 5 languages, 4 competitors. grep precision: 2%. GitNexus: 7.6%. knowing: 23% (11.5x better, p<0.0001). Plus: 193x faster indexing, 28x less RAM, 48x more token-efficient than Repomix. The first statistically validated comparison of code intelligence tools for AI agents."
---

Your AI coding agent uses grep to find relevant code. Every time it searches, **98% of what it finds is wrong.**

We know this because we measured it. 107 tasks. 5 codebases. 5 languages. 571,000 edges. Statistical rigor (Wilcoxon signed-rank, Cohen's d, bootstrap confidence intervals). Not a demo on a toy project. A real benchmark with real numbers.

## The Numbers Nobody Wants to Hear

| System | Precision (P@10) | What it means |
|--------|:---:|---|
| grep | 2.0% | 98 out of 100 results are irrelevant |
| GitNexus (knowledge graph) | 7.6% | 92 out of 100 results are irrelevant |
| **knowing** | **23.0%** | 77 out of 100 results are irrelevant, but top results are ranked correctly (MRR=0.38) |

None of these are good in absolute terms. Code retrieval is hard. But the relative differences are enormous:

- **knowing vs grep: 11.5x more precise** (p<0.0001, d=0.92 very large effect)
- **knowing vs GitNexus: 2.75x more precise** (p=0.0003, d=0.50 medium effect)

Your agent currently operates at 2% precision. Every "find relevant code" operation burns tokens on 98% noise. The agent reads irrelevant functions, reasons about them, discards them, and tries again. You pay for all of that.

## What We Tested

Five codebases covering the range of real engineering work:

| Repo | Language | LOC | Files | Edges extracted |
|------|----------|----:|------:|---------:|
| Kubernetes | Go | 3.5M | 4,877 | 268,249 |
| VS Code | TypeScript | 1M | 43K nodes | 93,382 |
| Django | Python | 400K | 2,937 | 185,431 |
| Cargo (Rust) | Rust | 150K | 979 | 79,305 |
| Flask | Python | 15K | 97 | 9,042 |

107 task fixtures across 5 difficulty levels (easy, medium, hard, cross-file, architectural). Hand-curated ground truth validated against actual database contents (95% achievability rate). Independent ground truth: never derived from knowing's own output.

## Why Grep Fails

Grep has one strategy: match text patterns in files. It has no understanding of:

- **What calls what** (a function name appearing in a file doesn't mean it's called there)
- **Type relationships** (which classes implement an interface)
- **Relevance to a task** (matching a keyword isn't the same as being architecturally relevant)
- **Inheritance** (a method defined on a parent class is relevant to all subclasses)

On Kubernetes (3.5M LOC), grep returns thousands of matches for common terms. The agent must read each one to determine if it's relevant. Most aren't.

On Flask (15K LOC), grep is tolerable because the codebase is small. But even there, knowing is 16x more precise because it understands the graph structure: "this function is called by that route handler, which implements this interface, which is consumed by these tests."

## Why Graph Retrieval Wins

knowing builds a content-addressed graph of code relationships. When you ask "what's relevant for this task?", it:

1. **Seeds** from keywords (5-tier matching: exact, prefix, substring, file-path, interface-aware)
2. **Walks** the graph via Random Walk with Restart (finds structurally connected symbols, not just text matches)
3. **Ranks** by blast radius, confidence, recency, and graph distance
4. **Packs** results into your token budget (HITS reranking, density-scored knapsack)

The graph walk is the key differentiator. When you search for "authentication middleware", grep finds every file containing those words. knowing finds the authentication function, then follows call edges to the middleware that uses it, the handler that registers it, and the tests that verify it. Structural relevance, not textual coincidence.

## The Competitor Landscape

We tested every tool we could install:

### GitNexus (Knowledge Graph, LadybugDB)

P@10 = 0.076. Has task-oriented retrieval but 2.75x less precise than knowing.

Also: **cannot handle enterprise repos**. Killed after 60 minutes on Kubernetes (5.7GB RAM, single-threaded JavaScript). knowing indexes the same repo in 18.6 seconds at 200MB RAM.

| Metric | knowing | GitNexus | Ratio |
|--------|---------|----------|-------|
| P@10 | 0.209 | 0.076 | **2.75x** |
| Query latency | 60ms | 612ms | **10x** |
| Index Kubernetes | 18.6s | >60 min (killed) | **>193x** |
| Index VS Code | 4.1s | >22 min (killed) | **>321x** |
| RAM (Kubernetes) | 200MB | 5.7GB | **28x less** |
| Incremental (1 file) | 64ms | 7,000ms | **109x** |

### CodeGraphContext (KuzuDB Graph)

**Cannot perform task-oriented retrieval at all.** Only supports exact name search. Also: 2,159x slower indexing on Flask (215 seconds vs 0.1 seconds for knowing).

### Repomix (25K stars, pack entire repo)

The brute-force approach: dump the entire repo into the context window. Achieves 100% recall by including everything. Token cost: ~300,000 tokens for Flask. knowing achieves ranked results in ~4,000 tokens. **48x more token-efficient** for the same task.

Most models can't fit a Repomix dump. knowing fits in any context window.

### Gortex (Go, in-memory graph)

The closest architectural competitor (Go, tree-sitter, parallel). Comparable quality on small repos. **46x slower on enterprise repos** (14.2 minutes vs 18.6 seconds). Uses 14GB RAM vs 200MB. Re-indexes the entire repo on every query (no caching).

## The Architectural Reason

knowing is built on content-addressed identity (SHA-256 hashes for every node, edge, and snapshot). This isn't just for integrity. It's the query optimization layer:

- **O(packages) diff** instead of O(edges): 216x faster change detection
- **O(1) cache keys**: same query against same graph state = cache hit in 42ns
- **Scoped invalidation**: only evict caches for packages that actually changed
- **Kill-safe**: data streams to SQLite, process death loses at most one file's extraction

Other tools rebuild from scratch on restart. knowing persists everything and resumes where it left off.

## Feedback Compounding

knowing gets smarter with use. When an agent reports which symbols were useful, that signal anchors to the content-addressed hash and persists across sessions:

| Round | P@10 |
|-------|------|
| Cold start | 16% |
| After 1 feedback round | 36% |
| After 5 rounds | ~45% (diminishing returns) |

The feedback expires automatically when code changes (the symbol's package Merkle root changes, old feedback becomes invisible). No manual curation. No stale data. Structural property of the identity model.

## The Honest Limitations

1. **23% absolute precision means 77% miss rate.** knowing is 11.5x better than grep, but most returned symbols still don't match ground truth. The primary bottleneck is graph connectivity: symbols must be reachable via edges from seed keywords.

2. **Dense codebases score higher.** Django (deep class hierarchies): P@10=0.33. Kubernetes (flat Go packages): P@10=0.18. Graph retrieval rewards architectural density.

3. **Cold-start matters.** First-time precision is 23%. After feedback compounding: 36-45%. The system must be used to improve.

4. **Not a fault localizer.** knowing answers "what does the developer need to understand?" not "which function has the bug?" SWE-bench scores are near zero because it measures a different capability.

## Statistical Methodology

This isn't marketing. It's measurement.

- **Pairwise comparison:** Wilcoxon signed-rank test (non-parametric, no normality assumption)
- **Effect size:** Cohen's d with bootstrap 95% confidence intervals
- **Significance threshold:** p < 0.05 (Bonferroni-corrected for multiple comparisons)
- **Ground truth:** Hand-curated fixtures validated against DB contents (95% achievability)
- **No circular validation:** Ground truth never derived from knowing's own output
- **Reproducible:** `GOWORK=off go test ./bench/cross-system/ -run TestCrossSystem -v -timeout 30m`

## The Complete Performance Profile

| Metric | Value |
|--------|-------|
| Retrieval precision (P@10) | 0.230 (11.5x vs grep, 2.75x vs GitNexus) |
| Recall (R@10) | 0.284 (d=0.92 very large effect) |
| Token efficiency vs Repomix | 48x |
| Index: Kubernetes (3.5M LOC) | 18.6s, 200MB RAM |
| Index: VS Code (1M LOC) | 4.1s |
| Index: Flask (15K LOC) | 0.1s |
| Incremental re-index (1 file) | 64ms |
| Query latency (avg) | 60ms |
| GCF wire format vs JSON | 84% fewer tokens |
| Merkle proof generation | 59μs |
| Feedback compounding | +20pp per round |

## Try It

```bash
brew install blackwell-systems/tap/knowing
knowing add .
knowing context -task "refactor auth middleware" -format gcf
```

MCP integration (one line in your config):

```json
{ "mcpServers": { "knowing": { "command": "knowing", "args": ["mcp", "--watch"] } } }
```

Your agent now has graph-ranked context instead of grep. 11.5x better. Measured.

## Reproduce the Benchmark

```bash
git clone https://github.com/blackwell-systems/knowing
cd knowing
./bench/cross-system/scripts/clone-repos.sh
./bench/cross-system/scripts/index-repos.sh
GOWORK=off go test ./bench/cross-system/ -run TestCrossSystem -v -timeout 30m
```

Full methodology: [bench/CONTEXT-PACKING-STUDY.md](https://github.com/blackwell-systems/knowing/blob/main/bench/CONTEXT-PACKING-STUDY.md)

Competitive findings: [bench/cross-system/FINDINGS.md](https://github.com/blackwell-systems/knowing/blob/main/bench/cross-system/FINDINGS.md)

Whitepaper: [Content-Addressing as a Computation Primitive for Software Relationship Intelligence](https://zenodo.org/records/20342255) (DOI: 10.5281/zenodo.20342255)

---

MIT license. Single Go binary. Open source.

[github.com/blackwell-systems/knowing](https://github.com/blackwell-systems/knowing)
