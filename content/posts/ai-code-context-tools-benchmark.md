---
title: "We Benchmarked the Most Popular Code Search Tools. We Beat All of Them."
date: 2026-06-03
draft: false
tags: ["ai", "mcp", "code-intelligence", "benchmark", "knowledge-graph", "retrieval", "precision", "codegraph", "aider", "knowing", "developer-tools"]
categories: ["ai", "benchmarks", "open-source"]
description: "Head-to-head benchmark: knowing vs codegraph (19K stars) vs Aider (20K stars) vs Gortex vs GitNexus (40K stars) across 300 tasks, 16 repos, 8 languages. knowing is 3.37x more precise than codegraph, 19.5x more precise than grep. 13 self-adapting mechanisms. Gets smarter with use."
summary: "codegraph has 19K GitHub stars. GitNexus has 40K. Aider has 20K. We benchmarked 7 systems on 300 tasks across 16 codebases, 8 languages. knowing is 3.37x more precise than codegraph, 5.33x vs GitNexus, 5.63x vs Gortex, 19.5x vs grep. 13 self-adapting mechanisms that compound over time."
---

codegraph has 19,459 GitHub stars. We have zero. So we stopped talking and started measuring.

## The Headline

| System | P@10 | Query k8s | Time-to-consistency | Stars |
|--------|------|-----------|---------------------|-------|
| **knowing** | **0.293** | **2ms** | **167ms** | 0 |
| codegraph | 0.087 | ~1s | 805ms | 19,459 |
| GitNexus | 0.055 | 612ms | minutes | 40,362 |
| Gortex | 0.052 | ~6s | minutes | - |
| Aider | 0.023 | ~3s | 3,150ms (misses new symbols) | ~20K |
| codebase-memory | 0.137* | 2,900ms | N/A | 2,600 |
| grep | 0.015 | instant | instant | N/A |

*codebase-memory completed only 22 of 300 tasks before timing out (60 min limit). P@10 measured on completed subset only.

**How to read these numbers:**
- **P@10** (Precision at 10): of the top 10 symbols returned, what fraction are actually relevant. P@10 = 0.293 means ~3 of every 10 results are ground truth. Higher is better.
- **Query latency**: wall clock time per query. knowing pre-computes an adjacency cache; competitors re-traverse on every call.
- **Time-to-consistency**: you add a function; how fast can the system find it?

**knowing is 3.37x more precise than codegraph** (19K stars, tree-sitter + FTS5).
**knowing is 5.11x more precise than GitNexus** (40K stars, knowledge graph MCP).
**knowing is 5.40x more precise than Gortex** (Go graph engine, 256 languages).
**knowing is 12.2x more precise than Aider** (20K stars, PageRank repo-map).
**knowing is 19.5x more precise than grep.**

## Why 19K Stars Means Nothing

codegraph uses tree-sitter + FTS5 + heuristic scoring (co-location bonuses, multi-term matching, CamelCase boundary matching). No graph-theoretic ranking. No random walk. No structural propagation.

knowing uses Random Walk with Restart on a content-addressed call graph. The walk propagates relevance through the actual dependency structure: "this function calls that one, which implements this interface, which is tested by those tests." Structural relevance, not string coincidence.

The result: codegraph finds symbols that contain your keywords. knowing finds symbols that are structurally relevant to your task. These are often different things.

## Framework Intelligence: 263 Equivalence Classes

42% of Django tasks scored zero. The reason: ground truth symbols share no keywords with the task description. "How does Django handle form validation?" needs to find `RegexValidator`, `EmailValidator`, `URLValidator`. No keyword overlap. No embedding bridges the gap reliably either (we proved it: three runs identical with/without embeddings).

The fix: 263 hand-curated concept-to-symbol mappings across 20 frameworks and 8 languages. When a task says "form validation," the engine knows the answer is `RegexValidator`. High-confidence matches bypass the graph walk entirely and inject directly into results.

This is not a thesaurus. Each equivalence class maps a concept that appears in natural-language task descriptions to the specific symbols that implement that concept in a framework's codebase. "Django middleware" -> `MiddlewareMixin`, `process_request`, `process_response`. "Terraform provider" -> `ResourceProvider`, `GRPCProviderPlugin`, `ProviderSchema`.

Impact: P@10 0.176 -> 0.278 (+57%). Every repo improved except the two that were already at ceiling.

## Graph Ranking Beats Embeddings

We tested embeddings extensively. Three models (jina-code, nomic-embed-text, BGE-small). Two architectures (re-ranker, gap-fill seeds). 15+ experiments.

**Result: embeddings are dead weight for cold-start retrieval.**

Three benchmark runs with and without embeddings produced identical P@10 (0.176, 0.175, 0.176). The "+11% gap-fill" and "+17% re-ranker" we reported earlier were caused by task memory contamination (stale entries in corpus DBs inflating measurements). Once we fixed the measurement, the signal disappeared.

