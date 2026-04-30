---
title: "Open Source Software"
date: 2026-01-29
draft: false
showMetadata: false
---

## Open Source Projects

### Systems Research

**[libdrainprof](https://github.com/blackwell-systems/drainability-profiler)** - C library for detecting structural memory leaks invisible to traditional tools (Valgrind, ASan). Measures drainability satisfaction rate at allocator granule boundaries with <2ns overhead. Companion tool to the [drainability paper](https://doi.org/10.5281/zenodo.18653776).

**[gsm](https://github.com/blackwell-systems/gsm)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/gsm)) - Governed state machines with build-time convergence verification. Define state variables, business invariants, and compensation logic; the library exhaustively verifies that event ordering cannot cause replica divergence. Runtime event application is O(1) via precomputed table lookup. Companion library to the [normalization confluence paper](https://doi.org/10.5281/zenodo.18677400).

**[temporal-slab](https://github.com/blackwell-systems/temporal-slab)** - Epoch-based slab allocator. The experimental allocator used to validate the [drainability theorem](https://doi.org/10.5281/zenodo.18653776).

### Cloud Infrastructure

**[vaultmux-server](https://github.com/blackwell-systems/vaultmux-server)** - Language-agnostic secrets control plane for Kubernetes. HTTP REST API enabling polyglot teams (Python, Node.js, Go, Rust) to fetch secrets from AWS, GCP, or Azure without SDK dependencies. Deploy as sidecar or cluster service.

**GCP Emulator Platform** - Composable local emulation stack for Google Cloud Platform. Each emulator runs standalone or registers into a unified single-process server via a shared hook architecture: one binary, one gRPC port, one Docker image.

- **[gcp-emulator](https://github.com/blackwell-systems/gcp-emulator)** - Unified GCP local development platform. Composes Secret Manager, KMS, IAM, and Eventarc into a single process on a shared gRPC port with a unified REST gateway. Run your entire GCP stack locally with one command, no docker-compose juggling. Optional IAM enforcement via policy.yaml.
- **[gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator)** - The most widely adopted community GCP Secret Manager emulator, ranked #1 on Google, Bing, and DuckDuckGo, recommended by Google AI Overview, Gemini, and GitHub Copilot. ~24k downloads with confirmed enterprise CI adoption by [Flipt](https://github.com/flipt-io/flipt) (4.8K stars, enterprise feature flag platform) and [Reindeer AI](https://github.com/reindeer-ai). Dual gRPC + REST APIs with optional IAM enforcement. Deployable standalone or composed into gcp-emulator.
- **[gcp-eventarc-emulator](https://github.com/blackwell-systems/gcp-eventarc-emulator)** - Full Eventarc API surface (47 RPCs) with CloudEvent routing, CEL-based trigger matching, and HTTP delivery in binary content mode. Triple protocol support: gRPC, REST, and CloudEvents. Deployable standalone or composed into gcp-emulator.
- **[gcp-iam-emulator](https://github.com/blackwell-systems/gcp-iam-emulator)** - Deterministic IAM policy engine. Evaluates ALLOW/DENY decisions against GCP IAM semantics and emits machine-readable authorization traces for debugging. Deployable standalone or composed into gcp-emulator.
- **[gcp-kms-emulator](https://github.com/blackwell-systems/gcp-kms-emulator)** - KMS emulator with real cryptographic operations. Supports key versioning, rotation, and destruction with the same API surface as Cloud KMS. Deployable standalone or composed into gcp-emulator.

### AI-Native Developer Tooling and MCP Servers

**[agent-lsp](https://github.com/blackwell-systems/agent-lsp)** - Stateful MCP server runtime over real language servers. Maintains a persistent warm LSP session, reshapes LSP into agent-oriented workflows, and adds a transactional speculative execution layer for safe in-memory edits. 50 tools across navigation, analysis, refactoring, and formatting. CI-verified end-to-end against real language servers across 30 languages. Speculative execution lets agents simulate edits in-memory, evaluate the diagnostic delta (errors introduced vs resolved), then commit or discard atomically without touching disk. Ships 20 Agent Skills-compliant skills as the behavioral reliability layer over the raw tool surface. Listed on the [official MCP Registry](https://registry.modelcontextprotocol.io), [Glama](https://glama.ai/mcp/servers/blackwell-systems/agent-lsp) (A-tier), and [awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers).

**[mcp-assert](https://github.com/blackwell-systems/mcp-assert)** ([docs](https://blackwell-systems.github.io/mcp-assert)) - The testing standard for deterministic MCP tools. Single Go binary that connects over stdio, SSE, or HTTP, calls tools, and asserts results. 18 assertion types defined in YAML, run against any MCP server in any language. Zero-effort coverage: `generate` auto-scaffolds stub assertions for every tool a server exposes, `snapshot` captures actual outputs as golden files. Available on the [GitHub Actions Marketplace](https://github.com/blackwell-systems/mcp-assert-action), as a [pytest plugin](https://github.com/blackwell-systems/pytest-mcp-assert), and as a [Vitest plugin](https://www.npmjs.com/package/vitest-mcp-assert). 55 servers scanned across 7 languages, 570 assertions, 20 upstream bugs found across 9 servers. Adopted as the CI testing standard by [antvis/mcp-server-chart](https://github.com/antvis/mcp-server-chart) (Ant Group, 4K stars) and [wyre-technology](https://github.com/wyre-technology) across 25+ MCP server repos as their company-wide testing layer. Full results on the [public scorecard](https://blackwell-systems.github.io/mcp-assert/scorecard/).

**[commitmux](https://github.com/blackwell-systems/commitmux)** - Keyword and semantic search over git history, exposed as MCP tools for coding agents. Cross-repo, local-first, no credentials, no rate limits. Builds a read-optimized SQLite index over commit subjects, bodies, and patches; serves it via a narrow read-only MCP surface.

**[claudewatch](https://github.com/blackwell-systems/claudewatch)** - Full-cycle AI development observability platform. Scores project AI readiness, surfaces friction patterns, generates CLAUDE.md patches from session data, snapshots metrics to SQLite for before/after effectiveness scoring. Ships as both CLI and MCP server. Zero network calls.

**[scout-and-wave](https://github.com/blackwell-systems/scout-and-wave)** - Methodology for reducing conflict with parallel AI agents. A throwaway scout maps the dependency graph, interface contracts, and file ownership before any code is written. Development agents execute in waves, revising a living coordination artifact between each wave. Includes canonical prompts and a Claude Code `/saw` skill.

**[ai-cold-start-audit](https://github.com/blackwell-systems/ai-cold-start-audit)** - Turn AI's lack of context into a feature. Agents cold-start your CLI in a container and report every friction point a new user would hit. Structured severity-tiered findings with reproduction steps.

**[github-release-engineer](https://github.com/blackwell-systems/github-release-engineer)** - Claude Code skill automating the full GitHub release lifecycle: version detection, changelog validation, tag safety checks, CI/CD monitoring, intelligent failure diagnosis with automated fix-retag-rewatch loops. 11-step gated pipeline.

**[dotclaude](https://blackwell-systems.github.io/dotclaude/#/)** - Profile manager for Claude Code. Switch between work/personal contexts, multi-backend routing.

### Developer Tools

**[blackdot](https://blackwell-systems.github.io/blackdot/#/)** - Modular development framework with multi-vault secrets, Claude Code integration, extensible hooks, and health checks.

### Libraries

**[goldenthread](https://github.com/blackwell-systems/goldenthread)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/goldenthread)) - Build-time schema compiler generating TypeScript Zod schemas from Go struct tags. Single source of truth for validation with automatic drift detection in CI.

**[domainstack](https://github.com/blackwell-systems/domainstack)** ([Rust crate](https://crates.io/crates/domainstack)) - Full-stack validation ecosystem for Rust: Type-safe validation with automatic TypeScript/Zod schema generation, serde integration, OpenAPI schemas, and web framework adapters (Axum, Actix, Rocket).

**[error-envelope](https://github.com/blackwell-systems/error-envelope)** ([Rust crate](https://crates.io/crates/error-envelope)) - Consistent, traceable, retry-aware HTTP error responses for Rust APIs.

**[vaultmux](https://github.com/blackwell-systems/vaultmux)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/vaultmux)) | **[vaultmux-rs](https://github.com/blackwell-systems/vaultmux-rs)** ([Rust crate](https://crates.io/crates/vaultmux)) - Unified secret management library across Bitwarden, 1Password, pass, AWS, GCP, Azure. Available in Go and Rust with 95%+ test coverage. Powers vaultmux-server.

**[err-envelope](https://github.com/blackwell-systems/err-envelope)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/err-envelope)) - Structured HTTP error responses for Go. Works with net/http, Chi, Gin, and Echo. Machine-readable codes, field validation, trace IDs.

**[bubbletea-components](https://github.com/blackwell-systems/bubbletea-components)** - Reusable Bubble Tea TUI component library: carousel, command palette, Miller columns, multiselect, and picker. Five composable packages for interactive Go terminal applications.

### Utilities

**[brewprune](https://github.com/blackwell-systems/brewprune)** - Free up GB of disk space by removing unused Homebrew packages. Tracks actual usage via FSEvents monitoring, scores removal safety (0-100 confidence), and creates automatic snapshots for instant rollback.

**[shelfctl](https://github.com/blackwell-systems/shelfctl)** - CLI tool for organizing PDF and book libraries using GitHub Release assets. Interactive TUI and scriptable CLI modes.

**[mdfx](https://github.com/blackwell-systems/mdfx)** - Make your GitHub README stand out: tech badges, progress bars, gauges, and Unicode text effects. Local and customizable.

**[pipeboard](https://blackwell-systems.github.io/pipeboard/#/)** - Secure clipboard sharing over SSH tunnels. Share text between machines without exposing ports or using third-party services.

---

## Upstream Contributions

Fix PRs and bug reports submitted to open source projects. 35 contributions across 25 repos, 6 merged. Bugs discovered via [mcp-assert](https://github.com/blackwell-systems/mcp-assert) scanning are marked with *.

### Merged

| Project | Description | Details |
|---------|-------------|---------|
| [grafana/mcp-grafana#793](https://github.com/grafana/mcp-grafana/pull/793) | `get_assertions` timestamp validation fix | Go. Validation ordering bug.* |
| [langchain-ai/langchain#37037](https://github.com/langchain-ai/langchain/pull/37037) | Remove dead C#/Elixir separators in `RecursiveCharacterTextSplitter` | Python. Copy-paste from adjacent language defs. |
| [antvis/mcp-server-chart#292](https://github.com/antvis/mcp-server-chart/pull/292) | 9 tools crash with unhandled exceptions on default input | TypeScript. Led to first mcp-assert CI adoption.* |
| [google/go-containerregistry#2281](https://github.com/google/go-containerregistry/pull/2281) | `.local` FQDN incorrectly treated as non-HTTPS | Go. Regex fix per RFC 6761. |
| [punkpeye/awesome-mcp-servers#5145](https://github.com/punkpeye/awesome-mcp-servers/pull/5145) | Add agent-lsp listing | |

### Highlights (open, under review)

| Project | Description | Why it matters |
|---------|-------------|----------------|
| [etcd-io/etcd#21684](https://github.com/etcd-io/etcd/pull/21684) | `ErrNotPrimary` returns gRPC Unknown instead of Unavailable | Go. 51k stars. Clients can't retry on Unknown. Mapped to Unavailable, consistent with ErrLeaderChanged. |
| [modelcontextprotocol/go-sdk#913](https://github.com/modelcontextprotocol/go-sdk/pull/913) | Race condition in `ClientSession.Close()` | Go. Traced from Alan Donovan's (Google) analysis of gopls CI flakes. Regression test verified. |
| [biomejs/biome#10151](https://github.com/biomejs/biome/pull/10151) | `--suppress` with `--only` ignores rule overrides | Rust. Two-line fix in a 24.5k-star codebase. Regression test added. |
| [hashicorp/terraform-provider-aws#47660](https://github.com/hashicorp/terraform-provider-aws/pull/47660) | GovCloud crash: `UnsupportedOperationException` in Directory Service Data | Go. Triaged by maintainer within 14 hours. |
| [hashicorp/terraform-provider-aws#47661](https://github.com/hashicorp/terraform-provider-aws/pull/47661) | QuickSight `theme_arn` silently ignored in Create/Update/Read | Go. Field wired through full CRUD lifecycle. |
| [github/github-mcp-server#2408](https://github.com/github/github-mcp-server/pull/2408) | Angle brackets stripped from code blocks by HTML sanitizer | Go. 30k stars. Sentinel-based protection for code content during bluemonday sanitization. |
| [traefik/traefik#13065](https://github.com/traefik/traefik/pull/13065) | `rewrite-target` regex breaks base path match for `ImplementationSpecific` paths | Go. 53k stars. Trailing slash in regex made optional to match nginx behavior. |
| [antvis/mcp-server-chart#294](https://github.com/antvis/mcp-server-chart/pull/294) | mcp-assert CI integration (25 assertions) | TypeScript. First external adoption. 4k stars, 35k npm downloads/mo. |
| [charmbracelet/bubbletea#1687](https://github.com/charmbracelet/bubbletea/pull/1687) | `ExecProcess` leaks `View()` output to stdout | Go. Traced renderer flush lifecycle. |
| [stretchr/testify#1877](https://github.com/stretchr/testify/pull/1877) | Panic when `SetupTest` skips with `HandleStats` | Go. `runtime.Goexit` ordering with deferred cleanup. |

### All Open PRs

| Project | Description | Status |
|---------|-------------|--------|
| [modelcontextprotocol/python-sdk#2511](https://github.com/modelcontextprotocol/python-sdk/pull/2511) | Add custom content support to `ToolError` for `isError` responses | All CI green |
| [vercel/ai#14758](https://github.com/vercel/ai/pull/14758) | Send `content: null` for tool-only assistant messages (xai, deepseek, groq, mistral) | Open |
| [sashabaranov/go-openai#1104](https://github.com/sashabaranov/go-openai/pull/1104) | Fix `stream` field omitted from non-streaming request JSON | Open |
| [sashabaranov/go-openai#1105](https://github.com/sashabaranov/go-openai/pull/1105) | Use pointer for `ContentFilterResults` to distinguish absent from empty | Open |
| [sashabaranov/go-openai#1106](https://github.com/sashabaranov/go-openai/pull/1106) | Detect Content-Type from file extension for gpt-image-1 uploads | Open |
| [grafana/grafana#123664](https://github.com/grafana/grafana/pull/123664) | Remove debug `console.log` in Explore scanning loop | Open |
| [grafana/grafana#123665](https://github.com/grafana/grafana/pull/123665) | Fix `typeof` check in LegacyVariableWrapper + remove `console.log` | Open |
| [grafana/grafana#123666](https://github.com/grafana/grafana/pull/123666) | Fix `defer span.End()` inside loop in expression pipeline | Open |
| [grafana/grafana#123691](https://github.com/grafana/grafana/pull/123691) | Propagate `QueryHistoryDetails` insert errors instead of silently discarding | Open |
| [mark3labs/mcp-go#828](https://github.com/mark3labs/mcp-go/pull/828) | stdio transport crash on slow tools (`fmt.Printf` corrupts JSON-RPC) | Open* |
| [sammcj/mcp-devtools#258](https://github.com/sammcj/mcp-devtools/pull/258) | Tool handler returns internal error instead of `isError` for validation failures | Open* |
| [modelcontextprotocol/servers#4044](https://github.com/modelcontextprotocol/servers/pull/4044) | `read_media_file` returns `type: "blob"`, violating MCP spec | Open* |
| [modelcontextprotocol/servers#4051](https://github.com/modelcontextprotocol/servers/pull/4051) | `puppeteer_navigate` crashes on invalid URL with unhandled CDP error | Open* |
| [tavily-ai/tavily-mcp#162](https://github.com/tavily-ai/tavily-mcp/pull/162) | Missing API key throws McpError instead of returning `isError: true` | Open* |
| [dvcrn/mcp-server-linear#5](https://github.com/dvcrn/mcp-server-linear/pull/5) | 24 tools throw McpError instead of returning `isError` when unauthenticated | Open* |
| [modelcontextprotocol/kotlin-sdk#734](https://github.com/modelcontextprotocol/kotlin-sdk/pull/734) | Type-unsafe cast in polymorphic result deserialization | Kotlin. `ready for work` label. |
| [pypa/pip#13960](https://github.com/pypa/pip/pull/13960) | Replace deprecated `locale.getpreferredencoding()` for Python 3.15 compat | Open |
| [mark3labs/mcp-go#828](https://github.com/mark3labs/mcp-go/pull/828) | Redirect hook output to stderr in everything server example | Open |
| [punkpeye/awesome-mcp-devtools#144](https://github.com/punkpeye/awesome-mcp-devtools/pull/144) | Add mcp-assert to Testing Tools listing | Open |

### Bugs Filed (fixed by others)

| Project | Description | Outcome |
|---------|-------------|---------|
| [blazickjp/arxiv-mcp-server#92](https://github.com/blazickjp/arxiv-mcp-server/issues/92) | `get_abstract` returns error content without `isError` flag | Maintainer fix merged* |
| [steipete/Peekaboo#108](https://github.com/steipete/Peekaboo/issues/108) | `image` returns internal error without Screen Recording permission | Community fix PR [#109](https://github.com/steipete/Peekaboo/pull/109)* |

### Pending (ready, blocked on process)

| Project | Description | Blocker |
|---------|-------------|---------|
| [langchain-ai/langchain#36750](https://github.com/langchain-ai/langchain/issues/36750) | PERL separators + `InMemoryCache` eviction fix | Awaiting assignment (LangChain requires label before PR) |
| [cli/cli#12895](https://github.com/cli/cli/issues/12895) | `gh pr status` deduplicates cancelled checks with newer success | Awaiting `help wanted` label |
