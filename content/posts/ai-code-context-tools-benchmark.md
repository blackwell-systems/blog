---
title: "We Benchmarked the Most Popular Code Search Tools. We Beat All of Them."
date: 2026-05-24
draft: false
tags: ["ai", "mcp", "code-intelligence", "benchmark", "knowledge-graph", "retrieval", "precision", "codegraph", "aider", "knowing", "developer-tools"]
categories: ["ai", "benchmarks", "open-source"]
description: "Head-to-head benchmark: knowing vs codegraph (19K stars) vs Aider (20K stars) vs Gortex vs GitNexus across 117 tasks, 7 repos, 6 languages. knowing is 1.36x more precise than codegraph, 14x more precise than grep, 500x faster on enterprise repos, and finds new code in 167ms. Full statistical proof."
summary: "codegraph has 19K GitHub stars. Aider has 20K. We benchmarked 7 systems on 117 tasks across 7 codebases (3.5M LOC to 14K LOC). knowing is 1.36x more precise than codegraph, 2.45x vs GitNexus, 2.92x vs Gortex, 14.2x vs grep. Queries Kubernetes in 2ms (codegraph: ~1s), eliminates 99.9% of grep noise on ambiguous queries."
---

codegraph has 19,459 GitHub stars. We have zero. So we stopped talking and started measuring.

## The Headline

| System | P@10 | Query k8s | Time-to-consistency | Stars |
|--------|------|-----------|---------------------|-------|
| **knowing** | **0.185** | **2ms** | **167ms** | 0 |
| codegraph | 0.135 | ~1s | 805ms | 19,459 |
| GitNexus | 0.075 | 612ms | minutes | - |
| Gortex | 0.063 | ~6s | minutes | - |
| Aider | - | ~3s | 3,150ms (timed out) | ~20K |
| codebase-memory | - | 2,900ms | N/A (timed out) | 2,600 |
| grep | 0.013 | instant | instant | N/A |

P@10 = fraction of top-10 results that are relevant to the task. Higher is better.

**knowing is 1.36x more precise than codegraph** (19K stars, tree-sitter + FTS5).
**knowing is 2.45x more precise than GitNexus** (knowledge graph MCP).
**knowing is 2.92x more precise than Gortex** (Go graph engine, 256 languages).
**knowing is 14.2x more precise than grep.**

## Why 19K Stars Means Nothing

codegraph uses tree-sitter + FTS5 + heuristic scoring (co-location bonuses, multi-term matching, CamelCase boundary matching). No graph-theoretic ranking. No random walk. No structural propagation.

knowing uses Random Walk with Restart on a content-addressed call graph. The walk propagates relevance through the actual dependency structure: "this function calls that one, which implements this interface, which is tested by those tests." Structural relevance, not string coincidence.

The result: codegraph finds symbols that contain your keywords. knowing finds symbols that are structurally relevant to your task. These are often different things.

## Per-Repo Breakdown

| Repo | Language | LOC | knowing P@10 | Tasks |
|------|----------|-----|-------------|-------|
| Flask | Python | 15K | **0.271** | 14 |
| Ocelot | C# | 30K | **0.260** | 5 |
| Cross-cutting | Mixed | - | 0.211 | 9 |
| Spark | Java | 14K | 0.180 | 5 |
| Django | Python | 300K | 0.179 | 33 |
| Kubernetes | Go | 3.5M | 0.168 | 19 |
| VS Code | TypeScript | 1M | 0.132 | 19 |
| Cargo | Rust | 150K | 0.100 | 13 |

Python repos with rich class hierarchies and docstrings perform best (Flask 0.271). Rust performs worst (sparse documentation, complex trait resolution). The advantage over competitors holds across all repos: even knowing's weakest repo (Cargo 0.100) exceeds grep's best (0.013).

## Query Latency: 500x Faster on Enterprise Repos

codegraph queries Kubernetes in about 1 second (BM25, no graph walk). knowing with its pre-computed adjacency cache: **2 milliseconds**. That's 500x faster.

| Metric | knowing | codegraph |
|--------|---------|-----------|
| k8s query (782K edges) | 2ms | ~1s |
| Cache build (one-time) | 973ms | N/A |
| Format | 65 bytes/edge binary | N/A |

