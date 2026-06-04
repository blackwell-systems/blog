---
title: "We Scanned 300 npm and PyPI Packages for Supply Chain Attacks Without Executing a Single Line of Code"
date: 2026-06-03
draft: false
tags: ["security", "supply-chain", "npm", "pypi", "static-analysis", "knowing", "merkle-proofs", "open-source"]
categories: ["security", "open-source"]
description: "Structural supply chain detection using code relationship graphs. 1.0% false positive rate validated on 300 clean packages (200 initial + 100 held-out). Detects TanStack/event-stream attack patterns by analyzing who reads credentials and who spawns processes, not by running anything."
summary: "We indexed 300 popular packages with knowing's code graph, computed isolation scores based on credential access + process spawning patterns, and achieved a 1.0% false positive rate across both the initial 200 and a held-out 100. No sandbox. No execution. No heuristics. Just graph structure."
---

Every supply chain scanner you've heard of does one of two things: runs the code in a sandbox and watches what it does, or pattern-matches on known CVEs. The first is expensive and fragile. The second misses novel attacks by definition.

We tried something different. We asked: **can you detect supply chain attacks from the structure of the code alone?**

## The Insight

Supply chain attacks have a structural signature. The TanStack/Mini Shai-Hulud attack (2026) reads `process.env.GITHUB_TOKEN`, spawns `curl` to exfiltrate it, and runs at module load time in a file with zero inbound edges from the rest of the package. The event-stream attack (2018) makes an `http.request` to a hardcoded IP. Both share three properties:

1. **Isolated**: the malicious code has few or no inbound connections from the rest of the package
2. **Reads credentials**: `process.env`, `os.getenv()`, `os.Getenv()`
3. **Exfiltrates**: spawns a process (`curl`, `wget`) or makes a network call

Legitimate code that reads env vars (dotenv, debug) usually doesn't spawn processes. Legitimate code that spawns processes (build tools, test runners) usually has many inbound edges (it's called by the rest of the package). The combination of isolation + credential access + process spawning is rare in clean code and universal in supply chain payloads.

## How It Works

