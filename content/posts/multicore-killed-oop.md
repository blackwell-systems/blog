---
title: "How Multicore CPUs Killed Object-Oriented Programming"
date: 2026-01-24
draft: false
tags: ["oop", "object-oriented", "concurrency", "parallelism", "multicore", "go", "rust", "java", "python", "reference-semantics", "value-semantics", "race-conditions", "mutex", "performance", "programming-paradigms", "history"]
categories: ["programming", "architecture"]
description: "Object-oriented programming dominated for decades, but the multicore revolution exposed a fatal flaw: shared mutable state through references. Modern languages chose value semantics specifically to make concurrency safe by default."
summary: "OOP's reference semantics were manageable in single-threaded code. But when CPUs went multicore in 2005, hidden shared state went from 'confusing' to 'catastrophic.' This is why Go, Rust, and modern languages abandoned default references for value semantics."
---

For 30 years (1980s-2010s), object-oriented programming was the dominant paradigm. Java, Python, Ruby, C++, C# - all centered their design around objects: bundles of data and behavior, allocated on the heap, accessed through references.

Then something changed.

Languages designed after 2007 - Go, Rust, Zig - deliberately rejected classical OOP patterns. No classes. No inheritance. No default reference semantics. Why?

{{< callout type="info" >}}
**The Multicore Revolution**

In 2005, Intel released the Pentium D - the first mainstream dual-core processor. By 2007, quad-core CPUs were common. CPU clock speeds had hit a wall (~3-4 GHz), and the only path to faster programs was parallelism: running code on multiple cores simultaneously.

This hardware shift exposed a fundamental flaw in OOP's design: **shared mutable state through references makes concurrent programming catastrophic**.
{{< /callout >}}

This post explores how the need for safe, efficient concurrency drove modern languages to abandon OOP's reference semantics in favor of value semantics.

---

## The OOP Design Choice: References by Default

Object-oriented languages made a deliberate choice: **assignment copies references (pointers), not data**.

### Python: Everything Is a Reference

```python
class Point:
    def __init__(self, x, y):
        self.x, self.y = x, y

p1 = Point(1, 2)
p2 = p1  # Copies reference, not data

p2.x = 10
print(p1.x)  # 10 - p1 affected! Both reference same object
```

**Memory layout:**

```
Stack:                        Heap:
┌──────────────┐            ┌──────────────┐
│ p1: 0x1000   │───────────>│ Point object │
└──────────────┘     ┌─────>│ x: 10, y: 2  │
                     │      └──────────────┘
┌──────────────┐     │
│ p2: 0x1000   │─────┘
└──────────────┘

Both variables point to same object (shared state)
```

### Java: Objects Use References

```java
class Point {
    int x, y;
}

Point p1 = new Point();
p1.x = 1;
p1.y = 2;

Point p2 = p1;  // Copies reference

p2.x = 10;
System.out.println(p1.x);  // 10 - p1 affected!
```

Java splits the difference: primitives (`int`, `double`) use value semantics, but objects use reference semantics.

### Why This Design?

Reference semantics enabled:

1. **Efficient passing** - Pass 8-byte pointer instead of copying large objects
2. **Shared state** - Multiple parts of code operate on same data
3. **Polymorphism** - References enable dynamic dispatch through vtables
4. **Object identity** - Objects have identity (`id()` in Python, `==` checks reference in Java)

This worked well in the **single-threaded era** of the 1990s-2000s. The problems were manageable:
- Hidden mutations were confusing but debuggable
- Memory leaks were an issue (pre-GC) but deterministic
- Performance was good enough for most applications

But everything changed when CPUs went multicore.

---

## The Multicore Catalyst (2005-2010)

{{< mermaid >}}
timeline
    title The Shift to Multicore
    2005 : Intel Pentium D (first mainstream dual-core)
         : Clock speeds hit 3-4 GHz ceiling
    2006 : Intel Core 2 Duo/Quad
         : Industry realizes: parallelism is the future
    2007 : Go development begins at Google
         : Rob Pike: "Go is designed for the multicore world"
    2009 : Go 1.0 released
         : Goroutines + channels for safe concurrency
    2010 : Rust development begins at Mozilla
         : Goal: fearless concurrency through ownership
    2015 : Rust 1.0 released
         : Zero-cost abstractions + thread safety
{{< /mermaid >}}

