---
title: "agent-lsp: Reliable Code Intelligence for AI Agents via MCP and LSP"
date: 2026-04-15
lastmod: 2026-04-22
draft: false
tags: ["ai", "mcp", "lsp", "go", "golang", "developer-tools", "language-server", "ai-agents", "code-intelligence", "open-source", "model-context-protocol", "mcp-server", "language-server-protocol", "speculative-execution", "agent-skills", "agentskills"]
categories: ["ai", "tools", "open-source", "developer-tools"]
description: "Built a persistent LSP runtime layer for AI agents: 50 tools, 20 AgentSkills-conformant workflows, 30 CI-verified languages, speculative execution, and an audit trail. Works with Claude, Copilot, Cursor, Gemini, Codex, and any MCP-compatible agent."
summary: "I needed AI agents to reliably rename symbols, find references, and check diagnostics without silent failures. The existing MCP-LSP tools were stateless, feature-poor, and untested. So I built agent-lsp: a persistent runtime with 50 tools, 20 provider-agnostic skills, speculative execution, and an audit trail for every AI-driven edit."
---

I was using an AI agent to rename a function that appeared in 23 files. The agent called `rename_symbol`, got a success response, and moved on. Three of the callers were never updated. The language server session had dropped mid-operation and the tool returned stale data. The agent had no way to know.

This is the failure mode I kept hitting. Not the model making the wrong decision, but the tooling silently giving it wrong information.

