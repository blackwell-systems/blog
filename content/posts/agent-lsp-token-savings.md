---
title: "We Measured It: LSP Saves AI Agents 5-34x Tokens vs Grep"
date: 2026-05-03
draft: false
tags: ["ai", "mcp", "lsp", "agent-lsp", "ai-agents", "token-savings", "context-window", "developer-tools", "ai-coding", "model-context-protocol", "language-server-protocol", "grep", "code-navigation", "speculative-execution", "benchmark", "open-source"]
categories: ["ai", "tools", "open-source", "benchmarks"]
description: "Reproducible experiment measuring token consumption of AI agents navigating code with grep/read vs structured LSP calls. Results across 4 codebases, 3 languages, 13 tasks: 5-34x fewer tokens, 92-99% of grep results are false positives."
summary: "We built a reproducible experiment measuring how many tokens AI coding agents consume when navigating code with grep vs LSP. On HashiCorp Consul (319K lines), LSP uses 34x fewer tokens. On a TypeScript rename across 24 files: 1,441x fewer bytes. The experiment covers 4 codebases, 3 languages, 13 tasks covering 7 agent workflows."
---

We renamed a function across 24 files in a TypeScript codebase.

The grep approach ingested 492,954 bytes to accomplish it: grep to find all occurrences, read each file to understand context, replace, build to verify, read build output.

The LSP approach ingested 342 bytes. One `rename_symbol` call returned a structured workspace edit.

That's 1,441x fewer tokens for the exact same operation.

## The experiment

