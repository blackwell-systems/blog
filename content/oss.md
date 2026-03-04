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

**GCP Emulator Ecosystem** - Hermetic local emulation stack for Google Cloud Platform services.

- **[gcp-iam-emulator](https://github.com/blackwell-systems/gcp-iam-emulator)** - Deterministic IAM policy engine that evaluates authorization decisions (ALLOW/DENY) based on explicit policy definitions. Acts as the control plane for all Blackwell emulators via policy.yaml. Emits machine-readable authorization traces for analysis and policy refinement with gcp-emulator-pro.
- **[gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator)** - Local Secret Manager emulator with dual gRPC + REST APIs. Integrates with [gcp-iam-emulator](https://github.com/blackwell-systems/gcp-iam-emulator) for pre-flight authorization enforcement and trace generation. Designed for deterministic local development and CI/CD testing workflows.
- **[gcp-kms-emulator](https://github.com/blackwell-systems/gcp-kms-emulator)** - Key Management Service emulator with real cryptographic operations using local key material. Integrated with [gcp-iam-emulator](https://github.com/blackwell-systems/gcp-iam-emulator) for permission enforcement on encrypt/decrypt and key-management operations. Supports key versioning, rotation, and destruction with trace output.
- **[gcp-iam-control-plane](https://github.com/blackwell-systems/gcp-iam-control-plane)** - Unified orchestration CLI for the Blackwell GCP emulator ecosystem. A single policy.yaml drives IAM enforcement across Secret Manager, KMS, and future emulators. Start and stop services, manage policies, inspect authorization traces, and test principal-based access control locally and in CI.

**[vaultmux](https://github.com/blackwell-systems/vaultmux)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/vaultmux)) | **[vaultmux-rs](https://github.com/blackwell-systems/vaultmux-rs)** ([Rust crate](https://crates.io/crates/vaultmux)) - Unified secret management across Bitwarden, 1Password, pass, AWS, GCP, Azure. Write once, support 7+ backends. Available in Go and Rust.

### AI-Native Developer Tooling & MCP Servers

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
