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
3. **Polymorphism** - References enable dynamic dispatch through [vtables](https://en.wikipedia.org/wiki/Virtual_method_table)
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

## Threads Existed Before Multicore

A common misconception: threads were invented for multicore CPUs. Actually, threads predate multicore by **decades**.

**Timeline:**
- **1960s-1970s:** Threads invented for single-core mainframes
- **1995:** Java ships with threading API (Pentium era - single core)
- **2005:** Intel Pentium D - first mainstream multicore
- **Gap:** 30+ years of threads on single-core systems

**Why threads on single core?**

Threads solved **concurrency** (I/O multiplexing), not parallelism:

```python
# Web server on single Pentium (1995)
def handle_client(client):
    request = client.recv()         # I/O wait (10ms)
    data = database.query(request)  # I/O wait (50ms)
    client.send(data)               # I/O wait (10ms)

# While Thread 1 waits for I/O, Thread 2 runs
# CPU never idle despite I/O delays
# 100 threads serve 100 clients on 1 core
```

**Time-slicing visualization:**

```
Single Core (1995):
Time:  0ms   10ms  20ms  30ms  40ms
CPU:   [T1]  [T2]  [T3]  [T1]  [T2]
       ↑ Rapid switching (only one executes at a time)

All threads make progress, but not simultaneously
```

**This worked fine with reference semantics** because:
- Only one thread executing at any moment (time-slicing)
- Context switches at predictable points
- Race conditions possible but rare
- Locks needed, but contention low

**Multicore changed everything:**

```
Dual Core (2005):
Time:  0ms──────────────────────40ms
Core 1: [Thread 1 continuously]
Core 2: [Thread 2 continuously]
        ↑ True simultaneous execution

NOW threads run truly parallel
```

**The paradigm shift:**

| Era | Hardware | Threads For | Locks |
|-----|----------|-------------|-------|
| Pre-2005 | Single core | I/O concurrency | Nice to have |
| Post-2005 | Multicore | CPU parallelism | **Mandatory** |

{{< callout type="warning" >}}
**Threads Weren't the Problem**

Threads worked fine for 30+ years on single-core systems. The crisis emerged when:

**Threads + Multicore + Reference Semantics** = Data races everywhere

OOP languages designed in the single-core era (1980s-1990s) assumed sequential execution with occasional context switches. Multicore exposed hidden shared state that had always existed but was protected by time-slicing serialization.
{{< /callout >}}

**Why does Python have a GIL?**

**The GIL (Global Interpreter Lock)** is a mutex lock on the CPython interpreter process. Only one thread can hold the GIL at a time, which means only one thread can execute Python bytecode at any moment - even on multicore CPUs.

The GIL was created in 1991 - the **single-core era**. Guido van Rossum's design assumption:

> "Only one thread needs to execute Python bytecode at a time"

This made perfect sense when CPUs had one core! The single mutex lock simplified:
- **Memory management:** Reference counting without per-object locks (all mutations serialized by GIL)
- **C extension compatibility:** C extensions don't need thread-safety (GIL protects them)
- **Implementation complexity:** Simpler interpreter (one global lock vs thousands of fine-grained locks)

**Problem:** This assumption broke in 2005 when multicore arrived.

```python
# Two CPU-bound threads on dual-core
Thread 1: heavy_computation()  # Wants Core 1
Thread 2: heavy_computation()  # Wants Core 2

# GIL ensures only one executes Python code
# Core 2 sits idle!
# No parallelism for CPU-bound Python code
```

**Why Python couldn't remove the GIL for 33 years:**
- Reference counting everywhere (not thread-safe without GIL)
- Thousands of C extensions assume single-threaded execution
- Backward compatibility nightmare

{{< callout type="info" >}}
**Update: Python 3.13 (October 2024)**

Python finally made the GIL optional via PEP 703, but the implementation reveals how deep the architectural constraint went:

- **Requires build flag:** `python3.13 --disable-gil` (not default)
- **Performance cost:** 8-10% single-threaded slowdown without GIL
- **C extension compatibility:** Requires per-object locks (massive ecosystem refactor)
- **Timeline:** Won't be default until Python 3.15+ (2026 at earliest)
- **Technical debt:** Deferred reference counting, per-object biased locks, thread-safe allocator

It took **33 years** (1991-2024) to make the GIL optional, and it's still not the default. Even with GIL removal, Python's reference semantics mean you still need explicit synchronization for shared mutable state.
{{< /callout >}}

**The lesson:** Design choices from the single-core era became architectural constraints that took decades to unwind. Languages designed after 2005 (Go, Rust) made different choices from the start - they didn't have 30+ years of single-threaded assumptions baked into their ecosystems.

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

1. **Serializes execution** - Only one thread can access locked section (**defeats parallelism**)
2. **Adds complexity** - Every shared access needs lock/unlock logic
3. **Enables deadlocks** - Multiple locks can deadlock if acquired in wrong order
4. **Hides race conditions** - Forget one lock, and you have data corruption

{{< callout type="warning" >}}
**Mutexes: The Band-Aid That Kills Performance**

Mutexes don't solve OOP's concurrency problems - they're a band-aid that sacrifices the very parallelism you're trying to achieve. Locked critical sections serialize execution, turning parallel code into sequential code.
{{< /callout >}}

### Reference Semantics Specifically Made This Catastrophic

**Critical insight:** Not all languages suffered equally. The multicore crisis was specific to **reference-dominant languages** (Python, Java, Ruby, C#).

**Value-oriented languages handled multicore fine:**

```c
// C (1972) - value semantics
struct Point {
    int x, y;
};

void worker(struct Point p) {  // Receives COPY
    p.x = 100;  // Modifies copy, not original
}

Point p1 = {1, 2};
// Spawn threads - each gets independent copy
// Safe by default (unless using pointers explicitly)
```

**C programmers already knew:**
- Assignment copies values
- Pointers are explicit (`*`, `&`)
- Sharing is visible in the code

**Multicore just meant "use fewer global variables and more thread-local copies."** The mental model didn't change.

**OOP languages had the opposite problem:**

```python
# Python - reference semantics
class Point:
    def __init__(self, x, y):
        self.x, self.y = x, y

p1 = Point(1, 2)
p2 = p1  # Copies REFERENCE (hidden sharing)

# Threads see SAME object
# Sharing is invisible in the code
# Race conditions everywhere on multicore
```

**Why OOP struggled:**
- Assignment copies references (hidden sharing)
- All objects heap-allocated by default
- Mutation affects all references
- No way to tell from code what's shared

**The design space:**

|                       | **Single Core** | **Multicore** |
|-----------------------|-----------------|---------------|
| **Reference Semantics** (Python/Java) | ✓ Time-slicing provides safety | ✗ Data races everywhere |
| **Value Semantics** (C/Go) | ✓ Independent copies | ✓ Still independent copies |

{{< callout type="info" >}}
**Why Go Succeeded Where Java Struggled**

Go (2007) was designed specifically for the multicore era:

- **Value semantics by default:** Assignment copies data
- **Explicit pointers:** `&` and `*` make sharing visible
- **Cheap goroutines:** 2KB stacks vs 1MB OS threads
- **Channels:** Message passing instead of shared memory

Java's reference-everywhere model required pervasive synchronization. Go's copy-by-default model made parallelism safe without locks.
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

```
Reference semantics (scattered memory):

Array of pointers:           Objects on heap:
┌──────────┐
│ ptr[0]   │──────────────> Point @ 0x1000 (x, y)
├──────────┤
│ ptr[1]   │──────────────> Point @ 0x5000 (x, y) (different cache line!)
├──────────┤
│ ptr[2]   │──────────────> Point @ 0x9000 (x, y) (different cache line!)
└──────────┘

Each pointer dereference = potential cache miss
Array traversal requires jumping between scattered heap locations
```

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

```
Value semantics (contiguous memory):

Array of Point values (all in one block):
┌────────────────────────────────────────────────────┐
│ Point[0]   │ Point[1]   │ Point[2]   │ Point[3]   │
│ (x:0, y:0) │ (x:1, y:1) │ (x:2, y:2) │ (x:3, y:3) │
└────────────────────────────────────────────────────┘
  ↑──────────── Single contiguous memory block ──────↑
  ↑────────── Fits in one or two cache lines ────────↑

Sequential access = cache hits (CPU prefetches next values)
All data local, no pointer chasing required
```

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

## Inheritance: The Cache Locality Killer

Inheritance has a hidden cost that compounds the reference semantics problem: **you cannot store polymorphic objects contiguously**.

### The Fundamental Problem

When you use inheritance for polymorphism, you must use pointers to the base class. This forces heap allocation and destroys cache locality:

```java
// Java: Classic OOP inheritance
abstract class Shape {
    int id;
    abstract double area();
}

class Circle extends Shape {
    int radius;
    double area() { return Math.PI * radius * radius; }
}

class Rectangle extends Shape {
    int width, height;
    double area() { return width * height; }
}

// Can't store different types in same array directly
// Must use references to base class:
Shape[] shapes = new Shape[1000];
for (int i = 0; i < 1000; i++) {
    if (i % 2 == 0) {
        shapes[i] = new Circle(i);      // Heap allocated
    } else {
        shapes[i] = new Rectangle(i, i*2);  // Heap allocated
    }
}

// Iteration: Pointer chasing every access
for (Shape s : shapes) {
    double a = s.area();  // Follow pointer + vtable dispatch
}
```

**Memory layout visualization:**

```
shapes array (contiguous):        Heap (scattered):
┌──────────┐
│ ref [0]  │─────────────────────> Circle @ 0x1000
├──────────┤                       (vtable ptr, id, radius)
│ ref [1]  │─────────────────────> Rectangle @ 0x5200
├──────────┤                       (vtable ptr, id, width, height)
│ ref [2]  │─────────────────────> Circle @ 0x9800
├──────────┤
│ ref [3]  │─────────────────────> Rectangle @ 0xF400
└──────────┘

Problem: Objects scattered across heap
Every access = pointer dereference + potential cache miss
CPU cannot prefetch (unpredictable memory pattern)
```

### Go's Alternative: No Inheritance, Opt-In Polymorphism

Go achieves polymorphism through interfaces, but **doesn't force you to use them**:

```go
// Go: Concrete types (no inheritance)
type Circle struct {
    ID     int
    Radius int
}

type Rectangle struct {
    ID           int
    Width, Height int
}

// When you DON'T need polymorphism (common case):
// Separate arrays (cache-friendly!)
circles := make([]Circle, 500)
rectangles := make([]Rectangle, 500)

// Process circles (contiguous, cache-friendly)
for i := range circles {
    area := math.Pi * float64(circles[i].Radius * circles[i].Radius)
    // All Circle data sequential in memory
    // CPU prefetches next values
}

// Process rectangles (contiguous, cache-friendly)
for i := range rectangles {
    area := rectangles[i].Width * rectangles[i].Height
    // All Rectangle data sequential in memory
}
```

**Memory comparison:**

```
Java (inheritance required):
- shapes array: 8,000 bytes (1000 refs × 8 bytes)
- Circle objects: ~20,000 bytes (500 × 40 bytes, scattered)
- Rectangle objects: ~24,000 bytes (500 × 48 bytes, scattered)
Total: ~52 KB, scattered across heap

Go (concrete types, no inheritance):
- circles array: 8,000 bytes (500 × 16 bytes, contiguous)
- rectangles array: 12,000 bytes (500 × 24 bytes, contiguous)
Total: 20 KB, sequential memory (2.6× smaller, cache-friendly)
```

**When you DO need polymorphism in Go:**

```go
// Go: Interface (opt-in polymorphism)
type Shape interface {
    Area() float64
}

// Now both types implement Shape
func (c Circle) Area() float64 {
    return math.Pi * float64(c.Radius * c.Radius)
}

func (r Rectangle) Area() float64 {
    return float64(r.Width * r.Height)
}

// Interface array (reference-based, like Java)
shapes := []Shape{
    Circle{1, 5},
    Rectangle{2, 10, 20},
}

// Now you pay the cost (pointer indirection)
for _, s := range shapes {
    area := s.Area()  // Interface dispatch
}
```

**Go's philosophy:** Polymorphism is opt-in. Most code doesn't need it, so most code gets cache-friendly contiguous layout.

### Real-World Impact: Game Engines and ECS

This is why modern game engines abandoned OOP inheritance for **Entity-Component Systems (ECS)**:

**Old way (OOP inheritance):**

```cpp
// Bad: Deep inheritance hierarchy
class GameObject { virtual void update() = 0; };
class MovableObject : public GameObject { Vector3 pos, vel; };
class Enemy : public MovableObject { int health; };
class FlyingEnemy : public Enemy { float altitude; };

// Array of pointers (scattered, cache misses)
GameObject* entities[100000];
for (auto* e : entities) {
    e->update();  // Pointer chase + vtable = cache miss nightmare
}

Performance: 1,000-5,000 entities before frame drops below 60 FPS
```

**Modern way (ECS, data-oriented):**

```go
// Good: Separate arrays by component type (no inheritance)
type Position struct { X, Y, Z float64 }
type Velocity struct { X, Y, Z float64 }
type Health struct { HP int }

// Contiguous arrays (cache-friendly!)
positions := make([]Position, 100000)
velocities := make([]Velocity, 100000)
healths := make([]Health, 100000)

// Process in bulk (vectorized, SIMD-friendly)
for i := range positions {
    positions[i].X += velocities[i].X
    positions[i].Y += velocities[i].Y
    positions[i].Z += velocities[i].Z
}
// Sequential access, CPU prefetches, can use SIMD (4-8 values at once)

Performance: 100,000+ entities at 60 FPS
```

**Why ECS won:**

| Aspect | OOP Inheritance | ECS (Data-Oriented) |
|--------|-----------------|---------------------|
| **Memory layout** | Scattered (pointers) | Contiguous (values) |
| **Cache locality** | Poor (random access) | Excellent (sequential) |
| **SIMD** | Difficult (scattered data) | Easy (contiguous arrays) |
| **Entities/frame** | 1,000-5,000 | 100,000+ |
| **Speedup** | Baseline | 20-100× faster |

{{< callout type="success" >}}
**Inheritance Forces Indirection**

You cannot store polymorphic objects contiguously. Inheritance requires pointers to base class, which scatters derived objects across the heap. This destroys cache locality and prevents CPU prefetching.

Go's interfaces are opt-in: use concrete types (cache-friendly) until you need polymorphism, then pay the cost explicitly (interfaces).
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

## The Three Factors: Why Multicore Killed OOP

The multicore crisis wasn't caused by one thing - it was the **collision of three independent factors**:

### Factor 1: Threads (1960s-2005)

**Purpose:** I/O concurrency on single-core systems

```python
# Threads handled 1000s of clients on single Pentium
while True:
    client = accept_connection()
    Thread(target=handle_request, args=(client,)).start()
    # CPU switches between threads during I/O waits
```

**Worked perfectly** because time-slicing serialized execution.

### Factor 2: Reference Semantics (1980s-1990s)

**Design choice:** Assignment copies references, not data

```java
List<String> list1 = new ArrayList<>();
List<String> list2 = list1;  // Shared reference
list2.add("item");  // list1 affected
```

**Worked fine** on single core (time-slicing provided safety).

### Factor 3: Multicore CPUs (2005+)

**Hardware shift:** Clock speeds plateaued, cores multiplied

```
1995: 1 core @ 200 MHz
2005: 2 cores @ 3 GHz  ← Paradigm shift
2015: 8 cores @ 4 GHz
2025: 16+ cores @ 5 GHz
```

**Changed everything:** Threads now run **truly simultaneously**.

### The Perfect Storm

**Any two factors together was manageable:**

| Combination | Result |
|-------------|--------|
| Threads + Single Core | ✓ I/O concurrency (worked great) |
| References + Single Core | ✓ Time-slicing provides safety |
| Values + Multicore | ✓ Independent copies (C handled fine) |
| **Threads + References + Multicore** | ✗ **Data races everywhere** |

{{< mermaid >}}
graph TB
    subgraph safe1["Safe Combinations"]
        A[Threads] --> B[Single Core]
        C[References] --> B
        D[Values] --> E[Multicore]
    end
    
    subgraph crisis["The Crisis"]
        F[Threads] --> G[Multicore]
        H[References] --> G
        G --> I[Data Races<br/>Lock Hell<br/>Deadlocks]
    end
    
    style safe1 fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style crisis fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style I fill:#C24F54,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### Why This Matters

**The multicore crisis was specific to reference-dominant languages:**

- **Python/Java/Ruby:** Designed in single-core era with references everywhere
- **C/Go/Rust:** Value semantics by default handled multicore naturally

**The paradigm shift:**

```
Pre-2005 Mental Model:
"Threads help with I/O, locks prevent occasional race conditions"
    ↓
Post-2005 Reality:
"Threads enable parallelism, locks MANDATORY for ALL shared state"
```

**OOP languages couldn't adapt** because reference semantics was fundamental to their design. You can't bolt value semantics onto a reference-oriented language.

### The Rankings

**If we rank by actual impact:**

**1. Hardware Evolution (PRIMARY - 60%)**
- Forced the crisis
- Changed assumptions about execution model
- Made latent problems visible

**2. Reference Semantics (CRITICAL FACTOR - 30%)**
- Made all state shared by default
- Required pervasive synchronization
- Invisible sharing everywhere

**3. Thread API Design (AMPLIFIER - 10%)**
- Manual lock management
- Easy to forget, wrong order, error paths
- No compiler help

{{< callout type="success" >}}
**The Key Insight**

Threads existed for 30+ years before multicore without major problems. Reference semantics existed for 20+ years without breaking everything.

**Multicore + References = Crisis**

This is why Go's value semantics were the right solution. Not just performance optimization - **fundamental correctness** in the parallel era.
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

### 3. We Traded malloc/free for lock/unlock

**The irony of OOP's evolution:**

OOP (with garbage collection) was supposed to eliminate manual memory management. No more juggling `malloc()` and `free()`. No more memory leaks, double frees, use-after-free bugs.

**What we got instead:** Manual concurrency management. Now we juggle `lock()` and `unlock()`:

```c
// 1990s: Manual memory management
ptr = malloc(size);
// ... use ptr ...
free(ptr);  // Forget this = memory leak

// 2010s: Manual lock management  
mutex_lock(&m);
// ... use shared data ...
mutex_unlock(&m);  // Forget this = deadlock
```

**Same failure modes, different domain:**

| Memory Management | Concurrency Management |
|-------------------|------------------------|
| Forget `free()` = memory leak | Forget `unlock()` = deadlock |
| Double `free()` = crash | Double `unlock()` = undefined behavior |
| Use after `free()` = corruption | Access without lock = race condition |
| No compiler help | No compiler help |

**The pattern:** When complexity is implicit (malloc/free, lock/unlock), humans make mistakes. Garbage collection solved memory. Ownership systems (Rust) and value semantics (Go) solve concurrency by making sharing explicit and automatic.

OOP with GC fixed one manual management problem but created another. Post-OOP languages (Go, Rust) eliminate both through different mechanisms: GC + value semantics (Go) or compile-time ownership (Rust).

### 4. Performance Matters More Than We Thought

**Single-threaded era:** Convenience > performance (references were "good enough")

**Multicore era:** Need every optimization (8 cores × 0.9 efficiency = 7.2× speedup matters)

Value semantics deliver:
- True parallelism (no lock serialization)
- Cache locality (contiguous memory)
- Stack allocation (no GC pressure)

### 5. Explicit Is Better Than Implicit

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

## Value Semantics at Scale: Why Copy-by-Value Enables Massive Throughput

This might seem counterintuitive: if value semantics mean copying data, doesn't that hurt performance at scale? And if OOP is so bad for concurrency, why do Java/Spring services handle millions of requests per second?

The answers reveal important nuances about when value semantics matter and when they don't.

### The Paradox: Copying Everything Should Be Slow

**The concern:**

```go
// Go: Every function call copies the struct
type Request struct {
    UserID    int
    SessionID string
    Data      []byte  // Could be large!
}

func handleRequest(req Request) Response {
    // req is a COPY of the original
    // Doesn't this waste memory and CPU?
}
```

**The reality:** Most structs are **small** (16-64 bytes), and copying is **fast**:

```
Benchmark: Copy struct vs follow pointer

16-byte struct copy:     ~2 nanoseconds
64-byte struct copy:     ~8 nanoseconds
Pointer dereference:     ~1-5 nanoseconds (but cache miss = 100ns)

For small structs, copying is comparable to pointer overhead
For cache-cold pointers, copying is FASTER (sequential memory)
```

**Critical insight:** Slices, maps, and strings contain **pointers internally**. Copying the struct copies the pointer (cheap), not the underlying data:

```go
type Request struct {
    UserID    int     // 8 bytes
    SessionID string  // 16 bytes (pointer + length internally)
    Data      []byte  // 24 bytes (pointer + len + cap internally)
}

// Size: 48 bytes (not including underlying data)
// Copying: 48 bytes (~6ns)
// Underlying arrays: Shared via pointers (not copied)
```

**When copying would be expensive, Go uses pointers:**

```go
// Large struct: Use pointer
type LargeConfig struct {
    Settings [1000]string
}

func process(cfg *LargeConfig) {  // Pointer (8 bytes)
    // Don't copy 1000-element array
}
```

### How Value Semantics Enable Scale

**1. True parallelism without locks:**

```go
// Handle 10,000 concurrent requests (no locks!)
func handler(w http.ResponseWriter, r *http.Request) {
    // Each request in separate goroutine
    // Each has independent copy of request data
    // No shared state = no locks = perfect parallelism
    
    user := getUser(r.Context())      // Local copy
    result := processData(user.Data)  // Local copy
    writeResponse(w, result)          // No contention
}

// 10,000 goroutines process in parallel
// No serialization at locks
// Full CPU utilization across all cores
```

**2. Stack allocation reduces GC pressure:**

```go
// Most values stay on stack (escape analysis)
func process(id int) Result {
    config := Config{Timeout: 30}  // Stack
    data := transform(id)          // Stack
    return Result{Value: data}     // May escape to heap
}

// Only long-lived values go to heap
// Short-lived values (99% of allocations) are stack-only
// GC pressure: Minimal
```

**3. Predictable memory usage:**

```go
// Value semantics = predictable allocation
func handleRequest(req Request) {
    // Size known at compile time
    // Stack allocation (deterministic)
    // No heap fragmentation
}

// vs OOP: Every object is heap allocation
// Unpredictable GC pauses
// Heap fragmentation over time
```

### But Java/Spring Is Fast Too - What Gives?

**The reality:** Modern Java (especially with Spring Boot) powers some of the highest-throughput systems in the world. How?

**1. I/O-bound workloads dominate:**

Most backend services spend 90%+ of time waiting for I/O (database, network, disk). CPU efficiency matters less:

```java
// Java/Spring: Typical request handler
@GetMapping("/users/{id}")
public User getUser(@PathVariable Long id) {
    return userRepository.findById(id);  // 99% of time: waiting for DB
}

// Time breakdown:
// CPU (object allocation, GC): ~1ms (1%)
// Database query: ~99ms (99%)
// 
// Even if Go is 10× faster on CPU, total time:
// Java: 1ms + 99ms = 100ms
// Go:   0.1ms + 99ms = 99.1ms
// Difference: Negligible (0.9%)
```

**When I/O dominates, language overhead is invisible.**

**2. JVM optimizations are excellent:**

Modern JVMs have 25+ years of optimization:

- **JIT compilation:** Hotspot compiles hot paths to native code
- **Escape analysis:** Stack-allocates objects that don't escape (like Go!)
- **Generational GC:** Young generation GC is fast (~1-10ms pauses)
- **TLAB (Thread-Local Allocation Buffer):** Lock-free allocation per thread

```java
// Java: JVM may stack-allocate this!
public int calculate() {
    Point p = new Point(1, 2);  // Doesn't escape
    return p.x + p.y;
}
// After JIT: p allocated on stack (no heap, no GC)
```

**3. Thread pools limit concurrency overhead:**

Spring doesn't spawn threads per request (expensive). It uses **thread pools**:

```java
// Spring Boot default: 200 threads (Tomcat thread pool)
// 10,000 concurrent requests → 200 threads
// No goroutine overhead (Java threads are OS threads)
```

Go's advantage: **cheap goroutines** (100,000+ on same hardware)

**4. Vertical scaling covers many use cases:**

```
Single Spring Boot instance:
- 16 cores, 64 GB RAM
- 10,000 requests/second (typical web app)
- Thread pool: 200-500 threads
- Cost: $500-1000/month (AWS)

When this works: 99% of web apps
```

Go's advantage shines at **extreme scale**:

```
Discord (Go-based):
- 2.5+ trillion messages
- 5+ million concurrent WebSocket connections
- Millions of goroutines across cluster
- GC pauses: <1ms (critical for real-time)

Twitter timeline service (rewritten in Go):
- Reduced infrastructure by 80%
- Latency: 200ms → 30ms
- Memory: 90% reduction

Uber (migrated to Go):
- Highest queries per second microservice
- 95th percentile: 40ms
```

### When Value Semantics Matter Most

**Value semantics shine when:**

1. **Extreme concurrency** - Millions of goroutines vs thousands of threads
2. **CPU-bound workloads** - Where language overhead is significant
3. **Real-time requirements** - Predictable latency (GC pauses matter)
4. **Memory-constrained** - Every allocation counts
5. **High-frequency operations** - Tight loops processing data

**Examples:**

```
Use Go/Rust (value semantics critical):
- Real-time systems (game servers, trading systems)
- Data processing pipelines (map-reduce, streaming)
- High-frequency microservices (>100k req/s per instance)
- WebSocket servers (millions of persistent connections)
- CLI tools (startup time, memory efficiency)

Java/Spring works fine (I/O-bound):
- CRUD applications (database-heavy)
- REST APIs (most business logic)
- Admin dashboards
- Batch processing (latency not critical)
- Enterprise systems (vertical scaling acceptable)
```

### The Real Comparison

**Java/Spring strengths:**

- Mature ecosystem (decades of libraries)
- Enterprise support
- Developer pool (more Java developers)
- Vertical scaling works for most apps
- I/O-bound workloads hide language overhead

**Go strengths:**

- Extreme horizontal scaling (cheap goroutines)
- Predictable latency (low GC pauses)
- Lower memory footprint (3-10× less)
- Faster CPU-bound operations
- Simpler concurrency model (no callback hell)

**The nuance:**

```
                                 Java/Spring          Go
────────────────────────────────────────────────────────
Typical web API (I/O-bound)      Excellent           Good
Real-time WebSocket server       Struggles           Excellent
CRUD application                 Excellent           Good
Data processing pipeline         Good                Excellent
Microservices (<10k req/s)       Excellent           Good
Microservices (>100k req/s)      Expensive scaling   Efficient scaling
```

{{< callout type="warning" >}}
**Don't Rewrite Your Java Service**

If your Java/Spring service handles 5,000 requests/second comfortably, there's no reason to rewrite it in Go. The overhead doesn't matter when I/O dominates.

Value semantics matter when you're pushing the limits: millions of connections, microsecond latencies, or tight CPU-bound loops. For most web apps, Java/Spring is perfectly adequate.
{{< /callout >}}

### Where Value Semantics Deliver 10-100× Wins

**1. WebSocket/persistent connections:**

```
Java (threads):
- 10,000 concurrent connections
- 10,000 threads × 1MB stack = 10 GB memory
- Context switching overhead

Go (goroutines):
- 1,000,000 concurrent connections
- 1M goroutines × 2KB stack = 2 GB memory
- Minimal context switching
```

**2. CPU-bound data processing:**

```
Processing 100M records:

Java:
- Object allocation per record: 100M allocations
- GC pauses: 100-500ms
- Cache misses: Scattered objects
- Time: 60 seconds

Go:
- Stack allocation (escape analysis): Minimal heap
- GC pauses: <1ms
- Cache hits: Contiguous data
- Time: 10 seconds
```

**3. Microservice mesh (1000s of services):**

```
1000 microservices:

Java (200MB per service):  200 GB total memory
Go (20MB per service):     20 GB total memory

Savings: 10× memory reduction = 10× fewer servers = 10× cost reduction
```

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
