---
title: "Open Source Software"
date: 2026-01-29
draft: false
showMetadata: false
---

## Open Source Projects

### Cloud Infrastructure

**[vaultmux-server](https://github.com/blackwell-systems/vaultmux-server)** - Language-agnostic secrets control plane for Kubernetes. HTTP REST API enabling polyglot teams (Python, Node.js, Go, Rust) to fetch secrets from AWS, GCP, or Azure without SDK dependencies. Deploy as sidecar or cluster service.

**GCP Emulator Ecosystem** - Hermetic local emulation stack for Google Cloud Platform services.

- **[gcp-iam-emulator](https://github.com/blackwell-systems/gcp-iam-emulator)** - Deterministic IAM policy engine that evaluates authorization decisions (ALLOW/DENY) based on explicit policy definitions. Acts as the control plane for all Blackwell emulators via policy.yaml. Emits machine-readable authorization traces for analysis and policy refinement with gcp-emulator-pro.
- **[gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator)** - Local Secret Manager emulator with dual gRPC + REST APIs. Integrates with [gcp-iam-emulator](https://github.com/blackwell-systems/gcp-iam-emulator) for pre-flight authorization enforcement and trace generation. Designed for deterministic local development and CI/CD testing workflows.
- **[gcp-kms-emulator](https://github.com/blackwell-systems/gcp-kms-emulator)** - Key Management Service emulator with real cryptographic operations using local key material. Integrated with [gcp-iam-emulator](https://github.com/blackwell-systems/gcp-iam-emulator) for permission enforcement on encrypt/decrypt and key-management operations. Supports key versioning, rotation, and destruction with trace output.
- **[gcp-iam-control-plane](https://github.com/blackwell-systems/gcp-iam-control-plane)** - Unified orchestration CLI for the Blackwell GCP emulator ecosystem. A single policy.yaml drives IAM enforcement across Secret Manager, KMS, and future emulators. Start and stop services, manage policies, inspect authorization traces, and test principal-based access control locally and in CI.

{{< callout type="success" >}}
**Why This Architecture Exists**

Google Cloud provides service emulators, but local IAM enforcement is not part of the standard emulator workflow. Blackwell fills this gap by enabling hermetic, deterministic authorization testing — no cloud credentials, no network calls, no propagation delays.
{{< /callout >}}

**[gcp-emulator-pro](https://blackwell-systems.github.io/blog/products/)** (Commercial) - Post-execution analysis for emulator trace artifacts. Consumes authorization traces to generate least-privilege IAM policies, compliance reports, and drift detection. Coming soon.

**[vaultmux](https://github.com/blackwell-systems/vaultmux)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/vaultmux)) | **[vaultmux-rs](https://github.com/blackwell-systems/vaultmux-rs)** ([Rust crate](https://crates.io/crates/vaultmux)) - Unified secret management across Bitwarden, 1Password, pass, AWS, GCP, Azure. Write once, support 7+ backends. Available in Go and Rust.

### Developer Tools

**[blackdot](https://blackwell-systems.github.io/blackdot/#/)** - Modular development framework with multi-vault secrets, Claude Code integration, extensible hooks, and health checks.

**[dotclaude](https://blackwell-systems.github.io/dotclaude/#/)** - Profile manager for Claude Code. Switch between work/personal contexts, multi-backend routing.

### Libraries

**[goldenthread](https://github.com/blackwell-systems/goldenthread)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/goldenthread)) - Build-time schema compiler generating TypeScript Zod schemas from Go struct tags. Single source of truth for validation with automatic drift detection in CI.

**[domainstack](https://github.com/blackwell-systems/domainstack)** ([Rust crate](https://crates.io/crates/domainstack)) - Full-stack validation ecosystem for Rust: Type-safe validation with automatic TypeScript/Zod schema generation, serde integration, OpenAPI schemas, and web framework adapters (Axum, Actix, Rocket).

**[error-envelope](https://github.com/blackwell-systems/error-envelope)** ([Rust crate](https://crates.io/crates/error-envelope)) - Consistent, traceable, retry-aware HTTP error responses for Rust APIs - no framework required.

**[vaultmux](https://github.com/blackwell-systems/vaultmux)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/vaultmux)) | **[vaultmux-rs](https://github.com/blackwell-systems/vaultmux-rs)** ([Rust crate](https://crates.io/crates/vaultmux)) - Unified secret management library across Bitwarden, 1Password, pass, AWS, GCP, Azure. Available in Go and Rust with 95%+ test coverage. Powers vaultmux-server.

**[err-envelope](https://github.com/blackwell-systems/err-envelope)** ([Go pkg](https://pkg.go.dev/github.com/blackwell-systems/err-envelope)) - Structured HTTP error responses for Go. Works with net/http, Chi, Gin, and Echo. Machine-readable codes, field validation, trace IDs.

### Utilities

**[mdfx](https://github.com/blackwell-systems/mdfx)** - Make your GitHub README stand out — tech badges (like shields.io, but better), progress bars, gauges, and Unicode text effects. Local and customizable.

**[pipeboard](https://blackwell-systems.github.io/pipeboard/#/)** - Secure clipboard sharing over SSH tunnels. Share text between machines without exposing ports or using third-party services.