[agent-lsp](https://github.com/blackwell-systems/agent-lsp) is what I built to fix it.

## What It Is

agent-lsp is a persistent LSP runtime layer that gives AI agents real code intelligence. One Go binary, one long-lived process, 50 tools.

The key word is persistent. Most MCP-LSP bridges cold-start the language server on every request. There's no session, no cross-file index, no warm state. The language server protocol is designed for long-lived connections: an editor keeps the server running so it can build a full semantic model of the workspace. A per-request wrapper throws that model away after every call.

With agent-lsp, you call `start_lsp("/your/project")` once. From that point, every call hits the full index. `get_references` waits for all indexing progress events to complete before returning. `go_to_definition` finds the actual definition, not a guess based on a cold server that hasn't seen the file yet.

## Why Persistence Matters

The language server protocol is stateful by design. When an editor starts gopls, it sends `initialize`, then `initialized`, then starts opening documents and notifying the server about file changes. The server builds its understanding incrementally: parsing imports, resolving types, building the call graph. That process takes time, and the results are only valid while the session is alive.

When you call a tool through a stateless bridge, the server starts from zero. It hasn't seen your imports. It doesn't know your project structure. `get_references` runs against an empty index and returns nothing, or returns partial results from whatever it managed to index in the 200ms before timing out.

agent-lsp keeps the server alive between calls. The first request after `start_lsp` might be slow while the index builds. Every subsequent request is fast and correct, because the server already knows your codebase.

It also handles the protocol details that matter. gopls sends three server-initiated requests during workspace initialization: `client/registerCapability`, `workspace/configuration`, and `workspace/semanticTokens/refresh`. Without responses to these, the workspace never fully loads and `get_references` returns empty. agent-lsp responds to all of them automatically.

## The Tools

50 tools covering everything the LSP spec provides. The full reference is at [agent-lsp.com/tools](https://agent-lsp.com/tools/), but the highlights:

**Speculative execution** is the one nobody else has. `simulate_edit_atomic` applies a change to a virtual document in memory, runs diagnostics against the modified state, and returns the delta: how many errors this edit would introduce or resolve, without writing anything to disk.

```
simulate_edit_atomic(
  file_path: "internal/session/manager.go",
  start_line: 42, start_column: 1,
  end_line: 42, end_column: 30,
  new_text: "func (m *Manager) Initialize(ctx context.Context) error {"
)
→ { net_delta: 0, confidence: "high", errors_introduced: [] }
```

`net_delta: 0` means the edit introduces no new errors. `simulate_chain` extends this to multi-step refactors: chain edits across multiple files in memory, check `cumulative_delta` and `safe_to_apply_through_step` at each step, then either `commit_session` to write everything to disk or `discard_session` to throw it all away. Your files are never touched until you explicitly say so.

Speculative execution is CI-verified across 8 languages: Go, TypeScript, Python, Rust, C++, C#, Dart, and Java.

**`get_change_impact`** takes a file path and returns every exported symbol, every caller partitioned into test vs production code, and the full blast radius. Run this before touching any file.

**`get_cross_repo_references`** finds all usages of a library symbol across consumer repos. Pass the symbol location and a list of workspace roots; get back all references partitioned by repo.

**`call_hierarchy` and `type_hierarchy`** each handle both directions in one call. Pass `direction: "both"` to get incoming + outgoing calls or supertypes + subtypes in one round trip.

**`rename_symbol`** supports `dry_run: true` for preview and `exclude_globs` to skip generated files. Small feature, but anyone working in a repo with generated code knows how many renames get derailed by updating a file you weren't supposed to touch.

## The Skill Layer

Having the right tools isn't enough if the agent doesn't use them in the right sequence.

A rename has a correct sequence. `prepare_rename` validates the operation: it returns the exact token at the cursor position and confirms the server will accept the rename. Without it, you can end up renaming a keyword or a built-in type. Then `rename_symbol` with `dry_run: true` to preview all affected files. Then confirmation. Then apply. Then verify diagnostics.

Without a skill, the agent might skip `prepare_rename`. It might not preview. It might not check diagnostics after applying. Each step individually seems optional; together they're what make the operation safe.

Skills are markdown files the agent follows. They specify the exact sequence: which tool, in what order, what to check at each step, when to stop and ask for confirmation.

**All 20 skills conform to the [AgentSkills](https://agentskills.io/) open standard.** This means they work with any conforming agent: Claude Code, Cursor, GitHub Copilot, Gemini CLI, OpenAI Codex, JetBrains Junie, Roo Code, and [30+ others](https://agentskills.io/clients). The skills are not locked to any single AI provider.

Here's what `/lsp-rename` actually does:

1. Call `prepare_rename` at the cursor position: validates the operation is safe
2. Call `rename_symbol` with `dry_run: true`: returns every file and line that will change
3. Present the diff to the user, ask for confirmation
4. Call `apply_edit` with the workspace edit: all files updated atomically
5. Call `get_diagnostics`: verify no errors were introduced

That sequence happens every time. Not just when the model happens to reason through all five steps on its own.

The 20 skills cover the full editing lifecycle:

| Skill | What it enforces |
|-------|-----------------|
| `/lsp-refactor` | Blast-radius → speculative preview → apply → build verify → targeted tests |
| `/lsp-rename` | `prepare_rename` gate → dry-run preview → confirm → apply → verify |
| `/lsp-safe-edit` | Simulate edit in memory, check `net_delta` before touching disk |
| `/lsp-simulate` | Full speculative session lifecycle across multiple files |
| `/lsp-impact` | `get_change_impact` → call hierarchy → type hierarchy: full blast radius |
| `/lsp-verify` | Diagnostics + build + tests after every edit |
| `/lsp-explore` | Hover + implementations + call hierarchy + references in one pass |
| `/lsp-understand` | Deep Code Map: type info, 2-level call hierarchy, all references, source |
| `/lsp-implement` | Find all concrete implementations before changing an interface |
| `/lsp-dead-code` | Surface exported symbols with zero references |
| `/lsp-edit-export` | Find all callers before changing a public symbol |
| `/lsp-edit-symbol` | Edit a symbol by name without knowing its file or position |
| `/lsp-cross-repo` | Find usages across consumer repos |
| `/lsp-test-correlation` | Run only the tests covering the edited file |
| `/lsp-extract-function` | Extract code into a named function with LSP code action or manual fallback |
| `/lsp-generate` | Interface stubs, test skeletons, missing methods via LSP code actions |
| `/lsp-fix-all` | Sequential quick-fix loop with diagnostic re-collection between each fix |
| `/lsp-docs` | Three-tier documentation: hover → offline toolchain → source |
| `/lsp-format-code` | Format file or selection via language server |
| `/lsp-local-symbols` | File-scoped symbol list and usage search |

Skills install with one command:

```bash
cd /path/to/agent-lsp/skills && ./install.sh
```

The `--dest` flag lets you install to any agent's skill directory:

```bash
./install.sh                          # Claude Code (default)
./install.sh --dest ~/.cursor/skills  # Cursor
```

The installer also updates agent instruction files (CLAUDE.md, AGENTS.md, GEMINI.md) with a managed skills table, if those files exist.

## 30 Languages, CI-Verified

"Supports 30 languages" can mean two different things: listed in a config file, or tested against a real language server on every CI run. agent-lsp does the latter.

The integration test matrix starts the actual language server binary, opens a real source file, calls the actual tool, and verifies the result. Every language, every CI run.

Go, TypeScript, Python, Rust, Java, C, C++, C#, Ruby, PHP, Kotlin, Swift, Zig, Lua, Scala, Elixir, Dart, Gleam, Clojure, Nix, Terraform, SQL, Prisma, MongoDB, and more. The full matrix is at [agent-lsp.com/language-support](https://agent-lsp.com/language-support/).

Multi-server routing is automatic. Configure agent-lsp with multiple servers, and it routes each request to the right one based on file extension:

```json
{
  "mcpServers": {
    "lsp": {
      "command": "agent-lsp",
      "args": [
        "go:gopls",
        "typescript:typescript-language-server,--stdio",
        "python:pyright-langserver,--stdio"
      ]
    }
  }
}
```

One process handles your Go backend, TypeScript frontend, and Python scripts.

## Audit Trail

Every mutating operation is logged. `apply_edit`, `rename_symbol`, and `commit_session` each produce a JSONL record with before/after diagnostic snapshots, files touched, and the edit summary. Enable with `--audit-log /path/to/audit.jsonl` or the `AGENT_LSP_AUDIT_LOG` environment variable.

When an AI agent changes your code, you can see exactly what happened, what broke, and what was resolved.

## Getting Started

```bash
# Homebrew (macOS/Linux)
brew install blackwell-systems/tap/agent-lsp

# curl | sh
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/agent-lsp/main/install.sh | sh

# npm
npm install -g @blackwell-systems/agent-lsp

# Go
go install github.com/blackwell-systems/agent-lsp/cmd/agent-lsp@latest
```

Then run the setup wizard:

```bash
agent-lsp init
```

It detects which language servers are on your PATH, asks which AI tool you use, and writes the correct MCP config. For CI or scripted environments: `agent-lsp init --non-interactive`.

Docker images are available with language servers pre-installed, including ARM64 for native Apple Silicon and AWS Graviton performance:

```bash
docker pull ghcr.io/blackwell-systems/agent-lsp:go
docker pull ghcr.io/blackwell-systems/agent-lsp:typescript
docker pull ghcr.io/blackwell-systems/agent-lsp:fullstack
```

Also available via Scoop and Winget on Windows, and listed on the [official MCP Registry](https://registry.modelcontextprotocol.io), [Glama](https://glama.ai/mcp/servers/blackwell-systems/agent-lsp) (A grade), Smithery, PulseMCP, and cursor.directory.

Full documentation at [agent-lsp.com](https://agent-lsp.com). The library packages (`pkg/lsp`, `pkg/session`, `pkg/types`) expose a stable Go API for using the LSP client directly without the MCP server.

The repo is [blackwell-systems/agent-lsp](https://github.com/blackwell-systems/agent-lsp). MIT license. Single static Go binary, no runtime dependencies.
