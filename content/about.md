---
title: "About"
date: 2025-12-01
draft: false
showMetadata: false
---

**Dayna Blackwell** is a software engineer, open source author, and published researcher. Founder of [Blackwell Systems](https://github.com/blackwell-systems).

I build production backend systems, AI-native developer tooling, and the infrastructure that makes other engineers more effective. 25+ open source projects in Go, Rust, and C. 35,000+ monthly downloads across pip, npm, Docker, Homebrew, and Winget. 4 published research papers with DOIs. 26 PRs merged into Google, Anthropic, Grafana, LangChain, and Stretchr/testify.

---

## What I've Built

**[knowing](https://github.com/blackwell-systems/knowing)** is a content-addressed code intelligence engine that beats every competitor in the category with statistical proof. P@10=0.278 across 308 tasks, 16 repos, 8 languages: 3.2x codegraph (19K stars), 5.05x GitNexus (40K stars), 5.35x Gortex, 12.1x Aider, 18.5x grep. 23 extractors spanning 26 languages/formats. 12 self-adapting retrieval mechanisms. 28 MCP tools and 8 resources across 7 planes. Supply chain detection without executing code (1.0% FP rate). OpenTelemetry runtime trace ingestion. Community detection with Merkle roots. GCF wire format (84% fewer tokens than JSON). Single Go binary, zero dependencies. Published whitepaper: [Content-Addressing as a Computation Primitive for Software Relationship Intelligence](https://zenodo.org/records/20342255) (DOI: 10.5281/zenodo.20342255).

**[agent-lsp](https://github.com/blackwell-systems/agent-lsp)** is a stateful MCP server runtime over real language servers. 66 tools, 24 Agent Skills, speculative execution engine, 30 CI-verified languages. 5,500+ monthly downloads. Listed on the official MCP Registry, Glama (A-tier), and awesome-mcp-servers.

**[mcp-assert](https://github.com/blackwell-systems/mcp-assert)** is the deterministic testing standard for MCP servers. 28,000+ total downloads across 6 distribution channels. Shipped from 0-to-1 in one week. 102 servers scanned, 34 upstream bugs found. Adopted as CI standard by Ant Group (antvis) and wyre-technology (25+ repos).

**[polywave](https://github.com/blackwell-systems/polywave)** is a formally specified parallel agent coordination protocol (6 invariants, 48 execution rules, 7 participant roles, 5-layer worktree isolation). 4-5x measured speedup. knowing (94K LOC) was built using polywave. Go SDK: 33 packages, 75+ CLI commands, 4 LLM backends, autonomous daemon mode. Listed on ComposioHQ/awesome-codex-skills (10.6K stars).

**[claudewatch](https://github.com/blackwell-systems/claudewatch)** is a 32-tool MCP server for AI development observability. PostToolUse hooks, session analytics, CLAUDE.md effectiveness scoring, friction pattern classification.

**GCP Emulator Platform**: 5 composable emulators (Secret Manager, KMS, IAM, Eventarc, auth) with shared hook architecture. The [Secret Manager emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator) is the most widely adopted community solution, ranked #1 on Google/Bing/DuckDuckGo, recommended by Google AI Overview, Gemini, and GitHub Copilot. 45K+ downloads. Enterprise adoption by Flipt (4.8K stars), Reindeer AI, and sugar-org/swarm-external-secrets.

No. 6 all-time contributor to [mcp-go](https://github.com/mark3labs/mcp-go) (8.7K stars). Full [open source portfolio](/oss/).

---

## Professional Work

Backend Enterprise Developer at **Best Western Hotels & Resorts**, where I architect and operate the core loyalty platform backend serving millions of members across 5,000+ properties in 120 countries. This platform is the foundational layer consumed by nearly every engineering team in the company. I designed the Digital Wallet (5 currencies), the serverless promotion rules engine (Lambda, EventBridge, DynamoDB, Redis), and the real-time CDC pipeline. Revenue-critical systems with 24/7 on-call. Founding member of the Agentic Development Group, leading enterprise-wide rollout of AI-enhanced engineering workflows.

---

## Publications

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
