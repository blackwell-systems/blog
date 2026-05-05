---
title: "Concurrency Models Explained: How Go, Node.js, Java, Erlang, Rust, and Python Actually Work"
date: 2026-05-04
draft: false
tags: ["go", "golang", "goroutines", "concurrency", "scheduler", "csp", "channels", "parallelism", "runtime", "GMP", "threads", "operating-systems", "performance", "systems-programming", "mental-models", "nodejs", "java", "erlang", "rust", "python", "kotlin"]
categories: ["programming", "concurrency"]
description: "Every concurrency model in every language is a different answer to the same physical constraint: you have more work than cores, and most of that work is waiting. This is the article that lays bare the entire landscape."
summary: "Go, Node.js, Java virtual threads, Erlang, Rust, Python, Kotlin: each language's concurrency model is a different engineering trade-off against the same physics. This article builds the framework for understanding all of them, starting from the OS scheduler and working upward."
---

Every language with a concurrency story is solving the same physical problem: you have more concurrent tasks than CPU cores, and most of those tasks spend most of their time waiting. Waiting for a database to respond, a network packet to arrive, a disk seek to complete. The CPU is idle while the work sits in the kernel.

The question is how to use that idle time productively. Each language's concurrency model is a different answer.

This article builds the framework for understanding all of them. It starts from the OS scheduler, because every user-space concurrency model is either an imitation of it, a workaround for its limitations, or a layer on top of it. Once you see the common structure, the differences between goroutines, virtual threads, event loops, and actor processes become derivable rather than memorized.

Go gets the most depth because its scheduler is the most instructive to understand in detail. But the comparisons are the point.

---

## The Physical Constraint Every Model Is Solving

A CPU core executes one instruction stream at a time. On a modern server with 16 cores, 16 instruction streams run simultaneously. That's the ceiling.

A web server handling 10,000 concurrent requests is not running 10,000 instruction streams. It is running 16, and switching among 10,000 tasks as each one blocks and unblocks on I/O. The concurrency is an illusion created by the scheduler.

The OS scheduler creates this illusion at the process and thread level. It preempts running threads every few milliseconds, saves their registers, and resumes a different thread. From any thread's perspective it runs continuously. From the CPU's perspective it runs in short slices.

The problem is that OS threads are expensive: 1-8MB of stack each, kernel involvement for every scheduling decision, and context switches that cost 1-10 microseconds. At 10,000 concurrent connections, you need 10,000 threads, which requires 10-80GB of stack memory and overwhelms the kernel scheduler.

Every modern concurrency model is an attempt to decouple "number of concurrent tasks" from "number of OS threads." They differ in how they do it:

- **Event loop (Node.js):** One thread, never blocks, callbacks on I/O completion
- **M:N scheduling (Go, Erlang, Java Loom):** Many lightweight units on few OS threads, runtime scheduler in user space
- **Async/await (Python asyncio, Rust):** State machines compiled from sequential code, driven by an executor
- **Actor model (Erlang, Akka):** Isolated processes with message passing, scheduler managed by the VM

All of these solve the same equation. The trade-offs are in what they sacrifice to solve it.

---

## The Intellectual Lineage

The landscape didn't appear fully formed. Each model emerged from a specific problem at a specific time:

**1978:** Tony Hoare publishes "Communicating Sequential Processes." Processes communicate via synchronous channels; no shared memory. The theory that Go's channels implement.

**1986:** Erlang is created at Ericsson for telephone switches. Millions of concurrent call sessions, each isolated, each supervised. The actor model in its most uncompromising form.

**1991:** POSIX threads standardize OS-level threading. One thread per concurrent task becomes the default model for a decade.

**2003:** The C10K problem paper. Dan Kegel documents why 10,000 concurrent connections breaks the thread-per-connection model. Event-driven I/O is the answer, but writing it is painful.

**2009:** Node.js and Go both ship. Node.js brings the event loop to server-side JavaScript and makes it ergonomic. Go takes a different path: implement the scheduler in user space so programmers can write blocking sequential code, and the runtime handles the multiplexing.

**2014:** Go 1.3. The scheduler adds work stealing, M:N scheduling matures.

**2021:** Go 1.14 adds asynchronous preemption. Goroutines can be interrupted mid-computation, not just at function calls.

