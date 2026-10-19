---
title: "Building AI Agents in Go: From the Agent Loop to Production"
date: 2026-10-19
draft: false
tags: ["go", "golang", "ai-agents", "agents", "llm", "book", "agent-loop", "tool-calling", "mcp", "model-context-protocol", "evals", "prompt-injection", "sandboxing", "durable-execution", "idempotency", "streaming", "context-management", "standard-library", "net-http", "encoding-json", "anthropic", "openai", "deepseek"]
categories: ["ai", "go", "books"]
description: "My new book teaches how AI agents work by building one in Go with the standard library, from a 30-line loop to a production crash-triage agent."
summary: "An agent is a model in a loop. Building AI Agents in Go has you build the loop: 17 chapters and 776 pages, from the first request to a crash-triage agent for a real Go web service, using only Go's standard library. Every example runs offline with no API key."
---

<a href="https://golang-agents.com"><img src="/images/building-ai-agents-in-go.jpg" alt="Building AI Agents in Go, by Dayna Blackwell" width="100%"></a>

An agent is a model in a loop. My new book, **[Building AI Agents in Go](https://golang-agents.com)**, has you build the loop.

It is a book for Go developers who are new to language models. You build an AI agent one tested piece at a time with Go's standard library (`net/http`, `encoding/json/v2`, `context`) and no framework, so you learn how agents, models and the harness around them actually work. You start with a 30-line loop and finish with a crash-triage agent for a real Go web service: it reproduces each bug, fixes it, and files one issue per cause, both as a command and as a service.

{{< callout type="info" >}}
**First edition (1.0), October 2026.** 17 chapters in three parts, 776 pages, plus exercise notes, a glossary and an index. $29, one price, and every update of this edition is free. [Buy it for $29](https://blackwellsystems.gumroad.com/l/go-agents), or start with the [free 27-page sample](https://golang-agents.com/sample/building-ai-agents-in-go-sample-light.pdf).
{{< /callout >}}

## What it covers

- The harness and its four-stage loop: build the request, call the model, run the tools, decide
- Inside the model: tokens, sampling, and why answers vary
- Tool calling on the wire, and designing tools a model uses well
- Context management, streaming, concurrency and MCP
- Providers and SDKs, retries, tracing and cost tracking
- Evals with sound statistics, graded by hidden tests across models
- Sandboxing, prompt-injection defenses and human approval
- Crash-safe runs that never repeat an action
- Go agent frameworks, compared against what you built

{{< mermaid >}}
flowchart LR
    req["Build the request"] --> call["Call the model"]
    call --> tools["Run the tools"]
    tools --> decide["Decide"]
    decide -->|"more tool calls"| req
    decide -->|"the model answered"| done["Return the result"]

    style req fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style call fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style tools fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style decide fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style done fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

## Measured, from recorded runs

The book doesn't ask you to take its claims on trust. Every result below comes from a recorded run:

- One sentence in a tool description decided the first move in 79 of 80 replies.
- Parallel agents were no faster than one, at about 25 to 60 percent more cost.
- The same agent, run twice, scored 15 points apart by chance.
- 910 crash scenarios, 0 duplicate actions with idempotency keys.
- The final comparison: anthropic/claude-haiku-5.5 70%, deepseek/deepseek-v4.1-flash 63%, openai/gpt-5.6-luna 20%.

## Formats and code

- **PDF** in five reading themes (Light, Dark, Tokyo Night, Gruvbox Dark, Catppuccin Latte), **EPUB**, and a code zip.
- **Code:** Go 1.27, standard library first. Every example runs offline with no API key. Apache 2.0, on GitHub at [blackwell-systems/go-agents-book-code](https://github.com/blackwell-systems/go-agents-book-code) (tag v1.0).

## Links

- Buy, $29: [blackwellsystems.gumroad.com/l/go-agents](https://blackwellsystems.gumroad.com/l/go-agents)
- The book and its companion guide: [golang-agents.com](https://golang-agents.com) (also golangagents.com)
- Free sample, 27 pages: [Light](https://golang-agents.com/sample/building-ai-agents-in-go-sample-light.pdf) or [Dark](https://golang-agents.com/sample/building-ai-agents-in-go-sample-dark.pdf)
- Code: [github.com/blackwell-systems/go-agents-book-code](https://github.com/blackwell-systems/go-agents-book-code)
