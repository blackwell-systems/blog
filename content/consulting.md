---
title: "Consulting Services"
date: 2026-01-26
draft: false
showMetadata: false
---

<!-- meta:author=Dayna Blackwell -->
<!-- meta:topic=claude,ai-agents,cloud-architecture,backend,cli-tools -->
<!-- meta:last-updated=2026-03-22 -->

I build production systems — AI agents, cloud infrastructure, backend services, and developer tooling. Not prototypes. Systems that run in production and handle real traffic.

---

## Claude Code & Anthropic Platform

**Specialization:** Deep expertise in Claude Code extensibility, Anthropic API integration, and Claude-based agent orchestration. I build the infrastructure that makes Claude useful in production, not just in demos.

### Services Offered

#### Claude Code Extensibility
- Custom subagent types with domain-specific tooling, permission sets, and behavioral constraints
- Skills development for workflow automation (release engineering, audits, code generation)
- PostToolUse / SessionStart hook systems for real-time monitoring and behavioral enforcement
- CLAUDE.md behavioral contracts for persistent project-level guidance
- Claude Code profile management and multi-backend routing

#### Claude API & Bedrock Integration
- Anthropic API integration into existing backends (direct API and AWS Bedrock)
- Structured JSON output schemas with multi-rule validation pipelines
- AI output validation: fuzzy matching, deduplication, schema enforcement, hallucination prevention
- Context-augmented generation with parallel web search and faceted content extraction
- Token optimization and cost management strategies

#### Claude Agent Orchestration
- Multi-agent coordination protocol design (parallel execution, conflict prevention)
- MCP (Model Context Protocol) server development
- Agent observability, analytics, and performance monitoring
- Multi-backend model routing (Anthropic, OpenAI, Ollama/local models)

#### Team Adoption & Training
- Claude Code rollout strategy for engineering organizations
- Workshop facilitation on AI-assisted development workflows
- Best practices documentation and internal knowledge sharing
- Agentic development methodology training

### What I've Built

