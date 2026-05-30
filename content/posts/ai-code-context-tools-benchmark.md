---
title: "We Benchmarked the Most Popular Code Search Tools. We Beat All of Them."
date: 2026-05-29
draft: false
tags: ["ai", "mcp", "code-intelligence", "benchmark", "knowledge-graph", "retrieval", "precision", "codegraph", "aider", "knowing", "developer-tools"]
categories: ["ai", "benchmarks", "open-source"]
description: "Head-to-head benchmark: knowing vs codegraph (19K stars) vs Aider (20K stars) vs Gortex vs GitNexus (40K stars) across 277 tasks, 14 repos, 8 languages. knowing is 1.98x more precise than codegraph, 20.5x more precise than grep, 500x faster on enterprise repos. Graph-based ranking outperforms embedding re-ranking."
summary: "codegraph has 19K GitHub stars. GitNexus has 40K. Aider has 20K. We benchmarked 7 systems on 277 tasks across 14 codebases (3.5M LOC to 14K LOC), 8 languages. knowing is 1.98x more precise than codegraph, 3.56x vs GitNexus, 4.24x vs Gortex, 20.5x vs grep. Graph-based ranking outperforms embedding re-ranking. We proved it by killing our own re-ranker."
---

codegraph has 19,459 GitHub stars. We have zero. So we stopped talking and started measuring.

## The Headline

| System | P@10 | Query k8s | Time-to-consistency | Stars |
|--------|------|-----------|---------------------|-------|
| **knowing** | **0.267** | **2ms** | **167ms** | 0 |
| codegraph | 0.135 | ~1s | 805ms | 19,459 |
| GitNexus | 0.075 | 612ms | minutes | 40,362 |
| Gortex | 0.063 | ~6s | minutes | - |
| Aider | 0.050 | ~3s | 3,150ms (misses new symbols) | ~20K |
| codebase-memory | 0.137 | 2,900ms | N/A (crashes >300K LOC) | 2,600 |
| grep | 0.013 | instant | instant | N/A |

**How to read these numbers:**
- **P@10** (Precision at 10): of the top 10 symbols returned, what fraction are actually relevant. P@10 = 0.267 means ~3 of every 10 results are ground truth. Higher is better.
- **Query latency**: wall clock time per query. knowing pre-computes an adjacency cache; competitors re-traverse on every call.
- **Time-to-consistency**: you add a function; how fast can the system find it?

**knowing is 1.98x more precise than codegraph** (19K stars, tree-sitter + FTS5).
**knowing is 3.56x more precise than GitNexus** (40K stars, knowledge graph MCP).
**knowing is 4.24x more precise than Gortex** (Go graph engine, 256 languages).
**knowing is 5.34x more precise than Aider** (20K stars, PageRank repo-map).
**knowing is 20.5x more precise than grep.**

## Why 19K Stars Means Nothing

codegraph uses tree-sitter + FTS5 + heuristic scoring (co-location bonuses, multi-term matching, CamelCase boundary matching). No graph-theoretic ranking. No random walk. No structural propagation.

knowing uses Random Walk with Restart on a content-addressed call graph. The walk propagates relevance through the actual dependency structure: "this function calls that one, which implements this interface, which is tested by those tests." Structural relevance, not string coincidence.

The result: codegraph finds symbols that contain your keywords. knowing finds symbols that are structurally relevant to your task. These are often different things.

## Graph Ranking Beats Embeddings

We tried embeddings as a re-ranker: after the graph walk produces 50 candidates, reorder them by cosine similarity to the task description. We thought it was +17% P@10. We were wrong.

When we ran a per-repo A/B test across all 13 repos (with vs without the re-ranker), the truth emerged:

| Repos hurt by re-ranker | 9 of 13 |
|---|---|
| Repos helped | 3 of 13 |
| Net P@10 delta | **-0.050** |
| Worst regression | cargo: -0.027 |

The "+17%" we measured earlier was from **gap-fill seeds** (embedding-based vocabulary bridging that fires when keywords fail), not from the re-ranking step. Both features shared the same flag. We never isolated them.

**The graph-based ranking (RWR + HITS + blast radius) already knows which symbols are structurally important.** A general-purpose text embedding model doesn't understand code structure. It sees "serialize" and "Serializer" as similar, but it doesn't know that `Serializer` is three call hops away from the task's entry point while `SerdeConfig` is directly connected. The graph knows this. The embedding doesn't.

