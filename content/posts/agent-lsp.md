---
title: "agent-lsp: Reliable Code Intelligence for AI Agents via MCP and LSP"
date: 2026-04-15
draft: false
tags: ["ai", "mcp", "lsp", "go", "golang", "claude-code", "developer-tools", "language-server", "ai-agents", "code-intelligence", "open-source", "model-context-protocol", "mcp-server", "mcp-tools", "language-server-protocol", "lsp-3.17", "gopls", "typescript-language-server", "pyright", "rust-analyzer", "clangd", "solargraph", "code-refactoring", "symbol-rename", "speculative-execution", "call-hierarchy", "type-hierarchy", "semantic-tokens", "cross-repo", "agentic-coding", "ai-coding", "cursor", "copilot", "continue-dev", "lsp-mcp", "agent-skills", "homebrew", "docker", "polyglot", "monorepo", "static-analysis", "diagnostics"]
categories: ["ai", "tools", "open-source", "developer-tools"]
description: "Built a stateful MCP server for AI agents that keeps the language server index warm — 50 tools, 30 CI-verified languages, speculative execution, and a skill layer that encodes correct tool sequences. Solves the silent failures of stateless MCP-LSP bridges."
summary: "I needed AI agents to reliably rename symbols, find references, and check diagnostics without silent failures. The existing MCP-LSP tools were stateless, feature-poor, and untested. So I built agent-lsp — a persistent session runtime with 50 tools, 30 CI-verified languages, speculative execution, and a skill layer that makes correct tool sequences happen automatically."
---

I was using an AI agent to rename a function that appeared in 23 files. The agent called `rename_symbol`, got a success response, and moved on. Three of the callers were never updated. The language server session had dropped mid-operation and the tool returned stale data. The agent had no way to know.

This is the failure mode I kept hitting. Not the model making the wrong decision — the tooling silently giving it wrong information.

