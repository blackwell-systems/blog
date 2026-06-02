---
title: "Consulting Services"
date: 2026-01-26
draft: false
showMetadata: false
---

I build production systems: AI agents, code intelligence, cloud infrastructure, backend services, and developer tooling. 25+ open source projects, 35,000+ monthly downloads, 4 published research papers with DOIs.

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
- Agentic development methodology training

### What I've Built

- **[knowing](https://github.com/blackwell-systems/knowing):** Content-addressed code intelligence engine (94K LOC). 28 MCP tools, 8 resources, 23 extractors spanning 26 languages/formats. P@10=0.278 across 308 tasks, 16 repos, 8 languages (3.2x codegraph, 5.05x GitNexus, 5.35x Gortex, 12.1x Aider, 18.5x grep). 12 self-adapting retrieval mechanisms. Supply chain detection without executing code (1.0% FP rate). OpenTelemetry runtime trace ingestion. Community detection with Merkle roots. GCF wire format (84% fewer tokens than JSON, 47% tool call reduction). Published whitepaper with DOI
- **[polywave](https://github.com/blackwell-systems/polywave):** Formally specified multi-agent coordination protocol (6 invariants, 48 execution rules, 7 participant roles). 4-5x measured speedup. knowing was built using polywave. Go SDK: 33 packages, 75+ CLI commands, 4 LLM backends, autonomous daemon mode. Listed on ComposioHQ/awesome-codex-skills (10.6K stars)
- **[polywave-web](https://github.com/blackwell-systems/polywave-web):** Full-stack orchestration platform for parallel Claude agents. Go backend (40+ REST endpoints, real-time SSE streaming), React frontend (live wave dashboard, interactive dependency graphs), single binary deployment
- **[claudewatch](https://github.com/blackwell-systems/claudewatch):** 32-tool MCP server for AI development observability. PostToolUse hooks, session analytics, CLAUDE.md effectiveness scoring, friction pattern classification
- **[mcp-assert](https://github.com/blackwell-systems/mcp-assert):** Deterministic MCP server testing. 28,000+ downloads across 6 distribution channels. 102 servers scanned, 34 upstream bugs found. Adopted as CI standard by Ant Group (antvis) and wyre-technology (25+ repos). Fix PRs merged into Grafana and LangChain
- **[agent-lsp](https://github.com/blackwell-systems/agent-lsp):** Stateful MCP server runtime over real language servers. 66 tools, 24 Agent Skills, speculative execution engine, 30 CI-verified languages. 5,500+ monthly downloads. Listed on official MCP Registry, Glama (A-tier), awesome-mcp-servers
- **[ai-cold-start-audit](https://github.com/blackwell-systems/ai-cold-start-audit):** UX audit methodology using Claude agents as surrogate new users in containerized sandboxes
- **[commitmux](https://github.com/blackwell-systems/commitmux):** Cross-repository semantic search engine with MCP server (Rust, sqlite-vec, FTS5)
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
- Ecommerce backends (Shopify apps, payment integrations, subscription billing)

### What I've Built

- **[FDA Compliance Guard](https://blog.blackwell-systems.com):** Production Shopify app with Rust semantic engine (9,967 disease-claim patterns, 8 NLP subsystems), validated against 17 FDA warning letters with 0.5% false positive rate. React/TypeScript frontend, PostgreSQL, three-tier subscription billing
- **[agentic-workflows](https://github.com/blackwell-systems):** Composable multi-agent workflow system with data contract-based integration enabling deterministic handoffs between AI agents

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

- 5+ years of experience in revenue-critical backend systems serving millions of members across 120 countries
- Built real-time CDC pipeline replacing full-table-scan approach, processing in ~1.3 minutes regardless of dataset size
- GCP emulator ecosystem (Secret Manager, IAM, KMS, Eventarc) with 45K+ downloads and confirmed enterprise adoption by Flipt (4.8K stars), Reindeer AI, and sugar-org/swarm-external-secrets
- Designed serverless event-driven promotion system (Lambda, EventBridge, DynamoDB, Redis)
- AWS (Solutions Architect, Developer, AI Practitioner), Azure, Terraform, Oracle certified

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

### Experience Highlights

- Backend developer for global loyalty platform serving millions of members, core infrastructure consumed by nearly every engineering team in the company
- Architected Digital Wallet backend (5 currencies, payment gateway integration, distributed caching)
- Built serverless promotion rules engine with plugin-style extensibility
- Diagnosed and eliminated database connection exhaustion causing production outages (60% connection reduction)
- 4 published research papers with DOIs: [code intelligence](https://doi.org/10.5281/zenodo.20342255), [memory management](https://doi.org/10.5281/zenodo.18653776), and [distributed systems convergence](https://doi.org/10.5281/zenodo.18677400) (2 papers)

---

## CLI Tools & Developer Experience

**Specialization:** Production-quality CLI tools in Go and Rust. Interactive TUIs, multi-channel distribution, cross-platform deployment.

### Services Offered

- CLI tool design and implementation (Go, Rust)
- Interactive TUI development (Bubble Tea)
- Multi-channel distribution engineering (Homebrew, npm, PyPI, Docker, Winget, Snap)
- MCP server development for AI tool integration
- Developer workflow automation
- Cross-platform deployment (single binary, go:embed, Wails)

### What I've Built

- **[shelfctl](https://github.com/blackwell-systems/shelfctl):** Feature-complete Go TUI with Bubble Tea, Homebrew distribution, shipped in 4 days
- **[brewprune](https://github.com/blackwell-systems/brewprune):** Homebrew package cleanup with FSEvents monitoring and confidence scoring
- **[goldenthread](https://github.com/blackwell-systems/goldenthread):** Schema compiler generating TypeScript/Zod from Go struct tags
- **[vaultmux](https://github.com/blackwell-systems/vaultmux):** Vendor-agnostic secret management across AWS, GCP, Azure, 1Password, Bitwarden
- **[domainstack](https://crates.io/crates/domainstack):** Full-stack validation ecosystem in Rust (9 crates on crates.io)
- **5 reusable [Bubble Tea components](https://github.com/blackwell-systems):** carousel, command palette, Miller columns, multiselect, picker

---

## Engagement Models

### Claude / AI Integration Sprint
**Duration:** 1-4 weeks
**Deliverable:** MCP server, Claude Code skills/hooks, or LLM integration, scoped, built, and deployed

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

## Contact

**Ready to discuss your project?**

- **Email:** dayna@blackwell-systems.com
- **LinkedIn:** [linkedin.com/in/dayna-blackwell](https://linkedin.com/in/dayna-blackwell)
- **GitHub:** [@blackwell-systems](https://github.com/blackwell-systems)

**Response time:** Within 24-48 hours for all inquiries.

[View full open source portfolio →](/oss/)
