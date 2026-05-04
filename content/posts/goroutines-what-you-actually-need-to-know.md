---
title: "Goroutines: What You Actually Need to Know (Most Go Developers Don't)"
date: 2026-05-04
draft: false
tags: ["go", "golang", "goroutines", "concurrency", "scheduler", "csp", "channels", "parallelism", "runtime", "GMP", "threads", "operating-systems", "performance", "systems-programming", "mental-models"]
categories: ["programming", "go"]
description: "Most Go developers use goroutines as magic async functions. That's not what they are. To truly understand Go concurrency — to debug goroutine leaks, write correct concurrent code, avoid scheduler traps — you need the real mental model: goroutines are to the Go runtime what processes are to the OS."
summary: "Most Go developers can start a goroutine. Far fewer can explain what actually happens when they do. This post builds the real mental model: the G/M/P scheduler, why goroutines aren't threads, what CSP actually means, and the analogy that makes everything click — the Go runtime is an operating system for goroutines."
---

Ask a Go developer what a goroutine is and you'll hear something like: "it's a lightweight thread." That's not wrong. It's just so incomplete that it's nearly useless for reasoning about real concurrency problems.

Here's a better answer: **a goroutine is to the Go runtime what a process is to the operating system.** The Go runtime is a miniature OS running inside your program. It schedules goroutines onto OS threads the same way an OS schedules processes onto CPU cores. It manages their memory, handles their blocking, and multiplexes thousands of them onto a handful of real threads — exactly as an OS multiplexes hundreds of processes onto a handful of physical cores.

Once you truly understand this analogy, everything else about Go concurrency clicks into place: why goroutines are cheap, why channels work the way they do, why `go func()` doesn't mean "run this on a thread," and why most of what you've read about goroutines is technically accurate but practically misleading.

---

## The Claim Most People Nod At But Can't Explain

"Goroutines are lightweight threads managed by the Go runtime."

Fine. But what does that actually mean? Let's stress-test it with three questions:

1. If a goroutine makes a blocking system call (like reading from disk), does it block the OS thread it's running on?
2. Can two goroutines run in parallel on two different CPU cores at the same time?
3. If you start 100,000 goroutines, how many OS threads does Go create?

If you answered "yes, yes, one per goroutine" — you have the mental model most Go tutorials teach. You also have the mental model that will cause you to write slow code, miss goroutine leaks, and misattribute scheduler behavior to bugs in your code.

The correct answers: no (usually), yes (if GOMAXPROCS > 1), and somewhere between 1 and GOMAXPROCS (typically your CPU core count). Understanding why requires understanding how the Go scheduler actually works.

---

## Start With the OS: Processes, Threads, and CPU Cores

Before you can understand the Go scheduler, you need to understand what it was designed to replace.

A modern operating system manages many processes running on a small number of CPU cores. At any given moment, a 4-core machine might have 200 processes. Only 4 can actually execute simultaneously — one per core. The OS creates the illusion of concurrent execution through **preemptive multitasking**: every few milliseconds, the OS timer fires, the current process is suspended (its registers and stack pointer saved to a kernel structure called the Process Control Block), and the OS picks the next process to run. This is a **context switch**.

Context switches are expensive. The OS must save all CPU registers, switch virtual memory page tables (different processes have different address spaces), and potentially flush CPU caches. A context switch between processes costs roughly 1-10 microseconds.

Threads are a lighter weight alternative: multiple threads within the same process share the same address space (same page tables, no cache flush required). Thread context switches cost 100-300 nanoseconds — much cheaper than process switches. But threads still have substantial overhead: typically 1MB of stack, creation costs of 10-50 microseconds, and kernel involvement for scheduling.

The OS scheduler uses a preemptive model. It interrupts threads at regular intervals via a hardware timer, regardless of whether the thread is ready to yield. This is important: threads don't cooperate with the scheduler. They just run until interrupted.

Now look at this from a programmer's perspective. You're writing a web server. Each incoming request needs to do some work, make a database query (which takes 10ms), process the result, and respond. With OS threads:

```
1 request = 1 thread
10,000 concurrent requests = 10,000 threads
10,000 threads × 1MB stack = 10GB RAM just for stacks
10,000 threads × context switch overhead = scheduler bottleneck
```

This is the C10K problem that drove the creation of event loops, async/await, and ultimately — Go's goroutines.

---

## The Go Scheduler: An OS Inside Your Program

The Go runtime implements its own scheduler that manages goroutines the same way an OS manages processes. This is not a metaphor. It is structurally identical.

