---
title: "Building AI Agents in Go: From the Agent Loop to Production"
date: 2026-10-19
lastmod: 2026-10-20
draft: false
tags: ["go", "golang", "ai-agents", "agents", "llm", "book", "agent-loop", "tool-calling", "mcp", "model-context-protocol", "evals", "prompt-injection", "sandboxing", "durable-execution", "idempotency", "streaming", "context-management", "standard-library", "net-http", "encoding-json", "anthropic", "openai", "deepseek"]
categories: ["ai", "go", "books"]
description: "A book that teaches how AI agents work by building one in Go with the standard library, from a 30-line loop to a production crash-triage agent."
summary: "An agent is a model in a loop. Building AI Agents in Go has you build the loop: 17 chapters and 776 pages, from the first request to a crash-triage agent for a real Go web service, using only Go's standard library. Every example runs offline with no API key."
---

<a href="https://golang-agents.com"><img src="/images/building-ai-agents-in-go.jpg" alt="Building AI Agents in Go, by Dayna Blackwell" width="100%"></a>

An agent is a model in a loop. My new book, **[Building AI Agents in Go](https://golang-agents.com)**, has you build the loop.

Very little of an agent is machine learning. The model sits behind an HTTP API and answers one request at a time. Everything else is ordinary program design: deciding what goes into each request, running the tools the model asks for, stopping for a clear reason, staying within a budget, retrying only what is safe, surviving a crash without repeating an action, and keeping a person in the loop for anything risky. That is the part you write, and it is the part this book teaches, in Go, with the standard library, one tested piece at a time.

{{< callout type="info" >}}
**First edition (1.0), October 2026.** 17 chapters in three parts, 776 pages, plus exercise notes, a glossary and an index. $29, one price, and every update of this edition is free. [Buy it for $29](https://blackwellsystems.gumroad.com/l/go-agents), or start with the [free 27-page sample](https://golang-agents.com/sample/building-ai-agents-in-go-sample-light.pdf).
{{< /callout >}}

## The whole loop fits on one screen

This is the agent loop from the book's first chapter, as it appears in the [companion code](https://github.com/blackwell-systems/go-agents-book-code):

```go
// Run runs the agent loop: it sends the conversation to the model, runs
// any tools the model asks for, and repeats until the model answers
// without calling a tool, the turn limit is reached, or ctx is done. It
// returns the conversation so far even when it returns an error.
func Run(ctx context.Context, m Model, tools []Tool,
	msgs []Message, lim Limits) (Result, error) {
	defs, byName := index(tools)
	msgs = slices.Clone(msgs)
	for range lim.MaxTurns {
		if err := ctx.Err(); err != nil {
			return Result{Messages: msgs}, fmt.Errorf("run: %w", err)
		}
		req := Request{Messages: msgs, Tools: defs}
		reply, err := m.Generate(ctx, req)
		if err != nil {
			err = fmt.Errorf("generate: %w", err)
			return Result{Messages: msgs}, err
		}
		msgs = append(msgs, reply.Message)
		if len(reply.Message.ToolCalls) == 0 {
			return Result{Messages: msgs}, nil
		}
		for _, call := range reply.Message.ToolCalls {
			msgs = append(msgs, runTool(ctx, byName, call))
		}
	}
	return Result{Messages: msgs}, ErrMaxTurns
}
```

Every turn passes through the same four stages:

{{< mermaid >}}
flowchart LR
    build["1 · Build the request"] --> model["2 · Call the model"]
    model --> run["3 · Run the tools"]
    run --> decision["4 · Decide"]
    decision -->|"more tool calls"| build
    decision -->|"an answer, or a limit"| result["Return the result"]

    style build fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style model fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style run fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style decision fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style result fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

`Model` is an interface with one method, `Generate`, so the same loop runs against a scripted list of replies in tests and against a real model in production. The loop sends the whole conversation on every call, because the model keeps nothing between calls, and it stops on an answer, at the turn limit, or when the context is cancelled. The rest of the book grows this function into an agent you could leave running unattended, and you can read every line of it. [The agent loop in Go](https://golang-agents.com/basics/agent-loop/) walks through it stage by stage.

## Who it's for

The book is written for Go developers who are new to language models.

- **You should be comfortable writing Go:** structs and interfaces, errors, packages, and starting a goroutine. The code uses Go 1.27 and newer parts of the standard library, such as `encoding/json/v2`, iterators and `testing/synctest`.
- **You don't need machine learning or math.** One chapter opens up the model itself (tokens, sampling, why answers vary) with a toy model in Go, and that is all the theory the book needs.
- **You don't need a framework.** The agent is built from `net/http`, `encoding/json/v2` and `context`. A late chapter ports the agent to Go agent frameworks and compares them with what you built, so you can judge any framework by the parts it replaces.

It is not a book about training models, prompt-writing tricks, or Python.

## What you build

One project runs through all 17 chapters. In Part 1 the agent fixes a failing test in a tiny Go package. From Part 2 on, it does a real job: it triages crash reports from `remind`, a small Go web service with bugs seeded on purpose. By the end it groups the reports by cause, reproduces each bug with a test, fixes the code, and files one issue per cause, as a command and as a service.

| Part | Chapters | What you build |
| --- | --- | --- |
| **1. Foundations** | 1 to 6 | A loop driven by a scripted model, then a real model with tools that fixes a failing test on its own, with budgets, offline tests, and streaming. |
| **2. Building out** | 7 to 10 | The crash-triage job: tools the model uses well, context that keeps a long investigation focused and affordable, work in parallel, and MCP. |
| **3. Production** | 11 to 17 | Other providers, retries and tracing, evals, sandboxing and human approval, crash-safe runs, frameworks compared, and the finished agent measured across models. |

The chapters, one line each:

1. **What an agent is:** run a working agent loop with no AI involved.
2. **Talking to a model:** call a real model from Go, hold a conversation, and see what each call costs.
3. **Inside the model:** how a language model turns text into tokens and picks the next one, and why it varies and makes things up.
4. **Your first real agent:** give a real model tools and watch it fix a failing test on its own.
5. **Hardening and testing the loop:** stop for clear reasons, stay within budget, and pass offline tests.
6. **Streaming the loop:** show the agent's work as it happens, and stop it partway without leaving work half done.
7. **Designing tools:** tools a model uses well, answers in a fixed structure, and measuring whether it picks the right tool.
8. **Context and memory:** improve the system prompt by measurement, and keep a long run focused, affordable, and within its context window.
9. **Concurrency:** run tools and whole investigations in parallel safely, and give one task a fresh context with a sub-agent.
10. **MCP:** use tools from other programs, and offer yours to them, through a standard protocol.
11. **Providers and SDKs:** plug in a provider whose API works differently without changing the agent.
12. **Reliability and observability:** see what the agent did, retry only what's safe, and know what each run cost.
13. **Testing and evals:** test an agent whose answers vary, and measure honestly whether a change made it better.
14. **Safety and human approval:** sandbox the tools, defend against prompt injection, and require a person's approval for risky actions.
15. **Durable, deployed agents:** keep running through crashes without repeating an action, and ship a program you can stop and restart safely.
16. **Frameworks in context:** judge any agent framework against the parts you built, and decide whether to build, adopt, or adopt for part of the job.
17. **Capstone, the crash-triage agent:** run the complete agent on a service's crash reports, as a command and as a service, and measure it across models.

## Measured, from recorded runs

The book doesn't ask you to take its advice on trust. Its claims come from recorded runs of its own code, and each finding below has a write-up, with its method and its limits, on [golang-agents.com](https://golang-agents.com/findings/):

| What was tested | What happened |
| --- | --- |
| [One planted sentence in an MCP tool's description](https://golang-agents.com/findings/tool-description-poisoning/) | It decided the first move in 79 of 80 replies, across four models. |
| [Splitting a batch of crash reports across parallel agents](https://golang-agents.com/findings/fan-out/) | No faster than one agent, at about 25 to 60 percent more cost. |
| [The same agent, run twice with nothing changed](https://golang-agents.com/findings/identical-runs/) | Two scores 15 points apart, by chance alone. |
| [Crashing the agent at every point in its loop and restarting it](https://golang-agents.com/findings/crash-sweep/) | 910 crash scenarios and no duplicate issues, with idempotency keys. |
| [Two wordings of the same tool error](https://golang-agents.com/findings/error-wording/) | "Locked" kept models retrying for a median of 18 turns; "don't retry" stopped them in 4. |
| [The same bug fix as a workflow and as an agent](https://golang-agents.com/findings/workflow-vs-agent/) | The workflow cost a quarter to a sixth as much. |
| [The finished agent on 20 held-out tasks](https://golang-agents.com/findings/the-finished-agent/) | Passed 70% of runs on `anthropic/claude-haiku-5.5`, 63% on `deepseek/deepseek-v4.1-flash`, and 20% on `openai/gpt-5.6-luna`. |

Each write-up ends with what to do about it. Two examples: write tool errors that say whether another attempt can succeed, and never trust a change smaller than the difference between two identical runs.

## Why Go, and why the standard library

An agent spends most of its time waiting on a network, running work side by side, and deciding when to stop. Go's standard library covers that job: `net/http` for the API, `encoding/json/v2` for the messages, `context` for deadlines and cancellation, goroutines for parallel tool calls, and `testing` for replaying recorded runs offline. Building on it means you see every request the agent sends and every decision it makes.

That isn't an argument against frameworks. Chapter 16 ports the agent to Go agent frameworks and credits what each one does well; the point is that you can judge a framework once you've built the parts it replaces. [Why Go for agents](https://golang-agents.com/ecosystem/why-go/) on the companion site makes the case with numbers, including what Go costs you here.

## Try it before you buy

There are three ways to see whether the book suits you, all free:

- **Run the code.** Every example runs offline from recorded replies, with no API key and no account:

  ```bash
  git clone https://github.com/blackwell-systems/go-agents-book-code
  cd go-agents-book-code/code
  go run ./ch01
  ```

  That prints an agent fixing a failing test, turn by turn. With an OpenRouter key set, the same programs talk to a real model instead.
- **Read the sample.** The first 27 pages, in [Light](https://golang-agents.com/sample/building-ai-agents-in-go-sample-light.pdf) or [Dark](https://golang-agents.com/sample/building-ai-agents-in-go-sample-dark.pdf).
- **Read the companion site.** [golang-agents.com](https://golang-agents.com) has 60 free guides on building agents in Go, from [what an agent is](https://golang-agents.com/basics/what-is-an-agent/) to [prompt injection](https://golang-agents.com/production/prompt-injection/) and [durable runs](https://golang-agents.com/production/durable-runs/), using the same companion code. The book goes step by step, with the tests and exercises.

## Formats and code

- **PDF** in five reading themes (Light, Dark, Tokyo Night, Gruvbox Dark, Catppuccin Latte), **EPUB** for e-readers, and the companion code.
- **Code:** Go 1.27, standard library first, Apache 2.0, on GitHub at [blackwell-systems/go-agents-book-code](https://github.com/blackwell-systems/go-agents-book-code), with tagged releases (the latest is v1.4). Each chapter is a full snapshot in its own directory, `ch01` to `ch17`, so you can run any step of the build on its own.

## Common questions

**Do I need an API key?** Not to follow the book. Every example replays a recorded run offline. A key from [OpenRouter](https://openrouter.ai), which gives one API for many models, lets you run the same programs live; five dollars of credit covers every early example many times over.

**Which models does it use?** Any model on OpenRouter that supports tool calls. The model is one setting, and every recorded result names the exact model that produced it. Chapter 11 adds a provider with a different native API without changing the loop.

**What do I need to know about machine learning?** Nothing beyond what chapter 3 explains with a toy model in Go.

**Do updates cost extra?** No. Buyers get every update of this edition free.

## Links

- Buy, $29: [blackwellsystems.gumroad.com/l/go-agents](https://blackwellsystems.gumroad.com/l/go-agents)
- The book and its companion guide: [golang-agents.com](https://golang-agents.com) (also golangagents.com)
- Free sample, 27 pages: [Light](https://golang-agents.com/sample/building-ai-agents-in-go-sample-light.pdf) or [Dark](https://golang-agents.com/sample/building-ai-agents-in-go-sample-dark.pdf)
- Code: [github.com/blackwell-systems/go-agents-book-code](https://github.com/blackwell-systems/go-agents-book-code)
