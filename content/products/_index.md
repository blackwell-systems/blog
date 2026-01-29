---
title: "Products"
description: "Open-source execution layer and commercial intelligence tools"
showMetadata: false
---

## Blackwell GCP Emulator Ecosystem

A two-layer architecture for hermetic cloud testing: open-source emulators that execute reality, and commercial analysis tools that explain it.

---

## Blackwell GCP Emulators (Open Source)

**Hermetic, production-like local testing for GCP services - including optional IAM enforcement so permission bugs fail in CI, not prod.**

Unlike standard emulators that allow everything, Blackwell can enforce real IAM policies locally so tests fail like production would. **This closes the hermetic seal:** your tests run fully offline, with deterministic behavior, and real authorization enforcement.

### Key Features

- **Run fully offline** - No GCP credentials needed
- **Hermetic Seal** - Optional pre-flight IAM enforcement (Off / Permissive / Strict modes)
- **Protocol support** - gRPC + REST/HTTP where relevant
- **Deterministic** - Same inputs produce same outputs, always
- **Production-like failures** - Permission denied locally means permission denied in prod

### The Security Paradox

Most emulators bypass authorization entirely. Tests pass locally, then fail in production when IAM rejects the request. Blackwell solves this by making IAM enforcement optional but available - so you can test permissions as rigorously as you test logic.

### Available Emulators

- **[gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator)** - Secret Manager with optional IAM enforcement
- **[gcp-kms-emulator](https://github.com/blackwell-systems/gcp-kms-emulator)** - Cloud KMS with cryptographic operations and IAM
- **gcp-iam-emulator** (control plane) - Authorization decisions and trace emission

[View Documentation](https://github.com/blackwell-systems) · [GitHub Organization](https://github.com/blackwell-systems)

---

## gcp-emulator-pro (Commercial)

**Post-execution analysis for emulator trace artifacts. Turns what happened into actionable security artifacts.**

gcp-emulator-pro is the intelligence layer. It consumes authorization traces produced during test execution and performs offline analysis - generating policies, detecting drift, and providing audit evidence.

### Key Features

- **Offline + deterministic** - No cloud calls, works in air-gapped CI
- **Least-privilege policy generation (v1.0)** - Minimal IAM policies from observed behavior
- **Post-execution only** - Never participates in runtime decisions
- **File-based** - Consumes trace artifacts, produces reviewable outputs

### Planned Analysis Capabilities

- Trace summarization
- Authorization coverage analysis
- Drift detection between test runs
- Compliance and audit reports

### Architecture Fit

| Layer | Role | License |
|-------|------|---------|
| **Data Plane** | GCP service emulation | Open Source |
| **Control Plane** | Authorization decisions & trace emission | Open Source |
| **Intelligence Plane** | Post-execution analysis & insight | **Commercial** |

> Anything that participates in execution must be open source.  
> Anything that interprets artifacts after execution may be commercial.

[Learn More](/products/gcp-emulator-pro/) · [Request Trial](#)

---

## Why This Architecture?

The execution boundary creates a clean trust model:

- **OSS emulators** run your tests, make authorization decisions, emit traces. They're trusted, transparent, and required for execution.
- **gcp-emulator-pro** analyzes traces after execution completes. It's optional, offline, and never affects runtime behavior.

This separation preserves trust: you can audit the OSS platform and verify it doesn't depend on proprietary code. The commercial layer is purely analytical.

[Read: The Execution Boundary](/posts/productization-execution-boundary/)

---

**Blackwell Systems**  
Builders of open, trustworthy infrastructure tooling.