**2023:** Java 21 ships virtual threads (Project Loom). The JVM finally has its own M:N scheduler after 25 years of 1:1 OS threads.

**2024:** Python 3.13 experiments with a per-interpreter GIL, opening the door to real CPU parallelism in Python for the first time.

The arc: sequential programs struggle to use all available cores. Threads help but don't scale. Event loops scale for I/O but break for CPU work. M:N schedulers handle both. The industry is still converging.

---

## The OS Scheduler: The Foundation Underneath Everything

Before examining any user-space concurrency model, you need to understand what it is built on.

A modern OS manages hundreds of processes on a handful of CPU cores. On a 4-core machine, only 4 processes execute simultaneously, one per core. The OS creates the illusion of concurrent execution through **preemptive multitasking**: every few milliseconds, a hardware timer fires, the running process is suspended (registers and stack pointer saved to its Process Control Block in the kernel), and the scheduler picks the next process. This is a **context switch**.

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

## The Four Dimensions That Separate the Models

Before the comparisons, a framework. Every concurrency model makes choices along four dimensions. The models diverge most sharply on these:

**1. Scheduling model:** Who decides which unit of work runs next? OS kernel (threads), language runtime (goroutines, virtual threads, BEAM processes), or the programmer via explicit yields (async/await, Node.js callbacks).

**2. Communication model:** How does concurrent work exchange data? Shared memory with locks (threads), message passing with copying (Erlang), synchronous channels (Go CSP), asynchronous channels (Go buffered, actors), or implicit single-threaded access (Node.js, single-threaded Python).

**3. Stack model:** How is the call stack managed for each concurrent unit? Fixed OS-allocated stack (threads), heap-allocated growable stack (goroutines), continuation frames saved to heap (virtual threads), no per-task stack (async/await state machines).

**4. Fault model:** What happens when a concurrent unit crashes? Process isolation with supervision (Erlang), unhandled panic takes down the process (Go, Rust), exception caught or propagates (Java, Python), unhandled rejection (Node.js).

Every concrete decision you make in a system design, in choosing a language, or in debugging a performance problem, traces back to one of these four dimensions. Keep them in mind as you read the comparisons.

---

## Go's Answer: A Scheduler in User Space

Here's a better answer to "what is a goroutine" than "lightweight thread": **a goroutine is to the Go runtime what a process is to the operating system.** The Go runtime is a miniature OS running inside your program. It schedules goroutines onto OS threads the same way an OS schedules processes onto CPU cores. It manages their memory, handles their blocking, and multiplexes thousands of them onto a handful of real threads, exactly as an OS multiplexes hundreds of processes onto a handful of physical cores.

This is not a metaphor. It is structurally identical. Once you see it, everything about Go concurrency follows from it.

### What "Lightweight Thread" Actually Means

"Goroutines are lightweight threads managed by the Go runtime."

Fine. But what does that actually mean? Three questions:

1. If a goroutine makes a blocking system call (like reading from disk), does it block the OS thread it's running on?
2. Can two goroutines run in parallel on two different CPU cores simultaneously?
3. If you start 100,000 goroutines on an 8-core machine, how many OS threads does Go create?

Most tutorials teach: yes, yes, one per goroutine. That mental model will cause you to write slow code, miss goroutine leaks, and blame scheduler behavior on bugs in your own code.

The actual answers require understanding the Go scheduler.

### The Go Scheduler: G, M, P

The Go runtime implements a scheduler that manages goroutines the way an OS manages processes. Three types of entities:

**G (Goroutine):** The goroutine itself: its stack (starting at 8KB, growable), program counter, status, and the closure it's running. Analogous to a Process Control Block.

**M (Machine):** An OS thread. The entity that actually executes instructions on a CPU core. The Go runtime creates and parks M's as needed; the default limit is 10,000. Analogous to the physical thread executing a process.

**P (Processor):** A scheduling token and run queue, one per logical core of parallelism. P is not a CPU core and not an OS thread; it is the Go runtime's bookkeeping unit for "one slot of concurrent Go execution." Each P owns a local queue of runnable goroutines and a cache of runtime resources (memory allocator state, deferred work). An M must hold a P to execute any Go code at all; without one, an M sits idle. The number of P's is set by `GOMAXPROCS` (default: `runtime.NumCPU()`), which is why `GOMAXPROCS` controls the degree of true parallelism rather than the number of goroutines or threads. P exists to decouple "I have a runnable goroutine" from "I have an OS thread," the separation that makes the blocking story work.

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

