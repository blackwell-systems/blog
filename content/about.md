---
title: "About"
date: 2025-12-01
draft: false
showMetadata: false
---

**Dayna Blackwell** is a software engineer, open source author, and published researcher. Founder of [Blackwell Systems](https://github.com/blackwell-systems).

I build production backend systems, AI-native developer tooling, and the research infrastructure that connects tokenizer design to transformer internal organization. 25+ open source projects in Go, Rust, TypeScript, Python, and C. 60,000+ monthly downloads across pip, npm, Docker, Homebrew, and Winget. 9 published research papers. 32 PRs merged into Google, Anthropic, HashiCorp, GitHub, Grafana, LangChain, etcd, and Stretchr/testify.

---

## What I've Built

**[GCF](https://gcformat.com)** ([spec](https://github.com/blackwell-systems/gcf), [playground](https://gcformat.com/playground.html), [betterthanjson.com](https://betterthanjson.com)) is an AI-native wire format reverse-engineered from tokenizer data. 100% comprehension on every frontier model on standard workloads. 91.2% on structurally complex code graphs where JSON drops to 54.1%. 50-92% fewer tokens than JSON. 43 billion+ lossless round-trips across 5 formats, zero failures. Six language implementations (Go, TypeScript, Python, Rust, Swift, Kotlin), seven registries, tree-sitter grammar. Adopted by Chrome DevTools MCP (46K stars, the #1 MCP server on GitHub), OmniRoute (6.5K stars), Speakeasy (customers include Google, Verizon, Mistral AI), the Linux Foundation's Open Data Products SDK, netclaw (560 stars, replaced TOON entirely), ctx (515 stars), NeuroNest, Raycast Store, and others. Published whitepapers: [GCF wire format](https://doi.org/10.5281/zenodo.20579817), [tokenizer-attention coupling](https://doi.org/10.5281/zenodo.20925910), [stranded attention](https://doi.org/10.5281/zenodo.21158886), [developmental atlas of attention head specialization](https://doi.org/10.5281/zenodo.21205389), [structural ambiguity in JSON tokenization](https://doi.org/10.5281/zenodo.20810588).

**[knowing](https://github.com/blackwell-systems/knowing)** is a content-addressed code intelligence engine that beats every competitor in the category with statistical proof. P@10=0.278 across 308 tasks, 16 repos, 8 languages: 3.2x codegraph (19K stars), 5.05x GitNexus (40K stars), 5.35x Gortex, 12.1x Aider, 18.5x grep. 23 extractors spanning 26 languages/formats. 12 self-adapting retrieval mechanisms. 28 MCP tools and 8 resources across 7 planes. Supply chain detection without executing code (1.0% FP rate). OpenTelemetry runtime trace ingestion. Community detection with Merkle roots. GCF wire format (84% fewer tokens than JSON). Single Go binary, zero dependencies. Published whitepaper: [Content-Addressing as a Computation Primitive for Software Relationship Intelligence](https://doi.org/10.5281/zenodo.20342255).

**[agent-lsp](https://github.com/blackwell-systems/agent-lsp)** is a stateful MCP server runtime over real language servers. 66 tools, 24 Agent Skills, speculative execution engine, 30 CI-verified languages. 5,500+ monthly downloads. Listed on the official MCP Registry, Glama (A-tier), and awesome-mcp-servers. Adopted in production by OmniRoute, NUR (Nix User Repository), and others.

**[mcp-assert](https://github.com/blackwell-systems/mcp-assert)** is the deterministic testing standard for MCP servers. 28,000+ total downloads across 6 distribution channels. Shipped from 0-to-1 in one week. 102 servers scanned, 34 upstream bugs found. Adopted as CI standard by Ant Group (antvis) and wyre-technology (25+ repos).

**[polywave](https://github.com/blackwell-systems/polywave)** is a formally specified parallel agent coordination protocol (6 invariants, 48 execution rules, 7 participant roles, 5-layer worktree isolation). 4-5x measured speedup. knowing (94K LOC) was built using polywave. Go SDK: 33 packages, 75+ CLI commands, 4 LLM backends, autonomous daemon mode. Listed on ComposioHQ/awesome-codex-skills (13.6K stars).

**[claudewatch](https://github.com/blackwell-systems/claudewatch)** is a 32-tool MCP server for AI development observability. PostToolUse hooks, session analytics, CLAUDE.md effectiveness scoring, friction pattern classification.

**GCP Emulator Platform**: 5 composable emulators (Secret Manager, KMS, IAM, Eventarc, auth) with shared hook architecture. The [Secret Manager emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator) is the most widely adopted community solution, ranked #1 on Google/Bing/DuckDuckGo, recommended by Google AI Overview, Gemini, and GitHub Copilot. 45K+ downloads. Enterprise adoption by Flipt (4.8K stars), Reindeer AI, and sugar-org/swarm-external-secrets.

No. 6 all-time contributor to [mcp-go](https://github.com/mark3labs/mcp-go) (8.7K stars). Full [open source portfolio](/oss/).

---

## Professional Work

Backend Enterprise Developer at **Best Western Hotels & Resorts**, where I architect and operate the core loyalty platform backend serving millions of members across 5,000+ properties in 120 countries. This platform is the foundational layer consumed by nearly every engineering team in the company. I designed the Digital Wallet (5 currencies), the serverless promotion rules engine (Lambda, EventBridge, DynamoDB, Redis), and the real-time CDC pipeline. Revenue-critical systems with 24/7 on-call. Founding member of the Agentic Development Group, leading enterprise-wide rollout of AI-enhanced engineering workflows.

---

## Publications

**Blackwell, D. (2026).** *Tokenizer-Attention Coupling: How BPE Merge Decisions Permanently Shape Transformer Internal Organization.* Preprint.<br>
[doi:10.5281/zenodo.20925910](https://doi.org/10.5281/zenodo.20925910)

43 tokenizers from 20 providers. Every one merges delimiter characters with adjacent content, destroying structural boundaries before the transformer runs. Controlled experiment: two identical 410M models, same corpus, same hyperparameters, different tokenizer. The one with 16 merge-barrier characters develops 4.6x more structural attention heads, achieves 3-738x better structured data perplexity, 3-5x better code comprehension, with zero natural language cost. 18-phase causal ablation protocol proves the heads are necessary, sufficient, and format-general. Validated across 2 architectures, 2 scales, and 3 domains (structured data, code, molecular chemistry). Introduces *tokenizer-attention coupling*: BPE merge decisions permanently constrain which attention heads develop.

**Blackwell, D. (2026).** *Stranded Attention: BPE Tokenization Permanently Constrains Transformer Structural Capacity.* Preprint.<br>
[doi:10.5281/zenodo.21158886](https://doi.org/10.5281/zenodo.21158886)

When a standard BPE model is fed clean delimiter boundaries using its own frozen weights, all 384 attention heads at 410M and all 768 at 1.3B show 4x more delimiter attention (14% to 54%). This *frustration gap* appears by step 5,000 and does not change across 35,000 additional steps. At 1.3B, standard BPE develops 124 counterproductive delimiter heads whose removal improves comprehension by 57%. Stranded heads are a third attention state: active but unproductive, neither functional nor safely removable.

**Blackwell, D. (2026).** *Developmental Atlas of Attention Head Specialization: Spacing, Stranding, and the Capacity Tax of BPE Tokenization.* Preprint.<br>
[doi:10.5281/zenodo.21205389](https://doi.org/10.5281/zenodo.21205389)

The first comprehensive tracking of attention head specialization at scale: 384 heads across 7 behavior types, 131 checkpoints per run, 7 training runs on 2 corpora and 2 architectures (GPT-NeoX 410M, Llama 410M). The BPE capacity tax is architecture-independent: spacing ablation costs +64.3% on NeoX (MHA) and +67.0% on Llama (GQA). Together, 48-56% of attention capacity in standard BPE is non-productive (40-48% spacing recovery, ~8% collapsed into position-zero sinks). Merge barriers (a 16-line tokenizer config change) eliminate the need for it entirely.

**Blackwell, D. (2026).** *GCF: A Token-Optimized Wire Format for Structured LLM Interactions.* Working Paper.<br>
[doi:10.5281/zenodo.20579817](https://doi.org/10.5281/zenodo.20579817)

2,400+ LLM evaluations across 11 models and 3 providers. 100% comprehension on every frontier model on standard workloads. 91.2% on structurally complex data where JSON drops to 54.1%. 43 billion+ lossless round-trips. Grammar characters selected from the set empirically verified to have near-zero BPE merge rates across 43 tokenizers. Spec v3.2 Stable.

**Blackwell, D. (2026).** *Structural Ambiguity in JSON Tokenization: A Cross-Tokenizer Analysis.* Preprint.<br>
[doi:10.5281/zenodo.20810588](https://doi.org/10.5281/zenodo.20810588)

8 tokenizers from 6 providers. JSON's 15 most common field names merge with the opening quote on 50-63% of tokenizers. JSON boundary merge rate: 8.93%. Pipe-delimited: 1.00%. Tab-delimited (TOON): 59.82%. JSON overhead reaches 81% at 500 rows.

**Blackwell, D. (2026).** *Content-Addressing as a Computation Primitive for Software Relationship Intelligence.* Technical Report.<br>
[doi:10.5281/zenodo.20342255](https://doi.org/10.5281/zenodo.20342255)

Hierarchical Merkle trees over code relationship edges as a query-optimization substrate. Self-adapting retrieval, cryptographic proofs of relationship presence and absence, supply chain detection. No prior art found in a survey of Sourcegraph, Kythe, CodeQL, Bazel, Neo4j, IPFS, and Nix. Companion implementation: [knowing](https://github.com/blackwell-systems/knowing).

**Blackwell, D. (2026).** *Normalization Confluence in Federated Registry Networks.* Technical Report.<br>
[doi:10.5281/zenodo.18677400](https://doi.org/10.5281/zenodo.18677400)

Extends normalization confluence to federated environments where multiple registries with independent invariants are connected by morphisms encoding cross-organizational constraints. Proves federated convergence requires only validity preservation for tree-shaped networks.

**Blackwell, D. (2026).** *Normalization Confluence for Registry-Governed Stream Processing.* Technical Report.<br>
[doi:10.5281/zenodo.18671870](https://doi.org/10.5281/zenodo.18671870)

A third regime for coordination-free convergence in distributed systems: normalization confluence, where non-commutative operations converge through compensation. Companion implementations: [nccheck](https://github.com/blackwell-systems/nccheck) (verification DSL) and [gsm](https://github.com/blackwell-systems/gsm) (Go runtime with O(1) event application).

**Blackwell, D. (2026).** *Drainability: When Coarse-Grained Memory Reclamation Produces Bounded Retention.* Technical Report.<br>
[doi:10.5281/zenodo.18653776](https://doi.org/10.5281/zenodo.18653776)

Proves the O(1) vs Omega(t) dichotomy for coarse-grained allocators: drainability produces bounded retention, its absence produces unbounded growth. Companion implementation: [libdrainprof](https://github.com/blackwell-systems/drainability-profiler) (C profiler, sub-2ns overhead).

---

## Books

**[You Don't Know JSON](https://leanpub.com/you-dont-know-json)** (107,000 words) covers JSON ecosystem architecture, schema validation, binary formats (MessagePack, CBOR, Protocol Buffers), streaming architectures, security patterns, API design, and testing strategies. Available on Leanpub.

---

## What I Write About

This blog provides technical deep-dives into programming language fundamentals, distributed systems, and AI-native development tooling.

**Tokenization & LLM Architecture:**
- BPE merge barriers and their effect on attention head specialization
- Structured data comprehension at scale
- Tokenizer-attention coupling across architectures and domains

**Code Intelligence & AI Tooling:**
- [Benchmark methodology for code context retrieval](/posts/ai-code-context-tools-benchmark/)
- MCP server development and testing
- Multi-agent coordination and parallel development workflows
- Claude Code extensibility (skills, hooks, subagents)

**Language Design & Systems:**
- Value semantics vs reference semantics across languages
- Memory models, concurrency primitives, escape analysis
- Why modern languages moved away from OOP patterns

**Distributed Systems:**
- Event-driven architectures at scale
- Idempotent message handling and deduplication patterns
- Serverless patterns and AWS architecture

---

## Contact

- Email: dayna@blackwell-systems.com
- GitHub: [@blackwell-systems](https://github.com/blackwell-systems)
- Open source: [full portfolio](/oss/) | [consulting](/consulting/)