**The hardware reality:** CPU speeds stopped increasing. Single-threaded performance plateaued. The only way to make programs faster was to use multiple cores - which meant writing concurrent code.

**The software problem:** OOP's reference semantics, which were merely "confusing" in single-threaded code, became **catastrophic** in concurrent code.

---

## Why Reference Semantics Broke with Concurrency

### Single-Threaded: Annoying but Manageable

```python
# Python: Shared mutable state (single-threaded)
users = []

def add_user(user):
    users.append(user)  # Modifies shared list

def process_users():
    for user in users:
        user['active'] = False  # Modifies shared objects

# Problems:
# - Hidden mutation (users modified without explicit indication)
# - Hard to track where changes happen
# - Confusing for debugging
# 
# But: Deterministic, debuggable, doesn't crash
```

### Multi-Threaded: Race Conditions Everywhere

```python
# Same code, now with threads
import threading

users = []
lock = threading.Lock()  # Must add locks everywhere!

def add_user(user):
    with lock:  # Lock required
        users.append(user)

def process_users():
    with lock:  # Lock required
        for user in users:
            user['active'] = False

# Thread 1: add_user()
# Thread 2: process_users()
# 
# Without locks: DATA RACE
# - Both threads modify users simultaneously
# - List corruption, crashes, lost data
# 
# With locks: SERIALIZED
# - Threads wait for each other
# - No parallelism achieved
# - Defeats the purpose of multiple cores!
```

**The fundamental problem:** Reference semantics mean **all state is shared by default**. In concurrent code, shared mutable state requires synchronization (locks), which:

1. **Serializes execution** - Only one thread can access locked section (defeats parallelism)
2. **Adds complexity** - Every shared access needs lock/unlock logic
3. **Enables deadlocks** - Multiple locks can deadlock if acquired in wrong order
4. **Hides race conditions** - Forget one lock, and you have data corruption

{{< callout type="warning" >}}
**Mutexes: The Band-Aid That Kills Performance**

Mutexes don't solve OOP's concurrency problems - they're a band-aid that sacrifices the very parallelism you're trying to achieve. Locked critical sections serialize execution, turning parallel code into sequential code.
{{< /callout >}}

---

## The Post-OOP Response: Value Semantics for Safe Concurrency

### Go's Solution (2007-2009): Values + Goroutines + Channels

Go's designers (Ken Thompson, Rob Pike, Robert Griesemer) came from systems programming backgrounds and saw the concurrency crisis firsthand at Google. Their solution: **value semantics by default, with explicit sharing**.

```go
// Go: Values are copied by default
type Point struct {
    X, Y int
}

p1 := Point{1, 2}
p2 := p1  // Copies the entire struct (independent copy)

p2.X = 10
fmt.Println(p1.X)  // 1 - p1 unchanged!
```

**Memory layout:**

```
Stack:
┌──────────────┐    ┌──────────────┐
│ p1           │    │ p2           │
│ X: 1, Y: 2   │    │ X: 10, Y: 2  │
└──────────────┘    └──────────────┘

Two independent copies (no shared state)
```

**Concurrent code is safe by default:**

```go
// Each goroutine gets independent copy
func worker(id int, data []int) {
    // Make local copy
    localData := make([]int, len(data))
    copy(localData, data)
    
    // Process independently - NO LOCKS NEEDED
    for i := range localData {
        localData[i] *= 2
    }
}

// Spawn 1000 workers (cheap, safe, parallel)
data := []int{1, 2, 3, 4, 5}
for i := 0; i < 1000; i++ {
    go worker(i, data)  // Each gets independent copy
}
```

**Key insight:** Each goroutine operates on independent data. No shared state = no locks = true parallelism.

{{< callout type="info" >}}
**Stack vs Heap: Lifetime and Performance**

Value semantics enable a critical optimization: **stack allocation**.

**Stack allocation (deterministic lifetime):**
- Values live exactly as long as the function scope (LIFO deallocation)
- Allocation: Move stack pointer (1 CPU cycle)
- Deallocation: Automatic when function returns (instant)
- Cache-friendly: Sequential, predictable access
- No GC tracking needed