- **[scout-and-wave](https://github.com/blackwell-systems/scout-and-wave):** Formally specified multi-agent coordination protocol for Claude Code (6 invariants, 37+ execution rules) validated across 16+ production repositories with 4-5x measured speedup. Published specification with state machine, message formats, and conformance criteria
- **[scout-and-wave-web](https://github.com/blackwell-systems/scout-and-wave-web):** Full-stack orchestration platform for parallel Claude agents — Go backend (40+ REST endpoints, real-time SSE streaming), React frontend (live wave dashboard, interactive dependency graphs, streaming agent output), single binary deployment
- **[claudewatch](https://github.com/blackwell-systems/claudewatch):** Self-improving observability platform for Claude Code — 22-tool MCP server for live session metrics, PostToolUse hooks alerting on error loops and cost spikes, CLAUDE.md effectiveness scoring with before/after comparison, multi-agent workflow analytics
- **[ai-cold-start-audit](https://github.com/blackwell-systems/ai-cold-start-audit):** UX audit methodology using Claude agents as surrogate new users in containerized sandboxes, producing severity-tiered findings reports
- **[commitmux](https://github.com/blackwell-systems/commitmux):** Cross-repository semantic search engine with MCP server — in-process vector search (sqlite-vec), FTS5 full-text indexing, 6 read-only MCP tools over stdio JSON-RPC
- **Led Claude Code adoption at Best Western** as founding member of the Agentic Development Group, driving enterprise-wide rollout of AI-enhanced engineering workflows

### Ideal For

- Teams adopting Claude Code for engineering workflows
- Companies integrating Claude API into existing products
- Organizations building MCP servers or Claude-based tooling
- Engineering leaders evaluating agentic development practices

---

## AI & Agent Systems

**Specialization:** Production LLM systems, multi-agent architectures, and AI-assisted development infrastructure beyond Claude-specific work.

### Services Offered

- Multi-agent workflow design with deterministic handoffs and data contracts
- RAG pipelines with source verification and grounding
- Prompt engineering with structured output parsing and validation
- AI-driven automation (release engineering, UX audits, code review)
- LLM output validation: Jaccard similarity, fuzzy matching, schema enforcement
- Agentic workflow composition (audit-fix-verify, release-publish patterns)

### What I've Built

- **[FDA Compliance Guard](https://blog.blackwell-systems.com):** Production Shopify app with Rust semantic engine (9,967 disease-claim patterns, 8 NLP subsystems), validated against 17 FDA warning letters with 0.5% false positive rate. React/TypeScript frontend, PostgreSQL, subscription billing
- **[agentic-workflows](https://github.com/blackwell-systems):** Composable multi-agent workflow system with data contract-based integration enabling deterministic handoffs between AI agents despite natural language interfaces
- **[rezmakr](https://github.com/blackwell-systems):** AI-powered resume tailoring tool with weighted bullet validation, deterministic quality gates, and hash-based deduplication

### Ideal For

- Startups building AI-powered products
- Teams needing reliable, validated AI output in production
- Companies automating workflows with agent-based systems

---

## Cloud Infrastructure

**Specialization:** Cloud-native architecture across AWS, GCP, and Azure. Event-driven systems, serverless, data pipelines, and infrastructure-as-code.

### Services Offered

- Event-driven architecture (SNS, SQS, EventBridge pipelines)
- Serverless systems (Lambda, Step Functions, DynamoDB)
- Data pipeline design (CDC, ETL, real-time streaming)
- Infrastructure-as-code (Terraform, CDK)
- Database architecture (DynamoDB single-table design, Redshift, PostgreSQL, Oracle)
- GCP service emulation and local development environments
- Legacy modernization to cloud-native patterns
- Cost optimization strategies
- Multi-cloud architecture (AWS, GCP, Azure)

### Experience Highlights

- 5 years operating revenue-critical backend systems serving millions of members across 100+ countries
- Built real-time CDC pipeline replacing full-table-scan approach, processing in ~1.3 minutes regardless of dataset size
- GCP emulator ecosystem (Secret Manager, IAM, KMS) with 13,000+ downloads and confirmed enterprise adoption
- Designed serverless event-driven promotion system (Lambda, EventBridge, DynamoDB, Redis)
- 3x AWS Certified, Azure, Terraform, Oracle certified

### Ideal For

- Teams migrating to cloud-native architectures
- Engineering leaders scaling distributed systems
- Companies needing hermetic CI/CD testing strategies
- Organizations improving system reliability and observability

---

## Backend Engineering

**Specialization:** Production backend systems in Go, Python, and Java. REST APIs, event-driven architectures, and data pipelines at enterprise scale.

### Services Offered

- REST API design and implementation (Go, Python, Java)
- Event-driven pipeline architecture
- Database design and optimization (SQL, NoSQL, data warehousing)
- Real-time data processing (CDC, streaming, caching)
- Production reliability (idempotency, circuit breakers, graceful degradation)
- Performance optimization and incident response
- Ecommerce backends (Shopify apps, payment integrations, subscription billing)

### Experience Highlights

- Backend developer for global loyalty platform — core infrastructure consumed by nearly every engineering team in the company
- Architected Digital Wallet backend (5 currencies, payment gateway integration, distributed caching)
- Built serverless promotion rules engine with plugin-style extensibility
- Diagnosed and eliminated database connection exhaustion causing production outages (60% connection reduction with HikariCP)
- Published researcher: 2 peer-reviewed papers with DOIs on [memory management](https://doi.org/10.5281/zenodo.18653776) and [distributed systems convergence](https://doi.org/10.5281/zenodo.18677400)

---

## CLI Tools & Developer Experience

**Specialization:** Production-quality CLI tools in Go and Rust. Interactive TUIs, Homebrew distribution, cross-platform deployment.

### Services Offered

- CLI tool design and implementation (Go, Rust)
- Interactive TUI development (Bubble Tea)
- Homebrew tap creation and distribution
- MCP server development for AI tool integration
- Developer workflow automation
- Cross-platform deployment (single binary, go:embed, Wails)

### What I've Built

- **[shelfctl](https://github.com/blackwell-systems/shelfctl):** Feature-complete Go TUI with Bubble Tea, Homebrew distribution, shipped in 4 days
- **[brewprune](https://github.com/blackwell-systems/brewprune):** Homebrew package cleanup with FSEvents monitoring and confidence scoring
- **[goldenthread](https://github.com/blackwell-systems/goldenthread):** Schema compiler generating TypeScript/Zod from Go struct tags
- **[vaultmux](https://github.com/blackwell-systems/vaultmux):** Vendor-agnostic secret management across AWS, GCP, Azure, 1Password, Bitwarden
- **[domainstack](https://crates.io/crates/domainstack):** Full-stack validation ecosystem in Rust (9 crates on crates.io)
- **[pipeboard](https://github.com/blackwell-systems/pipeboard):** Secure clipboard sharing over SSH tunnels
- **5 reusable [Bubble Tea components](https://github.com/blackwell-systems):** carousel, command palette, Miller columns, multiselect, picker

---

## Engagement Models

### Claude / AI Integration Sprint
**Duration:** 1-4 weeks
**Deliverable:** MCP server, Claude Code skills/hooks, or LLM integration — scoped, built, and deployed

### Architecture Review
**Duration:** 1-2 weeks
**Deliverable:** Comprehensive architecture assessment with recommendations

### Implementation Consulting
**Duration:** Ongoing (hourly or retainer)
**Deliverable:** Hands-on architecture guidance, code review, and implementation

### Team Workshops
**Duration:** Half-day or full-day sessions
**Topics:** Claude Code adoption, AI-assisted development, distributed systems patterns

---

## Speaking & Content

Available for:
- **Conference talks** on AI agent orchestration, Claude Code, distributed systems, cloud architecture
- **Podcast interviews** on agentic development, multi-agent systems, developer productivity
- **Corporate workshops** on Claude Code adoption and AI-assisted development workflows
- **Book talks** on [You Don't Know JSON](https://leanpub.com/you-dont-know-json) (107,000 words)

---

## Contact

**Ready to discuss your project?**

- **Email:** dayna@blackwell-systems.com
- **LinkedIn:** [linkedin.com/in/dayna-blackwell](https://linkedin.com/in/dayna-blackwell)
- **GitHub:** [@blackwell-systems](https://github.com/blackwell-systems)
- **Blog:** [blog.blackwell-systems.com](https://blog.blackwell-systems.com)

**Response time:** Within 24-48 hours for all inquiries.

---

## Open Source Portfolio

16+ production projects. All consulting work is informed by real production experience.

- [scout-and-wave-web](https://github.com/blackwell-systems/scout-and-wave-web) - Full-stack AI agent orchestration platform (Go/React)
- [scout-and-wave](https://github.com/blackwell-systems/scout-and-wave) - Multi-agent coordination protocol (formal specification)
- [claudewatch](https://github.com/blackwell-systems/claudewatch) - Claude Code observability platform (22-tool MCP server)
- [commitmux](https://github.com/blackwell-systems/commitmux) - Cross-repository semantic search (Rust, MCP server)
- [gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator) - GCP emulator (13,000+ downloads)
- [goldenthread](https://github.com/blackwell-systems/goldenthread) - Schema compiler (Go → TypeScript Zod)
- [vaultmux](https://github.com/blackwell-systems/vaultmux) - Unified secret management (7+ backends)
- [domainstack](https://crates.io/crates/domainstack) - Full-stack validation (Rust, 9 crates)
- [shelfctl](https://github.com/blackwell-systems/shelfctl) - Document storage CLI (Go, Bubble Tea TUI)
- [brewprune](https://github.com/blackwell-systems/brewprune) - Homebrew package cleanup (Go, FSEvents)

[View all projects →](/oss/)