### The Three Primitives: G, M, P

The Go scheduler is built on three types of entities:

**G (Goroutine):** A goroutine. Contains the goroutine's stack (starting at 2-8KB, growable), its program counter (where it's currently executing), and its current status. Analogous to a Process Control Block in an OS.

**M (Machine):** An OS thread. The M is what actually executes code on a CPU. The Go scheduler runs as many M's as it needs, up to a configurable limit (default 10,000). Analogous to a CPU core from the goroutine scheduler's perspective.

**P (Processor):** A logical processor — a scheduling context. Each P has a local run queue of goroutines ready to execute. The number of P's is set by `GOMAXPROCS` (default: number of CPU cores). Analogous to a CPU core from the process scheduler's perspective, but implemented in software.

The relationship:

```
G (goroutines, thousands)
     ↕  scheduled onto
P (processors = GOMAXPROCS, e.g., 8)
     ↕  each P runs on one
M (OS threads, one per active P plus extras for blocking)
     ↕  mapped to
CPU cores (physical hardware)
```

A P can only be held by one M at a time. An M needs a P to run Go code. When an M is executing a goroutine, it's executing on one of your CPU cores. The Go scheduler multiplexes the G's onto the P's, and the OS maps the M's onto the CPU cores.

{{< callout type="info" >}}
**The OS Analogy, Made Precise**

| OS Concept | Go Scheduler Concept |
|------------|---------------------|
| Process | Goroutine (G) |
| CPU Core | Processor (P) |
| Running process | G bound to P |
| OS thread running process | M holding P, running G |
| Process context switch | Goroutine context switch |
| Process scheduler | Go runtime scheduler |
| `fork()` | `go func()` |
| Process stack (1-8MB) | Goroutine stack (2KB initial) |
| Process blocked on I/O | Goroutine parked, M released |
{{< /callout >}}

### Why This Architecture Exists

The key insight: most goroutines are blocked most of the time. A web server goroutine spends 95% of its time waiting for a database query, a network read, or a channel receive. If each goroutine held an OS thread while blocked, you'd need as many OS threads as goroutines — and you're back to the C10K problem.

The P solves this. When a goroutine blocks, it releases the P. The M can pick up a different goroutine from the P's run queue. One OS thread (M) can make progress on many goroutines — just like one CPU core can make progress on many OS processes.

---

## Goroutine Context Switches: Cooperative, Not Preemptive (Mostly)

The Go scheduler was originally cooperative: goroutines yielded control voluntarily at function call boundaries. The runtime inserted yield checks at the entry of function calls. A goroutine doing tight CPU work with no function calls could starve other goroutines.

Go 1.14 added **asynchronous preemption**: signals are sent to goroutines at 10ms intervals, forcing a yield even in tight loops. The Go scheduler is now a hybrid — cooperative at function call boundaries (the common case), preemptive via signals as a safety net.

Goroutine context switches cost roughly **200-300 nanoseconds** — 3-10x cheaper than OS thread context switches, and 5-10x cheaper than process context switches. The reason: goroutines share an address space, stacks are small and contiguous in Go's virtual address space, and no kernel involvement is needed.

This is why you can have 100,000 goroutines without catastrophe. The context switch overhead is negligible compared to actual work.

---

## What Actually Happens When You Write `go func()`

```go
go func() {
    doWork()
}()
```

Most developers think: "this starts a goroutine, which runs on a separate thread." Here's what actually happens:

1. The runtime allocates a new G struct (2-8KB of stack, program counter set to the start of the closure).
2. The G is placed on the **local run queue** of the current P.
3. The current goroutine continues executing.
4. At the next scheduling point (function call, channel operation, system call), the scheduler may switch to the new G or continue with the current one.
5. The new G is eventually picked up by a free P (either the current one, or another P via work stealing).

No OS thread is created. No `pthread_create` call. No kernel involvement. Just a small allocation and a pointer added to a queue. This is why goroutines are cheap — starting 100,000 of them uses roughly 2-8KB × 100,000 = 200-800MB of stack space, plus negligible scheduler overhead.

Compare to 100,000 OS threads: 1MB × 100,000 = 100GB of stack space, plus kernel thread management overhead.

### Work Stealing

When a P's local run queue is empty, it doesn't sit idle. It **steals** goroutines from other P's run queues:

```
P0 run queue: [G1, G2, G3, G4, G5, G6]  (busy)
P1 run queue: []  (empty, idle)

P1 steals half of P0's queue:
P0 run queue: [G1, G2, G3]
P1 run queue: [G4, G5, G6]  (P1 now has work)
```

This keeps all cores busy when work is available, without any programmer intervention. Work stealing is why you don't need to manually distribute work across goroutines — the scheduler does it automatically.

---

## Blocking Calls: The Scheduler's Superpower

This is the part most developers get wrong. When a goroutine blocks — on a channel receive, a mutex, a `time.Sleep` — what happens to the OS thread?

**For Go-aware blocking (channels, mutexes, sleep):**

The goroutine is parked (its state changes from "running" to "waiting"). The P is immediately made available to another goroutine. The M may stay on the P and pick up a new G. The original M is not blocked — only the G is blocked.

```
G1 running on P0/M1
  G1: result := <-ch  (no data available, G1 blocks)

  Runtime:
  - G1 status → waiting
  - G1 removed from P0's run queue
  - P0 picks up G2 from run queue
  - M1 continues running G2

  Later, when data is sent on ch:
  - G1 status → runnable
  - G1 added back to run queue
  - G1 resumes from exactly where it was blocked
```

**For blocking system calls (file I/O, certain network operations):**

The situation is more complex. Some syscalls cannot be made non-blocking (certain file I/O on Linux, for example). When a goroutine makes a blocking syscall:

1. The runtime detects the syscall is blocking.
2. The P is **handed off** to another M (or a new M is created if none are available).
3. The original M is now blocked in the kernel syscall, without a P.
4. When the syscall completes, the M attempts to acquire a P. If one is available, it continues. If not, the G is put in the global run queue and the M may be reused or returned to a pool.

```
G1 on P0/M1: read(fd, buf, n)  (blocking syscall)

Runtime detects blocking call:
  P0 → detached from M1
  P0 → handed to M2 (or new M created)
  M1 → blocked in kernel waiting for I/O

M2 running on P0 picks up G2, continues normally

I/O completes:
  M1 wakes from syscall
  M1 tries to acquire a P
    If P available → M1 continues running G1
    If no P available → G1 → global run queue, M1 → sleep
```

This is why network I/O in Go is so efficient: the `net` package uses non-blocking I/O under the hood with `epoll`/`kqueue`. Goroutines that wait for network data are parked (no thread blocked), and the runtime's **netpoller** thread is notified by the OS when data is available. The parked goroutine is resumed only when data arrives. One netpoller thread handles all network I/O events for all goroutines.

---

## CSP: The Philosophy Behind the Syntax

The `go` keyword and channels are not just syntactic sugar for threads and mutexes. They embody a specific theory of concurrent programming: **Communicating Sequential Processes**, published by Tony Hoare in 1978.

CSP's central claim is this: shared memory is hard to reason about because it's implicit and global. Any piece of code can modify shared state at any time. Proving correctness requires reasoning about all possible interleavings of all threads. This is exponentially hard.

CSP's alternative: make communication explicit. Instead of sharing memory and synchronizing access to it, **pass messages between processes**. Each process (goroutine) has private state. The only way to transfer data between goroutines is through a channel. No sharing, no races, no mutexes.

Go's design manifesto is: **"Do not communicate by sharing memory; instead, share memory by communicating."**

This is not just a cute quote. It's a statement about ownership. When you send a value on a channel, ownership conceptually transfers. The sender no longer accesses the value; the receiver now does. No two goroutines access the same memory at the same time — not because of a lock, but because the design makes it structurally impossible.

### What a Channel Actually Is

A channel is not magic. It's a data structure in the Go runtime:

```go
// Simplified version of Go's internal hchan struct
type hchan struct {
    qcount   uint           // number of elements in queue
    dataqsiz uint           // capacity of circular buffer
    buf      unsafe.Pointer // circular buffer for buffered channels
    elemsize uint16         // size of each element
    closed   uint32         // 1 if closed
    sendq    waitq          // goroutines waiting to send (blocked)
    recvq    waitq          // goroutines waiting to receive (blocked)
    lock     mutex          // protects all fields above
}
```

A channel is a locked circular buffer with two queues of parked goroutines. When you send on a full buffered channel, you're added to `sendq` and parked. When you receive from an empty channel, you're added to `recvq` and parked. When the condition is met (buffer has space, or data is available), the parked goroutine is woken and added back to the run queue.

The `lock` inside `hchan` is what makes channels safe — not the programmer's discipline. The runtime handles the locking internally, invisibly.

### Select: CSP's Choice Operator