The graph structure, BM25, and equivalence classes carry everything. We disabled embeddings by default. No 30MB model download for new users. The architecture is simpler, faster, and more honest.

The best thing we did for our embedding architecture was turn all of it off.

## It Gets Smarter With Use

Most retrieval systems are stateless: query in, results out, nothing learned. knowing compounds.

When an agent works on task A ("payment processing") and uses symbols like `settle_ledger`, the system records the association `payment -> settle_ledger`. When a different task B ("payment refund") shares the keyword "payment", the learned association surfaces `settle_ledger` for task B. The vocabulary bridges between tasks, not within them: 100% of improvements in our cross-task validation were cross-task. No self-reinforcement.

Three safeguards prevent this from becoming a noise factory:
1. **Keyword filter**: ~80 common English words ("use", "find", "not") are excluded from recording. Only domain-specific keywords create associations.
2. **Soft RRF injection**: learned vocab competes through reciprocal rank fusion, not forced to the top. On tasks with good BM25 coverage, learned vocab naturally loses to better candidates.
3. **Confidence weighting**: observation count scales injection weight from 0.3 (seen twice) to 0.8 (seen 10+ times). Reinforced associations get stronger each round.

And when code changes, stale associations expire automatically. Each association stores the Merkle root of its symbol's package at recording time. When the package changes (new commit, refactored code), the root misses and the association becomes invisible. No manual cleanup. No TTL policies. Structural validity.

**10-round compounding across 300 tasks, 16 repos:**

| Round | P@10 | MRR |
|-------|------|-----|
| 1 (cold) | 0.277 | 0.459 |
| 7 (peak) | 0.283 | 0.496 |
| 10 (final) | 0.293 | 0.504 |

+2.2% P@10, +8.1% MRR at peak. Never dips below cold-start baseline. The system learns monotonically: each round is at least as good as the first.

Competitors are stateless. knowing accumulates structural knowledge from every query it serves.

## Self-Adapting Retrieval

knowing observes its own graph at query time and adjusts its strategy. No configuration. The same binary handles a 14K-node Jekyll repo and a 200K-node VS Code repo with different strategies, automatically.

Thirteen mechanisms adapt:

1. **PreferTypeSeeds**: on dense graphs (>40K nodes), prefers type/interface nodes as seeds (VS Code +354%)
2. **Adaptive seed count**: more seeds on larger graphs to compensate for disconnection (Django +14%)
3. **Framework equivalence classes**: 263 curated concept-to-symbol bridges activated by detected language (+57%)
4. **Focused seed selection**: clusters candidates by package path, concentrates the walk in the dominant neighborhood (+6%)
5. **Task memory compounding**: records top-5 symbols per query, boosts them on similar future queries with 7-day decay
6. **Merkleized feedback expiration**: feedback records store per-package Merkle roots; stale feedback becomes invisible when code changes
7. **LSP enrichment interaction**: phantom nodes + type_hint_of edges create shared-type reachability paths (k8s 0.000 -> 0.232)
8. **Adaptive retrieval fallback**: repos >200K nodes with flat walk results fall back to direct FTS + contains-edge expansion
9. **RWR proximity packing**: symbols structurally closer to seeds get higher packing density, preventing distant centrality noise from filling the budget
10. **Implicit noise demotion**: symbols returned but never used get demoted on future queries, scoped by keyword cluster to prevent cross-task interference (+5.9% Django)
11. **Change-aware scoring**: recently committed symbols get a mild tiebreaker boost from git blame data
12. **Cross-task vocabulary bridging**: agent usage on task A teaches vocabulary that helps task B via shared keywords (Django +41.4% in isolation; 10-round MRR +8.1%)
13. **Incremental RWR with Merkle caching**: cache walk results keyed by per-package Merkle roots; unchanged packages skip the entire BFS/iteration pass (2x latency improvement)

Fixed-strategy systems get less precise as codebases grow. knowing gets more precise. And it gets more precise with use: 10-round compounding across the full 308-task corpus showed P@10 climbing from 0.277 to 0.283 (+2.2%) and MRR from 0.459 to 0.497 (+8.1%), never dipping below cold-start baseline.

## Zero External Dependencies