[agent-lsp](https://github.com/blackwell-systems/agent-lsp) is what I built to fix it.

## What It Is

agent-lsp is an MCP server that wraps real language servers and exposes their intelligence to AI agents. One process, persistent session, 50 tools.

The key word is persistent. Most MCP-LSP tools cold-start the language server on every request. There's no session, no cross-file index, no warm state. The language server protocol is designed for long-lived connections — an editor keeps the server running so it can build a full semantic model of the workspace. A per-request wrapper throws that model away after every call.

With agent-lsp, you call `start_lsp("/your/project")` once. From that point, every call has the full index. `get_references` waits for all indexing progress events to complete before returning. `go_to_definition` finds the actual definition, not a guess based on a cold server that hasn't seen the file yet.

## Why Persistence Matters

The language server protocol is stateful by design. When an editor starts gopls, it sends `initialize`, then `initialized`, then starts opening documents and notifying the server about file changes. The server builds its understanding incrementally — parsing imports, resolving types, building the call graph. That process takes time, and the results are only valid while the session is alive.

When you call a tool through a stateless bridge, the server starts from zero. It hasn't seen your imports. It doesn't know your project structure. `get_references` runs against an empty index and returns nothing, or returns partial results from whatever it managed to index in the 200ms before timing out.

agent-lsp keeps the server alive between calls. The first request after `start_lsp` might be slow while the index builds. Every subsequent request is fast and correct, because the server already knows your codebase.

It also handles the protocol details that matter. gopls sends three server-initiated requests during workspace initialization — `client/registerCapability`, `workspace/configuration`, and `workspace/semanticTokens/refresh`. Without responses to these, the workspace never fully loads and `get_references` returns empty. agent-lsp responds to all of them automatically.

## The Tools

50 tools covering everything the LSP spec provides. The full list is in [docs/tools.md](https://github.com/blackwell-systems/agent-lsp/blob/main/docs/tools.md), but here's the breakdown by category:

| Category | Tools |
|----------|-------|
| Session & Lifecycle | `start_lsp`, `restart_lsp_server`, `open_document`, `close_document`, `add_workspace_folder`, `remove_workspace_folder`, `list_workspace_folders`, `get_server_capabilities` |
| Navigation | `go_to_definition`, `go_to_type_definition`, `go_to_implementation`, `go_to_declaration`, `go_to_symbol`, `rename_symbol`, `prepare_rename`, `get_document_highlights`, `call_hierarchy`, `type_hierarchy` |
| Analysis | `get_info_on_location`, `get_completions`, `get_signature_help`, `get_code_actions`, `get_document_symbols`, `get_workspace_symbols`, `get_references`, `get_inlay_hints`, `get_diagnostics`, `get_semantic_tokens`, `get_symbol_documentation`, `get_symbol_source`, `get_change_impact`, `get_cross_repo_references` |
| Editing | `apply_edit`, `execute_command`, `format_document`, `format_range`, `did_change_watched_files` |
| Speculative Execution | `simulate_edit`, `simulate_edit_atomic`, `simulate_chain`, `create_simulation_session`, `commit_session`, `discard_session`, `evaluate_session` |
| Diagnostics & Build | `get_diagnostics`, `run_build`, `run_tests`, `get_tests_for_file`, `set_log_level` |

A few worth calling out individually:

### Speculative Execution

Run an edit in memory without touching the file. `simulate_edit_atomic` applies a change to a virtual document, runs diagnostics against the modified state, and returns the delta — how many errors this edit would introduce or resolve — without writing anything to disk.

```
simulate_edit_atomic(
  file_path: "internal/session/manager.go",
  start_line: 42,
  start_column: 1,
  end_line: 42,
  end_column: 30,
  new_text: "func (m *Manager) Initialize(ctx context.Context) error {"
)
→ { net_delta: 0, safe_to_apply: true, diagnostics_after: [] }
```

`net_delta: 0` means the edit introduces no new errors. `safe_to_apply: true` means you can commit it.

`simulate_chain` extends this to multi-step refactors. Chain edits across multiple files in memory, check `cumulative_delta` and `safe_to_apply_through_step` at each step, then either `commit_session` to write everything to disk atomically or `discard_session` to throw it all away.

This is the right way to preview a refactor. You know before touching a file whether the change is safe.

### `get_change_impact`

Give it a file path. Get back every exported symbol in that file, every caller partitioned into test vs non-test, and the full blast radius. Run this before touching any file to understand scope before you've written a single line.

### `call_hierarchy` and `type_hierarchy`

Single tool each, with a `direction` parameter. `call_hierarchy` handles `textDocument/prepareCallHierarchy`, `callHierarchy/incomingCalls`, and `callHierarchy/outgoingCalls` in one call. Pass `direction: "both"` to get everything. Same pattern for `type_hierarchy` — supertypes and subtypes in one round trip.

### `rename_symbol` with glob exclusions

```json
{
  "file_path": "pkg/session/client.go",
  "line": 14,
  "column": 6,
  "new_name": "LSPClient",
  "exclude_globs": ["**/*_gen.go", "vendor/**", "testdata/**"],
  "dry_run": true
}
```

`dry_run: true` returns the `workspace_edit` preview without applying anything. `exclude_globs` skips files matching those patterns. Small feature, but anyone working in a repo with generated code will tell you how many renames get derailed by updating a file you weren't supposed to touch.

### `get_cross_repo_references`

Find all usages of a library symbol across consumer repos. Pass the symbol location and a list of workspace roots; get back all references partitioned by repo. Useful for library authors who need to understand the impact of an API change across multiple downstream projects before making it.

## 30 Languages, CI-Verified

"Supports 30 languages" can mean two different things: listed in a config file, or tested against a real language server on every CI run. agent-lsp does the latter.

The integration test matrix starts the actual language server binary, opens a real source file, calls the actual tool, and verifies the result. Every language, every CI run.

| Language | Server | CI notes |
|----------|--------|----------|
| Go | gopls | Full test suite including speculative execution |
| TypeScript / JavaScript | typescript-language-server | Type hierarchy tested against TS class hierarchies |
| Python | pyright-langserver | Import resolution verified |
| Rust | rust-analyzer | Trait implementation lookup |
| Java | jdtls | Type hierarchy and call hierarchy |
| Ruby | solargraph | Reference resolution |
| C / C++ | clangd | Cross-file references |
| C# | csharp-ls | Basic navigation |
| PHP | intelephense | Symbol resolution |
| Kotlin | kotlin-language-server | — |
| Swift | sourcekit-lsp | macOS CI only |
| ... | | 19 more |

The full matrix is in [docs/language-support.md](https://github.com/blackwell-systems/agent-lsp/blob/main/docs/language-support.md).

Multi-server routing is automatic. Configure agent-lsp with multiple servers, and it routes each request to the right one based on file extension. One agent-lsp process handles your Go backend, TypeScript frontend, and Python scripts. No reconfiguration when you switch files.

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

## The Skill Layer

Having the right tools isn't enough if the agent doesn't use them in the right sequence.

A rename has a correct sequence. `prepare_rename` validates the operation — it returns the exact token at the cursor position and confirms the server will accept the rename. Without it, you can end up renaming a keyword, a built-in type, or a token that the language server doesn't allow renaming. Then `rename_symbol` with `dry_run: true` to preview all affected files before anything changes. Then confirmation. Then apply.

Without a skill, the agent might skip `prepare_rename`. It might not preview. It might not check diagnostics after applying. Each step individually seems optional; together they're what make the operation safe. An agent that has access to the right tools but uses them in the wrong order (or skips steps) produces the same outcome as an agent that doesn't have the tools at all.

Skills are markdown files the agent follows. They specify the exact sequence — which tool, in what order, what to check at each step, when to stop and ask for confirmation. They live in `~/.claude/skills/` and the agent picks them up automatically.

Here's what `/lsp-rename` actually does:

1. Call `prepare_rename` at the cursor position — validates the operation is safe, returns the token that will be renamed
2. Call `rename_symbol` with `dry_run: true` — returns the full `workspace_edit` showing every file and line that will change
3. Present the diff to the user, ask for confirmation
4. Call `apply_edit` with the workspace edit — all files updated atomically
5. Call `get_diagnostics` — verify no errors were introduced

That sequence happens every time. Not just when the model happens to reason through all five steps on its own.

Current skills:

| Skill | What it encodes |
|-------|----------------|
| `/lsp-rename` | `prepare_rename` gate → dry-run preview → confirm → apply → verify |
| `/lsp-safe-edit` | `simulate_edit_atomic` before disk write; diagnostic diff before and after; code actions on errors |
| `/lsp-impact` | `get_change_impact` → call hierarchy → type hierarchy — full blast radius before touching anything |
| `/lsp-verify` | Diagnostics + build + tests after every edit |
| `/lsp-explore` | Hover + implementations + call hierarchy + references in one pass — for navigating unfamiliar code |
| `/lsp-dead-code` | `get_references` across all exported symbols; surface zero-reference exports before cleanup |
| `/lsp-simulate` | `simulate_chain` across multiple files; verify `cumulative_delta` before committing |
| `/lsp-edit-export` | `get_references` first, then safe edit — for changing exported symbols with callers |
| `/lsp-cross-repo` | `get_cross_repo_references` across consumer repos; partition by repo |
| `/lsp-test-correlation` | `get_tests_for_file` → run only the tests that cover the edited file |
| `/lsp-local-symbols` | File-scoped symbol list, usage search, type info — faster than workspace search |
| `/lsp-docs` | Three-tier documentation: hover → offline toolchain → source |
| `/lsp-edit-symbol` | Navigate to a symbol by name, edit it, verify — without knowing file or position |
| `/lsp-format-code` | Format file or selection via language server; applies to disk |

Skills install with one command:

```bash
cd /path/to/agent-lsp/skills && ./install.sh
```

The installer symlinks each skill directory into `~/.claude/skills/` and updates your `~/.claude/CLAUDE.md` with a managed skills table so your AI tool knows they exist.

## Getting Started

```bash
# Homebrew
brew install blackwell-systems/tap/agent-lsp

# curl | sh
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/agent-lsp/main/install.sh | sh

# npm
npm install -g @blackwell-systems/agent-lsp

# Go
go install github.com/blackwell-systems/agent-lsp@latest
```

Then run the setup wizard:

```bash
agent-lsp init
```

It detects which language servers are on your PATH, asks which AI tool you use, and writes the correct MCP config. For CI or scripted environments: `agent-lsp init --non-interactive`.

Docker images are available if you want a fully contained setup with language servers pre-installed:

```bash
# Go
docker run --rm -i -v /your/project:/workspace ghcr.io/blackwell-systems/agent-lsp:go go:gopls

# TypeScript
docker run --rm -i -v /your/project:/workspace ghcr.io/blackwell-systems/agent-lsp:typescript typescript:typescript-language-server,--stdio

# Go + TypeScript + Python in one image
docker run --rm -i -v /your/project:/workspace ghcr.io/blackwell-systems/agent-lsp:fullstack \
  go:gopls typescript:typescript-language-server,--stdio python:pyright-langserver,--stdio
```

The library packages (`pkg/lsp`, `pkg/session`, `pkg/types`) also expose a stable Go API for using the LSP client directly without the MCP server, if you're building tooling that needs language server access without the agent layer.

The repo is [blackwell-systems/agent-lsp](https://github.com/blackwell-systems/agent-lsp). MIT license. Single Go binary, no runtime dependencies.