The `select` statement is Go's implementation of CSP's external choice: wait for whichever of several channel operations becomes ready first.

```go
select {
case msg := <-ch1:
    handle(msg)
case ch2 <- value:
    // sent
case <-time.After(5 * time.Second):
    timeout()
}
```

When `select` is reached:
1. All channel operations are evaluated simultaneously.
2. If one is immediately ready, it executes.
3. If multiple are ready, one is chosen at random (uniformly — this is specified).
4. If none are ready, the goroutine is parked, registered in the `recvq`/`sendq` of all channels simultaneously, and woken when any one becomes ready.

The random selection when multiple cases are ready is not arbitrary — it prevents starvation. If `select` always chose the first ready case, a high-frequency channel could permanently starve lower-frequency ones.

---

## The Goroutine Stack: Growable by Design

OS threads have a fixed stack size (typically 1-8MB, set at creation). This is conservative: you must allocate for the worst case upfront. If your function recurses deeply, you might overflow. If it doesn't, you've wasted memory.

Goroutines start with a 2-8KB stack (changed across Go versions, currently 8KB). The stack grows dynamically as needed, up to a configurable maximum (default 1GB). This is what makes starting 100,000 goroutines feasible.

### How Stack Growth Works

Go uses **contiguous stacks** (prior to Go 1.3, it used segmented stacks — a different approach with different trade-offs). When a goroutine needs more stack space:

1. The runtime detects insufficient stack space at function preamble.
2. A larger stack is allocated (typically 2x the current size).
3. The entire current stack is **copied** to the new allocation.
4. All stack pointers are updated to reflect the new addresses.
5. Execution continues on the new stack.

This copy is safe because Go's garbage collector tracks all pointers. Raw unsafe pointers into stack memory are not allowed in safe Go code.

The implication: **never store a pointer to a stack variable across goroutines**. When the stack grows, the stack variable moves. Any external pointer becomes invalid. This is why Go's escape analysis exists: if a local variable's address is taken in a way that might outlive the stack frame, it's allocated on the heap instead.

---

## The GOMAXPROCS Dial

`GOMAXPROCS` sets the number of P's — and therefore the maximum degree of true parallelism. By default it equals `runtime.NumCPU()`.

```go
import "runtime"

// Set to use all cores (default behavior)
runtime.GOMAXPROCS(runtime.NumCPU())

// Force single-threaded execution (for debugging)
runtime.GOMAXPROCS(1)

// Useful for benchmarking: compare behavior at different parallelism levels
```

With `GOMAXPROCS(1)`, all goroutines run on one OS thread, interleaved cooperatively. This eliminates data races caused by true parallelism (but not races caused by goroutine scheduling — those still exist). It's useful for deterministic testing of concurrent code.

With `GOMAXPROCS(N)` where N > 1, up to N goroutines can run in parallel simultaneously. For CPU-bound work, N should match your core count. For I/O-bound work (most web services), a higher N can help, but the benefit diminishes: goroutines waiting on I/O don't consume P slots.

{{< callout type="warning" >}}
**A Common Misconception About GOMAXPROCS and Goroutines**

Setting `GOMAXPROCS(4)` does not mean only 4 goroutines can run. It means only 4 goroutines can run *simultaneously*. Hundreds of thousands of goroutines can exist; up to 4 run at any instant. The rest are either waiting in run queues, parked on channels/mutexes, or blocked on system calls.

This is exactly how an OS works: 4 cores doesn't mean only 4 processes can exist — it means only 4 run at any given CPU cycle.
{{< /callout >}}

---

## Goroutine Leaks: The Silent Killer

A goroutine leak is a goroutine that is started but never terminates. It remains parked, consuming stack memory and a slot in the runtime's goroutine table forever.

```go
// Classic goroutine leak
func leak() {
    ch := make(chan int)  // unbuffered channel, never written to
    go func() {
        val := <-ch  // blocks forever — nobody sends
        process(val)
    }()
    // Function returns without sending or closing ch
    // Goroutine is now permanently parked
}
```

Every call to `leak()` starts a goroutine that lives until the program exits. In a long-running service, this accumulates. Leaked goroutines:
- Consume stack memory (2KB-8KB each, growing if the leak patterns are complex)
- Maintain references to their closures, preventing garbage collection of anything they close over
- Show up in `runtime.NumGoroutine()` and `pprof` goroutine profiles

### The Standard Patterns for Preventing Leaks

**1. Always have a termination path — use context:**