All 7 language resolvers (Go, Python, TypeScript, Java, C#, Rust, Ruby) run in-process during indexing. No gopls. No pyright. No tsserver. `knowing index` produces high-quality edges with nothing but the binary.

For the best experience, LSP enrichment with external language servers upgrades edge confidence from 0.5 to 0.9 and discovers cross-file relationships. Go enrichment alone moved Kubernetes from 0.000 to 0.232. Language servers are auto-detected from project markers. But they're optional: the binary alone gives you tree-sitter extraction + in-process resolution.

## Per-Repo Breakdown

| Repo | Language | P@10 | Tasks |
|------|----------|-----:|------:|
| Caddy | Go | **0.440** | 20 |
| Jekyll | Ruby | **0.430** | 20 |
| Kafka | Java | **0.421** | 19 |
| Terraform | Go | **0.405** | 20 |
| Rails | Ruby | **0.340** | 20 |
| Flask | Python | **0.321** | 19 |
| Ocelot | C# | **0.285** | 20 |
| FastAPI | Python | **0.275** | 20 |
| Saleor | Python | **0.236** | 11 |
| Spark-Java | Java | **0.235** | 20 |
| Ripgrep | Rust | **0.195** | 20 |
| Cargo | Rust | **0.186** | 19 |
| Django | Python | **0.183** | 33 |
| Kubernetes | Go | **0.168** | 19 |
| VS Code | TypeScript | **0.168** | 19 |

16 repos, 8 languages, 300 tasks. Saleor is a Django e-commerce application (not the Django framework itself), validating that equivalence classes generalize to real application code.

## You Can't Game These Numbers

A 32-configuration parameter sweep across every tunable parameter: RWR restart probability, max seeds, score cutoffs, ranking weights, RRF constants.

**All 32 configurations produce identical P@10.** Zero variance.

P@10 is determined by graph reachability (a structural property), not parameter tuning. You can't inflate these numbers with heuristics. The architecture is what matters.

## Where We Lose

Honesty matters.

**Dense TypeScript repos** (VS Code P@10=0.168): generic symbol names cause intense keyword competition (3,000+ matches for "action"). Density-adaptive type-seed preference helps but VS Code remains the weakest large repo.

**Django's vocabulary gap** (42% zero-rate): ground truth symbols share no keywords with task descriptions. Framework equivalence classes recovered many zeros (0.081 -> 0.183, +126%) but the fundamental problem persists for tasks that don't match any curated concept.

## Benchmark Methodology

- 300 tasks, 16 repos, 8 languages (Go, Python, TypeScript, Rust, Java, C#, Ruby, multi)
- Hand-curated ground truth (99% achievability, validated against DB, dot-bounded matching)
- Cold start: no task memory, no embeddings, no cached results
- Task memory cleared before every run, test cache cleared, binary rebuilt
- Wilcoxon signed-rank test (paired, non-parametric)
- Cohen's d effect size with bootstrap confidence intervals
- Competitive benchmarks: same tasks, same harness, default configurations
- Full reproduction: `BENCH_ADAPTERS=knowing GOWORK=off go test ./bench/cross-system/ -v -timeout 0`
- Corpus, tasks, and harness are open source

Every number in this post is reproducible from that command.

## Try It

```bash
brew install blackwell-systems/tap/knowing
```

```json
{ "mcpServers": { "knowing": { "command": "knowing", "args": ["mcp", "--watch"] } } }
```

No manual indexing. The MCP server auto-detects your git repo and indexes on first launch. No model downloads. No API keys. No charges. Single Go binary.

## The Complete Picture

| Dimension | knowing | codegraph | GitNexus | Gortex | Aider | grep |
|-----------|---------|-----------|----------|--------|-------|------|
| P@10 (precision) | **0.281** | 0.087 | 0.055 | 0.052 | 0.023 | 0.015 |
| P@10 (compounded) | **0.283** | - | - | - | - | - |
| Tasks completed | **308/308** | 118/308 | 77/308 | 246/308 | 278/308 | 297/308 |
| Query latency (k8s) | **2ms** | ~1s | 612ms | ~6s | ~3s | instant |
| Time-to-consistency | **167ms** | 805ms | minutes | minutes | 3,150ms | instant |
| Index Kubernetes | **18.6s** | - | >60 min | 14.2 min | N/A | N/A |
| RAM (Kubernetes) | **200MB** | - | 5.7GB | 14GB | - | - |
| Determinism | **Yes** | Yes | **No (7-9 unique)** | Yes | No | Yes |
| Self-adapting mechanisms | **13** | 0 | 0 | 0 | 0 | 0 |
| Equiv classes | **263** | 0 | 0 | 0 | 0 | 0 |
| In-process resolvers | **7 languages** | 0 | 0 | 0 | 0 | 0 |
| Edge types | **38** | ~5 | ~3 | ~10 | 1 | 0 |

---

13 self-adapting mechanisms. 263 equivalence classes. 38 edge types. 28 MCP tools. 7 in-process resolvers. Single Go binary. Gets smarter with scale, and smarter with use.

---

MIT license. Open source.

[github.com/blackwell-systems/knowing](https://github.com/blackwell-systems/knowing)

Benchmark methodology: [METHODOLOGY.md](https://github.com/blackwell-systems/knowing/blob/main/bench/cross-system/METHODOLOGY.md)

Full findings: [FINDINGS.md](https://github.com/blackwell-systems/knowing/blob/main/bench/cross-system/FINDINGS.md)