[knowing](https://github.com/blackwell-systems/knowing) is a code intelligence engine that builds a content-addressed graph of code relationships. When you run `knowing index`, it extracts 38 edge types including:

- `reads_env`: function -> environment variable it reads
- `executes_process`: function -> process it spawns
- `consumes_endpoint`: function -> HTTP endpoint it calls

The `knowing audit-supply-chain` command computes an **isolation score** for each file:

```
isolation = inbound_factor * outbound_factor * hook_factor
```

Where:
- **inbound_factor**: files with many callers score low (well-connected = probably not malicious)
- **outbound_factor**: files with `reads_env` + `executes_process` edges score high
- **hook_factor**: 1.5x multiplier if the file runs at install/load time

A **package-level verdict** aggregates file scores: a package is "suspicious" only when both the ratio of suspicious files exceeds 10% AND the count exceeds 2. This is the key to low false positives.

## The Evaluation

We scanned 200 known-clean, popular packages: 100 from npm and 100 from PyPI.

| Ecosystem | Packages | Examples |
|-----------|----------|---------|
| npm | 100 | lodash, express, axios, react, webpack, jest, eslint, typescript, fastify, pino |
| PyPI | 100 | requests, flask, django, fastapi, numpy, pandas, pytest, celery, sqlalchemy, click |

Every package was downloaded, indexed with tree-sitter extraction, and scanned. No LSP, no execution, no sandbox.

### Results

| Metric | Value |
|--------|-------|
| Packages scanned | 200 |
| Packages with "suspicious" verdict | **2 (1.0%)** |
| Packages with "review" verdict | 41 (20.5%) |
| Packages with "clean" verdict | 157 (78.5%) |

The two "suspicious" packages:

- **esbuild**: its install script downloads and runs a platform-specific binary. Structurally identical to a supply chain attack. This is correct behavior from the scanner.
- **nox**: a test runner whose core function is spawning processes. 3/29 files flagged (10.3% ratio).

### Held-Out Validation (100 Additional Packages)

After finalizing thresholds on the initial 200, we scanned 100 more packages that were never used during threshold tuning: 50 npm (zod, drizzle-orm, hono, vitest, prisma, etc.) and 50 PyPI (polars, ruff, typer, loguru, orjson, etc.).

| Metric | Value |
|--------|-------|
| Held-out packages scanned | 100 |
| Packages with "suspicious" verdict | **1 (1.0%)** |

The one suspicious package: **pyright** (a type checker that spawns processes as its core function, structurally indistinguishable from exfiltration).

**Combined 300-package corpus: 3 suspicious (esbuild, nox, pyright), all legitimate tools.** The 1.0% FP rate holds on data the thresholds never saw. This mitigates the overfitting threat: the thresholds generalize.

### What About the 41 "review" Packages?

Packages like django (2/643 files = 0.3%), webpack (1/616 = 0.2%), and pino (0 after test exclusion) have a handful of files that legitimately spawn processes. The package-level verdict correctly classifies them as "review" (worth a human look) rather than "suspicious" (block in CI).

This is the critical insight: **raw file-level scoring gives a 21.5% false positive rate. Package-level aggregation gives 1.0%.** Most clean packages have 1-2 process-spawning files out of hundreds. Real attacks have a high ratio.

## Three Layers of False Positive Reduction

Getting from 21.5% to 1.0% required three complementary filters:

### 1. Env-Only Attenuation

Reading environment variables alone is not suspicious. dotenv, debug, axios (proxy config), and commander all read env vars as their core function. The isolation score applies a 0.2x multiplier to files that read env vars but don't spawn processes.

**Impact**: Eliminates 100% of config-reading package FPs.

### 2. Benign Process Target Classification

Not all process spawning is suspicious. We maintain a list of 22 known-safe executables:

```
node, npm, npx, yarn, pnpm, python, python3, pip, pip3,
go, cargo, rustc, javac, tsc, git, sh, bash, zsh,
node.exe, worker_threads, cluster.fork
```

Spawning `node` or `python` is normal. Spawning `curl` or `wget` is suspicious. Unknown/dynamic targets (`process://dynamic`) are treated as suspicious by default.

**Impact**: Eliminates build tool and runtime FPs.

### 3. Test/Benchmark Exclusion

Files in `/test/`, `/benchmarks/`, `_test.go`, `.spec.ts`, etc. are excluded from scoring. Test runners legitimately spawn processes; these files are not shipped to users.

**Impact**: Eliminates test runner FPs (pino: 5 -> 0).

## True Positive Verification

### TanStack/Mini Shai-Hulud (2026)

The attack reads `process.env.GITHUB_TOKEN`, spawns `curl` to post it to an external server, and executes at module load time via a postinstall hook.

```
Isolation score: 0.9
Verdict: suspicious
Detected edges: reads_env -> GITHUB_TOKEN, executes_process -> curl
```

### event-stream (2018)

The attack adds a dependency (`flatmap-stream`) that makes an `http.request` to a hardcoded IP to exfiltrate Bitcoin wallet keys.

```
Isolation score: 0.24
Detected edges: consumes_endpoint -> 111.90.151.35
```

Both detected without executing any code.

## What This Doesn't Catch

Honesty matters more than marketing:

- **Dynamic targets**: `spawn(variable)` where the variable resolves at runtime to a malicious target. We flag these as suspicious by default, but can't confirm.
- **Obfuscated code**: heavily minified or encoded code may not produce extractable edges.
- **Novel exfiltration methods**: if the attack uses an API not in our dangerous-sink list (e.g., DNS exfiltration), the structural pattern doesn't match.
- **Benign-looking process targets**: `spawn("node", ["malicious-script.js"])` looks benign because `node` is in our safe list. The argument analysis is future work.

## The Cryptographic Angle

This is where knowing diverges from every other scanner. Because the graph is content-addressed with a hierarchical Merkle tree, you can generate **cryptographic proofs**:

- `knowing prove-absent`: prove a module CANNOT reach a dangerous API. The proof is 660 bytes, verifiable offline with nothing but SHA-256.
- `knowing prove`: prove a specific capability path EXISTS (e.g., "this function reads GITHUB_TOKEN and calls curl").
- `knowing diff`: compare two versions of a package and show exactly which new capability paths appeared.

No other supply chain tool can do this. Socket.dev tells you "this package is risky." We tell you "here is a 660-byte cryptographic proof that this module is isolated from the network, verifiable by any third party without access to our infrastructure."

## Try It

```bash
brew install blackwell-systems/tap/knowing

# Index a package
knowing index ./path-to-package

# Scan for supply chain patterns
knowing audit-supply-chain --base @first --scan-all

# Generate a cryptographic isolation proof
knowing prove-absent -source "suspicious-module" -target "network-api"
```

The scanner, the graph engine, and the proof system are all open source under MIT.

## GitHub Action: Ship It in CI

The [knowing-supply-scan](https://github.com/blackwell-systems/knowing-supply-scan) GitHub Action (v1.0.0) runs supply chain checks on every PR:

```yaml
- uses: blackwell-systems/knowing-supply-scan@v1
  with:
    path: .
    threshold: 0.3
```

It indexes the PR diff, computes isolation scores, and fails the check if any file exceeds the threshold. No API keys. No external service. Runs in your CI runner.

## What's Next

- **Registry scanning**: continuous monitoring of npm/PyPI new releases
- **Argument analysis**: inspect process spawn arguments, not just target names
- **Community benign list**: crowdsourced classification of legitimate process targets
- **Synthetic attack fixtures**: reproducible demo packages for CI testing (real attack artifacts are scrubbed from registries)

The full evaluation data is at:
- Initial 200 packages: [`bench/supply-chain/false-positive-results-v2.jsonl`](https://github.com/blackwell-systems/knowing/blob/main/bench/supply-chain/false-positive-results-v2.jsonl)
- Held-out 100 packages: [`bench/supply-chain/false-positive-held-out.jsonl`](https://github.com/blackwell-systems/knowing/blob/main/bench/supply-chain/false-positive-held-out.jsonl)

The whitepaper with formal definitions, soundness theorem, and Merkle proof construction is at [`docs/research/whitepapers/supply-chain-proof-of-absence.md`](https://github.com/blackwell-systems/knowing/blob/main/docs/research/whitepapers/supply-chain-proof-of-absence.md).
