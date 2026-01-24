---
title: "About"
date: 2025-12-01
draft: false
---

**Dayna Blackwell** builds reliable distributed systems at scale.

I'm a software architect specializing in event-driven architectures at scale. Currently, I design and operate the global loyalty and promotions platform for a major hospitality brand - the backend services powering rewards programs, digital wallets, and promotional campaigns used by millions of customers worldwide.

My work focuses on making distributed systems predictable: idempotent message handling, content-based deduplication, selective semantic hashing, and observability patterns that make production failures understandable when they happen. The goal is systems where 3 AM pages are rare and debuggable.

The tech stack spans serverless AWS (Lambda, EventBridge, DynamoDB, Glue, Redshift), backend services (Python FastAPI, Java Jakarta EE), and infrastructure-as-code (CDK, Terraform). My career path - from operations leadership through backend architecture - shapes how I think about systems: they have to work for the people maintaining them at 3 AM, not just the people designing them at 3 PM.

---

## What I Write About

This blog provides comprehensive technical deep-dives into programming language fundamentals and distributed systems architecture. I write to build strong mental models - the kind you can't get from framework documentation or tutorials. When you understand *why* Go chose value semantics, or *why* multicore CPUs exposed OOP's flaws, you're not just learning syntax - you're understanding fundamental tradeoffs that apply across all languages and systems.

**Language Design & Mental Models:**
- Value semantics vs reference semantics (Go, Rust vs Python, Java)
- Why modern languages moved away from OOP patterns
- Memory models, concurrency primitives, and performance implications
- Cache locality, stack vs heap, escape analysis
- Building strong mental models through polyglot comparison

**Distributed Systems:**
- Event-driven architectures at scale
- Idempotent message handling and deduplication patterns
- Observability and debugging production failures
- Serverless patterns and AWS architecture
- API design (REST, GraphQL, WebSocket, gRPC)

**Developer Tools:**
- Claude Code workflows and AI-assisted development
- Secret management and security patterns
- Structured error handling across frameworks
- Open source library design

These articles are the ones I wish existed when I was learning: comprehensive (5,000+ words is common), visual (Mermaid diagrams throughout), and focused on the "why" rather than the "how."

---

## Recent Articles

- **[How Multicore CPUs Killed Object-Oriented Programming](/posts/multicore-killed-oop/)** - Why the 2005 hardware shift exposed OOP's fatal flaw: shared mutable state through references became catastrophic for concurrency
- **[Go's Value Philosophy Series](/series/go-value-philosophy/)** - Deep dive into why Go treats everything as a value, not an object, and how this enables safe concurrency
- **[Python Object Overhead](/posts/python-object-overhead/)** - Why a simple integer uses 28 bytes in Python, and what this means for performance
- **[API Communication Patterns Guide](/posts/api-communication-patterns-guide/)** - REST, GraphQL, WebSocket, gRPC comparison with decision frameworks and real-world examples

---

## Polyglot Programming Philosophy

As a polyglot programmer (Python, Java, Go, Rust), I approach each language by building strong mental models: understanding why Go treats everything as a value, why Python makes everything an object, why Rust enforces ownership. Polyglot programming forces you to confront the underlying implementations and low-level details of each language - when something you're used to "just working" in one language completely breaks in another, you can't stay at the surface level anymore.

Each language represents a fundamentally different way of thinking about memory, concurrency, and composition. This cross-language perspective shapes how I design systems and choose the right tool for each problem. Seeing the same concept across multiple languages reveals the tradeoffs behind each design decision - from memory models and type systems to the low-level implementation details that determine whether your architecture survives production.

---

## Open Source & Technical Writing

Outside the Python/Java enterprise world, I build developer tools and libraries in Go and Rust. My open source work includes unified secret management across multiple vault backends (vaultmux), profile management for Claude Code with automatic context detection (dotclaude), type-safe validation with automatic TypeScript schema generation (domainstack), and structured error handling that works across different web frameworks (error-envelope, err-envelope).

As a technical writer (3x AWS Certified, 225,000+ lines of documentation), I've authored **You Don't Know JSON** (127,000 words) - a comprehensive guide to JSON's ecosystem: from schema validation to binary formats (MessagePack, CBOR, Protocol Buffers), streaming architectures, security patterns, API design, data pipelines, and testing strategies. Learn when JSON works, when it doesn't, and what to use instead.

---

## Books

**[You Don't Know JSON](https://leanpub.com/you-dont-know-json)** - A comprehensive guide to JSON's ecosystem: from schema validation to binary formats (MessagePack, CBOR, Protocol Buffers), streaming architectures, security patterns, API design, data pipelines, and testing strategies. Learn when JSON works, when it doesn't, and what to use instead. Available on Leanpub.

---

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

---

## Contact

I'm available for contract work, consulting, speaking engagements, and podcast interviews. I specialize in distributed systems architecture, event-driven patterns, serverless AWS, API design, language design trade-offs, developer tooling, and JSON ecosystem architecture (author of *You Don't Know JSON*).

**Reach out for:**
- Contract development work on distributed systems, event-driven architectures, or AWS serverless platforms
- Architecture consulting and technical advisory
- Technical speaking engagements (conferences, meetups, corporate events)
- Podcast interviews on systems design, language design, developer productivity, or JSON/API architecture
- Book talks and workshops on *You Don't Know JSON*
- Open source collaboration and sponsorship inquiries

**Contact:**
- Email: dayna@blackwell-systems.com
- GitHub: [@blackwell-systems](https://github.com/blackwell-systems)
- Project issues: [blackdot](https://github.com/blackwell-systems/blackdot/issues) | [dotclaude](https://github.com/blackwell-systems/dotclaude/issues) | [gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator/issues) | [domainstack](https://github.com/blackwell-systems/domainstack/issues) | [error-envelope](https://github.com/blackwell-systems/error-envelope/issues) | [vaultmux](https://github.com/blackwell-systems/vaultmux/issues) | [err-envelope](https://github.com/blackwell-systems/err-envelope/issues) | [mdfx](https://github.com/blackwell-systems/mdfx/issues) | [pipeboard](https://github.com/blackwell-systems/pipeboard/issues)