```go
func worker(ctx context.Context, ch <-chan int) {
    for {
        select {
        case val, ok := <-ch:
            if !ok {
                return  // channel closed
            }
            process(val)
        case <-ctx.Done():
            return  // context cancelled — clean exit
        }
    }
}
```

**2. Use buffered channels when you don't need synchronization:**

```go
// If you don't care whether the goroutine has consumed the value,
// a buffered channel prevents the sender from blocking when the
// receiver exits early.
ch := make(chan result, 1)
go func() {
    ch <- expensiveComputation()  // doesn't block even if nobody reads
}()

select {
case r := <-ch:
    use(r)
case <-timeout:
    // goroutine will write to buffered ch and exit cleanly
    // (not leak — it completes after writing)
}
```

**3. Close channels to signal completion:**

```go
done := make(chan struct{})

go func() {
    defer close(done)  // signal completion no matter how we exit
    for {
        select {
        case val := <-work:
            process(val)
        case <-stop:
            return
        }
    }
}()

<-done  // wait for goroutine to signal it's done
```

**Detecting leaks:** The `goleak` package by Uber provides a `goleak.VerifyNone(t)` test helper that fails the test if any goroutines started during the test are still running at the end.

---

## Practical Consequences of the Mental Model

### Why goroutines are not "async functions"

In JavaScript/Python async models, `async/await` is syntactic sugar for callbacks. The code runs on a single thread (or a small thread pool). When you `await`, you yield to the event loop.

Goroutines are not this. They run on real OS threads. They can block (the runtime handles the unblocking). They can run in parallel. You don't need to mark functions as `async` — every function is schedulable.

The key difference: **there is no function coloring problem in Go.** In Python, a regular function cannot call an `async` function and wait for it. In Go, any goroutine can do anything. There's no distinction between "sync code" and "async code." All goroutines are treated uniformly by the scheduler.

### Why `go func()` is not "fire and forget"

"Fire and forget" implies you don't care about the result or completion. But every goroutine you start is a resource: stack memory, scheduler overhead, potential closure references. If you start goroutines and don't track them, you get leaks.

The Go runtime does not garbage-collect goroutines. A goroutine lives until it returns. There is no `goroutine.Cancel()`. The programmer is responsible for goroutine lifecycle.

Use `sync.WaitGroup` or channel signaling to track completion. Use `context.Context` to propagate cancellation.

### Why channels are better than mutexes (for most things)

A mutex protects access to shared state. The programmer must remember to lock and unlock correctly, in the right order, at all call sites. A missed lock = data race. A double-unlock = panic. A lock held too long = contention.

A channel transfers ownership. The value exists on one goroutine at a time. There's no shared state to protect. The compiler and runtime enforce the synchronization.

This doesn't mean never use mutexes — for protecting a counter, a mutex is simpler and faster than a channel. The rule of thumb: use channels for coordinating goroutines (sending work, collecting results, signaling), use mutexes for protecting shared state within one logical entity.

---

## The Number Everyone Gets Wrong

"How many goroutines can Go handle?"

The right question is: how many goroutines can be running (not just existing) simultaneously? The answer: `GOMAXPROCS` — typically your core count, 4-16 for most servers.

The number that can *exist*: limited by memory. A 1GB server can hold approximately 500,000 goroutines with 2KB stacks — though realistic stacks are larger. Production Go services routinely handle 100,000-500,000 concurrent goroutines for high-traffic applications.

For comparison: a typical Linux server handles 1,000-10,000 OS threads before scheduler overhead becomes prohibitive.

---

## Summary: The Mental Model That Changes How You Write Go

The Go runtime is a miniature operating system. Goroutines are its processes. The G/M/P scheduler is its process scheduler. Channels are its IPC mechanism. Context cancellation is its signal delivery.

When you understand this:

- You understand why goroutines are cheap (no kernel involvement, tiny stacks)
- You understand why blocking doesn't mean thread-blocking (P is released, M picks up new G)
- You understand why `GOMAXPROCS` is the true parallelism limit
- You understand why goroutine leaks are dangerous (no GC for goroutines)
- You understand why channels are the right primitive (CSP — communication, not shared memory)
- You understand why Go's concurrency model is fundamentally different from threads-and-locks

The next time you write `go func()`, remember: you're not starting a thread. You're creating a scheduled entity in a runtime that mirrors the design of every operating system scheduler ever written — just implemented in user space, tuned for your application's workload, and exposed through a syntax so clean that most people never realize how much machinery is underneath.
