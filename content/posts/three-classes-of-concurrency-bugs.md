---
title: "Three Classes of Concurrency Bugs"
date: 2026-05-12
draft: false
tags: ["concurrency", "go", "debugging", "goroutines", "static-analysis", "runtime-tools", "software-engineering"]
categories: ["programming", "debugging", "best-practices"]
description: "Concurrency bugs fall into three distinct classes: behavioral, resource, and structural. Runtime tools and visual debuggers help with the first two. The third class, missing safety code, is invisible to any runtime tool in any language. Here's why, and what to do about it."
summary: "Would a visual debugger like gotrace have caught three concurrency bugs found via static code reading in a production Go library? The answer reveals a fundamental taxonomy that holds across all programming languages."
---

You found a concurrency bug. You reach for a tool: the race detector, a goroutine visualizer, a thread profiler. Sometimes it helps. Sometimes you stare at a perfectly clean trace and the bug is still there.

The tool is fine. You're looking at the wrong class of bug. Concurrency bugs fall into three distinct classes, and runtime tools can only see two of them.

## The Taxonomy

I arrived at this taxonomy after finding three concurrency bugs in a production Go MCP server library via static code reading:

1. **Missing panic recovery** in `executeTaskTool`: a goroutine running user-provided handlers had no `defer recover()`, so any panic crashed the entire process
2. **Goroutine leak** in `scheduleTaskCleanup`: nested `time.Sleep` goroutines with no cancellation path accumulated proportionally to task volume
3. **Missing panic recovery** in SSE/stdio message handlers: goroutines processing client messages had no recovery, so a malformed request could kill the server

