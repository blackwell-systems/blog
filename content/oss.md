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
- **[gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator)** - The most widely adopted community GCP Secret Manager emulator, ranked #1 on Google, Bing, and DuckDuckGo, recommended by Google AI Overview, Gemini, and GitHub Copilot. ~24k downloads with confirmed enterprise CI adoption by [Flipt](https://github.com/flipt-io/flipt) (4.8K stars, enterprise feature flag platform), [Reindeer AI](https://github.com/reindeer-ai), and [sugar-org/swarm-external-secrets](https://github.com/sugar-org/swarm-external-secrets) (Docker Swarm secrets plugin, forked the emulator for GCP integration). Dual gRPC + REST APIs with optional IAM enforcement. Deployable standalone or composed into gcp-emulator.
- **[gcp-eventarc-emulator](https://github.com/blackwell-systems/gcp-eventarc-emulator)** - Full Eventarc API surface (47 RPCs) with CloudEvent routing, CEL-based trigger matching, and HTTP delivery in binary content mode. Triple protocol support: gRPC, REST, and CloudEvents. Deployable standalone or composed into gcp-emulator.
- **[gcp-iam-emulator](https://github.com/blackwell-systems/gcp-iam-emulator)** - Deterministic IAM policy engine. Evaluates ALLOW/DENY decisions against GCP IAM semantics and emits machine-readable authorization traces for debugging. Deployable standalone or composed into gcp-emulator.
- **[gcp-kms-emulator](https://github.com/blackwell-systems/gcp-kms-emulator)** - KMS emulator with real cryptographic operations. Supports key versioning, rotation, and destruction with the same API surface as Cloud KMS. Deployable standalone or composed into gcp-emulator.

### AI-Native Developer Tooling and MCP Servers

**[agent-lsp](https://github.com/blackwell-systems/agent-lsp)** ([agent-lsp.com](https://agent-lsp.com)) - Stateful MCP server runtime over real language servers. Maintains a persistent warm LSP session, reshapes LSP into agent-oriented workflows, and adds a transactional speculative execution layer for safe in-memory edits. 61 tools across navigation, analysis, refactoring, and formatting. CI-verified end-to-end against real language servers across 30 languages. Speculative execution lets agents simulate edits in-memory, evaluate the diagnostic delta (errors introduced vs resolved), then commit or discard atomically without touching disk. Ships 21 Agent Skills-compliant skills as the behavioral reliability layer over the raw tool surface. Listed on the [official MCP Registry](https://registry.modelcontextprotocol.io), [Glama](https://glama.ai/mcp/servers/blackwell-systems/agent-lsp) (A-tier), and [awesome-mcp-servers](https://github.com/punkpeye/awesome-mcp-servers).

**[mcp-assert](https://github.com/blackwell-systems/mcp-assert)** ([mcp-assert.com](https://mcp-assert.com), [docs](https://blackwell-systems.github.io/mcp-assert)) - The testing standard for deterministic MCP tools. Single Go binary that connects over stdio, SSE, or HTTP, calls tools, and asserts results. 18 assertion types defined in YAML, run against any MCP server in any language. Zero-effort coverage: `generate` auto-scaffolds stub assertions for every tool a server exposes, `snapshot` captures actual outputs as golden files. Available on the [GitHub Actions Marketplace](https://github.com/blackwell-systems/mcp-assert-action), as a [pytest plugin](https://github.com/blackwell-systems/pytest-mcp-assert), [Vitest plugin](https://www.npmjs.com/package/vitest-mcp-assert), [Jest plugin](https://www.npmjs.com/package/jest-mcp-assert), [Bun plugin](https://www.npmjs.com/package/bun-mcp-assert), and [Go test plugin](https://github.com/blackwell-systems/mcp-assert/tree/main/go-plugin). 61 server suites scanned across 7 languages, 570 assertions, 20 upstream bugs found across 9 servers. Adopted as the CI testing standard by [antvis/mcp-server-chart](https://github.com/antvis/mcp-server-chart) (Ant Group, 4K stars) and [wyre-technology](https://github.com/wyre-technology) across 25+ MCP server repos as their company-wide testing layer. Full results on the [public scorecard](https://blackwell-systems.github.io/mcp-assert/scorecard/).

**[commitmux](https://github.com/blackwell-systems/commitmux)** - Keyword and semantic search over git history, exposed as MCP tools for coding agents. Cross-repo, local-first, no credentials, no rate limits. Builds a read-optimized SQLite index over commit subjects, bodies, and patches; serves it via a narrow read-only MCP surface.

**[claudewatch](https://github.com/blackwell-systems/claudewatch)** - Full-cycle AI development observability platform. Scores project AI readiness, surfaces friction patterns, generates CLAUDE.md patches from session data, snapshots metrics to SQLite for before/after effectiveness scoring. Ships as both CLI and MCP server. Zero network calls.

**[polywave](https://github.com/blackwell-systems/polywave)** - Formal coordination protocol for parallel AI agents. 6 invariants, 48 execution rules, and a 10-state machine that makes merge conflicts structurally impossible. Disjoint file ownership enforced before worktrees are created. Five repositories:

- [polywave-protocol](https://github.com/blackwell-systems/polywave-protocol) - Implementation-agnostic specification (invariants, execution rules, state machine, message formats)
- [polywave](https://github.com/blackwell-systems/polywave) - Claude Code implementation (Agent Skill, 22 enforcement hooks, agent prompts)
- [polywave-codex](https://github.com/blackwell-systems/polywave-codex) - Codex CLI implementation (same protocol, different platform; in progress)
- [polywave-go](https://github.com/blackwell-systems/polywave-go) - Go engine + `polywave-tools` CLI (75+ commands, 4 LLM backends: Anthropic, OpenAI, Bedrock, Ollama)
- [polywave-web](https://github.com/blackwell-systems/polywave-web) - Real-time web dashboard with live wave execution, IMPL review, and SSE streaming

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

Fix PRs and bug reports submitted to open source projects. 67 contributions across 25 organizations, 21 merged. Bugs discovered via [mcp-assert](https://github.com/blackwell-systems/mcp-assert) scanning are marked with *.

### Merged

| Organization | PR | Lang | Description | Stars |
|-------------|-----|------|-------------|------:|
| **Anthropic** (MCP Go SDK) | [go-sdk#929](https://github.com/modelcontextprotocol/go-sdk/pull/929) | Go | HTTP response body leak in streamable HTTP session close | 4.5K |
| **Google** | [go-containerregistry#2281](https://github.com/google/go-containerregistry/pull/2281) | Go | `.local` FQDN incorrectly treated as non-HTTPS (RFC 6761) | 3.8K |
| **Google** | [go-containerregistry#2283](https://github.com/google/go-containerregistry/pull/2283) | Go | Extract round-trip test for filesystem object preservation | 3.8K |
| **Grafana** | [mcp-grafana#793](https://github.com/grafana/mcp-grafana/pull/793) | Go | `get_assertions` timestamp validation fix | 2.9K |
| **Grafana** | [mcp-grafana#829](https://github.com/grafana/mcp-grafana/pull/829) | Go | Dynamic server instructions from enabled tool categories (feature) | 2.9K |
| **Grafana** | [mcp-grafana#834](https://github.com/grafana/mcp-grafana/pull/834) | Go | Sift unchecked type assertion panic | 2.9K |
| **Ant Group** | [mcp-server-chart#292](https://github.com/antvis/mcp-server-chart/pull/292) | TS | 9 tools crash with unhandled exceptions on default input | 4K |
| **LangChain** | [langchain#37037](https://github.com/langchain-ai/langchain/pull/37037) | Python | Remove dead C#/Elixir separators in `RecursiveCharacterTextSplitter` | 136K |
| **mark3labs** (mcp-go SDK) | [mcp-go#828](https://github.com/mark3labs/mcp-go/pull/828) | Go | Redirect hook output to stderr (stdio transport corruption) | 8.7K |
| **mark3labs** (mcp-go SDK) | [mcp-go#838](https://github.com/mark3labs/mcp-go/pull/838) | Go | Return isError for input validation instead of -32603 | 8.7K |
| **mark3labs** (mcp-go SDK) | [mcp-go#839](https://github.com/mark3labs/mcp-go/pull/839) | Go | listenForever retries indefinitely on session terminated (404) | 8.7K |
| **mark3labs** (mcp-go SDK) | [mcp-go#849](https://github.com/mark3labs/mcp-go/pull/849) | Go | Response body leak on 404 in sendHTTP (TCP connection leaked per retry) | 8.7K |
| **mark3labs** (mcp-go SDK) | [mcp-go#852](https://github.com/mark3labs/mcp-go/pull/852) | Go | Add CloseSessions + fix double-close panic race in SSE shutdown | 8.7K |
| **mark3labs** (mcp-go SDK) | [mcp-go#861](https://github.com/mark3labs/mcp-go/pull/861) | Go | Transport goroutines lack panic recovery (9 goroutines crash process on panic, found by inspector) | 8.7K |
| **Anthropic** (MCP Python SDK) | [python-sdk#2542](https://github.com/modelcontextprotocol/python-sdk/pull/2542) | Python | Broken exception chains in get_prompt and read_resource | 23K |
| **Anthropic** (MCP PHP SDK) | [php-sdk#297](https://github.com/modelcontextprotocol/php-sdk/pull/297) | PHP | URI regex rejects valid RFC 3986 URIs | 1.5K |
| **Stretchr** | [testify#1877](https://github.com/stretchr/testify/pull/1877) | Go | Suite panics when `SetupTest` skips with `HandleStats` (`runtime.Goexit` ordering) | 26K |
| **Microsoft** | [winget-pkgs](https://github.com/microsoft/winget-pkgs) | YAML | Winget manifests for mcp-assert and agent-lsp | 10K |

### Highlights (open, under review)

| Organization | PR | Lang | Description | Stars |
|-------------|-----|------|-------------|------:|
| **mark3labs** (mcp-go SDK) | [mcp-go#882](https://github.com/mark3labs/mcp-go/pull/882) | Go | SSE + stdio transport panic recovery (completes #861 coverage, found by inspector) | 8.7K |
| **mark3labs** (mcp-go SDK) | [mcp-go#880](https://github.com/mark3labs/mcp-go/pull/880) | Go | Task goroutine panic recovery + cleanup goroutine leak (found by inspector) | 8.7K |
| **Google** | [go-containerregistry#2286](https://github.com/google/go-containerregistry/pull/2286) | Go | OCI artifact config corruption in mutate package (silent data loss in Cloud Build/Artifact Registry plumbing) | 3.8K |
| **Anthropic** (MCP PHP SDK) | [php-sdk#301](https://github.com/modelcontextprotocol/php-sdk/pull/301) | PHP | Add missing `title` field to Resource and ResourceTemplate (spec compliance) | 1.5K |
| **Anthropic** (MCP Conformance) | [conformance#263](https://github.com/modelcontextprotocol/conformance/pull/263) | TS | tier-check reports 0% despite all tests passing (server/client scenario lists swapped) | MCP |
| **Anthropic** (MCP Go SDK) | [go-sdk#913](https://github.com/modelcontextprotocol/go-sdk/pull/913) | Go | Race condition in `ClientSession.Close()` | 4.5K |
| **Anthropic** (MCP TS SDK) | [typescript-sdk#2013](https://github.com/modelcontextprotocol/typescript-sdk/pull/2013) | TS | Null arguments crash every TS SDK server | 12K |
| **Anthropic** (MCP Python SDK) | [python-sdk#2565](https://github.com/modelcontextprotocol/python-sdk/pull/2565) | Python | 12 remaining `raise` sites missing exception chain (`from`) | 23K |
| **Anthropic** (MCP Python SDK) | [python-sdk#2536](https://github.com/modelcontextprotocol/python-sdk/pull/2536) | Python | Lost-wakeup race: concurrent pollers hang forever | 23K |
| **etcd** (CNCF) | [etcd#21684](https://github.com/etcd-io/etcd/pull/21684) | Go | `ErrNotPrimary` returns wrong gRPC code | 51K |
| **Traefik** | [traefik#13089](https://github.com/traefik/traefik/pull/13089) | Go | rewrite-target regex breaks base path match | 53K |
| **Charmbracelet** | [bubbletea#1687](https://github.com/charmbracelet/bubbletea/pull/1687) | Go | `ExecProcess` leaks `View()` output to stdout | 42K |
| **GitHub** | [github-mcp-server#2408](https://github.com/github/github-mcp-server/pull/2408) | Go | Angle brackets stripped from code blocks | 30K |
| **HashiCorp** | [terraform-provider-aws#47660](https://github.com/hashicorp/terraform-provider-aws/pull/47660) | Go | GovCloud crash in Directory Service Data | 10.9K |
| **HashiCorp** | [terraform-provider-aws#47661](https://github.com/hashicorp/terraform-provider-aws/pull/47661) | Go | QuickSight `theme_arn` silently ignored | 10.9K |
| **jackc** (pgx) | [pgx#2546](https://github.com/jackc/pgx/pull/2546) | Go | BeforeConnect gets bare context from healthcheck | 14K |
| **Biome** | [biome#10151](https://github.com/biomejs/biome/pull/10151) | Rust | `--suppress` with `--only` ignores overrides | 24.5K |

### Issues filed

| Organization | Issue | Description | Stars |
|-------------|-------|-------------|------:|
| **Anthropic** (filesystem) | [servers#4095](https://github.com/modelcontextprotocol/servers/issues/4095) | 16 required params missing descriptions | 85K |
| **GitHub** | [github-mcp-server#2425](https://github.com/github/github-mcp-server/issues/2425) | 112 schema quality issues (20 errors, 92 warnings) | 19K |
| **Notion** | [notion-mcp-server#280](https://github.com/makenotion/notion-mcp-server/issues/280) | 8 required params undescribed across 22 tools | 4.2K |
| **Bankless** | [onchain-mcp#21](https://github.com/Bankless/onchain-mcp/issues/21) | All 10 tools return -32603 for missing API token | Web3 |
| **Peekaboo** | [Peekaboo#108](https://github.com/steipete/Peekaboo/issues/108) | -32603 for missing Screen Recording permission | **Fixed by Peter Steinberger**, credited mcp-assert |
| **Grafana** | [mcp-grafana#830](https://github.com/grafana/mcp-grafana/issues/830) | 72 fuzz crashes on type mismatches | 2.9K |
| **Anthropic** (MCP Python SDK) | [python-sdk#2564](https://github.com/modelcontextprotocol/python-sdk/issues/2564) | 12 remaining exception chain sites | 23K |
| **Oraios** (Serena) | [serena#1467](https://github.com/oraios/serena/issues/1467) | 9 schema errors, 47 warnings across 29 tools; isError never set for exceptions* | 24K |
| **AWS** (awslabs/mcp) | [awslabs/mcp#3486](https://github.com/awslabs/mcp/issues/3486) | 2,160 schema errors across 43 servers (870 tools); systemic: union types drop `type` field* | AWS |

### Other open PRs

| Organization | PR | Lang | Description | Stars |
|-------------|-----|------|-------------|------:|
| **Grafana** (core) | [grafana#124437-124440](https://github.com/grafana/grafana/pull/124437) | Go/TS | 4 PRs: console.log removal, typeof fix, span.End loop, error propagation | 74K |
| **Vercel** | [ai#14758](https://github.com/vercel/ai/pull/14758) | TS | Send `content: null` for tool-only messages (4 providers) | 24K |
| **sashabaranov** | [go-openai#1104-1106](https://github.com/sashabaranov/go-openai/pull/1104) | Go | 3 PRs: stream field, ContentFilter pointer, MIME detection | 10.6K |
| **Anthropic** (servers) | [servers#4044, #4051](https://github.com/modelcontextprotocol/servers/pull/4044) | TS | blob content type violation + puppeteer crash | 85K |
| **MoonshotAI** | [kimi-cli#2144](https://github.com/MoonshotAI/kimi-cli/pull/2144) | Python | Multiline input text misaligned | 8.3K |
| **Charmbracelet** | [huh#777](https://github.com/charmbracelet/huh/pull/777) | Go | V2 regression: blurred styles not applied | 5.5K |
| **pypa** | [pip#13960](https://github.com/pypa/pip/pull/13960) | Python | locale deprecation fix for Python 3.15 | 10K |
| **Anthropic** (MCP Python SDK) | [python-sdk#2511](https://github.com/modelcontextprotocol/python-sdk/pull/2511) | Python | Custom content support for ToolError | 23K |
| **Anthropic** (MCP TS SDK) | [typescript-sdk#2019](https://github.com/modelcontextprotocol/typescript-sdk/pull/2019) | TS | Check AbortSignal in handleAutomaticTaskPolling | 12K |
| **Tavily** | [tavily-mcp#162](https://github.com/tavily-ai/tavily-mcp/pull/162) | TS | Missing API key throws McpError instead of isError | Open |
| **dvcrn** | [mcp-server-linear#5](https://github.com/dvcrn/mcp-server-linear/pull/5) | TS | 24 tools throw McpError when unauthenticated | Open |
| **sammcj** | [mcp-devtools#258](https://github.com/sammcj/mcp-devtools/pull/258) | TS | Internal error instead of isError for validation | Open |

### Bugs Filed (fixed by others)

| Project | Description | Outcome |
|---------|-------------|---------|
| [blazickjp/arxiv-mcp-server#92](https://github.com/blazickjp/arxiv-mcp-server/issues/92) | `get_abstract` returns error content without `isError` flag | Maintainer fix merged* |

### Pending (ready, blocked on process)

| Project | Description | Blocker |
|---------|-------------|---------|
| [langchain-ai/langchain#36750](https://github.com/langchain-ai/langchain/issues/36750) | PERL separators + `InMemoryCache` eviction fix | Awaiting assignment (LangChain requires label before PR) |
| [cli/cli#12895](https://github.com/cli/cli/issues/12895) | `gh pr status` deduplicates cancelled checks with newer success | Awaiting `help wanted` label |