### What Actually Happens When You Write `go func()`

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

### Blocking: The Scheduler's Defining Feature

This is where most developers' mental model falls apart, and where the OS analogy pays off most.

When a goroutine blocks, *what happens to the OS thread?*

The answer depends on *why* it blocks.

**Go-Aware Blocking (Channels, Mutexes, Sleep)**

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

**Blocking Syscalls (File I/O, CGo)**

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

**Network I/O Is Different**

Network I/O doesn't use the blocking syscall path at all. The `net` package registers file descriptors with `epoll` (Linux) or `kqueue` (macOS/BSD) for non-blocking I/O. When a goroutine reads from a network connection with no data available, it parks itself, the same as a channel receive. A dedicated **netpoller** goroutine (running in its own M) monitors all registered file descriptors and unparks the waiting goroutines when their data arrives.

One goroutine handles the I/O multiplexing for all 100,000 concurrent connections. The waiting goroutines consume no CPU, no thread, and no P slot. This is how Go web servers achieve the concurrency of an event loop with the code structure of blocking calls.

### To Answer the Diagnostic Questions

**1. Does a blocking syscall block the OS thread?**
Yes, but the P is detached first via `entersyscall`, so other goroutines keep running on another M. The blocked M stalls in the kernel while work continues elsewhere.

**2. Can two goroutines run in parallel?**
Yes, if `GOMAXPROCS > 1`. Two goroutines on two different P's, each held by a different M, each on a different CPU core: genuinely parallel.

**3. How many OS threads for 100,000 goroutines on an 8-core machine?**
Approximately 8 M's for running goroutines (one per P), plus however many M's are currently blocked in syscalls. If 50 goroutines are doing blocking file I/O simultaneously, there are 58 M's. The number of M's is not bounded by GOMAXPROCS; it is bounded by how many goroutines are simultaneously blocked in the kernel, up to the 10,000 default limit.

### Context Switches: Cooperative and Preemptive

The Go scheduler is a hybrid. Originally it was purely cooperative: goroutines yielded at function call boundaries, where the runtime inserted scheduling checks. A goroutine doing tight arithmetic in a loop with no function calls would never yield, starving other goroutines.

Go 1.14 added **asynchronous preemption**: the runtime's monitor thread (`sysmon`) runs every 10ms and can signal any goroutine that has been running for too long, forcing a yield even mid-computation. This is done by sending a signal (SIGURG) to the OS thread running the goroutine.

The result: goroutine context switches happen cooperatively at function calls (the fast, common path) and preemptively via signal every 10ms (the fallback). This is architecturally identical to how operating systems handle preemption: most context switches happen on blocking calls, with the timer interrupt as the safety net.

Goroutine context switches cost roughly **100-300 nanoseconds**, faster than OS thread switches (300ns-1µs) because no kernel call is involved and the address space is shared, so no page table manipulation is needed.

### CSP: Why Channels Are Not Optional

The `go` keyword and channels are not convenience syntax for threads and mutexes. They embody a specific theory of concurrent correctness: **Communicating Sequential Processes**, formalized by Tony Hoare in 1978.

The problem CSP was designed to solve: shared memory is hard to reason about. Any thread can touch any shared variable at any time. Correctness requires reasoning about every possible interleaving of every thread's every instruction. As thread count grows, that space explodes. This is why multithreaded code is famously difficult to test and debug: you cannot reproduce most concurrency bugs on demand, because they depend on exact scheduling timing.

CSP's answer: don't share memory. Make communication the only mechanism for data transfer. Each goroutine owns its own state. The only way data moves between goroutines is through a channel, an explicit, typed conduit. No two goroutines ever touch the same memory simultaneously, not because of a lock, but because the design makes it structurally impossible.

Go's maxim captures this: **"Do not communicate by sharing memory; instead, share memory by communicating."**

To see why this matters, compare the two approaches. Shared memory with a mutex:

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

`n` is never shared. It exists only inside `counter`. No other goroutine can access it, not because there's a lock, but because there's no path to it from outside the goroutine. The correctness is structural, not advisory.