Afterward I asked: would a visual concurrency debugger (like [gotrace](https://github.com/divan/gotrace) or [gotraceui](https://github.com/felixge/gotraceui)) have caught these? The answer is no for 2 out of 3, and "barely" for the third. That surprised me enough to think about why.

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

## Why Three?

The taxonomy falls out of a single distinction: **presence vs. absence.**

Classes 1 and 2 are bugs of presence. Something wrong is happening. A race *produces* corruption. A leak *produces* accumulating goroutines. The wrongness manifests as observable state in a running program.

Class 3 is a bug of absence. Nothing wrong is happening right now. The goroutine runs, completes, and exits cleanly. The bug exists only as a conditional: *if* a handler panics, *then* the process will crash. But right now, no handler is panicking. The code is missing something it should contain, but this absence produces no runtime artifact until the triggering condition occurs.

This is why exactly two of the three classes yield to runtime observation. Runtime tools observe what *is*. They cannot observe what *isn't*. Two classes produce observable phenomena. One produces nothing until it's too late.

The split also explains why test suites have blind spots. Tests exercise paths: "call this function, assert that result." You can achieve 100% line coverage and 100% branch coverage and still have structural bugs everywhere, because coverage measures which lines *executed*, not which lines *should exist but don't*. You cannot cover code that hasn't been written. A missing `recover()` has no line to cover. A missing timeout has no branch to exercise. The test framework literally cannot represent "this safety mechanism should be here" as a test case, unless you write a meta-test that asserts structural properties about the code itself (which is what linters are).

## Class 1: Behavioral Bugs

The program does the wrong thing. Two goroutines corrupt shared state. A lock cycle deadlocks. A channel send blocks because the receiver closed early.

**Why runtime tools help:** The incorrect behavior *happens*. It produces observable symptoms: corrupted data, frozen goroutines, race detector warnings. A visual debugger shows you two goroutines accessing the same memory, or a goroutine stuck waiting on a channel that will never receive.

**Tools:** `-race` flag, `go tool trace`, gotrace, gotraceui, Helgrind, ThreadSanitizer, deadlock detectors.

## Class 2: Resource Bugs

The program accumulates things it should release. Goroutines pile up. Connection pools exhaust. File descriptors leak. Memory grows monotonically.

**Why runtime tools help:** The accumulation is *measurable*. A goroutine profiler shows 200 goroutines all sleeping at `scheduleTaskCleanup:55`. A goroutine count gauge climbs and never comes back down. A visual timeline shows goroutines that spawn and sit blocked for minutes.

This is the one class where a visual tool *would* have helped with the cleanup leak. If you ran the server under `pprof`, triggered 100 tasks, and looked at the goroutine dump, you'd see:

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

Consider the panic bug:

```go
go s.executeTaskTool(ctx, entry, toolToUse, request)
```

This goroutine calls user-provided handlers. If a handler panics (nil pointer, index out of range, type assertion failure), Go has no parent-catches-child mechanism. The panic propagates up, kills the goroutine, and since there's no `recover()`, crashes the process.

But if you're running gotrace, pprof, or any visual debugger, and no handler panics during your test, you see a perfectly healthy goroutine. It spawns, runs, completes. Nothing looks wrong. The bomb is there, but it hasn't gone off.

**Tools:** Code reading, grep patterns, LSP reference analysis, linters (where rules exist). There is no runtime tool.

## The Epistemological Gap

A runtime observer can only observe what *happens*. Structural bugs are defined by what *would happen under conditions that haven't occurred*. No amount of instrumentation closes this gap:

- You can't observe "this goroutine lacks recovery" by watching it not crash
- You can't observe "this sleep has no cancellation" by watching it successfully complete
- You can't observe "this call has no timeout" by watching it return quickly

This is a logical impossibility, not a tooling limitation. Even a hypothetical perfect tracer that records every goroutine state transition, every memory access, every channel operation, will show a structurally unsafe goroutine as identical to a structurally safe one during normal execution. The difference between them is what happens *on the error path*, and if the error path never fires during your observation window, they're indistinguishable.

Distributed systems theory has a related concept. Lamport's safety properties ("bad things don't happen") and liveness properties ("good things eventually happen") are both about observable system behavior. Structural bugs don't fit cleanly into either category. They're about *preparedness*: "when bad things happen, the system degrades gracefully rather than catastrophically." Preparedness is a property of code structure, not of runtime behavior. You can't model-check for "this goroutine should contain a recover()" without first specifying the rule "all library goroutines that call user code must recover."

Which leads to the real constraint: **detecting structural bugs requires a specification of what should be present.** Our grep for `go func()` without `recover()` was implicitly applying the specification "every library goroutine that calls user-provided code must have panic recovery." Without that rule (in your head, in a linter, in a code review checklist), the absence is invisible. The code works fine. The bomb is there, but there's no alarm until it detonates.

This is why linters can catch *some* structural bugs (like `errcheck` catching ignored error returns) but not all of them. Every linter rule encodes a structural specification: "this pattern must be accompanied by that safety mechanism." The bug classes that don't have linter rules yet are the ones where nobody has formalized the specification. "Every spawned goroutine in a library must recover" is well-understood enough to encode. "Every blocking call should have a timeout proportional to the caller's SLA" requires too much domain context for a general linter.

The only way to detect structural bugs is to examine the code structure against a specification of what should exist at each boundary. This is inherently a static operation.

## How We Actually Found the Bugs

The approach: enumerate goroutine spawn points, verify each one has appropriate safety code.

```bash
# Find all goroutine spawn points
grep -n "go func\|go s\." server/*.go

# For each: does the function body contain recover()?
# For each: does the blocking operation have a cancellation path?
```

We used LSP tooling (`get_change_impact` to identify all goroutine-spawning functions, then read each one), but the technique is simple. Find spawn boundaries, check for safety code. One pass through the codebase surfaced all three bugs.

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

A library like this is consumed by thousands of applications. A panic in any task handler kills the consuming application. The fix is high priority despite the handlers working fine during testing.

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

Runtime tools are essential for behavioral and resource bugs. `pprof` goroutine profiles are the fastest way to find leaks in production. The race detector catches data corruption before it reaches users. `go tool trace` reveals lock contention that benchmarks miss.

The point is narrower: know which class you're looking at before reaching for a tool. If you suspect a behavioral bug (race, deadlock), runtime tools are your best bet. If you suspect a resource bug (leak, exhaustion), profiling will show it. If you suspect a structural bug (missing safety code), the only tool is reading the code.

Or, more concisely: **a tracer shows you what goroutines do, not what they should do.**