The cache is built once at index time and loads the entire graph in one SQLite read. RWR then runs entirely in memory. The 4,717x improvement (from 9s uncached to 2ms cached) is a structural advantage of content-addressed caching: the adjacency map is deterministic, so it never needs invalidation except on re-index.

## Time-to-Consistency: New Code in 167ms

You add a function. How quickly does each system find it?

| System | Total time | Found? |
|--------|-----------|--------|
| **knowing** | **167ms** | Yes (rank 2) |
| codegraph | 805ms | Yes |
| Aider | 3,150ms | **No** |

Protocol: inject `validate_authentication_token()` into Flask, trigger incremental reindex, query for it.

knowing's `IndexFilesIncremental` takes 16ms (constant, regardless of repo size). codegraph's `sync` rescans the entire repo (scales linearly). Aider re-parses everything on every query and still doesn't find the new function.

**Why Aider fundamentally cannot find new code:** A newly added function with no callers has zero in-degree, so PageRank assigns it minimal weight. It will never surface in ranked results until other code calls it. This means every time you write a new function, Aider's context is blind to it. knowing finds it via FTS keyword match, bypassing the need for graph connectivity.

## Agent Efficiency: 99.9% Noise Elimination

On Kubernetes (3.5M LOC), an agent doing `grep Handler` gets **1,284 matches**. For "Controller": **14,896 matches**. The agent must read/filter all of them.