**What a Channel Actually Is**

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

A channel is a mutex-protected circular buffer with two queues of parked goroutines. The `lock` is what makes channels safe, not your discipline, not code review, not tests. The invariant is enforced by the data structure itself.

**Select: Waiting on Multiple Channels at Once**

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

When `select` executes, if multiple cases are ready, Go picks one **uniformly at random**. This is specified behavior, not implementation detail. It prevents starvation: if `select` always picked the first ready case, a high-throughput channel could permanently block a low-throughput one.

When no case is ready, the goroutine parks itself simultaneously in the `recvq`/`sendq` of all channels in the select. Whichever channel becomes ready first wakes the goroutine and deregisters it from all the others.

### The Goroutine Stack

OS threads have fixed stacks (1-8MB) allocated at creation. Goroutines start with an **8KB stack** and grow as needed. When the runtime detects insufficient stack space at a function's entry, it allocates a new stack (typically 2x), copies the entire current stack to the new allocation, updates all stack pointers, and continues. The stack can grow up to 1GB by default; in practice most goroutines use 8-64KB.

This is what makes 100,000 goroutines viable at startup: you're reserving 8KB per goroutine, not 1MB.

**Escape analysis** exists partly because of this. When the compiler sees that a local variable's address escapes the current goroutine (taken by `go func()`, sent on a channel, stored in a heap-allocated struct), it moves the variable to the heap. A local variable's memory address changes when the stack grows, so any pointer that outlives the stack frame must live on the heap instead.

### GOMAXPROCS, Containers, and the Single-Core Argument

`GOMAXPROCS` controls the number of P's, and therefore the number of goroutines that can execute simultaneously. By default it equals `runtime.NumCPU()`.

{{< callout type="warning" >}}
**The Misconception That Trips People Up**

`GOMAXPROCS(4)` does not mean only 4 goroutines can run. It means only 4 can run *simultaneously*. Any number can exist: parked on channels, waiting in run queues, blocked on mutexes. Up to 4 are executing at any given CPU cycle.

4 CPU cores on a Linux machine doesn't limit you to 4 processes. It limits you to 4 processes executing simultaneously. The Go scheduler works identically.
{{< /callout >}}

**Fractional CPU allocations in containers:** `runtime.NumCPU()` reads the host machine's physical core count, not your container's CPU quota. A pod with `resources.limits.cpu: 500m` running on an 8-core node gets `GOMAXPROCS = 8`. Eight OS threads compete for half a core. The preemption overhead exceeds the useful work. The fix is a single blank import:

```go
import _ "go.uber.org/automaxprocs"
```

It reads the cgroup CPU quota at startup and sets `GOMAXPROCS` to match the actual allocation. Half a core becomes `GOMAXPROCS = 1`. This is worth adding to any Go service running in Kubernetes.

**"We run single-core containers, so goroutines don't help us":** This conflates parallelism with concurrency, and it's wrong. With `GOMAXPROCS = 1`, only one goroutine executes at any CPU cycle. There is no parallelism. But a web server's bottleneck is almost never CPU; it's waiting. On a single-core container handling 1,000 concurrent HTTP requests, those 1,000 goroutines are almost all parked, waiting for database queries. The one core cycles through whichever goroutines have data to process. The single core is never idle waiting for I/O because there is always another goroutine ready to run. Single-core Go outperforms a single-threaded model for I/O-bound workloads because concurrency, not parallelism, is what matters.

### Goroutine Leaks

In an OS, processes that never terminate accumulate as zombies consuming resources until the system halts. You cannot garbage collect processes; they live until they exit.

Goroutines work the same way. The Go runtime does not garbage collect goroutines. A goroutine lives until its function returns.

```go
func leak() {
    ch := make(chan int)  // never written to
    go func() {
        val := <-ch      // parks forever
        process(val)
    }()
    // Every call to leak() adds one permanently parked goroutine
}
```

Every goroutine needs a clear termination condition:

```go
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

`go.uber.org/goleak` provides `goleak.VerifyNone(t)` for tests. It fails if any goroutines started during the test are still running at cleanup.

---

## How Go's Model Relates to CSP

Go is CSP-inspired, not CSP-pure. The differences matter:

**Shared memory is allowed.** Pure CSP has no shared state. Go allows goroutines to share variables freely and provides `sync.Mutex` for managing that. The language encourages channels but doesn't enforce them.

**Buffered channels don't exist in original CSP.** A buffered channel lets a sender proceed without a receiver, up to capacity. This is a practical extension that changes the semantics: communication is no longer a synchronization point.

**Channels are first-class values.** In CSP, channels are named communication paths, not values you can pass around. In Go, a channel is just a value: store it in a struct, send it on another channel, return it from a function.

**No formal verification.** CSP was designed to be model-checked with tools like FDR. You can't formally verify Go programs as CSP processes.

Go takes CSP's vocabulary (channels, select, communicating processes) and implements the two most important primitives faithfully: synchronous rendezvous on unbuffered channels, and nondeterministic choice via `select`. The philosophy is genuine. The formal properties are not preserved.

---

## Comparison: Node.js

Node.js is the sharpest contrast to Go's concurrency model. Node.js is very good at concurrent I/O. It does it on a single thread. Any CPU work breaks the model entirely.

Node.js runs JavaScript on a single thread. The event loop processes one callback at a time. When your code calls `fs.readFile` or `fetch`, Node.js hands the I/O operation to libuv (its C++ I/O library), registers a callback, and moves on to the next event immediately. When libuv signals completion, the callback is queued. The event loop picks it up when the current callback finishes.

This is exactly what Go's netpoller does for network I/O: register file descriptors with `epoll`/`kqueue`, park the goroutine, resume it when data arrives. The mechanics underneath are similar. The difference is what each exposes to the programmer.

In Node.js, the single-threaded event loop is your programming model. Your code must cooperate with it. In Go, the scheduler is invisible. Your code just blocks.

**Where Node.js breaks:**

**CPU work stalls all I/O.** If a callback runs a CPU-intensive operation for 200ms, no other callbacks run during that 200ms. All in-flight requests are frozen. Go distributes CPU work across `GOMAXPROCS` threads simultaneously; computation in one goroutine does not affect others.

**Function coloring.** To call an async function and get its result, your function must be `async`. This propagates upward through the entire call stack. A non-async function cannot `await`. Go has no equivalent distinction; any goroutine can block on any operation and the scheduler handles it.

**No true parallelism in one process.** A single Node.js process uses one CPU core for JavaScript execution. Worker Threads exist for parallel CPU work, but they do not share the event loop, communicate via message passing only, and feel like separate processes.

**Where Node.js wins:**

A single Node.js process can handle tens of thousands of concurrent I/O-bound connections with very low memory footprint. There is no stack per connection; the event loop has near-zero overhead between callbacks. For pure I/O workloads (HTTP proxies, WebSocket servers, API gateways), a tuned Node.js process can match or beat Go per CPU core. The zero-stack-per-connection model is genuinely more memory efficient than Go's 8KB per goroutine.

**The key difference in one sentence:** The Go netpoller and Node.js's libuv solve the same OS-level problem. libuv exposes the event loop to your code. Go's scheduler hides it. Your code just blocks, and the runtime ensures the thread is never idle.

---

## Comparison: OS Threads

OS threads (pthreads, `std::thread`, Java pre-Loom) are what you get when you map concurrent tasks directly onto the OS scheduler. One thread per concurrent task. The OS schedules them onto CPU cores. They share an address space.

The resource cost is the problem. Each OS thread carries 1-8MB of stack allocated at creation, regardless of whether the thread does anything. Creating one requires a kernel call (10-50 microseconds). The OS scheduler has no knowledge of your application; it sees all threads as equally worthy of CPU time, switching between them at fixed intervals whether they're doing useful work or sleeping.

Goroutines address exactly this: 8KB instead of 1-8MB means 1,000x more concurrent units for the same memory. User-space context switches cost 100-300ns rather than 1-10µs. Goroutines waiting on I/O consume no CPU and no OS thread.

The programming model is otherwise identical: you write sequential, blocking code in both cases. The difference is entirely in what runs underneath.

---

## Comparison: The Actor Model

The actor model and CSP solve the same problem from different angles. Both replace shared memory with message passing. The distinction shapes how you structure programs.

In the actor model, the identity of the receiver matters. An actor has an address. You send a message *to actor A*. Actor A has a mailbox: an unbounded, asynchronous queue. The sender never blocks; it fires the message and moves on regardless of whether A is ready.

In CSP, the channel matters, not who is reading from it. A goroutine sends *on a channel*. The unbuffered channel is a synchronous rendezvous: both parties must be ready simultaneously. The sender blocks until a receiver is present.

The practical consequences:

**Backpressure.** CSP channels naturally propagate backpressure. If the consumer is slow, the producer blocks at the channel. Actor mailboxes are asynchronous by default; a slow consumer builds up an ever-growing mailbox, which can exhaust memory without any signal to the producer.

**Identity.** Actors are addressable by name or PID. Go goroutines are anonymous; you cannot address one directly. Communication happens through channels, which are values, not addresses.

**Fault isolation.** Erlang/Akka actors are isolated processes; a crash in one does not affect others. Goroutines share memory within a process. A panic in one goroutine, if unrecovered, takes down the whole program.

Go is not a pure actor system and not a pure CSP system. It takes CSP's synchronous channels and `select`, allows shared memory alongside them, and leaves fault isolation to the programmer.

---

## Comparison: Java Virtual Threads (Project Loom)

Java 21 shipped virtual threads, lightweight threads scheduled by the JVM rather than the OS, in direct response to the same problem goroutines solved in 2009. Both are M:N: many lightweight threads multiplexed onto fewer OS threads. Both park the lightweight thread (not the OS thread) when it blocks on I/O. Both eliminate function coloring.

The differences:

**Continuations vs stacks.** Go goroutines have their own growable stack: a real call stack that starts at 8KB and copies to a larger allocation when it overflows. Java virtual threads are implemented as continuations: when a virtual thread mounts onto a carrier thread, the JVM copies the relevant stack frames onto the carrier's stack. When it unmounts (blocks), those frames are saved to the heap. Java's approach avoids Go's stack copy cost, but the JVM must intercept every blocking operation to implement unmounting.

**Pinning.** A Java virtual thread can become *pinned* to its carrier thread, effectively turning it into a 1:1 OS thread for the duration of the pinning. This happens when the virtual thread holds a `synchronized` lock or calls native code. A pinned virtual thread blocks its carrier, negating the benefit. Go has no equivalent concept; goroutines can always be descheduled since Go 1.14.

**Structured concurrency.** Java's `StructuredTaskScope` formalizes the relationship between parent and child threads: when the scope exits, all spawned threads are cancelled. Go has no built-in equivalent. `context.Context` propagates cancellation, but the programmer wires it up manually.

**Work stealing visibility.** Go's `GOMAXPROCS` is explicit and well-documented. Java's carrier pool (a `ForkJoinPool`) is configured via system properties and less transparent to operators.

The practical summary: if your Java service is I/O-bound and was thread-per-request, virtual threads are a near-drop-in improvement. Go's model is older, more battle-tested, and exposes more of the machinery. Java's model integrates more tightly with the JVM ecosystem and adds structured concurrency on top.

---

## Comparison: Kotlin Coroutines

Kotlin is Go's closest peer in this landscape. Both use CSP-style channels as the primary coordination primitive, both have user-space schedulers, and neither has function coloring. The convergence is striking given that Go inherited CSP from Bell Labs lineage (Plan 9, Limbo) and Kotlin adopted it from JVM coroutine research.

```go
// Go                                    // Kotlin
ch := make(chan int, 10)                 val ch = Channel<Int>(10)
go func() { ch <- 42 }()                launch { ch.send(42) }
val := <-ch                              val value = ch.receive()
```

Both use channels as the primary coordination primitive. Both support `select`-style multiplexing. Both favor "share memory by communicating" over locks.

The key differences:

**Scheduling.** Go goroutines run on Go's own preemptive scheduler (since 1.14). Kotlin coroutines are cooperative: they only yield at suspension points (`suspend fun` calls, channel operations). A Kotlin coroutine doing tight CPU work will not be preempted and will stall its dispatcher thread.

**Structured concurrency.** Kotlin has it built in via `coroutineScope`: parent scopes automatically cancel children on failure, and a parent waits for all children before completing. Go requires manual `context.Context` + `WaitGroup` to approximate this.

**Blocking risk.** In Go, a goroutine that calls a blocking OS operation releases its P and never stalls other goroutines. In Kotlin, accidentally calling a blocking (non-suspending) function from a coroutine stalls the dispatcher thread. Kotlin provides `Dispatchers.IO` for this, but it requires discipline.

**Runtime.** Go's scheduler is purpose-built. Kotlin coroutines run on JVM thread pools, inheriting all the JVM's startup overhead and memory model.

If you know one, the other is immediately readable. The philosophical alignment is real. The mechanical differences (preemption, structured concurrency, blocking risk) are where they diverge.

---

## Comparison: Erlang Processes

Erlang was doing this before Go existed. The BEAM virtual machine has run millions of lightweight processes on a small pool of OS threads since the 1980s, and the design is more uncompromising than Go's in ways that illuminate the trade-offs Go made.

**True isolation.** Erlang processes share no memory. None. Every message between processes is copied. There are no shared variables, no mutexes, no data races, not because programmers are disciplined, but because the runtime makes sharing structurally impossible. Go allows shared memory and provides `sync.Mutex` for managing it. The Go documentation says to prefer channels, but the language doesn't enforce it. Erlang enforces it at the VM level.

**Preemptive scheduling by reduction count.** The BEAM scheduler preempts a process after a fixed number of *reductions* (roughly, function calls and operations). This gives Erlang extremely low and predictable scheduling latency: no process can starve another by doing CPU work in a tight loop, and the preemption doesn't rely on signals. The BEAM's scheduling model is closer to the OS process scheduler than Go's hybrid cooperative-preemptive model.

**Supervision trees as a first-class concept.** Erlang's OTP framework provides supervisors: processes whose entire job is to monitor other processes and restart them when they crash. This is the "let it crash" philosophy: rather than defensively handling every error, you write processes that do their job and crash on unexpected failure, trusting the supervisor to restart them with fresh state. Go has no equivalent. Goroutine lifecycle is the programmer's problem.

**The cost of isolation.** Copying every message has overhead. Go's channel model passes references (or small values) without copying, which is faster for high-throughput communication between goroutines on the same machine. Erlang's copy semantics are the right trade-off for distributed systems and fault-isolated services, but they impose a cost in pure throughput scenarios.

If fault tolerance and isolation are the primary concern (building a phone switch, a payment processor, a chat system with millions of simultaneous sessions), the BEAM's supervision trees and process isolation are genuinely superior tools. Go makes the pragmatic trade-off of allowing shared memory, which is faster and more familiar, at the cost of the correctness guarantees isolation provides.

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
| **Race prevention** | Race detector (runtime) | None | None | Partial (GIL) | Structural (no sharing) | Compile-time (ownership) | Structural (no sharing) |

**Go and Kotlin are the closest pair.** Both use CSP-style channels as the primary coordination primitive, both have user-space schedulers, and neither has function coloring. The main difference is preemption (Go) vs cooperative suspension (Kotlin) and structured concurrency (Kotlin built-in, Go manual).

**Rust is the outlier on safety.** Every other language relies on runtime checks, conventions, or structural isolation to prevent data races. Rust prevents them at compile time. The cost is a steeper learning curve and `async fn` function coloring. The benefit is race freedom without a runtime.

**Erlang stands alone on fault isolation.** No other language in this table provides process-level isolation, supervision trees, or automatic restart. If your primary concern is fault tolerance in a distributed system, no amount of Go's efficiency closes that gap.

**Python's GIL makes it unique in a bad way.** It's the only language here where threading exists but true CPU parallelism does not. Python threads release the GIL for I/O (making them useful for I/O-bound concurrency), but CPU-bound code must use `multiprocessing` to achieve parallelism.

---

## Choosing a Model

Given a problem profile, which model do you reach for?

{{< mermaid >}}
flowchart TD
    A([Start: What is your primary constraint?])

    A --> B{Fault tolerance\nis the top priority?}
    B -- Yes --> C["Erlang / Elixir\n\nSupervision trees, process isolation,\nlet-it-crash philosophy.\nDecades ahead for systems\nthat must stay up."]

    B -- No --> D{Existing codebase\nconstraint?}

    D -- JVM / Java --> E{I/O-bound\nor mixed?}
    E -- Pure I/O --> F["Java Virtual Threads\n(Project Loom)\n\nNear-drop-in over thread-per-request.\nNo function coloring. Integrates\nwith existing JVM libraries."]
    E -- Mixed I/O + CPU --> G["Kotlin Coroutines\n\nGo-style CSP on the JVM.\nBe careful of blocking\non coroutine dispatchers."]

    D -- Python ecosystem --> H{CPU-bound\nor I/O-bound?}
    H -- CPU-bound --> I["Python multiprocessing\nor switch languages\n\nThe GIL prevents CPU\nparallelism in threads.\nasyncio for I/O only."]
    H -- I/O-bound --> J["Python asyncio\n\nEvent loop, no parallelism.\nFunction coloring required.\nFamiliar ecosystem."]

    D -- No constraint --> K{Workload type?}

    K -- Pure I/O\nhigh connection count --> L["Node.js\n\nZero stack per connection.\nHighest I/O concurrency\nper CPU core. Accept\nfunction coloring + no\nCPU parallelism."]

    K -- Mixed I/O\nand CPU --> M{Runtime overhead\nacceptable?}

    M -- Yes --> N["Go\n\nM:N scheduler, no function\ncoloring, work stealing.\nBest default for\nmixed workloads."]

    M -- No\nzero overhead needed --> O["Rust\n\nCompile-time race prevention,\nno GC pauses. async/await\nfor I/O. Accept the\nlearning curve."]

    K -- CPU-bound\nno I/O --> P{Language preference?}
    P -- Systems / performance --> O
    P -- Simplicity --> N

    style C fill:#4a7058,color:#fff,stroke:#2d5040
    style F fill:#4a5568,color:#fff,stroke:#2d3748
    style G fill:#4a5568,color:#fff,stroke:#2d3748
    style I fill:#744a4a,color:#fff,stroke:#5c2d2d
    style J fill:#4a5568,color:#fff,stroke:#2d3748
    style L fill:#4a5568,color:#fff,stroke:#2d3748
    style N fill:#2d6a8a,color:#fff,stroke:#1a4a63
    style O fill:#6a4a2d,color:#fff,stroke:#4a2d10
{{< /mermaid >}}

**Pure I/O concurrency, maximum connections per CPU:** Node.js wins per-core. Zero stack per connection, near-zero callback overhead. Accept the function coloring constraint and the inability to use multiple cores without clustering.

**Mixed I/O and CPU, single process:** Go. Distributes CPU work across all cores automatically. No function coloring. Goroutines park on I/O without wasting threads.

**Fault tolerance is the primary requirement:** Erlang/Elixir. The supervision tree model is decades ahead of everything else for building systems that must stay up when components fail.

**Existing JVM codebase, I/O-bound:** Java virtual threads. Near-drop-in improvement over thread-per-request, no function coloring, integrates with existing libraries.

**Maximum CPU performance, zero runtime overhead:** Rust. Compile-time race prevention, no GC pauses, async tasks for I/O. Accept the learning curve and function coloring.

**You're on the JVM and want Go-style concurrency:** Kotlin coroutines. The CSP vocabulary is nearly identical; be careful about blocking operations on coroutine dispatchers.

---

## The Common Structure

Every concurrency model described here is solving the same equation:

```
Work to do >> Cores available
Most of that work is waiting, not computing
Goal: keep cores busy despite the waiting
```

The OS solved it first, with preemptive multitasking and kernel threads. The solutions that followed are all variations: move the scheduler to user space (Go, Erlang, virtual threads), eliminate per-task stacks (async/await, event loops), enforce isolation to eliminate races (Erlang, Rust), or accept single-threaded simplicity in exchange for ergonomics (Node.js).

None of them is universally best. Each is a rational engineering choice that optimizes different things: throughput, latency, safety, ergonomics, fault tolerance, operational simplicity. The best engineers know the trade-offs well enough to choose deliberately, and to explain why.

The Go scheduler is worth understanding in detail not because Go is uniquely important, but because it is the clearest example of the user-space-OS pattern. Once you see how G's, M's, and P's mirror processes, threads, and cores, the same pattern becomes visible everywhere: in Erlang's BEAM scheduler, in Java's virtual thread carrier pool, in the libuv event loop underneath Node.js. They are all solving the same problem. They just made different bets about which constraints to accept.