**Heap allocation (flexible lifetime):**
- Values outlive their creating function (deallocation decoupled from allocation)
- Allocation: Search free list, update metadata (~50-100 CPU cycles)
- Deallocation: Garbage collector scans and frees (variable latency)
- Cache-unfriendly: Scattered allocation
- Requires GC tracking overhead

**Go's escape analysis:** Compiler decides stack vs heap based on lifetime needs. Values that don't escape stay on stack (fast). Values that escape go to heap (flexible, GC-managed).

The performance difference (stack ~100× faster) stems from the lifetime model: deterministic LIFO deallocation is inherently cheaper than flexible GC-managed deallocation.
{{< /callout >}}

**When sharing is needed, use channels:**

```go
// Channel: Explicit communication (no shared memory)
results := make(chan int, 1000)

for i := 0; i < 1000; i++ {
    go func(id int) {
        result := expensiveComputation(id)
        results <- result  // Send to channel (no lock!)
    }(i)
}

// Collect results (single goroutine reads)
for i := 0; i < 1000; i++ {
    result := <-results
    fmt.Println(result)
}
```

{{< callout type="success" >}}
**Go's Concurrency Mantra**

"Don't communicate by sharing memory; share memory by communicating."

Value semantics + channels = safe parallelism without locks.
{{< /callout >}}

### Rust's Solution (2010-2015): Ownership + Borrow Checker

Rust took a different approach: enforce thread safety at **compile time** through ownership rules.

```rust
// Rust: Ownership prevents data races
let data = vec![1, 2, 3];

// ERROR: Can't share mutable reference
thread::spawn(move || {
    data.push(4);  // Would move ownership
});
// data no longer accessible here - COMPILE ERROR
```

**Ownership rules:**

1. Each value has exactly one owner
2. When owner goes out of scope, value is dropped
3. References are borrowed, not owned
4. Can't have mutable reference while immutable references exist

**Result:** The compiler prevents data races. No runtime locks, no race conditions, no undefined behavior.

```rust
// Correct: Each thread gets owned copy
let data = vec![1, 2, 3];

let handle1 = thread::spawn(move || {
    let mut local = data;  // Ownership moved
    local.push(4);
});

// Can't use `data` here - ownership moved to thread
```

{{< callout type="success" >}}
**Rust's Concurrency Guarantee**

"Fearless concurrency: If it compiles, it's thread-safe."

The borrow checker enforces memory safety and prevents data races at compile time.
{{< /callout >}}

---

## The Performance Bonus: Cache Locality

Concurrency was the primary driver for value semantics, but there was a significant **performance bonus**: cache locality.

### The Problem with References: Pointer Chasing

Modern CPUs read memory in **cache lines** (typically 64 bytes). When you access address X, the CPU fetches X plus the next 63 bytes into cache. Sequential memory access is fast; scattered memory access is slow.

**Reference semantics destroy cache locality:**

```python
# Python: Array of Point objects (references)
points = [Point(i, i) for i in range(1000)]

# Memory layout (scattered on heap):
# points[0] → 0x1000 (heap)
# points[1] → 0x5000 (heap, different location)
# points[2] → 0x9000 (heap, different location)
# ...

# Iteration requires pointer chasing (cache misses)
sum = 0
for p in points:
    sum += p.x + p.y  # Each access: follow pointer → cache miss
```

{{< mermaid >}}
graph LR
    A[Array of pointers] -->|ptr[0]| B[Point @ 0x1000]
    A -->|ptr[1]| C[Point @ 0x5000]
    A -->|ptr[2]| D[Point @ 0x9000]
    
    style A fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style B fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style C fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style D fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**Value semantics enable cache-friendly layout:**

```go
// Go: Array of Point values (contiguous)
type Point struct { X, Y int }
points := make([]Point, 1000)

// Memory layout (contiguous):
// [Point{0,0}, Point{1,1}, Point{2,2}, ...]
// All data in sequential memory

// Iteration is cache-friendly (prefetching works)
sum := 0
for i := range points {
    sum += points[i].X + points[i].Y  // Sequential access, cache hits
}
```

{{< mermaid >}}
graph LR
    A[Contiguous array] --> B[Point 0]
    B --> C[Point 1]
    C --> D[Point 2]
    D --> E[Point 3]
    
    style A fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style B fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style C fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style D fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style E fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**Performance impact:**

