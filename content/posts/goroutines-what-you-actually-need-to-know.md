---
title: "Goroutines: What You Actually Need to Know"
date: 2026-05-04
draft: false
tags: ["go", "golang", "goroutines", "concurrency", "scheduler", "csp", "channels", "parallelism", "runtime", "GMP", "threads", "operating-systems", "performance", "systems-programming", "mental-models"]
categories: ["programming", "go"]
description: "Most Go developers use goroutines as magic async functions. That's not what they are. To debug goroutine leaks, write correct concurrent code, and avoid scheduler traps, you need the real mental model: goroutines are to the Go runtime what processes are to the OS."
summary: "Most Go developers can start a goroutine. Far fewer can explain what actually happens when they do. This post builds the real mental model: the G/M/P scheduler, why goroutines aren't threads, what CSP actually means, and the analogy that makes everything click: the Go runtime is an operating system for goroutines."
---

{{< callout type="info" >}}
**Prerequisites**

This article assumes you can read Go and have written goroutines before. If you're new to Go concurrency, start with the [Go Tour concurrency section](https://go.dev/tour/concurrency/1) and come back when channel syntax feels familiar.
{{< /callout >}}

Ask a Go developer what a goroutine is and you'll hear: "it's a lightweight thread." That's not wrong. It's just so incomplete it's nearly useless for reasoning about real concurrency problems.

Here's a better answer: **a goroutine is to the Go runtime what a process is to the operating system.** The Go runtime is a miniature OS running inside your program. It schedules goroutines onto OS threads the same way an OS schedules processes onto CPU cores. It manages their memory, handles their blocking, and multiplexes thousands of them onto a handful of real threads, exactly as an OS multiplexes hundreds of processes onto a handful of physical cores.

This is not a metaphor. It is structurally identical. Once you see it, everything about Go concurrency follows from it.

---

## What "Lightweight Thread" Actually Means

"Goroutines are lightweight threads managed by the Go runtime."

Fine. But what does that actually mean? Three questions:

1. If a goroutine makes a blocking system call (like reading from disk), does it block the OS thread it's running on?
2. Can two goroutines run in parallel on two different CPU cores simultaneously?
3. If you start 100,000 goroutines on an 8-core machine, how many OS threads does Go create?

Most tutorials teach: yes, yes, one per goroutine. That mental model will cause you to write slow code, miss goroutine leaks, and blame scheduler behavior on bugs in your own code.

The actual answers require understanding the Go scheduler. Let's build that understanding from the bottom up.

---

## Start With the OS: The Problem Go Solved

A modern OS runs hundreds of processes on a handful of CPU cores. On a 4-core machine, only 4 processes can execute simultaneously, one per core. The OS creates the illusion of concurrent execution through **preemptive multitasking**: every few milliseconds, a hardware timer fires, the running process is suspended (registers and stack pointer saved to its Process Control Block in the kernel), and the scheduler picks the next process. This is a **context switch**.

Context switches are expensive. Switching between processes costs 1-10 microseconds: save CPU registers, swap virtual memory page tables (each process has its own address space), potentially flush TLB entries and CPU caches.

Threads are cheaper. Multiple threads share the same address space, so no page table swap is needed. Thread context switches cost 100-300 nanoseconds. But threads still carry 1-8MB of stack allocated upfront, cost 10-50 microseconds to create, and require kernel involvement for every scheduling decision.

Now: you're writing a web server. Each request makes a database query (10ms round trip), does some computation (1ms), and responds. With OS threads:

```
10,000 concurrent requests
= 10,000 threads
= 10,000 × 1MB stack = 10GB RAM just for stacks
+ kernel scheduler now managing 10,000 threads
```

This is the C10K problem. It drove the creation of event loops and async/await. Go took a different path: implement the scheduler in user space, with data structures designed from the start for millions of concurrent units.

---

## The Go Scheduler: G, M, P

The Go runtime implements a scheduler that manages goroutines the way an OS manages processes. Three types of entities:

**G (Goroutine):** The goroutine itself: its stack (starting at 8KB, growable), program counter, status, and the closure it's running. Analogous to a Process Control Block.

**M (Machine):** An OS thread. The entity that actually executes instructions on a CPU core. The Go runtime creates and parks M's as needed; the default limit is 10,000. Analogous to the physical thread executing a process.

**P (Processor):** A scheduling token and run queue, one per logical core of parallelism. P is not a CPU core and not an OS thread; it is the Go runtime's bookkeeping unit for "one slot of concurrent Go execution." Each P owns a local queue of runnable goroutines and a cache of runtime resources (memory allocator state, deferred work). An M must hold a P to execute any Go code at all; without one, an M sits idle. The number of P's is set by `GOMAXPROCS` (default: `runtime.NumCPU()`), which is why `GOMAXPROCS` controls the degree of true parallelism rather than the number of goroutines or threads. P exists to decouple "I have a runnable goroutine" from "I have an OS thread," the separation that makes the blocking story work, as we'll see shortly.

