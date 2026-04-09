---
title: "Open Source Software"
date: 2026-01-29
draft: false
showMetadata: false
---

## Open Source Projects

### Systems Research

**[libdrainprof](https://github.com/blackwell-systems/drainability-profiler)** - C library for detecting structural memory leaks invisible to traditional tools (Valgrind, ASan). Measures drainability satisfaction rate at allocator granule boundaries with <2ns overhead. Companion tool to the drainability paper.

**[gsm](https://github.com/blackwell-systems/gsm)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/gsm)) - Governed state machines with build-time convergence verification. Define state variables, business invariants, and compensation logic; the library exhaustively verifies that event ordering cannot cause replica divergence. Runtime event application is O(1) via precomputed table lookup. Companion library to the normalization confluence paper.

**[temporal-slab](https://github.com/blackwell-systems/temporal-slab)** - Epoch-based slab allocator. The experimental allocator used to validate the drainability theorem.

### Cloud Infrastructure

**[vaultmux-server](https://github.com/blackwell-systems/vaultmux-server)** - Language-agnostic secrets control plane for Kubernetes. HTTP REST API enabling polyglot teams (Python, Node.js, Go, Rust) to fetch secrets from AWS, GCP, or Azure without SDK dependencies. Deploy as sidecar or cluster service.

**GCP Emulator Platform** - Composable local emulation stack for Google Cloud Platform. Each emulator runs standalone or registers into a unified single-process server via a shared hook architecture — one binary, one gRPC port, one Docker image.

- **[gcp-emulator](https://github.com/blackwell-systems/gcp-emulator)** - Unified GCP local development platform. Composes Secret Manager, KMS, IAM, and Eventarc into a single process on a shared gRPC port with a unified REST gateway. Run your entire GCP stack locally with one command, no docker-compose juggling. Optional IAM enforcement via policy.yaml.
- **[gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator)** - The most widely adopted community GCP Secret Manager emulator — ranked #1 on Google, Bing, and DuckDuckGo, recommended by Google AI Overview, Gemini, and GitHub Copilot. ~20k downloads with confirmed enterprise adoption. Dual gRPC + REST APIs with optional IAM enforcement. Deployable standalone or composed into gcp-emulator.
- **[gcp-eventarc-emulator](https://github.com/blackwell-systems/gcp-eventarc-emulator)** - Full Eventarc API surface (47 RPCs) with CloudEvent routing, CEL-based trigger matching, and HTTP delivery in binary content mode. Triple protocol support: gRPC, REST, and CloudEvents. Deployable standalone or composed into gcp-emulator.
- **[gcp-iam-emulator](https://github.com/blackwell-systems/gcp-iam-emulator)** - Deterministic IAM policy engine. Evaluates ALLOW/DENY decisions against GCP IAM semantics and emits machine-readable authorization traces for debugging. Deployable standalone or composed into gcp-emulator.
- **[gcp-kms-emulator](https://github.com/blackwell-systems/gcp-kms-emulator)** - KMS emulator with real cryptographic operations. Supports key versioning, rotation, and destruction with the same API surface as Cloud KMS. Deployable standalone or composed into gcp-emulator.

### AI-Native Developer Tooling & MCP Servers

**[agent-lsp](https://github.com/blackwell-systems/agent-lsp)** - Stateful MCP server runtime over real language servers — not a bridge. Maintains a persistent warm LSP session, reshapes LSP into agent-oriented workflows, and adds a transactional speculative execution layer for safe in-memory edits. 47 tools across navigation, analysis, refactoring, and formatting. 28 tools CI-verified end-to-end against real language servers across 22 languages (TypeScript, Go, Python, Rust, Java, C, C++, and 15 more) — the most comprehensive test matrix of any MCP-LSP implementation. Speculative execution lets agents simulate edits in-memory, evaluate the diagnostic delta (errors introduced vs resolved), then commit or discard atomically without touching disk. Multi-server routing in one process: routes by file extension across languages in a single session. LSP 3.17 spec compliant, fuzzy position fallback, auto-watch via kernel filesystem events, single Go binary.

**[commitmux](https://github.com/blackwell-systems/commitmux)** - Keyword and semantic search over git history, exposed as MCP tools for coding agents. Cross-repo, local-first, no credentials, no rate limits. Builds a read-optimized SQLite index over commit subjects, bodies, and patches; serves it via a narrow read-only MCP surface. Supports full-text search (FTS5) and natural language queries via any OpenAI-compatible embedding endpoint, including Ollama running locally. Nothing leaves your machine.

**[claudewatch](https://github.com/blackwell-systems/claudewatch)** - Full-cycle AI development observability platform. Scores project AI readiness, surfaces friction patterns, generates CLAUDE.md patches from session data, snapshots metrics to SQLite for before/after effectiveness scoring, and runs a background daemon alerting on friction spikes and budget overruns. Ships as both CLI and MCP server — exposes cache-adjusted session cost, AI-generated friction scores, and cross-session trends as tools the agent can query mid-session, surfacing data the Claude ecosystem records locally but never exposes. Zero network calls.

**[scout-and-wave](https://github.com/blackwell-systems/scout-and-wave)** - Methodology for reducing conflict with parallel AI agents. A throwaway scout maps the dependency graph, interface contracts, and file ownership before any code is written. Development agents execute in waves, revising a living coordination artifact between each wave. Includes canonical prompts and a Claude Code `/saw` skill.

**[ai-cold-start-audit](https://github.com/blackwell-systems/ai-cold-start-audit)** - Turn AI's lack of context into a feature. Agents cold-start your CLI in a container and report every friction point a new user would hit. Structured severity-tiered findings with reproduction steps. Includes a Claude Code `/cold-start-audit` skill.

**[github-release-engineer](https://github.com/blackwell-systems/github-release-engineer)** - Claude Code skill automating the full GitHub release lifecycle: version detection from language-specific manifests, changelog validation, tag safety checks, CI/CD monitoring with background-aware polling, intelligent failure diagnosis with automated fix-retag-rewatch loops, release asset polling with stability checks, and companion skill composition for downstream distribution. 11-step gated pipeline with a 15-row error matrix defining behavior for every failure mode.

**[dotclaude](https://blackwell-systems.github.io/dotclaude/#/)** - Profile manager for Claude Code. Switch between work/personal contexts, multi-backend routing.

### Developer Tools

**[blackdot](https://blackwell-systems.github.io/blackdot/#/)** - Modular development framework with multi-vault secrets, Claude Code integration, extensible hooks, and health checks.

### Libraries

**[goldenthread](https://github.com/blackwell-systems/goldenthread)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/goldenthread)) - Build-time schema compiler generating TypeScript Zod schemas from Go struct tags. Single source of truth for validation with automatic drift detection in CI.

**[domainstack](https://github.com/blackwell-systems/domainstack)** ([Rust crate](https://crates.io/crates/domainstack)) - Full-stack validation ecosystem for Rust: Type-safe validation with automatic TypeScript/Zod schema generation, serde integration, OpenAPI schemas, and web framework adapters (Axum, Actix, Rocket).

**[error-envelope](https://github.com/blackwell-systems/error-envelope)** ([Rust crate](https://crates.io/crates/error-envelope)) - Consistent, traceable, retry-aware HTTP error responses for Rust APIs - no framework required.

**[vaultmux](https://github.com/blackwell-systems/vaultmux)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/vaultmux)) | **[vaultmux-rs](https://github.com/blackwell-systems/vaultmux-rs)** ([Rust crate](https://crates.io/crates/vaultmux)) - Unified secret management library across Bitwarden, 1Password, pass, AWS, GCP, Azure. Available in Go and Rust with 95%+ test coverage. Powers vaultmux-server.

**[err-envelope](https://github.com/blackwell-systems/err-envelope)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/err-envelope)) - Structured HTTP error responses for Go. Works with net/http, Chi, Gin, and Echo. Machine-readable codes, field validation, trace IDs.

**[bubbletea-components](https://github.com/blackwell-systems/bubbletea-components)** - Reusable Bubble Tea TUI component library: carousel (peeking single-row card layout), command palette (fuzzy-search overlay), Miller columns (hierarchical navigation), multiselect (checkbox wrapper), and picker (base selection foundation). Five composable packages designed for drop-in use in interactive Go terminal applications. Used in shelfctl for the interactive TUI interface.

### Utilities

**[brewprune](https://github.com/blackwell-systems/brewprune)** - Free up GB of disk space by removing unused Homebrew packages. Tracks actual usage via FSEvents monitoring, scores removal safety (0-100 confidence), and creates automatic snapshots for instant rollback. Categorizes packages into Safe/Medium/Risky tiers based on usage frequency, dependency relationships, and package age.

**[shelfctl](https://github.com/blackwell-systems/shelfctl)** - CLI tool for organizing PDF and book libraries using GitHub Release assets. Interactive TUI and scriptable CLI modes. Migrate PDFs from bloated git repos, browse with covers and metadata, and distribute via on-demand downloads. Zero infrastructure - your GitHub account is the storage backend.

**[mdfx](https://github.com/blackwell-systems/mdfx)** - Make your GitHub README stand out — tech badges (like shields.io, but better), progress bars, gauges, and Unicode text effects. Local and customizable.

**[pipeboard](https://blackwell-systems.github.io/pipeboard/#/)** - Secure clipboard sharing over SSH tunnels. Share text between machines without exposing ports or using third-party services.
