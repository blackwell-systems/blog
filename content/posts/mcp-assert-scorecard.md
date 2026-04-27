---
title: "We Tested 54 MCP Servers. Here's What Breaks."
date: 2026-04-27
draft: false
tags: ["mcp", "model-context-protocol", "testing", "ai-agents", "developer-tools", "open-source", "go", "mcp-server", "quality-assurance", "grafana", "anthropic", "microsoft", "mozilla"]
categories: ["ai", "tools", "open-source"]
description: "We scanned 54 MCP servers from Anthropic, Google, Microsoft, Mozilla, Sentry, Grafana, and AWS with mcp-assert. 20 bugs across 9 servers. The most common pattern: servers crash instead of returning errors agents can recover from."
summary: "MCP servers are the tools AI agents rely on. We tested 54 of them with mcp-assert, found 20 bugs across 9 servers, and submitted fix PRs. Grafana merged ours. The most common failure: servers throw unhandled exceptions instead of returning isError, leaving agents unable to recover."
---

I started scanning MCP servers because I wanted to know if they actually work. Not "does the demo run in MCP Inspector" but "what happens when an agent sends bad input at 2am in CI."

The answer, for a surprising number of servers: they crash.

## The Tool

[mcp-assert](https://github.com/blackwell-systems/mcp-assert) is the testing tool I built for this. It connects to any MCP server over stdio, SSE, or HTTP, calls tools with known inputs, and asserts the results. Define assertions in YAML, run them in CI. One Go binary, works with servers in any language.

The zero-config version:

```bash
mcp-assert audit --server "npx my-mcp-server"
```

This connects, discovers every tool via `tools/list`, generates inputs from JSON Schema, calls each one, and reports which tools are healthy vs. which crash. No YAML, no setup.

For CI regression testing, you write YAML assertions:

```yaml
name: read_query returns rows from users table
server:
  command: uvx
  args: [mcp-server-sqlite, --db-path, "{{fixture}}/test.db"]
assert:
  tool: read_query
  args:
    query: "SELECT * FROM users"
  expect:
    not_error: true
    contains: ["alice", "bob"]
```

536 assertions across 54 servers, 7 languages, 3 transports. Here's what I found.

## The Numbers

| Metric | Count |
|--------|-------|
| Servers scanned | 54 |
| Languages | 7 (Go, TypeScript, Python, Rust, Kotlin, Swift, C#) |
| Transports | 3 (stdio, SSE, HTTP) |
| Total assertions | 546 |
| Bugs found | 20 across 9 servers |
| Fix PRs submitted | 6 |
| Fix PRs merged | 1 (Grafana) |
| Clean scans | 45 servers |

The full scorecard is at [blackwell-systems.github.io/mcp-assert/scorecard](https://blackwell-systems.github.io/mcp-assert/scorecard/).

## What Breaks

The most common failure mode is unhandled exceptions propagating as JSON-RPC `-32603` internal errors instead of returning `isError: true`.

MCP has a deliberate distinction here. When a tool gets bad input, the server should return:

```json
{
  "content": [{"type": "text", "text": "Invalid URL format"}],
  "isError": true
}
```

The agent sees `isError: true`, reads the message, and adjusts its approach. Maybe it fixes the URL and retries. Maybe it asks the user.

What a lot of servers actually return:

```json
{"jsonrpc": "2.0", "error": {"code": -32603, "message": "Internal error"}}
```

This is a JSON-RPC protocol error. The agent treats it as "the server crashed." There's no recovery path. The tool call is a black hole.

The distinction matters because `-32603` is supposed to mean "something went wrong inside the server that isn't the client's fault." When servers use it for input validation failures, agents can't tell the difference between "I sent a bad URL" and "the server's database is down."

## The Bugs

### Grafana (mcp-grafana): merged fix

`get_assertions` crashes with an internal error when given an invalid timestamp string. Every other tool in the Grafana server validates input correctly and returns `isError: true`. This one tool skipped validation because `time.Time` unmarshal happens before the tool handler's input validation logic runs.

We submitted [PR #793](https://github.com/grafana/mcp-grafana/pull/793). Grafana merged it.

### Anthropic (server-puppeteer): fix PR submitted

`puppeteer_navigate` crashes on invalid URLs. The `page.goto()` call has no try/catch. Puppeteer's Chrome DevTools Protocol throws a protocol error, which propagates as `-32603`. Other tools in the same server (like `puppeteer_screenshot`) correctly catch errors and return `isError: true`.

[PR #4051](https://github.com/modelcontextprotocol/servers/pull/4051) submitted. The server was recently archived to a separate branch, but the npm package is still published and widely used.

### antvis/mcp-server-chart (Ant Group): fix PR submitted, CI integration requested

This was the worst. 9 out of 25 tools crash with full JavaScript stack traces when called with default input. The charting tools don't validate their input before attempting to render, so any missing or malformed parameter produces an unhandled exception.

We submitted [PR #292](https://github.com/antvis/mcp-server-chart/pull/292). The maintainer (from Ant Group's visualization team) reviewed it, asked how to use mcp-assert, and requested that we add CI integration to their repository. That follow-up PR is in progress.

### sammcj/mcp-devtools: fix PR submitted

4 tools return internal error instead of `isError: true` for input validation failures. The bug was in the central tool handler, not individual tools. The handler returned `(nil, fmt.Errorf(...))` to the mcp-go framework, which converts any non-nil error into a `-32603` response. The fix was three lines: replace `return nil, fmt.Errorf(...)` with `return mcp.NewToolResultError(...), nil`.

[PR #258](https://github.com/sammcj/mcp-devtools/pull/258) submitted.

### Other findings

- **mcp-go SDK** ([mark3labs/mcp-go](https://github.com/mark3labs/mcp-go)): The most popular Go MCP framework has a stdio transport corruption bug. When a tool handler uses `fmt.Printf` (which writes to stdout), the output interleaves with JSON-RPC messages and corrupts the protocol framing. [PR #828](https://github.com/mark3labs/mcp-go/pull/828) submitted.
- **arxiv-mcp-server**: Returns error content in the response but forgets to set the `isError` flag. An agent checking `isError` treats "Paper not found" as a successful result.
- **Peekaboo** (Swift): Returns internal error instead of `isError: true` when macOS Screen Recording permission is not granted.
- **rmcp** (Rust SDK example): A `get_value` getter that silently decrements the counter. An agent calling it to "check" the value unknowingly mutates state.

## What Passed Clean

45 of 54 servers had zero issues. The notable clean scans:

**Anthropic's core servers** (filesystem, memory, sqlite, time, fetch, everything) all handled bad input correctly. These are the reference implementations that other servers should emulate.

**Microsoft's Playwright MCP** (31K stars) was clean across all 14 tested tools. Navigate, screenshot, click, fill, evaluate, console messages, network requests. Every error path returned `isError: true`.

**Mozilla's Firefox DevTools MCP** (29 tools, all clean). Every tool gracefully returns `isError: true` when Firefox isn't running.

**Sentry's XcodeBuildMCP** (27 tools). Every tool returns `isError: true` properly when Xcode preconditions aren't met. Exemplary error handling.

**All mcp-go SDK examples** (9 suites across everything, typed tools, structured, roots, sampling, elicitation, completion, logging). The framework itself handles error paths correctly when tool authors use it as designed.

## The Pattern

The servers that fail share a pattern: they let library exceptions propagate uncaught. The server author tested the happy path (valid inputs, working dependencies) but not what happens when the agent sends garbage.

The servers that pass share a different pattern: they wrap external calls in error handling and always return structured responses. Even when the underlying operation fails, the agent gets `isError: true` with a message it can act on.

This isn't a quality judgment on the teams. Grafana, Anthropic, and Ant Group all build excellent software. The MCP protocol's error handling semantics are subtle and easy to miss, especially when `isError` is an application-level concept but `-32603` is a transport-level concept. Most server authors are web developers who expect exceptions to bubble up to an error handler. In MCP, there's no error handler. The exception becomes a protocol error.

## Testing Your Own Server

```bash
# Zero-config audit
mcp-assert audit --server "npx your-server"

# YAML assertions for CI
mcp-assert run --suite evals/ --threshold 95

# GitHub Action
- uses: blackwell-systems/mcp-assert-action@v1
  with:
    suite: evals/
```

The audit command is the fastest way to find out if your server has these issues. It takes about 10 seconds for a server with 20 tools.

The full tool, all 546 assertions, and the complete scorecard are at [github.com/blackwell-systems/mcp-assert](https://github.com/blackwell-systems/mcp-assert).