The hierarchy:

{{< mermaid >}}
graph TD
    subgraph G["G — Goroutines (thousands to millions)"]
        g1(G1)
        g2(G2)
        g3(G3)
        g4(G4)
        g5(G5)
        g6(G6)
        gn(...)
    end

    subgraph P["P — Logical Processors (GOMAXPROCS, e.g. 4)"]
        p0(P0\nrun queue)
        p1(P1\nrun queue)
        p2(P2\nrun queue)
        p3(P3\nrun queue)
    end

    subgraph M["M — OS Threads"]
        m0(M0)
        m1(M1)
        m2(M2)
        m3(M3)
    end

    subgraph CPU["CPU Cores (physical hardware)"]
        c0(Core 0)
        c1(Core 1)
        c2(Core 2)
        c3(Core 3)
    end

    g1 & g2 --> p0
    g3 & g4 --> p1
    g5 --> p2
    g6 & gn --> p3

    p0 --> m0
    p1 --> m1
    p2 --> m2
    p3 --> m3

    m0 --> c0
    m1 --> c1
    m2 --> c2
    m3 --> c3
{{< /mermaid >}}

{{< callout type="info" >}}
**The OS Analogy, Made Precise**

| OS Concept | Go Runtime Concept |
|------------|-------------------|
| Process | Goroutine (G) |
| Process Control Block | G struct |
| CPU core | Logical Processor (P) |
| OS thread running a process | M holding a P, executing a G |
| Process context switch | Goroutine context switch |
| Process scheduler | Go runtime scheduler |
| `fork()` | `go func()` |
| Process stack (1-8MB, fixed at creation) | Goroutine stack (8KB initial, copied to a larger allocation on overflow, up to 1GB) |
| Process blocked on I/O | Goroutine parked, P released |
| Process scheduler per-CPU run queue | P's local run queue |
| Scheduler work stealing | P steals from another P's queue |
{{< /callout >}}

### Why P Exists

The naive design would have M's schedule G's directly. P exists to separate "permission to run Go code" from "an OS thread." This separation is what enables the key feature of the scheduler: handling blocking without wasting threads, which we'll get to shortly.

The number of P's bounds the number of goroutines that can run simultaneously. But it does not bound the number of goroutines that can *exist*. Hundreds of thousands of goroutines can be parked, waiting, in queues, all without consuming an OS thread. They only need a P (and an M) when they're actually executing.

This is the OS analogy made concrete: on a 4-core machine running Linux with 200 processes, only 4 processes execute at any CPU cycle. The other 196 are in scheduler queues. The Go runtime does the same thing for goroutines, in user space, without a kernel call.

---

## What Actually Happens When You Write `go func()`

```go
go func() {
    doWork()
}()
```

Most developers think: "this starts a goroutine, which runs on a separate thread." Here's what actually happens:

1. The runtime allocates a G struct with an 8KB stack. Program counter is set to the start of the closure.
2. The G is placed on the **local run queue** of the current P.
3. The current goroutine continues executing. It is not interrupted.
4. At the next scheduling point (a function call, channel operation, or system call), the scheduler may switch to the new G or continue with the current one.
5. The new G is eventually picked up by a free P (either the current one, or another P via work stealing).

No OS thread is created. No kernel call. No `pthread_create`. Just a small heap allocation and a pointer added to a queue. This is why starting a goroutine costs roughly 3 microseconds and a few KB of memory, compared to 50 microseconds and 1MB for an OS thread.

Starting 100,000 goroutines costs about 800MB of stack (100,000 × 8KB) plus negligible scheduling overhead. The same 100,000 OS threads would need 100GB, and your kernel would refuse long before that.

### Work Stealing

When a P's local run queue empties, it doesn't wait. It **steals** from another P:

```
P0 run queue: [G1, G2, G3, G4, G5, G6]
P1 run queue: []  ← empty

P1 steals half:
  P0: [G1, G2, G3]
  P1: [G4, G5, G6]
```

{{< mermaid >}}
graph LR
    subgraph before["Before stealing"]
        p0q["P0 queue\nG1 G2 G3 G4 G5 G6"]
        p1q["P1 queue\n(empty)"]
    end

    subgraph after["After P1 steals half"]
        p0a["P0 queue\nG1 G2 G3"]
        p1a["P1 queue\nG4 G5 G6"]
    end

    p0q -- "P1 steals G4 G5 G6" --> p0a
    p1q -- "P1 now has work" --> p1a
{{< /mermaid >}}

Work stealing keeps all cores busy without any programmer intervention. You don't need to manually shard work across goroutines for CPU-bound tasks; the scheduler redistributes automatically.

---

## Blocking: The Scheduler's Defining Feature

This is where most developers' mental model falls apart, and where the OS analogy pays off most.

When a goroutine blocks, *what happens to the OS thread?*

The answer depends on *why* it blocks.

### Go-Aware Blocking (Channels, Mutexes, Sleep)

