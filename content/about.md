---
title: "About"
date: 2025-12-01
draft: false
---

**Dayna Blackwell** builds distributed systems that don't break at 2 AM.

I'm a software architect specializing in event-driven architectures at scale. Currently, I design and operate the global loyalty and promotions platform for a major hospitality brand - the backend services powering rewards programs, digital wallets, and promotional campaigns used by millions of customers worldwide.

My work focuses on making distributed systems predictable: idempotent message handling, content-based deduplication, selective semantic hashing, and observability patterns that make production failures understandable when they happen. The goal is systems where 3 AM pages are rare and debuggable.

The tech stack spans serverless AWS (Lambda, EventBridge, DynamoDB, Glue, Redshift), backend services (Python FastAPI, Java Jakarta EE), and infrastructure-as-code (CDK, Terraform). My career path - from operations leadership through backend architecture - shapes how I think about systems: they have to work for the people maintaining them at 3 AM, not just the people designing them at 3 PM.

Outside the Python/Java enterprise world, I build developer tools and libraries in Go and Rust. My open source work includes unified secret management across multiple vault backends (vaultmux), profile management for Claude Code with automatic context detection (dotclaude), type-safe validation with automatic TypeScript schema generation (domainstack), and structured error handling that works across different web frameworks (error-envelope, err-envelope).

As a polyglot programmer, I approach each language by building strong mental models: understanding why Go treats everything as a value, why Python makes everything an object, why Rust enforces ownership. Each represents a fundamentally different way of thinking about memory, concurrency, and composition. This cross-language perspective shapes how I design systems and choose the right tool for each problem.

As a technical writer (3x AWS Certified, 225,000+ lines of documentation), I've authored **You Don't Know JSON** (127,000 words) and focus on explaining how things actually work: memory models, type systems, serialization formats, system design, software architecture, and the low-level implementation details that determine whether your architecture survives production.

This blog explores developer tools, backend architecture, event-driven systems, performance optimization, data pipelines, and the lessons from building systems that handle real traffic.

## Books

**[You Don't Know JSON](https://leanpub.com/you-dont-know-json)** - A comprehensive guide to JSON's ecosystem: from schema validation to binary formats (MessagePack, CBOR, Protocol Buffers), streaming architectures, security patterns, API design, data pipelines, and testing strategies. Learn when JSON works, when it doesn't, and what to use instead. Available on Leanpub.

## Open Source Projects

### Developer Tools

**[blackdot](https://blackwell-systems.github.io/blackdot/#/)** - Modular development framework with multi-vault secrets, Claude Code integration, extensible hooks, and health checks.

**[dotclaude](https://blackwell-systems.github.io/dotclaude/#/)** - Profile manager for Claude Code. Switch between work/personal contexts, multi-backend routing.

**[gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator)** - Lightweight gRPC emulator for Google Cloud Secret Manager API. Local testing and CI/CD without GCP credentials.

### Libraries

**[domainstack](https://github.com/blackwell-systems/domainstack)** ([Rust crate](https://crates.io/crates/domainstack)) - Full-stack validation ecosystem for Rust: Type-safe validation with automatic TypeScript/Zod schema generation, serde integration, OpenAPI schemas, and web framework adapters (Axum, Actix, Rocket).

**[error-envelope](https://github.com/blackwell-systems/error-envelope)** ([Rust crate](https://crates.io/crates/error-envelope)) - Consistent, traceable, retry-aware HTTP error responses for Rust APIs — no framework required.

**[vaultmux](https://github.com/blackwell-systems/vaultmux)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/vaultmux) | [Rust crate](https://crates.io/crates/vaultmux-rs)) - Unified secret management across Bitwarden, 1Password, and pass. Available in both Go and Rust with interface-first design and 95%+ test coverage.

**[err-envelope](https://github.com/blackwell-systems/err-envelope)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/err-envelope)) - Structured HTTP error responses for Go. Works with net/http, Chi, Gin, and Echo. Machine-readable codes, field validation, trace IDs.

### Utilities

**[mdfx](https://github.com/blackwell-systems/mdfx)** - Make your GitHub README stand out — tech badges (like shields.io, but better), progress bars, gauges, and Unicode text effects. Local and customizable.

**[pipeboard](https://blackwell-systems.github.io/pipeboard/#/)** - Secure clipboard sharing over SSH tunnels. Share text between machines without exposing ports or using third-party services.

## Contact

- GitHub: [@blackwell-systems](https://github.com/blackwell-systems)
- Issues: [blackdot](https://github.com/blackwell-systems/blackdot/issues) | [dotclaude](https://github.com/blackwell-systems/dotclaude/issues) | [gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator/issues) | [domainstack](https://github.com/blackwell-systems/domainstack/issues) | [error-envelope](https://github.com/blackwell-systems/error-envelope/issues) | [vaultmux](https://github.com/blackwell-systems/vaultmux/issues) | [err-envelope](https://github.com/blackwell-systems/err-envelope/issues) | [mdfx](https://github.com/blackwell-systems/mdfx/issues) | [pipeboard](https://github.com/blackwell-systems/pipeboard/issues)
