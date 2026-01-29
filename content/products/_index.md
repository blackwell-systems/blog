---
title: "Products"
description: "Hermetic cloud testing, end to end"
showMetadata: false
---

## Blackwell GCP Emulator Ecosystem

**Hermetic cloud testing, end to end.**  
Open-source emulators that execute reality, plus commercial tools that explain it.

Blackwell Systems provides a clean, two-layer architecture for production-accurate GCP testing - fully offline, deterministic, and auditable.

---

## Blackwell GCP Emulators (Open Source)

**Hermetic, production-like local testing for GCP services.**

Unlike standard emulators that allow everything, Blackwell emulators can enforce real IAM policies locally, so permission bugs fail in CI - not in production.

**This closes the hermetic seal:** tests run fully offline, behave deterministically, and fail exactly like production would.

### Key Capabilities

- **Runs fully offline** - no GCP credentials required
- **Hermetic Seal** - optional pre-flight IAM enforcement (Off / Permissive / Strict modes)
- **Protocol support** - gRPC and REST/HTTP where relevant
- **Deterministic execution** - same inputs, same results
- **Production-like failures** - permission denied locally means denied in prod

### The Security Paradox

Most emulators bypass authorization entirely. Tests pass locally, then fail in production when IAM rejects the request.

Blackwell makes IAM enforcement optional but available - so you can test permissions as rigorously as logic, without breaking hermeticity.

### Available Emulators

- **[gcp-secret-manager-emulator](https://github.com/blackwell-systems/gcp-secret-manager-emulator)** - Secret Manager with optional IAM enforcement
- **[gcp-kms-emulator](https://github.com/blackwell-systems/gcp-kms-emulator)** - Cloud KMS with cryptographic operations and IAM
- **gcp-iam-emulator (control plane)** - Authorization decisions and trace emission

[View Documentation](https://github.com/blackwell-systems) · [GitHub Organization](https://github.com/blackwell-systems)

---

## gcp-emulator-pro (Commercial)

**Post-execution analysis for emulator trace artifacts.**

gcp-emulator-pro is the intelligence layer of the ecosystem.  
It consumes authorization traces produced during test execution and performs offline, post-execution analysis - turning what happened into actionable security artifacts.

### Key Capabilities

- **Offline & deterministic** - no cloud calls, works in air-gapped CI
- **Least-privilege policy generation (v1.0)** - minimal IAM policies from observed behavior
- **Post-execution only** - never participates in runtime decisions
- **File-based workflows** - trace artifacts in, reviewable outputs out

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

**Blackwell Systems**  
Builders of open, trustworthy infrastructure tooling.