We built a [reproducible Go script](https://github.com/blackwell-systems/agent-lsp/tree/main/experiments/token-savings) that measures the actual byte cost of common code intelligence tasks using two approaches:

1. **Grep/Read**: what AI agents do today. Grep for a symbol, read the file, grep again, read context. This is how every agent without LSP navigates code.
2. **LSP**: structured queries to a language server. Get exactly the information needed, in a machine-readable format, with zero false positives.

For each task, we measure total bytes that enter the agent's context window on both sides. The ratio is the savings.

## Results

We ran 13 tasks across 4 codebases in 3 languages:

| Codebase | Language | Lines | Overall savings | Tokens saved |
|----------|----------|------:|----------------:|-------------:|
| agent-lsp | Go | 15K | **5x** | ~633K |
| Hono | TypeScript | 24K | **13x** | ~1.2M |
| FastAPI | Python | 33K | **2x** | ~693K |
| HashiCorp Consul | Go | 319K | **34x** | ~13.1M |

The savings scale with codebase size. At 15K lines, LSP saves 5x. At 319K lines, 34x. This makes intuitive sense: grep output grows linearly with the number of files in the codebase, while LSP responses stay proportional to the number of actual references (regardless of codebase size).

## The strongest results

### Rename: 92-1,441x

Renaming a symbol is where the gap is most extreme.

The grep agent must:
1. Grep the entire codebase to find all occurrences
2. Read each matching file fully (to safely edit it without breaking things)
3. Make the replacements
4. Build to verify nothing broke
5. Read the build output

The LSP agent calls `rename_symbol` once. It returns a structured workspace edit that atomically renames the symbol across all files. 342 bytes.

| Codebase | Grep bytes | LSP bytes | Ratio |
|----------|----------:|----------:|------:|
| agent-lsp (Go, 14 files) | 209,589 | 2,285 | **92x** |
| Hono (TypeScript, 24 files) | 492,954 | 342 | **1,441x** |
| FastAPI (Python, 22 files) | 416,042 | 3,601 | **116x** |
| Consul (Go, 18 files) | 802,815 | 8,286 | **97x** |

TypeScript shows the highest ratio because `typescript-language-server`'s rename response is extremely compact.

### Precision: 92-99% of grep results are noise

This is the qualitative argument, not just a byte count.

We grepped for `Close` across HashiCorp Consul (319K lines). Grep returned **1,156 matches**. LSP returned **12 actual references** to the specific `Close` method we were querying.

**1,144 of 1,156 grep results are false positives.** They match the string "Close" in comments, other types' methods, string literals, and unrelated packages.

This is also why sed isn't a substitute for LSP rename. `sed 's/Close/Shutdown/g'` would modify 1,144 lines that happen to contain the text "Close" but aren't the symbol being renamed.

The precision numbers across codebases:

| Codebase | Grep matches | LSP references | False positive rate |
|----------|------------:|---------------:|--------------------:|
| agent-lsp | 61 | 5 | 92% |
| Hono | 15 | 1 | 93% |
| FastAPI | 64 | 2 | 97% |
| Consul | 1,156 | 12 | 99% |

### Interface implementations: 1,002-1,813x

"Find all types that implement this interface."

Grep cannot answer this question. There is no text pattern that identifies which types satisfy an interface in Go. The agent would need to read every file in the codebase, parse the method sets, and compare against the interface definition.

LSP answers in one call: `go_to_implementation` returns the concrete types directly.

| Codebase | Grep bytes | LSP bytes | Ratio |
|----------|----------:|----------:|------:|
| agent-lsp | 98,221 | 98 | **1,002x** |
| Consul | 177,668 | 98 | **1,813x** |

98 bytes. That's the entire response: one file path and a line number.

### Speculative execution: 2ms vs 1.3 seconds

"Is this edit safe? Will it break the build?"

Without LSP, the agent must:
1. Read the file
2. Edit the file on disk
3. Run the build (1+ seconds)
4. Read the build output (potentially thousands of lines)
5. Revert the file

With agent-lsp's `simulate_edit_atomic`, the agent previews the edit in memory without touching disk. The response is a structured JSON with `net_delta` (how many new errors the edit introduces). If `net_delta == 0`, the edit is safe. If not, discard and try again.

No disk writes. No build. No revert. 2 milliseconds.

### Multi-hop call chains: 9-12x, 87x faster

"Who calls the functions that call `Shutdown`?"

The grep agent must:
1. Grep for `Shutdown` (find direct callers)
2. Read each matching file to identify the enclosing function
3. Grep for each of those enclosing functions (find indirect callers)
4. Read context for each indirect caller

That's 25 grep calls and 585ms on a 15K-line codebase.

LSP does it in 2 calls: `call_hierarchy` incoming, 2 levels deep. 4.6KB, 2ms.

## Why savings scale with codebase size

The fundamental asymmetry:

- **Grep cost = O(codebase size)**: every grep scans every file. More files = more output.
- **LSP cost = O(result size)**: the response contains only the matching references. More files in the codebase doesn't change the number of references to a specific symbol.

On a 15K-line codebase, grep is tolerable (small files, few matches). On a 319K-line codebase, grep becomes expensive: 5,534 calls and 17.7MB of output for a single blast-radius analysis. LSP: 119 calls and 841KB for the same information.

## What the agent gets

With grep/read, the agent receives raw text it must parse, filter, and reason about. Every false positive is a distraction that costs output tokens (the agent thinks about it, decides to ignore it, moves on).

With LSP, the agent receives structured JSON. File paths, line numbers, type signatures. No parsing needed. No false positives to filter. The information is immediately actionable.

This means the real savings are even higher than the byte counts suggest. We only measure input tokens (bytes flowing into context). We don't measure the output token overhead of reasoning about noisy grep results. That cost is proportional to the noise: more false positives = more output tokens spent filtering them.

## Reproduce it

The experiment is a single Go file you can point at any project:

```bash
# Go project
go run ./experiments/token-savings --root /path/to/go/project

# Python project
go run ./experiments/token-savings --root /path/to/python/project --language python

# TypeScript project
go run ./experiments/token-savings --root /path/to/ts/project/src --language typescript
```

Prerequisites: `gopls` (Go), `pyright-langserver` (Python), or `typescript-language-server` (TypeScript) on PATH.

Source: [experiments/token-savings/main.go](https://github.com/blackwell-systems/agent-lsp/blob/main/experiments/token-savings/main.go)

Full results: [agent-lsp.com/token-savings](https://agent-lsp.com/token-savings)

## What this is

[agent-lsp](https://github.com/blackwell-systems/agent-lsp) is an open-source MCP server that gives AI agents structured access to language servers. 53 tools, 20 agent workflows, 30 CI-verified languages. Single Go binary.

Works with Claude Code, Cursor, Windsurf, GitHub Copilot, and any MCP client.

Your agent already has grep and read. agent-lsp gives it go-to-definition, find-all-references, rename, diagnostics, completions, call hierarchy, type hierarchy, and speculative execution. Same information, fewer tokens, zero false positives.