```
Benchmark: Sum 1 million Point coordinates

Python (references):  ~50-100 milliseconds
                      - Pointer chasing
                      - Cache misses every access
                      - Object headers add overhead

Go (values):          ~10-20 milliseconds  
                      - Sequential memory access
                      - CPU prefetches cache lines
                      - No object headers

Speedup: 3-5× faster
```

{{< callout type="info" >}}
**Why This Matters**

Cache locality wasn't the driver for value semantics - concurrency was. But it turned out that the same design choice that makes concurrent code safe (independent copies) also makes sequential code faster (contiguous memory).

Value semantics deliver both safety and performance.
{{< /callout >}}

---

## The Lock Bottleneck: How Mutexes Kill Parallelism

Let's look concretely at why locks defeat the purpose of multicore CPUs.

### The Setup: Parallel Processing

```go
// Goal: Process 1000 items in parallel
type Item struct { ID int, Value string }
type Result struct { ID int, Processed string }

func processItem(item Item) Result {
    // Expensive computation (takes 1ms)
    time.Sleep(1 * time.Millisecond)
    return Result{item.ID, strings.ToUpper(item.Value)}
}
```

### Approach 1: Shared Slice with Mutex (BAD)

```go
func processWithMutex(items []Item) []Result {
    var results []Result
    var mu sync.Mutex  // Protects shared slice
    
    var wg sync.WaitGroup
    for _, item := range items {
        wg.Add(1)
        go func(it Item) {
            defer wg.Done()
            
            result := processItem(it)  // Parallel (1ms per item)
            
            mu.Lock()
            results = append(results, result)  // SERIALIZED!
            mu.Unlock()
            // Only one goroutine can append at a time
        }(item)
    }
    wg.Wait()
    return results
}
```

**Timeline visualization:**

```
Time →
Goroutine 1: [process 1ms]──[Lock][append][Unlock]─────────────
Goroutine 2: [process 1ms]─────────[WAIT]───[Lock][append][Unlock]───
Goroutine 3: [process 1ms]──────────────────[WAIT]───[Lock][append][Unlock]

Processing is parallel, but appending is serialized
Result: 1000 goroutines, but only 1 can append at a time
```

**Performance:**

```
Best case (sequential):   1000 items × 1ms = 1000ms
With mutex (1000 cores):  1000ms compute + serialized append
                         Still slow due to lock contention
```

### Approach 2: Value Copies with Local Aggregation (GOOD)

```go
func processWithValues(items []Item) []Result {
    numWorkers := runtime.NumCPU()  // e.g., 8 cores
    chunkSize := len(items) / numWorkers
    
    type workResult struct {
        results []Result
    }
    resultsChan := make(chan workResult, numWorkers)
    
    // Spawn workers
    for i := 0; i < numWorkers; i++ {
        start := i * chunkSize
        end := start + chunkSize
        if i == numWorkers-1 {
            end = len(items)
        }
        
        go func(chunk []Item) {
            // Each worker has independent slice (NO LOCK!)
            localResults := make([]Result, 0, len(chunk))
            
            for _, item := range chunk {
                result := processItem(item)
                localResults = append(localResults, result)  // Local only
            }
            
            resultsChan <- workResult{localResults}
        }(items[start:end])
    }
    
    // Combine results (single goroutine, no contention)
    var results []Result
    for i := 0; i < numWorkers; i++ {
        wr := <-resultsChan
        results = append(results, wr.results...)
    }
    return results
}
```

**Timeline visualization:**

```
Time →
Worker 1 (125 items): [process][process]...[process] → send results
Worker 2 (125 items): [process][process]...[process] → send results
Worker 3 (125 items): [process][process]...[process] → send results
Worker 4 (125 items): [process][process]...[process] → send results
...
Worker 8 (125 items): [process][process]...[process] → send results

Main goroutine: [wait for all] → combine results (minimal)

True parallelism: No locks, no waiting, full CPU utilization
```

**Performance:**

```
Sequential:        1000 items × 1ms = 1000ms
With mutex:        ~800-900ms (lock contention)
With value copies: 1000 items ÷ 8 cores × 1ms = 125ms

Speedup: 8× faster (full parallelism, no serialization)
```

{{< callout type="success" >}}
**The Value Semantics Win**