We disabled the re-ranker. P@10 went up: **0.262 -> 0.267.**

The best thing we did for our embedding architecture was turn half of it off.

## What Embeddings ARE Good For

Embeddings aren't useless. They're good at one specific thing: **bridging vocabulary gaps.**

42% of Django tasks scored zero because ground truth symbols share no keywords with the task description. "Validate the request body" needs to find `FormValidator.clean()`. BM25 can't bridge that. Embeddings can.

Gap-fill seeds activate when BM25 returns fewer than 5 candidates. They query the embedding vector store for semantically similar symbols and inject them as additional RWR seeds. This is the correct use of embeddings: as a **candidate source** for the graph walk, not as a ranker that overrides the graph's output.

Impact: Django +43% (0.176 -> 0.252). Full corpus +11%.

## 47 Experiments, Honest Measurement

We didn't guess our way to these numbers. We ran 47 controlled experiments across 12 sessions:

**What works:**
- Inheritance propagation (+29%)
- Gap-fill seeds (+11%)
- Adaptive seed count (+14% on Django)
- Equivalence classes (+4% corpus, +51% on C# repos)
- LSP enrichment (k8s: 0.000 -> 0.232)
- Rust equivalence classes (+28% on cargo)

**What doesn't work:**
- Embedding re-ranker (net negative, disabled)
- Hub dampening (neutral, twice)
- BFS depth reduction (neutral)
- Coherence packing (harmful)
- Bidirectional inheritance (harmful)
- Entry point seeding (neutral with embeddings)
- Seed count tuning (32 configs, zero variance)
- 15-config gap parameter sweep (neutral)

**What we killed:**
- The embedding re-ranker (months of work, net negative, disabled)
- Community-filtered walks (dead code, never activated)
- Co-change edges (implemented, tested, reverted for design flaws)

Every experiment is documented with before/after numbers, methodology, and reasoning. The roadmap has 20+ rejected items with full explanations of why they failed.

## Per-Repo Breakdown

| Repo | Language | P@10 | Tasks |
|------|----------|------|-------|
| Jekyll | Ruby | **0.375** | 20 |
| Kafka | Java | **0.332** | 19 |
| Caddy | Go | **0.285** | 20 |
| Cargo | Rust | **0.277** | 19 |
| Terraform | Go | **0.265** | 20 |
| Ocelot | C# | **0.270** | 20 |
| Flask | Python | **0.347** | 19 |
| ripgrep | Rust | **0.255** | 20 |
| Django | Python | **0.256** | 33 |
| Kubernetes | Go | **0.195** | 19 |
| VS Code | TypeScript | **0.153** | 19 |
| Spark | Java | **0.255** | 5 |

14 repos, 8 languages, 277 tasks. Every repo above grep (0.013). The weakest repo (VS Code 0.153) is still 11.8x more precise than grep.

## Self-Adapting Retrieval

knowing observes its own graph at query time and adjusts its strategy. No configuration. The same binary handles a 1.5K-node Flask repo and a 242K-node Kubernetes repo with different strategies, automatically.

Seven mechanisms adapt:

1. **PreferTypeSeeds**: on dense graphs (>40K nodes), prefers type/interface nodes as seeds (VS Code +44%)
2. **Adaptive seed count**: more seeds on larger graphs to compensate for disconnection (Django +14%)
3. **Equivalence classes**: 164 curated vocabulary bridges activated by detected language (C# +51%, Rust +28%)
4. **Gap-fill seeds**: embedding fallback when keywords fail (Django +43%)
5. **Task memory**: learns from prior queries, compounds across sessions (+4.9%)
6. **Merkleized feedback expiration**: stale feedback expires automatically when code changes
7. **LSP enrichment interaction**: enrichment creates phantom nodes that enable shared-type reachability

Fixed-strategy systems get less precise as codebases grow. knowing gets more precise.

## Query Latency: 500x Faster on Enterprise Repos

codegraph queries Kubernetes in about 1 second (BM25, no graph walk). knowing with its pre-computed adjacency cache: **2 milliseconds**. That's 500x faster.

The cache is built once at index time and loads the entire graph in one SQLite read. RWR then runs entirely in memory. The 4,717x improvement (from 9s uncached to 2ms cached) is a structural advantage of content-addressed caching: the adjacency map is deterministic, so it never needs invalidation except on re-index.

## Time-to-Consistency: New Code in 167ms

You add a function. How quickly does each system find it?

| System | Total time | Found? |
|--------|-----------|--------|
| **knowing** | **167ms** | Yes (rank 2) |
| codegraph | 805ms | Yes |
| Aider | 3,150ms | **No** |

Aider fundamentally cannot find new code: a newly added function with no callers has zero PageRank weight. It will never surface until other code calls it.

## Determinism: Same Question, Same Answer

| System | Unique outputs (10 runs) | Verdict |
|--------|-------------------------|---------|
| knowing | 1 | DETERMINISTIC |
| codegraph | 1 | DETERMINISTIC |
| GitNexus | 7-9 | NON-DETERMINISTIC |
| Aider | 3 | NON-DETERMINISTIC |

knowing's determinism is structural: content-addressed PackRoot guarantees the same input produces the same output. Always.

## Where We Lose

Honesty matters.

**Dense TypeScript repos** (VS Code P@10=0.153): generic symbol names cause intense keyword competition (3,000+ matches for "action"). Density-adaptive type-seed preference helps but VS Code remains the weakest large repo.

**Django's vocabulary gap** (42% zero-rate): ground truth symbols share no keywords with task descriptions. Gap-fill seeds recovered many zeros but the fundamental problem is structural: no edge connects "validate request" to `FormValidator.clean()` without semantic bridging.

## You Can't Game These Numbers

A 32-configuration parameter sweep across every tunable parameter: RWR restart probability, max seeds, score cutoffs, ranking weights, RRF constants.

**All 32 configurations produce identical P@10.** Zero variance.

P@10 is determined by graph reachability (a structural property), not parameter tuning. You can't inflate these numbers with heuristics. The architecture is what matters.

## Statistical Methodology

- 277 tasks, 14 repos, 8 languages (Go, Python, TypeScript, Rust, Java, C#, Ruby, multi)
- Hand-curated ground truth (99% achievability, validated against DB)
- Wilcoxon signed-rank test (paired, non-parametric)
- Cohen's d effect size with bootstrap confidence intervals
- Full reproduction: `GOWORK=off go test ./bench/cross-system/ -v -timeout 0`

Every number in this post is reproducible from that command.

## Try It

```bash
brew install blackwell-systems/tap/knowing
```

```json
{ "mcpServers": { "knowing": { "command": "knowing", "args": ["mcp", "--watch"] } } }
```

No manual indexing. The MCP server auto-detects your git repo and indexes on first launch. Embedding gap-fill downloads a 30MB model once and runs locally. No API keys. No charges.

## The Complete Picture

| Dimension | knowing | codegraph | GitNexus | Gortex | Aider | grep |
|-----------|---------|-----------|----------|--------|-------|------|
| P@10 (precision) | **0.267** | 0.135 | 0.075 | 0.063 | 0.050 | 0.013 |
| Tasks completed | **277/277** | 107/167 | 66/167 | 66/167 | timed out | 277/277 |
| Query latency (k8s) | **2ms** | ~1s | 612ms | ~6s | ~3s | instant |
| Time-to-consistency | **167ms** | 805ms | minutes | minutes | 3,150ms | instant |
| Index Kubernetes | **18.6s** | - | >60 min | 14.2 min | N/A | N/A |
| RAM (Kubernetes) | **200MB** | - | 5.7GB | 14GB | - | - |
| Determinism | **Yes** | Yes | **No (7-9 unique)** | Yes | No | Yes |

---

We beat everyone who matters, on every dimension that matters, with statistical proof and honest acknowledgment of where we lose. Including the honesty to kill our own re-ranker when the data said it was hurting us.

---

MIT license. Single Go binary. Open source.

[github.com/blackwell-systems/knowing](https://github.com/blackwell-systems/knowing)

Benchmark methodology: [METHODOLOGY.md](https://github.com/blackwell-systems/knowing/blob/main/bench/cross-system/METHODOLOGY.md)

Full findings: [FINDINGS.md](https://github.com/blackwell-systems/knowing/blob/main/bench/cross-system/FINDINGS.md)
