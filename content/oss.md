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
- **[gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator)** - The most widely adopted community GCP Secret Manager emulator — ranked #1 on Google, Bing, and DuckDuckGo, recommended by Google AI Overview, Gemini, and GitHub Copilot. ~24k downloads with confirmed enterprise adoption. Dual gRPC + REST APIs with optional IAM enforcement. Deployable standalone or composed into gcp-emulator.
- **[gcp-eventarc-emulator](https://github.com/blackwell-systems/gcp-eventarc-emulator)** - Full Eventarc API surface (47 RPCs) with CloudEvent routing, CEL-based trigger matching, and HTTP delivery in binary content mode. Triple protocol support: gRPC, REST, and CloudEvents. Deployable standalone or composed into gcp-emulator.
- **[gcp-iam-emulator](https://github.com/blackwell-systems/gcp-iam-emulator)** - Deterministic IAM policy engine. Evaluates ALLOW/DENY decisions against GCP IAM semantics and emits machine-readable authorization traces for debugging. Deployable standalone or composed into gcp-emulator.
- **[gcp-kms-emulator](https://github.com/blackwell-systems/gcp-kms-emulator)** - KMS emulator with real cryptographic operations. Supports key versioning, rotation, and destruction with the same API surface as Cloud KMS. Deployable standalone or composed into gcp-emulator.

### AI-Native Developer Tooling & MCP Servers

**[agent-lsp](https://github.com/blackwell-systems/agent-lsp)** - Stateful MCP server runtime over real language servers — not a bridge. Maintains a persistent warm LSP session, reshapes LSP into agent-oriented workflows, and adds a transactional speculative execution layer for safe in-memory edits. 50 tools across navigation, analysis, refactoring, and formatting. 50 tools CI-verified end-to-end against real language servers across 30 languages (TypeScript, Go, Python, Rust, Java, C, C++, and 23 more) — the most comprehensive test matrix of any MCP-LSP implementation. Speculative execution lets agents simulate edits in-memory, evaluate the diagnostic delta (errors introduced vs resolved), then commit or discard atomically without touching disk. Ships 20 Agent Skills-compliant skills (`/lsp-safe-edit`, `/lsp-rename`, `/lsp-simulate`, `/lsp-impact`, `/lsp-dead-code`, `/lsp-cross-repo`, and more) as the behavioral reliability layer over the raw tool surface — in non-SDK human-in-the-loop agentic workflows, agents routinely ignore individual tools even when available; wrapping correct tool sequences as skills makes agents use them consistently without per-prompt orchestration instructions. Multi-server routing in one process: routes by file extension across languages in a single session. LSP 3.17 spec compliant, fuzzy position fallback, auto-watch via kernel filesystem events, single Go binary. Listed on the [official MCP Registry](https://registry.modelcontextprotocol.io), [Glama](https://glama.ai/mcp/servers/blackwell-systems/agent-lsp) (A-tier), and [awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers).

**[mcp-assert](https://github.com/blackwell-systems/mcp-assert)** ([docs](https://blackwell-systems.github.io/mcp-assert)) - The testing standard for deterministic MCP tools. Single Go binary that connects over stdio, SSE, or HTTP, calls tools, and asserts results. 14 assertion types defined in YAML, run against any MCP server in any language. Zero-effort coverage: `generate` auto-scaffolds stub assertions for every tool a server exposes, `snapshot` captures actual outputs as golden files. pass@k/pass^k reliability metrics distinguish capability from consistency. Cross-language matrix mode, regression detection with baseline comparison, Docker isolation per assertion. Available on the [GitHub Actions Marketplace](https://github.com/blackwell-systems/mcp-assert-action) for zero-setup CI and as a [pytest plugin](https://github.com/blackwell-systems/pytest-mcp-assert) for native Python test integration. 54 servers scanned across 7 languages, 536 assertions, 20 upstream bugs found across 9 servers (Anthropic, Grafana, mcp-go SDK, and more), 6 fix PRs submitted with Grafana PR merged. Adopted by [antvis/mcp-server-chart](https://github.com/antvis/mcp-server-chart) (4K stars, 35K monthly npm downloads) as their CI testing layer. Full results on the [public scorecard](https://blackwell-systems.github.io/mcp-assert/scorecard/).

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

## Upstream Contributions

Issues filed and fix PRs submitted to open source projects.

| Project | Type | Description | Status |
|---------|------|-------------|--------|
| [modelcontextprotocol/python-sdk#348](https://github.com/modelcontextprotocol/python-sdk/issues/348) | Fix PR [#2511](https://github.com/modelcontextprotocol/python-sdk/pull/2511) | Add custom content support to `ToolError` for `isError` responses | Open (all CI green) |
| [vercel/ai#14612](https://github.com/vercel/ai/issues/14612) | Fix PR [#14758](https://github.com/vercel/ai/pull/14758) | Send `content: null` for tool-only assistant messages in xai, deepseek, groq, mistral | Open |
| [langchain-ai/langchain#37030](https://github.com/langchain-ai/langchain/issues/37030) | Fix PR [#37037](https://github.com/langchain-ai/langchain/pull/37037) | Remove dead C#/Elixir separators in `RecursiveCharacterTextSplitter` | **Merged** |
| [langchain-ai/langchain#36750](https://github.com/langchain-ai/langchain/issues/36750) | Fix PR | Implement missing PERL separators + fix `InMemoryCache` eviction bug | Ready (awaiting assignment) |
| [sashabaranov/go-openai#1073](https://github.com/sashabaranov/go-openai/issues/1073) | Fix PR [#1104](https://github.com/sashabaranov/go-openai/pull/1104) | Fix `stream` field omitted from non-streaming request JSON | Open |
| [sashabaranov/go-openai#960](https://github.com/sashabaranov/go-openai/issues/960) | Fix PR [#1105](https://github.com/sashabaranov/go-openai/pull/1105) | Use pointer for `ContentFilterResults` to distinguish absent from empty | Open |
| [sashabaranov/go-openai#1012](https://github.com/sashabaranov/go-openai/issues/1012) | Fix PR [#1106](https://github.com/sashabaranov/go-openai/pull/1106) | Detect Content-Type from file extension for gpt-image-1 uploads | Open |
| [stretchr/testify#1722](https://github.com/stretchr/testify/issues/1722) | Fix PR [#1877](https://github.com/stretchr/testify/pull/1877) | Fix panic when `SetupTest` skips with `HandleStats` | Open |
| [charmbracelet/bubbletea#431](https://github.com/charmbracelet/bubbletea/issues/431) | Fix PR [#1687](https://github.com/charmbracelet/bubbletea/pull/1687) | `ExecProcess` leaks `View()` output to stdout before subprocess runs | Open |
| [cli/cli#12895](https://github.com/cli/cli/issues/12895) | Fix PR | `gh pr status` counts cancelled runs as failures despite newer success | Ready (awaiting `help wanted` label) |
| [grafana/mcp-grafana#793](https://github.com/grafana/mcp-grafana/pull/793) | Fix PR | `get_assertions` timestamp validation fix | **Merged** |
| [grafana/grafana#123664](https://github.com/grafana/grafana/pull/123664) | Fix PR | Remove debug `console.log` in Explore scanning loop | Open |
| [grafana/grafana#123665](https://github.com/grafana/grafana/pull/123665) | Fix PR | Fix `typeof` check in LegacyVariableWrapper + remove `console.log` | Open |
| [grafana/grafana#123666](https://github.com/grafana/grafana/pull/123666) | Fix PR | Fix `defer span.End()` inside loop in expression pipeline | Open |
| [grafana/grafana#123331](https://github.com/grafana/grafana/issues/123331) | Fix PR [#123691](https://github.com/grafana/grafana/pull/123691) | Propagate `QueryHistoryDetails` insert errors instead of silently discarding | Open |
| [antvis/mcp-server-chart#291](https://github.com/antvis/mcp-server-chart/issues/291) | Fix PR [#292](https://github.com/antvis/mcp-server-chart/pull/292) | 9 tools crash with unhandled exceptions on default input | **Merged** |
| [mark3labs/mcp-go#826](https://github.com/mark3labs/mcp-go/issues/826) | Fix PR [#828](https://github.com/mark3labs/mcp-go/pull/828) | stdio transport crash on slow tools (`fmt.Printf` corrupts JSON-RPC) | Open |
| [sammcj/mcp-devtools#258](https://github.com/sammcj/mcp-devtools/pull/258) | Fix PR | Tool handler returns internal error instead of `isError` for validation failures | Open |
| [modelcontextprotocol/servers#4029](https://github.com/modelcontextprotocol/servers/issues/4029) | Fix PR [#4044](https://github.com/modelcontextprotocol/servers/pull/4044) | `read_media_file` returns `type: "blob"`, violating MCP spec | Open |
| [modelcontextprotocol/servers#4051](https://github.com/modelcontextprotocol/servers/pull/4051) | Fix PR | `puppeteer_navigate` crashes on invalid URL with unhandled CDP error | Open |
| [modelcontextprotocol/go-sdk#855](https://github.com/modelcontextprotocol/go-sdk/issues/855) | Fix PR [#913](https://github.com/modelcontextprotocol/go-sdk/pull/913) | Race condition in `ClientSession.Close()`: suppress subprocess exit error during graceful shutdown | Open |
| [hashicorp/terraform-provider-aws#47607](https://github.com/hashicorp/terraform-provider-aws/issues/47607) | Fix PR [#47660](https://github.com/hashicorp/terraform-provider-aws/pull/47660) | Handle `UnsupportedOperationException` for Directory Service Data in GovCloud | Open |
| [hashicorp/terraform-provider-aws#47623](https://github.com/hashicorp/terraform-provider-aws/issues/47623) | Fix PR [#47661](https://github.com/hashicorp/terraform-provider-aws/pull/47661) | Wire `theme_arn` through Create/Update/Read for QuickSight dashboards | Open |
| [google/go-containerregistry#2139](https://github.com/google/go-containerregistry/issues/2139) | Fix PR [#2281](https://github.com/google/go-containerregistry/pull/2281) | `.local` FQDN incorrectly treated as non-HTTPS; only `.localhost` should be | Open |
| [antvis/mcp-server-chart#294](https://github.com/antvis/mcp-server-chart/pull/294) | PR | Add mcp-assert CI integration with 25 assertions | Open |
| [blazickjp/arxiv-mcp-server#92](https://github.com/blazickjp/arxiv-mcp-server/issues/92) | Issue | `get_abstract` returns error content without `isError` flag | Maintainer fix merged |
| [steipete/Peekaboo#108](https://github.com/steipete/Peekaboo/issues/108) | Issue | `image` returns internal error without Screen Recording permission | Open |
| [punkpeye/awesome-mcp-servers#5145](https://github.com/punkpeye/awesome-mcp-servers/pull/5145) | PR | Add agent-lsp listing | **Merged** |