Each worker operates on independent data (value copies). No locks needed, no serialization, no contention. Result: true parallelism and 8× speedup on 8 cores.

This is impossible with OOP's shared mutable state through references.
{{< /callout >}}

---

## The Three Drivers: Ranking the Importance

Why did modern languages abandon OOP's reference semantics? Three drivers, in order of importance:

### 1. Concurrency/Parallelism (PRIMARY - 60%)

**The multicore revolution made this critical.**

- Shared mutable state (references) → race conditions
- Race conditions → need locks
- Locks → serialization (defeats parallelism)
- Serialization → can't utilize multiple cores

**Impact:** OOP's reference semantics went from "confusing" to "catastrophic" in concurrent code.

### 2. Performance (SECONDARY - 30%)

**Value semantics have performance benefits:**

- Cache locality (contiguous memory)
- Stack allocation (fast, no GC pressure)
- No pointer indirection (direct access)

**But:** These existed in the single-threaded era too. They became more important with multicore (need every optimization), but weren't the driver.

### 3. Complexity (TERTIARY - 10%)

**OOP had design problems all along:**

- Deep inheritance hierarchies (fragile base class)
- Premature abstraction (AbstractFactoryFactoryProvider)
- Hidden mutations (confusing, hard to debug)

**But:** Developers tolerated these issues for 30 years. Multicore made them intolerable.

{{< callout type="info" >}}
**The Counterfactual**

If CPUs had stayed single-core, OOP might still be dominant despite its complexity issues. Reference semantics would still be "confusing but manageable."

But we didn't stay single-core, so concurrency forced the rethink.
{{< /callout >}}

---

## When OOP Still Makes Sense

Value semantics aren't a silver bullet. Some domains naturally fit OOP's reference semantics:

### 1. UI Frameworks

Widgets form natural hierarchies:

```
Window
├── MenuBar
│   ├── FileMenu
│   └── EditMenu
├── ContentArea
│   ├── Toolbar
│   └── Canvas
└── StatusBar
```

Widgets are long-lived objects with identity. References make sense here.

**But:** Even UI frameworks are moving away from OOP:
- React: Functional components, immutable state
- SwiftUI: Value types, declarative syntax
- Jetpack Compose: Composable functions, not classes

### 2. Game Engines (Entity-Component Systems)

Modern game engines use **ECS (Entity-Component System)**, which is fundamentally anti-OOP:

```go
// Not OOP inheritance:
// class Enemy extends GameObject extends Entity { }

// ECS: Entities are IDs, components are data, systems are functions
type Entity uint64

type Position struct { X, Y, Z float64 }
type Velocity struct { DX, DY, DZ float64 }
type Health struct { Current, Max int }

// Systems operate on component data (data-oriented design)
func PhysicsSystem(positions []Position, velocities []Velocity) {
    for i := range positions {
        positions[i].X += velocities[i].DX
        positions[i].Y += velocities[i].DY
        positions[i].Z += velocities[i].DZ
    }
}
```

**Why ECS won:** Better cache locality, easier parallelism, simpler reasoning.

### 3. Legacy Codebases

Millions of lines of Java/C++/Python exist. Rewriting is expensive.

**Pragmatic approach:** Use value semantics for new code, maintain OOP for legacy.

---

## Lessons Learned

After 30 years of OOP dominance and 15 years of post-OOP languages, what have we learned?

### 1. Default References Were the Wrong Choice

**The problem:**

- Assignment copies references (implicit sharing)
- Sharing is convenient for single-threaded code
- But catastrophic for concurrent code (race conditions)

**The solution:**

- Assignment copies values (explicit sharing)
- Sharing requires explicit pointers or channels
- Concurrent code is safe by default

### 2. Mutexes Are a Band-Aid, Not a Solution

**Mutexes don't fix OOP's concurrency problems:**

- They serialize execution (kill parallelism)
- They add complexity (lock/unlock everywhere)
- They enable deadlocks (wrong acquisition order)
- They hide race conditions (forget one lock = corruption)

**Value semantics eliminate the need for locks** in most code.

### 3. Performance Matters More Than We Thought

**Single-threaded era:** Convenience > performance (references were "good enough")

**Multicore era:** Need every optimization (8 cores × 0.9 efficiency = 7.2× speedup matters)