For blocking operations the runtime controls (channel receives, `sync.Mutex.Lock()`, `time.Sleep()`), the goroutine is **parked**. It leaves the run queue entirely. The P is immediately available for another goroutine. The OS thread is not blocked.

{{< mermaid >}}
sequenceDiagram
    participant G1
    participant Runtime
    participant P0
    participant M1
    participant G2

    G1->>Runtime: val := <-ch (empty channel)
    Runtime->>G1: status → waiting, remove from queue
    Runtime->>G1: register in channel recvq
    Runtime->>P0: pick next goroutine
    P0->>M1: schedule G2
    M1->>G2: executing (M1 never blocked)

    Note over G1: parked — no CPU, no thread

    G2->>Runtime: sender writes to ch
    Runtime->>G1: dequeue from recvq, status → runnable
    Runtime->>P0: add G1 back to run queue
    P0->>M1: schedule G1
    M1->>G1: resumes from <-ch
{{< /mermaid >}}

The OS thread never slept. It was doing other work the entire time G1 was parked. This is how one OS thread can serve thousands of concurrent goroutines, the same way one CPU core serves hundreds of OS processes.

### Blocking Syscalls (File I/O, CGo)

Some syscalls cannot be made non-blocking at the OS level: `read()` on a pipe with no data, certain file I/O on Linux, CGo calls into blocking C code. When a goroutine makes such a call, the OS thread executing it will genuinely block in the kernel. The Go runtime can't interrupt it.

The compiler inserts calls to `entersyscall` and `exitsyscall` around every syscall. `entersyscall` **detaches the P** from the M before the syscall executes. The now-free P can be picked up by another M (either an idle one from the thread pool, or a newly created one). The blocking M continues into the kernel call, P-less.

{{< mermaid >}}
sequenceDiagram
    participant G1
    participant M1
    participant P0
    participant M2
    participant Kernel
    participant G2

    G1->>M1: read(fd, buf, n)
    M1->>P0: entersyscall() — detach P0
    P0->>M2: P0 acquired by M2
    M2->>G2: M2/P0 picks up G2, continues

    M1->>Kernel: blocked syscall (no P)
    Note over M1,Kernel: M1 stalled in kernel<br/>P0 is free, work continues on M2

    Kernel->>M1: I/O complete, syscall returns
    M1->>P0: exitsyscall() — try to reacquire P
    alt P is free
        P0->>M1: M1 takes P0, G1 continues
    else no P available
        M1->>G1: G1 → global run queue, M1 idles
    end
{{< /mermaid >}}

This is how the Go runtime prevents one slow file read from stalling an entire GOMAXPROCS of goroutines. The M stalls; the P keeps working.

### Network I/O Is Different

Network I/O doesn't use the blocking syscall path at all. The `net` package registers file descriptors with `epoll` (Linux) or `kqueue` (macOS/BSD) for non-blocking I/O. When a goroutine reads from a network connection with no data available, it parks itself, the same as a channel receive. A dedicated **netpoller** goroutine (running in its own M) monitors all registered file descriptors and unparks the waiting goroutines when their data arrives.

One goroutine handles the I/O multiplexing for all 100,000 concurrent connections. The waiting goroutines consume no CPU, no thread, and no P slot. This is how Go web servers achieve the concurrency of an event loop with the code structure of blocking calls.

---

## To Answer the Diagnostic Questions

Now we can answer properly:

**1. Does a blocking syscall block the OS thread?**
Yes, but the P is detached first via `entersyscall`, so other goroutines keep running on another M. The blocked M stalls in the kernel while work continues elsewhere.

**2. Can two goroutines run in parallel?**
Yes, if `GOMAXPROCS > 1`. Two goroutines on two different P's, each held by a different M, each on a different CPU core: genuinely parallel.

**3. How many OS threads for 100,000 goroutines on an 8-core machine?**
Approximately 8 M's for running goroutines (one per P), plus however many M's are currently blocked in syscalls. If 50 goroutines are doing blocking file I/O simultaneously, there are 58 M's. The number of M's is not bounded by GOMAXPROCS; it is bounded by how many goroutines are simultaneously blocked in the kernel, up to the 10,000 default limit.

---

## Context Switches: Cooperative and Preemptive

The Go scheduler is a hybrid. Originally it was purely cooperative: goroutines yielded at function call boundaries, where the runtime inserted scheduling checks. A goroutine doing tight arithmetic in a loop with no function calls would never yield, starving other goroutines.

Go 1.14 added **asynchronous preemption**: the runtime's monitor thread (`sysmon`) runs every 10ms and can signal any goroutine that has been running for too long, forcing a yield even mid-computation. This is done by sending a signal (SIGURG) to the OS thread running the goroutine.

The result: goroutine context switches happen cooperatively at function calls (the fast, common path) and preemptively via signal every 10ms (the fallback). This is architecturally identical to how operating systems handle preemption: most context switches happen on blocking calls (cooperative equivalent), with the timer interrupt as the safety net.