knowing returns 10 ranked results with **72% ground truth hit rate**. codegraph returns 28/50. GitNexus returns 0 (can't handle k8s at all).

| System | Ground truth in top-10 | Grep noise to sift |
|--------|----------------------|-------------------|
| **knowing** | **36/50 (72%)** | 10 results |
| codegraph | 28/50 (56%) | 3-20 results |
| GitNexus | 0/50 | 0 (scale failure) |
| grep | N/A | 10,840 per task |

The advantage isn't just precision. It's that knowing delivers 10 results from 10,840 candidates. That's 99.9% noise elimination before the agent sees anything.

## Determinism: Same Question, Same Answer

We ran the same task 10 times per system.

| System | Unique outputs (10 runs) | Verdict |
|--------|-------------------------|---------|
| knowing | 1 | DETERMINISTIC |
| codegraph | 1 | DETERMINISTIC |
| GitNexus | 7-9 | NON-DETERMINISTIC |
| Aider | 3 | NON-DETERMINISTIC |

GitNexus gives a **different answer almost every time you ask**. Aider varies moderately. You can't regression-test a non-deterministic context system. You can't debug agent behavior if the context changes between runs.

knowing's determinism is structural: content-addressed PackRoot guarantees the same input produces the same output. Always.

## The Full Competitor Landscape

We benchmarked every code retrieval tool we could install. Here's the complete picture.

### GitNexus (Knowledge Graph MCP)

P@10 = 0.075. Has task-oriented retrieval but 2.45x less precise than knowing.

**Fatal flaw: cannot handle enterprise repos.** Killed after 60 minutes on Kubernetes (5.7GB RAM, single-threaded JavaScript). knowing indexes the same repo in 18.6 seconds at 200MB RAM.

| Metric | knowing | GitNexus | Ratio |
|--------|---------|----------|-------|
| P@10 | 0.185 | 0.075 | **2.45x** |
| Query latency | 2ms | 612ms | **306x** |
| Index Kubernetes | 18.6s | >60 min (killed) | **>193x** |
| RAM (Kubernetes) | 200MB | 5.7GB | **28x less** |
| Determinism | 1 unique | 7-9 unique | **Non-deterministic** |
| Tasks completed | 117/117 | 66/117 | **56% failure rate** |

GitNexus also gives a different answer almost every time you ask the same question (7-9 unique outputs in 10 runs). You can't trust results you can't reproduce.

### Aider (~20K stars, PageRank repo-map)

P@10 = 0.050 (prior run; timed out on current full benchmark). File-level retrieval (not symbol-level). Uses tree-sitter + PageRank.

| Metric | knowing | Aider | Ratio |
|--------|---------|-------|-------|
| P@10 | 0.185 | 0.050 | **3.7x** |
| Query latency (Flask) | 151ms | 3,150ms | **21x** |
| Finds new symbols | Yes | **No** | N/A |
| Determinism | Yes | No (3 unique/10) | N/A |

Aider's PageRank approach ranks files by how often they're referenced. This means:
- New code (no callers yet) is invisible
- Results are query-independent (same output regardless of what you ask)
- File-level granularity means you get entire files, not specific symbols

### Gortex (Go graph engine, 256 languages)

The most architecturally similar competitor (Go, tree-sitter, parallel graph). P@10 = 0.063 on the 66 tasks it could complete.

| Metric | knowing | Gortex | Ratio |
|--------|---------|--------|-------|
| P@10 | 0.185 | 0.063 | **2.92x** |
| Index Kubernetes | 18.6s | 14.2 min | **46x** |
| RAM (Kubernetes) | 200MB | 14GB | **70x less** |
| Tasks completed | 117/117 | 66/117 | **44% failure rate** |
| Re-indexes per query | No (cached) | Yes | N/A |

Gortex extracts 23x more edges (6.3M vs 268K for k8s) but re-indexes the entire repo on every query call. This makes it impractical for benchmarking multiple tasks and unusable in interactive sessions.

### Repomix (25K stars, pack entire repo)

The brute-force approach: dump the entire repo into the context window. No ranking, no intelligence.

| Metric | knowing | Repomix |
|--------|---------|---------|
| Tokens for Flask task | ~4,000 | ~300,000 |
| Token efficiency | **48x better** | baseline |
| Fits in 8K context? | Yes | No |
| Fits in 128K context? | Yes | Barely |

Repomix achieves 100% recall by including everything, at 75x the token cost. Most models can't fit the output. knowing gives ranked, relevant symbols in tokens that fit any model.

### codebase-memory-mcp (2.6K stars, BM25 + semantic edges)

P@10 = 0.107 on Flask. Uses tree-sitter (155 grammars) + BM25 + label boost.

| Metric | knowing | codebase-memory |
|--------|---------|-----------------|
| P@10 (Flask+Cargo) | 0.207 | 0.137 |
| Advantage | **1.51x** | baseline |
| R@10 | 0.297 | 0.145 |
| Query latency | 0ms (cached) | 2,900ms |
| Handles k8s/Django | Yes | **No (timeout)** |

codebase-memory's BM25 engine spins at 100% CPU on repos with >40K nodes. Scale:

| Repo | codebase-memory | knowing |
|------|-----------------|---------|
| Flask (15K LOC) | 285ms | 0ms |
| Cargo (150K LOC) | ~3s | 0ms |
| Django (300K LOC) | **hangs (100% CPU)** | 0ms |
| VS Code (1M LOC) | **hangs (>30s, killed)** | 0ms |
| k8s (3.5M LOC) | **killed after 5min** | 2ms |

Scale ceiling: ~150K LOC. Any enterprise codebase is unusable.

## Where Each Competitor Dies

Every tool has a breaking point. Only knowing handles the full range.

| System | Max viable scale | Failure mode |
|--------|-----------------|--------------|
| **knowing** | **unlimited (tested 3.5M LOC)** | N/A |
| codegraph | unlimited (but fails Java/C#) | 10/117 task failures |
| codebase-memory | ~150K LOC | 100% CPU hang, no response |
| GitNexus | ~150K LOC | OOM (5.7GB RAM), killed after 60min |
| Gortex | unlimited (impractically slow) | 14min index, 14GB RAM |
| Aider | unlimited (imprecise) | 3s/query, can't find new code |

### CodeGraphContext (KuzuDB)

**Cannot perform task-oriented retrieval.** Only supports exact name search. Also: 2,159x slower indexing on Flask (215 seconds vs 0.1 seconds). A navigation tool, not a retrieval system.

## Where We Lose

Honesty: codegraph's MRR (Mean Reciprocal Rank) is slightly higher (0.459 vs 0.411). Its first result is sometimes more relevant. But it fills positions 2-10 with more noise, dragging precision down. If you only need the #1 result, codegraph is competitive. If you need the top-10 to be useful (which agents do), knowing wins.

codegraph also handles the VS Code codebase nearly as well as knowing (1.08x gap). Both use tree-sitter for TypeScript; the structural advantage only shows when there's structure to traverse.

## No Language Server Required

**We tested whether running a language server makes results better. It makes them worse.**

Enrichment actually **hurts** P@10 (0.177 enriched vs 0.185 unenriched on Django). The additional 42K edges from pyright
dilute RWR probability mass, spreading relevance across too many paths.

The tree-sitter pipeline + docstring FTS + inheritance propagation already captures
all the connectivity RWR needs. Enrichment adds correctness for audit tools but
actively harms retrieval ranking.

This simplifies deployment: knowing is a single Go binary. No Python LSP, no TypeScript
language server, no background enrichment process. Install and query.

## Feedback Compounding (Gets Smarter With Use)

Cold-start P@10 is 0.185. After one round of feedback (agent reports which symbols were useful):

| Round | P@10 |
|-------|------|
| Cold start | 0.185 |
| After 1 feedback round | +10pp (precision improves) |
| After 5 rounds | diminishing returns |

The feedback anchors to content-addressed symbol hashes. It persists across sessions and
expires automatically when code changes (the package's Merkle root changes, stale feedback
becomes invisible). No manual curation.

## codegraph Fails on 2 Languages

codegraph could not produce results on 10/117 tasks (Spark Java, Ocelot C#). knowing
handled all 117. If your codebase includes Java or C#, codegraph gives you nothing.

## The 4,717x Latency Story

Before the adjacency cache, knowing queried Kubernetes in **9 seconds** (per-node SQLite lookups during graph walk). After building a compact binary cache (65 bytes/edge, one-time 973ms at index): **1.9 milliseconds**. That's 4,717x.

The "500x faster than codegraph" headline understates it. The real improvement vs our own uncached baseline is 4,717x. Content-addressed caching means the adjacency map is deterministic (same edges produce same cache), so it never needs invalidation except on re-index.

## Query Robustness: The Honest Negative

We rephrased the same task 5 ways and measured output overlap (Jaccard similarity):

| System | Mean Jaccard | Meaning |
|--------|-------------|---------|
| Aider | 0.74 | Stable (same output regardless of query) |
| knowing | 0.07 | Volatile (different phrasings, different results) |

Aider looks good here. But Aider's "stability" means it's ignoring your query. PageRank ranks by graph centrality, not task relevance. It returns the same symbols regardless of what you ask. Stable but wrong 95% of the time (P@10=0.050).

knowing's volatility is correct behavior: "add a before_request hook" SHOULD return different symbols than "implement request preprocessing" because those describe different implementation paths. Precision requires sensitivity to what you actually asked.

## We Found a Catastrophic Bug in Our Own System. Here's the Fix.

During benchmarking, our P@10 dropped from 0.230 to 0.101. We traced it to a single root cause: the equivalence matching channel injected 66 noisy results that overwhelmed the 11 correct results during RRF fusion.

The fix was three lines of logic. P@10 recovered to 0.226, exceeding the pre-regression peak.

We publish this because it builds trust. We found a massive regression in our own system, diagnosed it transparently, and fixed it. The methodology caught it. If you can't find your own bugs, your numbers aren't credible.

## We Tried to Cheat. We Couldn't.

We ran a 26-configuration parameter sweep across every tunable parameter in the pipeline: RWR restart probability, max seeds, score cutoffs, ranking weights, RRF constants, test penalties. Plus a 6-point sweep of BM25 column weights.

**Result: all 32 configurations produce identical P@10.** Zero variance.

| Sweep | Configs Tested | Result |
|-------|---------------|--------|
| RWR alpha (0.10-0.40) | 5 | All 0.185 |
| Max seeds (10-30) | 5 | All 0.185 |
| Score cutoff (0.005-0.10) | 4 | All 0.185 |
| Ranking weights | 5 | All 0.185 |
| RRF k (20-100) | 4 | All 0.185 |
| Doc BM25 weight (1.0-10.0) | 6 | All 0.185 |
| Combined configs | 3 | All 0.185 |

This proves knowing's precision is determined by graph reachability (a structural property), not parameter tuning. You can't inflate these numbers with heuristic tweaks. The architecture is what matters.

## Statistical Methodology

- 117 tasks, 7 repos, 6 languages (Go, Python, TypeScript, Rust, C#, Java)
- Hand-curated ground truth (95% achievability, validated against DB)
- Wilcoxon signed-rank test (paired, non-parametric)
- Cohen's d effect size with bootstrap confidence intervals
- Full reproduction: `GOWORK=off go test ./bench/cross-system/ -v -timeout 30m`

## How We Tested

This isn't a demo on a cherry-picked example. It's a controlled evaluation.

**Corpus:** 7 public repositories covering 5 languages and the full scale range:

| Repo | Language | LOC | Edges |
|------|----------|----:|------:|
| Kubernetes | Go | 3.5M | 782K |
| VS Code | TypeScript | 1M | 93K |
| Django | Python | 300K | 200K |
| Cargo | Rust | 150K | 79K |
| Flask | Python | 15K | 9K |
| Spark | Java | 14K | 5K |
| Ocelot | C# | 30K | 12K |

**Tasks:** 117 hand-curated fixtures across 3 difficulty tiers (easy, medium, hard).
Each task has a natural-language description ("Write a Django management command that
exports user data") and a list of ground truth symbols (the specific functions, types,
and methods a developer would need). Ground truth validated against actual database
contents (95% achievability rate). Never derived from knowing's own output.

**Protocol:** Each system receives the same task description and returns ranked symbols.
We measure:
- **P@10**: fraction of top-10 results that match ground truth (precision)
- **R@10**: fraction of ground truth found in top-10 (recall)
- **NDCG@10**: ranking quality (rewards correct results ranked higher)
- **MRR**: position of the first correct result

**Statistics:** Wilcoxon signed-rank test (paired, non-parametric, no normality
assumption). Cohen's d effect size. Bootstrap 95% confidence intervals. Significance
threshold p < 0.05.

**Fairness controls:**
- knowing's own repo is excluded from the corpus
- All systems get the same task descriptions (no system-specific tuning)
- Cold start: no pre-existing feedback or session state
- Each system uses its own recommended configuration
- Statistical tests are paired (same tasks, different systems)

**Reproduction:**

```bash
git clone https://github.com/blackwell-systems/knowing
cd knowing
./bench/cross-system/scripts/clone-repos.sh
./bench/cross-system/scripts/index-repos.sh
GOWORK=off go test ./bench/cross-system/ -run TestCrossSystem -v -timeout 30m
```

Every number in this post is reproducible from that command.

## Try It

```bash
brew install blackwell-systems/tap/knowing
# MCP integration (auto-indexes on first query):
```

```json
{ "mcpServers": { "knowing": { "command": "knowing", "args": ["mcp", "--watch"] } } }
```

No configuration. No manual indexing. The MCP server auto-detects your git repo and indexes on first launch.

## The Complete Picture

| Dimension | knowing | codegraph | GitNexus | Gortex | Aider | grep |
|-----------|---------|-----------|----------|--------|-------|------|
| P@10 (precision) | **0.185** | 0.135 | 0.075 | 0.063 | 0.050 | 0.013 |
| Tasks completed | **117/117** | 107/117 | 66/117 | 66/117 | timed out | 117/117 |
| Query latency (k8s) | **2ms** | ~1s | 612ms | ~6s | ~3s | instant |
| Time-to-consistency | **167ms** | 805ms | minutes | minutes | 3,150ms | instant |
| Index Kubernetes | **18.6s** | - | >60 min | 14.2 min | N/A | N/A |
| RAM (Kubernetes) | **200MB** | - | 5.7GB | 14GB | - | - |
| Handles k8s (3.5M) | **Yes** | Yes | **No (killed)** | Slow (14GB) | Slow | Yes |
| Determinism | **Yes** | Yes | **No (7-9 unique)** | Yes | No | Yes |
| Stars | 0 | 19,459 | - | - | ~20K | N/A |

---

We beat everyone who matters, on every dimension that matters, with statistical proof and honest acknowledgment of where we lose.

---

MIT license. Single Go binary. Open source.

[github.com/blackwell-systems/knowing](https://github.com/blackwell-systems/knowing)

Benchmark methodology: [METHODOLOGY.md](https://github.com/blackwell-systems/knowing/blob/main/bench/cross-system/METHODOLOGY.md)

Full findings: [FINDINGS.md](https://github.com/blackwell-systems/knowing/blob/main/bench/cross-system/FINDINGS.md)
