---
title: "Open Source Software"
date: 2026-01-29
draft: false
showMetadata: false
---

## Open Source Projects

### Cloud Infrastructure

**[vaultmux-server](https://github.com/blackwell-systems/vaultmux-server)** - Language-agnostic secrets control plane for Kubernetes. HTTP REST API enabling polyglot teams (Python, Node.js, Go, Rust) to fetch secrets from AWS, GCP, or Azure without SDK dependencies. Deploy as sidecar or cluster service.

**[GCP Emulator Ecosystem](https://github.com/blackwell-systems?q=gcp)** - Complete local emulation stack for Google Cloud Platform:
- **[gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator)** - The de facto standard Secret Manager emulator (dual gRPC + REST, 11/12 methods, 90.8% test coverage, enterprise adoption)
- **[gcp-iam-emulator](https://github.com/blackwell-systems/gcp-iam-emulator)** - IAM policy enforcement for permission testing
- **[gcp-kms-emulator](https://github.com/blackwell-systems/gcp-kms-emulator)** - Key Management Service with real cryptographic operations
- **[gcp-emulator-control-plane](https://github.com/blackwell-systems/gcp-emulator-control-plane)** - CLI tool and orchestration layer for the complete GCP emulator ecosystem. Single `policy.yaml` drives IAM enforcement across all emulators. Start/stop services, manage policies, view logs, and test principal-based authorization locally and in CI

Fills gaps Google left unfilled - enables hermetic testing and CI/CD without GCP credentials.

**[gcp-emulator-pro](https://blackwell-systems.github.io/blog/products/)** (Commercial) - Post-execution analysis for emulator trace artifacts. Consumes authorization traces and generates least-privilege IAM policies, compliance reports, and drift detection. Coming soon.

**[vaultmux](https://github.com/blackwell-systems/vaultmux)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/vaultmux) | [Rust crate](https://crates.io/crates/vaultmux-rs)) - Unified secret management across Bitwarden, 1Password, pass, AWS, GCP, Azure. Write once, support 7+ backends. Available in Go and Rust.

### Developer Tools

**[blackdot](https://blackwell-systems.github.io/blackdot/#/)** - Modular development framework with multi-vault secrets, Claude Code integration, extensible hooks, and health checks.

**[dotclaude](https://blackwell-systems.github.io/dotclaude/#/)** - Profile manager for Claude Code. Switch between work/personal contexts, multi-backend routing.

### Libraries

**[goldenthread](https://github.com/blackwell-systems/goldenthread)** - Build-time schema compiler generating TypeScript Zod schemas from Go struct tags. Single source of truth for validation with automatic drift detection in CI.

**[domainstack](https://github.com/blackwell-systems/domainstack)** ([Rust crate](https://crates.io/crates/domainstack)) - Full-stack validation ecosystem for Rust: Type-safe validation with automatic TypeScript/Zod schema generation, serde integration, OpenAPI schemas, and web framework adapters (Axum, Actix, Rocket).

**[error-envelope](https://github.com/blackwell-systems/error-envelope)** ([Rust crate](https://crates.io/crates/error-envelope)) - Consistent, traceable, retry-aware HTTP error responses for Rust APIs - no framework required.

**[vaultmux](https://github.com/blackwell-systems/vaultmux)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/vaultmux) | [Rust crate](https://crates.io/crates/vaultmux-rs)) - Unified secret management library across Bitwarden, 1Password, pass, AWS, GCP, Azure. Available in Go and Rust with 95%+ test coverage. Powers vaultmux-server.

**[err-envelope](https://github.com/blackwell-systems/err-envelope)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/err-envelope)) - Structured HTTP error responses for Go. Works with net/http, Chi, Gin, and Echo. Machine-readable codes, field validation, trace IDs.

### Utilities

**[mdfx](https://github.com/blackwell-systems/mdfx)** - Make your GitHub README stand out — tech badges (like shields.io, but better), progress bars, gauges, and Unicode text effects. Local and customizable.

**[pipeboard](https://blackwell-systems.github.io/pipeboard/#/)** - Secure clipboard sharing over SSH tunnels. Share text between machines without exposing ports or using third-party services.