Goroutine context switches cost roughly **100-300 nanoseconds**, faster than OS thread switches (300ns-1µs) because no kernel call is involved and the address space is shared, so no page table manipulation is needed. The entire cost is saving a handful of registers and updating the P's current goroutine pointer.

---

## CSP: Why Channels Are Not Optional

The `go` keyword and channels are not convenience syntax for threads and mutexes. They embody a specific theory of concurrent correctness: **Communicating Sequential Processes**, formalized by Tony Hoare in 1978.

The problem CSP was designed to solve: shared memory is hard to reason about. Any thread can touch any shared variable at any time. Correctness requires reasoning about every possible interleaving of every thread's every instruction. As thread count grows, that space explodes. This is why multithreaded code is famously difficult to test and debug: you cannot reproduce most concurrency bugs on demand, because they depend on exact scheduling timing.

CSP's answer: don't share memory. Make communication the only mechanism for data transfer. Each goroutine owns its own state. The only way data moves between goroutines is through a channel, an explicit, typed conduit. No two goroutines ever touch the same memory simultaneously, not because of a lock, but because the design makes it structurally impossible.

Go's maxim captures this: **"Do not communicate by sharing memory; instead, share memory by communicating."**

To see why this matters, compare the two approaches on a concrete example. Shared memory with a mutex:

```go
var counter int
var mu sync.Mutex

func increment() {
    mu.Lock()
    counter++  // correct only because programmer remembered to lock
    mu.Unlock()
}
```

The correctness of this code depends entirely on every call site in the entire codebase remembering to acquire `mu`. Miss it once in any goroutine, in any function, anywhere, and you have a data race. The mutex is advisory. Nothing enforces it.

Channel-based ownership:

```go
func counter(inc <-chan struct{}, val chan<- int) {
    n := 0
    for range inc {
        n++
    }
    val <- n  // only this goroutine ever touches n
}
```

`n` is never shared. It exists only inside `counter`. No other goroutine can access it, not because there's a lock, but because there's no path to it from outside the goroutine. The compiler enforces this: you cannot pass `n` to another goroutine without going through a channel. The correctness is structural, not advisory.

### What a Channel Actually Is

Channels are not magic. They are a data structure in the Go runtime, roughly:

```go
// Simplified from Go's internal runtime/chan.go
type hchan struct {
    qcount   uint           // elements currently in queue
    dataqsiz uint           // capacity of circular buffer
    buf      unsafe.Pointer // pointer to circular buffer
    elemsize uint16         // size of one element
    closed   uint32
    sendq    waitq          // goroutines blocked on send
    recvq    waitq          // goroutines blocked on receive
    lock     mutex          // protects all fields
}
```

A channel is a mutex-protected circular buffer with two queues of parked goroutines. The runtime's locking is invisible to you. You `<-ch` and either get a value or park yourself in `recvq`. You `ch <- v` and either enqueue or park yourself in `sendq`. The runtime handles the coordination.

The `lock` is what makes channels safe, not your discipline, not code review, not tests. The invariant is enforced by the data structure itself.

### Select: Waiting on Multiple Channels at Once

```go
select {
case msg := <-ch1:
    handle(msg)
case ch2 <- result:
    // delivered
case <-ctx.Done():
    return
}
```

When `select` executes, if multiple cases are ready, Go picks one **uniformly at random**. This is specified behavior, not implementation detail. It prevents starvation: if `select` always picked the first ready case, a high-throughput channel could permanently block a low-throughput one from ever being serviced.

When no case is ready, the goroutine parks itself simultaneously in the `recvq`/`sendq` of all channels in the select. Whichever channel becomes ready first wakes the goroutine and deregisters it from all the others. This is the runtime mechanism behind Go's first-class support for timeouts, cancellation, and fan-in.

---

## The Goroutine Stack

OS threads have fixed stacks (1-8MB) allocated at creation. Allocate too little and you overflow. Allocate too much and you waste memory for every thread. You need to know your call depth upfront, which you often don't.

Goroutines start with an **8KB stack** and grow as needed. When the runtime detects insufficient stack space at a function's entry (via a stack growth check inserted by the compiler), it:

1. Allocates a new stack, typically 2x the current size
2. Copies the entire current stack to the new allocation
3. Updates all stack pointers and return addresses to reflect the new location
4. Continues execution on the new stack

The copy is safe because Go's garbage collector tracks all interior pointers. No raw unsafe pointer into the stack exists in normal Go code, so the copy is coherent.

The stack can grow up to 1GB by default. In practice, most goroutines use 8-64KB. This is what makes 100,000 goroutines viable at startup: you're reserving 8KB per goroutine, not 1MB. The rare goroutine with deep recursion pays the growth cost only when it actually recurses.

**Escape analysis** exists partly because of this. When the compiler sees that a local variable's address escapes the current goroutine (taken by `go func()`, sent on a channel, stored in a heap-allocated struct), it moves the variable to the heap. The programmer doesn't manage this manually; the compiler does it automatically. The reason: a local variable's memory address changes when the stack grows, so any pointer that outlives the stack frame must live on the heap instead.