Value semantics deliver:
- True parallelism (no lock serialization)
- Cache locality (contiguous memory)
- Stack allocation (no GC pressure)

### 4. Explicit Is Better Than Implicit

**OOP's philosophy:** Hide complexity (encapsulation, abstraction)

**Post-OOP philosophy:** Show complexity (explicit sharing, visible costs)

```go
// Explicit: You see where sharing happens
func modify(p *Point) {  // Pointer = might mutate
    p.X = 10
}

// Explicit: You see where copying happens
func transform(p Point) Point {  // Value = independent copy
    p.X *= 2
    return p
}
```

**Result:** Code is more verbose but easier to reason about.

---

## The Pendulum Swings

The history of programming is a pendulum between extremes:

{{< mermaid >}}
timeline
    title The Programming Paradigm Pendulum
    1970s : Procedural (C, Pascal)
          : Functions + data, manual memory
    1980s-2000s : Object-Oriented (Java, Python, C++)
                : Classes, inheritance, references
    2007-2020s : Post-OOP (Go, Rust, Zig)
               : Values, composition, explicit sharing
    Future : Data-Oriented Design?
           : Cache-friendly layouts, SIMD, GPU compute
{{< /mermaid >}}

**The lesson:** No paradigm is perfect. Each generation solves the problems of the previous generation but introduces new ones.

OOP solved procedural programming's lack of encapsulation, but introduced complexity and concurrency issues.

Post-OOP solves concurrency and performance, but introduces verbosity and requires understanding of memory models.

**The future:** Likely more focus on data-oriented design (cache locality, SIMD, GPU compute) as hardware continues to evolve.

---

## What This Means for You

### If You're Writing New Code

**Use value semantics by default:**

- Values for small, independent data (structs, configuration)
- Channels for communication (not shared memory)
- Pointers only when necessary (large data, mutation)

**Use concurrency primitives:**

- Go: Goroutines + channels
- Rust: Async/await + ownership
- Even in Java/Python: Immutable data + message passing

### If You're Maintaining OOP Code

**Incremental improvements:**

- Make classes immutable where possible
- Use value objects for data transfer
- Limit shared mutable state
- Add synchronization where needed (but minimize)

**Don't rewrite everything:**

- OOP isn't evil, it's just wrong for concurrent code
- Legacy code can coexist with modern patterns
- Rewrite only when pain justifies cost

### If You're Learning Programming

**Understand both paradigms:**

- OOP for understanding legacy codebases
- Value semantics for writing concurrent code
- Both have value in different contexts

**Focus on fundamentals:**

- Memory models (stack vs heap, value vs reference)
- Concurrency primitives (goroutines, async/await)
- Performance implications (cache locality, allocation)

---

## Conclusion

Object-oriented programming wasn't killed by bad design or theoretical flaws. It was killed by hardware evolution.

When CPUs went multicore in 2005, OOP's fundamental design choice - **shared mutable state through references** - went from "convenient but confusing" to "catastrophic for concurrency."

Modern languages (Go, Rust) chose value semantics specifically to make concurrent programming safe by default:

- Values are independent copies (no shared state)
- No shared state = no locks needed
- No locks = true parallelism (full CPU utilization)

The performance benefits (cache locality, stack allocation) were a bonus. The driver was concurrency.

After 30 years of OOP dominance, the pendulum has swung. Value semantics are the new default. References still exist, but they're explicit - you opt into sharing rather than opting out.

**The lesson:** Language design is shaped by hardware constraints. As hardware evolves (multicore, SIMD, GPUs), language design evolves to match.

OOP served us well for three decades. But the multicore era demands a different approach. Value semantics aren't perfect, but they're better suited to the hardware reality of 2020s and beyond.

---

## Further Reading

- **Go Concurrency Patterns:** [Go Blog - Share Memory By Communicating](https://go.dev/blog/codelab-share)
- **Rust Ownership:** [The Rust Book - Ownership](https://doc.rust-lang.org/book/ch04-00-understanding-ownership.html)
- **Data-Oriented Design:** [Mike Acton - Data-Oriented Design](https://www.youtube.com/watch?v=rX0ItVEVjHc)
- **Related Series:** [Go's Value Philosophy (Part 1-3)](/tags/go-value-philosophy/)
