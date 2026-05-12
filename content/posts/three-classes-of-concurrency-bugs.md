---
title: "Three Classes of Concurrency Bugs (and Why Visual Debuggers Only Find Two)"
date: 2026-05-12
draft: false
tags: ["concurrency", "go", "debugging", "goroutines", "static-analysis", "runtime-tools", "open-source", "mcp-go", "software-engineering"]
categories: ["programming", "debugging", "best-practices"]
description: "Concurrency bugs fall into three distinct classes: behavioral, resource, and structural. Runtime tools and visual debuggers help with the first two. The third class, missing safety code, is invisible to any runtime tool in any language. Here's why, and what to do about it."
summary: "After finding three concurrency bugs in mcp-go (8.7k stars) using static code reading, I asked: would a visual tool like gotrace have caught them? The answer reveals a fundamental taxonomy of concurrency bugs that holds across all programming languages."
---

You found a concurrency bug. You reach for a tool: the race detector, a goroutine visualizer, a thread profiler. Sometimes it helps. Sometimes you stare at a perfectly clean trace and the bug is still there.

This isn't bad tooling. It's a category error. Concurrency bugs fall into three distinct classes, and runtime tools can only see two of them.

## The Taxonomy

I found this taxonomy after contributing three concurrency fixes to [mcp-go](https://github.com/mark3labs/mcp-go) (the community MCP SDK for Go, 8.7k stars). The bugs were:

1. **Missing panic recovery** in `executeTaskTool`: a goroutine running user-provided handlers had no `defer recover()`, so any panic crashed the entire process ([#880](https://github.com/mark3labs/mcp-go/pull/880))
2. **Goroutine leak** in `scheduleTaskCleanup`: nested `time.Sleep` goroutines with no cancellation path accumulated proportionally to task volume ([#880](https://github.com/mark3labs/mcp-go/pull/880))
3. **Missing panic recovery** in SSE/stdio message handlers: goroutines processing client messages had no recovery, so a malformed request could kill the server ([#882](https://github.com/mark3labs/mcp-go/pull/882))

After filing the PRs, I asked: would a visual concurrency debugger (like [gotrace](https://github.com/divan/gotrace) or [gotraceui](https://github.com/felixge/gotraceui)) have caught these? The answer is no for 2 out of 3, and "barely" for the third. That surprised me enough to think about why.

The reason: these bugs belong to different classes, and only one class is visible at runtime.

```
             Concurrency Bug Classes
             
  Behavioral          Resource           Structural
  (wrong action)      (accumulation)     (missing safety)
  ──────────────      ──────────────     ──────────────
  Data races          Goroutine leaks    Missing recover()
  Deadlocks           Connection leaks   Missing cancellation
  Channel misuse      FD exhaustion      Missing timeout
  Message ordering    Memory growth      Missing backpressure
  
  Runtime tools       Profiling tools    Static analysis
  CAN see these       CAN see these     ONLY way to find
```

## Class 1: Behavioral Bugs

The program does the wrong thing. Two goroutines corrupt shared state. A lock cycle deadlocks. A channel send blocks because the receiver closed early.

**Why runtime tools help:** The incorrect behavior *happens*. It produces observable symptoms: corrupted data, frozen goroutines, race detector warnings. A visual debugger shows you two goroutines accessing the same memory, or a goroutine stuck waiting on a channel that will never receive.

**Tools:** `-race` flag, `go tool trace`, gotrace, gotraceui, Helgrind, ThreadSanitizer, deadlock detectors.

## Class 2: Resource Bugs

The program accumulates things it should release. Goroutines pile up. Connection pools exhaust. File descriptors leak. Memory grows monotonically.

**Why runtime tools help:** The accumulation is *measurable*. A goroutine profiler shows 200 goroutines all sleeping at `scheduleTaskCleanup:55`. A goroutine count gauge climbs and never comes back down. A visual timeline shows goroutines that spawn and sit blocked for minutes.

This is the one class where a visual tool *would* have helped with the mcp-go cleanup leak. If you ran the server under `pprof`, triggered 100 tasks, and looked at the goroutine dump, you'd see:

```
100 goroutines blocked at:
  time.Sleep(...)
  server.(*MCPServer).scheduleTaskCleanup(...)
  server.go:55
```

The cluster of identical stacks makes the accumulation obvious.

**Tools:** `pprof` goroutine profiles, `statsviz`, `runtime.NumGoroutine()` metrics, `goleak` in tests, `tokio-console` (Rust), VisualVM (Java).

## Class 3: Structural Bugs

The program is missing code that should exist. No crash handler on a goroutine. No cancellation path for a blocking operation. No timeout on a network call. No backpressure on a queue.

**Why runtime tools can't help:** During normal execution, the absence is invisible. The goroutine spawns, runs the handler, completes successfully. It looks identical to a goroutine that *does* have recovery. The bug is a counterfactual: "what would happen if this handler panicked?" The answer is "the process crashes," but that hasn't happened yet.

A runtime tool observes *what the program does*. A structural bug is about *what the program doesn't do*. This is a fundamental epistemological gap.

Consider the mcp-go panic bug:

```go
go s.executeTaskTool(ctx, entry, toolToUse, request)
```

This goroutine calls user-provided handlers. If a handler panics (nil pointer, index out of range, type assertion failure), Go has no parent-catches-child mechanism. The panic propagates up, kills the goroutine, and since there's no `recover()`, crashes the process.

But if you're running gotrace, pprof, or any visual debugger, and no handler panics during your test, you see a perfectly healthy goroutine. It spawns, runs, completes. Nothing looks wrong. The bomb is there, but it hasn't gone off.

**Tools:** Code reading, grep patterns, LSP reference analysis, linters (where rules exist). There is no runtime tool.

## The Epistemological Gap

This gap isn't a tooling limitation. It's a logical impossibility. A runtime observer can only observe what *happens*. Structural bugs are defined by what *would happen under conditions that haven't occurred*. No amount of instrumentation closes this gap:

- You can't observe "this goroutine lacks recovery" by watching it not crash
- You can't observe "this sleep has no cancellation" by watching it successfully complete
- You can't observe "this call has no timeout" by watching it return quickly

The only way to detect these bugs is to examine the code structure and verify that required safety mechanisms are present at each boundary. This is inherently a static operation.

## How We Actually Found the Bugs

The approach: enumerate goroutine spawn points, verify each one has appropriate safety code.

```bash
# Find all goroutine spawn points
grep -n "go func\|go s\." server/*.go

# For each: does the function body contain recover()?
# For each: does the blocking operation have a cancellation path?
```

We used LSP tooling (`get_change_impact` to identify all goroutine-spawning functions, then read each one), but the technique is simple. Find spawn boundaries, check for safety code. It took one pass to find three PRs worth of bugs.

## The Pattern Holds Across Languages

This isn't a Go-specific insight. Every concurrent language has all three classes. What changes is which classes the language *eliminates by design*:

**Rust eliminates behavioral bugs.** The borrow checker prevents data races at compile time. You cannot compile a program with a shared-mutable race. But Rust still has resource bugs (task leaks in Tokio) and structural bugs (`.unwrap()` in a `tokio::spawn` kills the task silently).

**Erlang/OTP eliminates structural bugs.** Supervisors automatically restart crashed processes. You don't need per-process recovery code because safety is in the runtime architecture, not in each spawn site. The "let it crash" philosophy is structural safety by default.

**JavaScript eliminates behavioral bugs.** Single-threaded execution means no data races. But everything shifts to structural: unhandled promise rejections, missing `AbortController` for cancellation, callback accumulation.

**Go eliminates nothing.** All three classes are present. Goroutines are trivially cheap to spawn, which means more spawn points, which means more places where structural safety must be manually verified. The language gives you maximum concurrency power and minimum concurrency safety.

| Language | Behavioral | Resource | Structural |
|----------|-----------|----------|------------|
| Go | Data races, deadlocks | Goroutine leaks | Missing `recover()`, missing context propagation |
| Rust | (Mostly eliminated by borrow checker) | Task leaks, Arc cycles | `.unwrap()` in spawned tasks, missing `.await` |
| Java | Visibility bugs, deadlocks | Thread pool exhaustion | Missing `UncaughtExceptionHandler` |
| Python | asyncio races | Task/thread accumulation | Silent exception swallowing in threads |
| JavaScript | (Eliminated: single-threaded) | Event listener leaks | Unhandled rejections, missing abort |
| Erlang | Message ordering | Process/mailbox leaks | (Mostly eliminated by supervisors) |

## Library Code vs Application Code

This matters most for library code. The principle:

**Application code can crash.** The process dies, a supervisor restarts it, the stack trace tells you where. Recovery is external to the crash site.

**Library code cannot crash.** A library doesn't own the process it runs in. A panic kills someone else's process, takes down every unrelated goroutine sharing the address space, and produces a stack trace pointing into internals the application developer didn't write. Recovery must be at the crash site.

Go's `recover()` only works within the panicking goroutine. There is no parent-catches-child mechanism. This makes the rule absolute for library code: every goroutine you spawn must have its own `recover()`. No exceptions.

mcp-go is a library consumed by thousands of applications. A panic in any task handler kills the consuming application. This is why the fix was prioritized despite the handlers working fine during testing.

## Practical Implications

If you maintain a concurrent library:

1. **Grep for spawn points.** Every `go func()`, `go s.method()`, `tokio::spawn`, `thread::spawn`, `new Thread()`. This is your attack surface for structural bugs.

2. **Check each one for safety code.** Does it have `recover()`? Does it have a cancellation path? Does it have a timeout? Does it handle the error case of whatever it's calling?

3. **Don't trust runtime testing alone.** You can run your test suite with `-race`, `goleak`, and full integration coverage and never trigger a structural bug. The absence of failure is not evidence of safety.

4. **Write tests that exercise the failure path.** For our panic bug, we wrote a test with a handler that deliberately panics and asserts the process survives:

```go
func TestExecuteTaskTool_PanicRecovery(t *testing.T) {
    // Register a task tool that panics
    server.AddTaskTool("panicker", func(ctx context.Context, req Request) (*Result, error) {
        panic("handler bug")
    })
    
    // Execute in goroutine
    go server.executeTaskTool(ctx, entry, tool, request)
    
    // If we reach this line, the process didn't crash
    select {
    case <-entry.done:
        assert.Equal(t, TaskStatusFailed, entry.task.Status)
    case <-time.After(5 * time.Second):
        t.Fatal("task never completed")
    }
}
```

Without the fix, this test crashes the test process itself.

## Why Visual Debuggers Are Still Valuable

This post isn't anti-tooling. Runtime tools are essential for behavioral and resource bugs. `pprof` goroutine profiles are the fastest way to find leaks in production. The race detector catches data corruption before it reaches users. `go tool trace` reveals lock contention that benchmarks miss.

The point is narrower: know which class you're looking at before reaching for a tool. If you suspect a behavioral bug (race, deadlock), runtime tools are your best bet. If you suspect a resource bug (leak, exhaustion), profiling will show it. If you suspect a structural bug (missing safety code), the only tool is reading the code.

Or, more concisely: **a tracer shows you what goroutines do, not what they should do.**