---

## GOMAXPROCS: Parallelism vs Concurrency

`GOMAXPROCS` controls the number of P's, and therefore the number of goroutines that can execute simultaneously.

```go
runtime.GOMAXPROCS(1)               // only 1 goroutine runs at a time
runtime.GOMAXPROCS(runtime.NumCPU()) // default: one per core
```

This is the exact analogue of CPU core count in an OS: more cores means more processes running simultaneously. The number of goroutines that can *exist* is unrelated to GOMAXPROCS; it is bounded only by available memory.

With `GOMAXPROCS(1)`, all goroutines run on one OS thread, interleaved. True parallelism is eliminated. This is useful for testing: deterministic scheduling makes some race conditions reproducible that would be timing-dependent with multiple P's. (It does not eliminate all races; goroutine scheduling still occurs.)

{{< callout type="warning" >}}
**The Misconception That Trips People Up**

`GOMAXPROCS(4)` does not mean only 4 goroutines can run. It means only 4 can run *simultaneously*. Any number can exist: parked on channels, waiting in run queues, blocked on mutexes. Up to 4 are executing at any given CPU cycle.

4 CPU cores on a Linux machine doesn't limit you to 4 processes. It limits you to 4 processes executing simultaneously. The Go scheduler works identically.
{{< /callout >}}

### Fractional CPU Allocations in Containers

The default of `runtime.NumCPU()` breaks in shared computing environments: Kubernetes pods, Docker containers, cloud VMs with fractional vCPU allocations.

`runtime.NumCPU()` reads the host machine's physical core count, not your container's CPU quota. A pod with `resources.limits.cpu: 500m` (half a core) running on an 8-core node gets `GOMAXPROCS = 8`. The Go runtime creates 8 P's and 8 OS threads. The Linux CFS scheduler then throttles your cgroup to 50% of one core's time, leaving 8 threads competing for the equivalent of half a core. The constant preemption and context switching between those 8 threads costs more than the useful work they do.

The fix is `go.uber.org/automaxprocs`. A single blank import in `main.go` is all it takes:

```go
import _ "go.uber.org/automaxprocs"
```

It reads the cgroup CPU quota (`cpu.cfs_quota_us / cpu.cfs_period_us`) at startup and sets `GOMAXPROCS` to match the actual allocation, rounded up to at least 1. Half a core becomes `GOMAXPROCS = 1`. 1.5 cores becomes `GOMAXPROCS = 2`. The Go scheduler now has an accurate picture of how much CPU it actually has.

This is worth adding to any Go service running in Kubernetes or any container platform that throttles CPU. The default behavior isn't wrong in a bare-metal context, but in a shared environment it actively works against you.

### "We Run Single-Core Containers, So Goroutines Don't Help Us"

This argument conflates parallelism with concurrency, and it's wrong.

With `GOMAXPROCS = 1`, only one goroutine executes at any CPU cycle. There is no parallelism. But a web server's bottleneck is almost never CPU; it's waiting: waiting for the database to respond, waiting for a downstream API, waiting for bytes to arrive on a socket. Goroutines spend the vast majority of their time parked, not running.

On a single-core container handling 1,000 concurrent HTTP requests, those 1,000 goroutines are almost all parked at any given moment, waiting for their respective database queries to return. The one core cycles through whichever goroutines have data to process. The single core is never idle waiting for I/O because there is always another goroutine ready to run.

Compare this to a single-threaded event loop (Node.js): the mechanics are similar, but goroutines let you write blocking code that reads sequentially. The Go scheduler parks the goroutine on the blocking operation and runs something else. With an event loop, you must explicitly yield via `async/await` or callbacks, and any accidental synchronous blocking stalls the entire server.

Single-core Go is fast for I/O-bound workloads because of concurrency, not parallelism. The argument only holds if your service is CPU-bound, doing heavy computation rather than waiting on I/O. In that case, a single core is a real constraint. But for the typical API server, message processor, or proxy, `GOMAXPROCS = 1` with goroutines outperforms a single-threaded model because the scheduler keeps the one available core fully occupied.

---

## Goroutine Leaks: The OS Analogy Applied

In an OS, if a process spawns child processes that never terminate, your machine accumulates zombie processes consuming resources until the system slows to a halt. You cannot garbage collect processes; they live until they exit.

Goroutines work the same way. The Go runtime does not garbage collect goroutines. A goroutine lives until its function returns. If you start a goroutine that blocks forever on a channel nobody writes to, that goroutine exists until your program exits.

```go
func leak() {
    ch := make(chan int)  // never written to
    go func() {
        val := <-ch      // parks forever
        process(val)
    }()
    // ch goes out of scope, but the goroutine is still parked on it
    // Every call to leak() adds one permanently parked goroutine
}
```

