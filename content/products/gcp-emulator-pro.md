---
title: "gcp-emulator-pro"
description: "Post-execution, hermetic analysis of GCP authorization behavior"
weight: 10
showMetadata: false
draft: true
---

## gcp-emulator-pro

**Hermetic, post-execution analysis for GCP emulator traces.**

**gcp-emulator-pro** is the commercial intelligence layer for the Blackwell GCP emulator ecosystem.  
It analyzes authorization traces produced during test execution and turns them into actionable security artifacts - offline, deterministic, and auditable.

The system under test executes reality.  
**gcp-emulator-pro explains it.**

---

## What It Does

gcp-emulator-pro consumes **authorization trace artifacts** emitted by open-source GCP emulators and performs post-execution analysis.

Today, that analysis includes:

- **Least-Privilege Policy Generation (v1.0)**  
  Generate minimal IAM policies directly from observed authorization behavior - no guesswork, no over-permissioning.

Additional analysis capabilities are planned, all operating on the same artifact contract:
- Trace summarization
- Authorization coverage analysis
- Drift detection between test runs
- Compliance and audit reports

---

## What Makes It Different

### Hermetic by Design
- No cloud calls
- No background services
- No live APIs
- No telemetry
- Works fully offline, including in air-gapped CI environments

If your tests can run, gcp-emulator-pro can analyze them - even weeks later, on a different machine.

### Post-Execution Only
gcp-emulator-pro **never participates in execution**:
- It does not affect authorization decisions
- It does not gate requests
- It does not modify emulator behavior

It only consumes artifacts **after execution completes**.

This preserves trust in the emulator stack and keeps the analysis layer optional.

### Deterministic & Auditable
- Same trace input → same output
- Stable, versioned trace schema
- File-based inputs and outputs
- Generated artifacts are reviewable, diffable, and CI-friendly

---

## Architecture Fit

gcp-emulator-pro is the **Intelligence Plane** in a three-layer system:

| Layer | Role | License |
|-----|-----|-----|
| Data Plane | GCP service emulation | Open Source |
| Control Plane | Authorization decisions & trace emission | Open Source |
| **Intelligence Plane** | Post-execution analysis & insight | **Commercial** |

The boundary is structural, not strategic:

> Anything that participates in execution must be open source.  
> Anything that interprets artifacts after execution may be commercial.

---

## Example: Least-Privilege Policy Generation

Run your tests with tracing enabled:

```bash
export IAM_TRACE_OUTPUT=authorization.jsonl
go test ./...
```

Analyze the trace:

```bash
gcp-emulator-pro policy generate authorization.jsonl --output terraform/
```

Result: minimal, production-accurate IAM policies derived from what your application actually did - not what you think it needs.

---

## Who It's For

- Teams using GCP emulators in CI
- Security-conscious engineers enforcing least privilege
- Organizations that need auditable authorization evidence
- Anyone tired of `roles/editor`

If you value correctness, determinism, and trust boundaries, this tool is for you.

---

## Licensing

gcp-emulator-pro uses offline license validation:

- No phone-home
- No usage tracking
- No runtime gating
- Works in CI and air-gapped environments

A free 30-day trial is available.

---

## Learn More

- [Trace Schema](#)
- [Input Contract](#)
- [Architecture: The Three-Layer Model](/posts/productization-execution-boundary/)
- [GitHub Repository](#)

---

**Blackwell Systems**  
Builders of open, trustworthy infrastructure tooling.