In a long-running service, this accumulates. Leaked goroutines:
- Hold their stack memory (8KB minimum, growing with execution depth)
- Pin anything they close over in heap memory (the GC won't collect it)
- Appear in `runtime.NumGoroutine()` and goroutine profiles in `pprof`

The fix is always the same: every goroutine needs a clear termination condition.

```go
// Every goroutine should handle context cancellation
func worker(ctx context.Context, jobs <-chan Job) {
    for {
        select {
        case job, ok := <-jobs:
            if !ok {
                return // channel closed, clean exit
            }
            process(job)
        case <-ctx.Done():
            return // caller cancelled, clean exit
        }
    }
}
```

The `goleak` package from Uber (`go.uber.org/goleak`) provides `goleak.VerifyNone(t)` for tests. It fails if any goroutines started during the test are still running at cleanup. Adding this to your test suite catches leaks automatically at test time, not in production.

---

## Why Goroutines Are Not "Async Functions"

Python and JavaScript developers sometimes map goroutines onto their `async/await` mental model. They are fundamentally different things.

`async/await` is a compiler transformation. An `async` function is rewritten into a state machine. When it `await`s, it yields to an event loop running on a single thread. The "concurrency" is cooperative and single-threaded; at most one task executes at any CPU cycle.

Goroutines are scheduled entities. They run on real OS threads. They can execute in parallel. They can block (the runtime handles the thread management). There is no function coloring in Go. In Python, a `def` function cannot `await` a coroutine without being marked `async`. This constraint propagates upward: once you have one async function, callers must become async, their callers must become async, and so on. Go has none of this. Any goroutine can do anything. A function that sleeps, reads from disk, or waits on a channel looks identical to the caller. The runtime handles the scheduling transparently.

The Go concurrency model is not an event loop with a nicer syntax. It's a fully preemptive, parallel, work-stealing scheduler with cooperative semantics as the fast path.

---

## Comparison: OS Threads

OS threads are what most systems languages (C, C++, Rust `std::thread`, Java pre-Loom) give you directly. One thread per concurrent task. The OS schedules them onto CPU cores. They share an address space within a process.

The problem is resource cost. Each OS thread carries a 1-8MB stack allocated at creation, regardless of whether the thread does anything. Creating one requires a kernel call (10-50 microseconds). The OS scheduler has no knowledge of your application; it sees all threads as equally worthy of CPU time, switching between them at fixed intervals whether they're doing useful work or sleeping. At 10,000 concurrent threads, the scheduler overhead and memory footprint become the bottleneck rather than the work itself.

Goroutines address exactly this. The 8KB starting stack instead of 1-8MB means you can have 1,000x more concurrent units for the same memory. The user-space scheduler means context switches cost 100-300ns rather than 1-10µs and don't require kernel involvement. The P-based design means goroutines waiting on I/O consume no CPU and no OS thread.

The deeper difference is in blocking behavior. When an OS thread blocks on a socket read, it is descheduled by the OS and another thread runs. That's fine if you have 100 threads. With 100,000 goroutines, the same mechanism at the OS level would require 100,000 OS threads, the very problem being solved. Goroutines park at the Go runtime level, releasing the P for another goroutine on the same OS thread. The OS never sees the blocking; it sees only the small pool of M's doing continuous work.

The programming model is otherwise identical: you write sequential, blocking code in both cases. The difference is entirely in what runs underneath that code.

---

## Comparison: The Actor Model

The actor model and CSP (the model Go's channels implement) solve the same problem from different angles. Both replace shared memory with message passing. The distinction is worth making explicit because they feel similar from the outside but differ in a way that shapes how you structure programs.

In the actor model, the identity of the receiver matters. An actor has an address. You send a message *to actor A*. Actor A has a mailbox: an unbounded, asynchronous queue. The sender never blocks; it fires the message and moves on regardless of whether A is ready.

In CSP, the channel matters, not who is reading from it. A goroutine sends *on a channel*. Any goroutine holding the other end can receive. The unbuffered channel is a synchronous rendezvous: both parties must be ready simultaneously. The sender blocks until a receiver is present.

The practical consequences:

**Backpressure.** CSP channels naturally propagate backpressure. If the consumer is slow, the producer blocks at the channel. This forces the system to slow down at the source rather than accumulate unbounded queues. Actor mailboxes are asynchronous by default; a slow consumer builds up an ever-growing mailbox, which can exhaust memory without any signal to the producer.

**Identity.** Actors are addressable by name or PID. You can store an actor reference and send to it later, from anywhere. Go goroutines are anonymous; you cannot address one directly. Communication happens through channels, which are values, not addresses. This is a philosophical choice: channels decouple the sender from knowing who receives.

**Fault isolation.** Erlang/Akka actors are isolated processes; a crash in one does not affect others. Goroutines share memory within a process. A panic in one goroutine, if unrecovered, takes down the whole program.

Go is not a pure actor system and not a pure CSP system. It takes CSP's synchronous channels and `select`, allows shared memory alongside them, and leaves fault isolation to the programmer. The result is pragmatic and fast, at the cost of the formal guarantees that pure actor systems and pure CSP provide.

---

## Comparison: Java Virtual Threads (Project Loom)

Java 21 shipped virtual threads, lightweight threads scheduled by the JVM rather than the OS, in direct response to the same problem goroutines solved in 2009. If you're moving between Java and Go, the similarities are real but the design choices diverge in ways that matter.

Both virtual threads and goroutines are M:N: many lightweight threads multiplexed onto fewer OS threads. Both park the lightweight thread (not the OS thread) when it blocks on I/O. Both allow you to write blocking sequential code without the function coloring problem that `async/await` imposes.

The differences:

**Continuations vs stacks.** Go goroutines have their own growable stack: a real call stack that starts at 8KB and copies to a larger allocation when it overflows. Java virtual threads are implemented as continuations: when a virtual thread mounts onto a carrier thread (Java's equivalent of M), the JVM copies the relevant stack frames onto the carrier's stack. When it unmounts (blocks), those frames are saved to the heap. There is no separate per-goroutine stack. The implications are subtle but real: Java's approach avoids Go's stack copy cost, but the JVM must intercept every blocking operation to implement unmounting, whereas Go handles this more uniformly at the scheduler level.

**No work stealing by default.** Go's scheduler steals work aggressively across P's. Java virtual threads run on a `ForkJoinPool` (the carrier thread pool), which does implement work stealing, but the virtual thread scheduler is less exposed and less tunable than Go's. `GOMAXPROCS` in Go is explicit and well-documented. The Java carrier pool is configured via system properties and less obvious to operators.

**Pinning.** A Java virtual thread can become *pinned* to its carrier thread, effectively turning it into a 1:1 OS thread for the duration of the pinning. This happens when the virtual thread holds a `synchronized` lock or calls native code. A pinned virtual thread blocks its carrier, negating the benefit. Go has no equivalent concept; goroutines can always be descheduled (since Go 1.14's asynchronous preemption). Migrating an existing Java codebase to virtual threads requires auditing `synchronized` blocks; Go has no such migration cost.

**Structured concurrency.** Java's `StructuredTaskScope` (previewing in Java 21+) formalizes the relationship between parent and child threads: when the scope exits, all spawned threads are cancelled. Go has no built-in equivalent. `context.Context` propagates cancellation, but the programmer is responsible for wiring it up. Goroutine lifecycle management is manual; Java's structured concurrency makes the relationship explicit.

The practical summary: Java virtual threads and Go goroutines solve the same problem with similar mechanisms. If your Java service is I/O-bound and was thread-per-request, virtual threads are a near-drop-in improvement. Go's model is older, more battle-tested, and exposes more of the machinery to the programmer. Java's model integrates more tightly with the existing JVM ecosystem and adds structured concurrency on top.

---

## Comparison: Erlang Processes

Erlang was doing this before Go existed. The BEAM virtual machine has run millions of lightweight processes on a small pool of OS threads since the 1980s, and the design is more uncompromising than Go's in ways that illuminate the trade-offs Go made.

**True isolation.** Erlang processes share no memory. None. Every message between processes is copied. There are no shared variables, no mutexes, no data races, not because programmers are disciplined, but because the runtime makes sharing structurally impossible. Go allows shared memory and provides `sync.Mutex` for managing it. The Go documentation says to prefer channels, but the language doesn't enforce it. Erlang enforces it at the VM level.

**Preemptive scheduling by reduction count.** The BEAM scheduler preempts a process after a fixed number of *reductions* (roughly, function calls and operations). This gives Erlang extremely low and predictable scheduling latency: no process can starve another by doing CPU work in a tight loop, and the preemption doesn't rely on signals (Go's approach since 1.14). The BEAM's scheduling model is closer to the OS process scheduler than Go's hybrid cooperative-preemptive model.

**Supervision trees as a first-class concept.** Erlang's OTP framework provides supervisors: processes whose entire job is to monitor other processes and restart them when they crash. This is the "let it crash" philosophy: rather than defensively handling every error, you write processes that do their job and crash on unexpected failure, trusting the supervisor to restart them with fresh state. Go has no equivalent. Goroutine lifecycle is the programmer's problem. `context.Context` propagates cancellation but there is no restart semantics, no supervision hierarchy, no automatic recovery.

**The cost of isolation.** Copying every message has overhead. For large data structures passed frequently between processes, this is significant. Go's channel model passes references (or small values) without copying, which is faster for high-throughput communication between goroutines on the same machine. Erlang's copy semantics are the right trade-off for distributed systems (where serialization is required anyway) and fault-isolated services, but they impose a cost in pure throughput scenarios.

The practical summary: Erlang processes are a more pure realization of CSP/actor principles than goroutines. If fault tolerance and isolation are the primary concern (building a phone switch, a payment processor, a chat system with millions of simultaneous sessions), the BEAM's supervision trees and process isolation are genuinely superior tools. Go makes the pragmatic trade-off of allowing shared memory, which is faster and more familiar, at the cost of the correctness guarantees isolation provides.

---

## How They All Compare

| | **Go** | **Java (Loom)** | **Kotlin** | **Python** | **Erlang** | **Rust** | **TypeScript / Node** |
|---|---|---|---|---|---|---|---|
| **Concurrency unit** | Goroutine | Virtual thread | Coroutine | Thread / coroutine | Process | Thread / async task | Async task |
| **Scheduling** | User-space (G/M/P, work stealing) | JVM (ForkJoinPool) | JVM (Dispatchers) | OS (GIL-limited) | BEAM (reduction count) | OS / executor (Tokio) | Event loop (libuv) |
| **Parallelism** | Yes (GOMAXPROCS) | Yes (carrier pool) | Yes (Dispatchers.Default) | No (GIL) | Yes (BEAM schedulers) | Yes | No (single thread) |
| **Blocking I/O** | Park goroutine, release P | Unmount virtual thread | Suspend coroutine | Block thread (GIL released) | Park process | Await future | Callback / await |
| **Shared memory** | Yes (with mutexes) | Yes (with synchronized) | Yes (with locks) | Yes (GIL limits races) | No (copy on send) | Yes (ownership enforced at compile time) | No (single-threaded) |
| **Function coloring** | No | No | No | Yes (`async def`) | No | Yes (`async fn`) | Yes (`async`) |
| **Unit cost** | ~8KB stack | ~few KB (continuation) | ~few hundred bytes | ~1MB stack | ~2KB heap | ~1MB stack / ~few KB async | N/A (event loop) |
| **Max practical units** | Millions | Millions | Millions | Thousands | Millions | Thousands (threads) / millions (async) | N/A |
| **Fault isolation** | None (shared process) | None | None | None | Per-process | None | None |
| **Supervision / lifecycle** | Manual (context.Context) | Manual (StructuredTaskScope) | Structured (coroutineScope) | Manual | Built-in (OTP supervisors) | Manual | Manual |
| **Race prevention** | Race detector (runtime) | None (compile-time for virtual threads: same as threads) | None | Partial (GIL) | Structural (no sharing) | Compile-time (ownership) | Structural (no sharing) |

A few things this table makes clear:

**Go and Kotlin are the closest pair.** Both use CSP-style channels as the primary coordination primitive, both have user-space schedulers multiplexing onto thread pools, and neither has function coloring. The main difference is that Kotlin's coroutines are cooperative and run on JVM thread pools, while Go's goroutines are preemptive (since 1.14) and run on Go's own scheduler.

**Rust is the outlier on safety.** Every other language in this table relies on runtime checks, conventions, or structural isolation to prevent data races. Rust prevents them at compile time through the ownership system. The cost is a steeper learning curve and the `async fn` function coloring problem. The benefit is race freedom without a runtime.

**Erlang stands alone on fault isolation.** No other language in this table provides process-level isolation, supervision trees, or automatic restart. If your primary concern is fault tolerance in a distributed system, no amount of Go's efficiency closes that gap.

**Python's GIL makes it unique in a bad way.** It's the only language here where threading exists but true CPU parallelism does not. Python threads release the GIL for I/O (making them useful for I/O-bound concurrency), but CPU-bound code must use `multiprocessing` to achieve parallelism. `asyncio` sidesteps this by never using threads, but at the cost of function coloring.

---

## The Mental Model That Changes How You Write Go

Return to the OS analogy. An operating system is responsible for:
- **Scheduling:** which process runs on which core, for how long
- **Blocking:** when a process waits for I/O, the CPU should do other work
- **Memory:** each process has its own stack; the kernel manages the heap
- **Communication:** processes communicate via pipes, signals, sockets; not by reading each other's memory directly
- **Lifecycle:** processes must exit or be killed; the OS does not garbage collect them

The Go runtime is responsible for exactly the same things, for goroutines:
- **Scheduling:** the G/M/P scheduler, work stealing
- **Blocking:** park the goroutine, release the P, pick up new work
- **Memory:** 8KB starting stacks, growable, escape analysis for heap allocation
- **Communication:** channels are Go's pipes: explicit, typed, owned by one goroutine at a time
- **Lifecycle:** goroutines must return or be cancelled; the runtime does not garbage collect them

When you understand this, every piece of Go concurrency becomes derivable rather than memorized. Why are goroutines cheap? Because starting one is like `fork()` in user space: a small struct and a queue entry, no kernel call. Why does blocking not waste threads? Because the runtime detaches the P before the block, exactly as an OS kernel puts a blocked process to sleep and runs something else. Why are channels the right primitive? Because they are Go's answer to the IPC problem: explicit, typed message passing rather than shared memory, for the same reason UNIX processes communicate via pipes rather than shared segments.

The next time you write `go func()`, you are not calling an async function. You are forking a new scheduled entity into a runtime that mirrors the design of every OS scheduler ever written, just in user space, tuned for your workload, and exposed through syntax clean enough that most developers never realize how much engineering is underneath.
