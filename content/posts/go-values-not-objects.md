---
title: "Go's Value Philosophy: Why Everything Is a Value, Not an Object"
date: 2026-01-22
draft: false
tags: ["go", "golang", "values", "objects", "memory-model", "philosophy", "python", "java", "comparison", "concurrency", "stack-allocation", "heap-allocation", "programming-paradigms", "type-systems", "performance", "mental-models"]
categories: ["programming", "go"]
description: "Deep dive into Go's value-oriented design philosophy and how it differs from Python's everything-is-an-object and Java's everything-is-a-class approaches. Understand how this fundamental choice affects memory, concurrency, and performance."
summary: "In Python, everything is an object. In Java, everything is a class. In Go, everything is a value. This isn't just terminology - it's a fundamental design philosophy that shapes how you write concurrent code, manage memory, and reason about performance."
---

You've heard the mantras:

- **Python:** "Everything is an object"
- **Java:** "Everything is a class"
- **Go:** "Everything is a value"

These aren't marketing slogans. They're fundamental design philosophies that shape every line of code you write. Understanding what "everything is a value" means in Go reveals why Go's concurrency model works, why it's fast, and why it feels different from object-oriented languages.

This post explores the mental model behind values, contrasts it with objects and classes, and shows how Go's value philosophy enables safe concurrency and predictable performance.

---

## Three Mental Models for Programming

### Python: Everything Is an Object

In Python, even the number `5` is a heap-allocated object with identity, methods, and reference semantics.

```python
# Everything is an object with identity
x = 5
y = 5

print(id(x))  # Object identity (memory address)
print(type(5))  # <class 'int'> - even integers are classes

# Integers have methods
print((5).bit_length())  # 3

# Functions are objects
def greet():
    pass

print(type(greet))  # <class 'function'>
greet.custom_attr = 42  # Can add attributes to functions!
```

**Objects have identity separate from value:**

```python
a = [1, 2, 3]
b = [1, 2, 3]

print(a == b)  # True (equal values)
print(a is b)  # False (different objects)
```

**All assignments are reference assignments:**

```python
class Point:
    def __init__(self, x, y):
        self.x, self.y = x, y

p1 = Point(1, 2)
p2 = p1  # Both reference SAME object

p2.x = 10
print(p1.x)  # 10 (p1 affected!)
```

### Java: Everything Is a Class

Java organizes all code into classes. Even the `main()` entry point requires a class wrapper.

```java
// Must wrap everything in classes
public class Main {
    public static void main(String[] args) {
        // Even main() needs a class
    }
}

// All behavior lives in classes
public class Calculator {
    public int add(int a, int b) {
        return a + b;
    }
}

// Primitives are the exception (not objects)
int x = 5;  // Primitive, not an object
Integer y = 5;  // Boxed object wrapper
```

**Class hierarchies define structure:**

```java
public class Animal {
    public void speak() { }
}

public class Dog extends Animal {
    @Override
    public void speak() {
        System.out.println("Woof");
    }
}

// Explicit interface implementation required
public class Database implements Storage {
    public void save(String data) { }
}
```

### Go: Everything Is a Value

Go represents data as values that are copied by default, have no hidden metadata, and don't inherit from anything.

```go
// Values are copied
type Point struct { X, Y int }

p1 := Point{1, 2}
p2 := p1           // p2 is a COPY of p1

p2.X = 10
fmt.Println(p1.X)  // 1 (p1 unchanged)
```

**Values have no identity:**

```go
a := Point{1, 2}
b := Point{1, 2}

// a and b are equal (same value)
// No concept of "same object in memory" vs "equal values"
```

**Explicit pointers for sharing:**

```go
p1 := &Point{1, 2}  // Explicit pointer
p2 := p1            // Both point to same Point

p2.X = 10
fmt.Println(p1.X)  // 10 (same underlying value)
```

{{< callout type="info" >}}
**The Core Distinction:**

- **Python:** Assignment copies references (shares objects)
- **Java:** Assignment copies references for objects, values for primitives
- **Go:** Assignment copies values; use explicit pointers for sharing

**This affects everything:** concurrency safety, memory layout, performance characteristics, and how you reason about code.
{{< /callout >}}

---

## What Does "Value" Mean?

### Values vs Objects: The Technical Difference

**Values:**
- Copied on assignment
- No identity separate from content
- No hidden metadata
- Stack-allocated when possible
- No inheritance hierarchy

**Objects:**
- Shared by reference on assignment
- Have identity (`id()` in Python, `hashCode()` in Java)
- Carry metadata (type, reference count, vtable pointer)
- Heap-allocated
- Part of class hierarchies

### Memory Model: Values

When you create a value in Go, it exists as raw bytes in memory:

```go
type Point struct {
    X int64  // 8 bytes
    Y int64  // 8 bytes
}

p := Point{1, 2}
// Memory layout (16 bytes total):
// [00 00 00 00 00 00 00 01][00 00 00 00 00 00 00 02]
//  ^-- X                    ^-- Y
// No metadata, no header, just the data
```

{{< mermaid >}}
flowchart LR
    subgraph go["Go Value (16 bytes)"]
        godata["X: 8 bytes<br/>Y: 8 bytes"]
    end
    
    subgraph python["Python Object (80+ bytes)"]
        pyheader["Object Header: 16 bytes<br/>Type Pointer: 8 bytes<br/>Dict: 48 bytes"]
        pydata["x ref → int(1): 28 bytes<br/>y ref → int(2): 28 bytes"]
        pyheader -.-> pydata
    end
    
    style go fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style python fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style godata fill:#66bb6a,stroke:#1b5e20,color:#fff
    style pyheader fill:#ef5350,stroke:#b71c1c,color:#fff
    style pydata fill:#ef5350,stroke:#b71c1c,color:#fff
{{< /mermaid >}}

**Copy operation is memcpy:**

```go
p1 := Point{1, 2}
p2 := p1  // memcpy(p2, p1, 16 bytes)

// p1 and p2 are independent 16-byte blocks
```

### Memory Model: Objects

When you create an object in Python, it's a heap-allocated structure with metadata:

```python
class Point:
    def __init__(self, x, y):
        self.x, self.y = x, y

p = Point(1, 2)
# Memory layout (simplified):
# ┌────────────────────────────────┐
# │ Object Header:                 │
# │  - Reference count             │
# │  - Type pointer (→ Point class)│
# │  - GC tracking info            │
# ├────────────────────────────────┤
# │ Attributes Dictionary:         │
# │  - x: (pointer to int object)  │
# │  - y: (pointer to int object)  │
# └────────────────────────────────┘
```

**Assignment copies references:**

```python
p1 = Point(1, 2)
p2 = p1  # p2 = pointer to p1's object

# p1 and p2 point to the SAME object in memory
```

### Why This Matters: Concurrency

**Go's value semantics make concurrency safer:**

```go
// Each goroutine gets a copy
func worker(data []int) {
    localData := make([]int, len(data))
    copy(localData, data)  // Explicit copy
    
    // Safe: no shared state
    for i := range localData {
        localData[i] *= 2
    }
}

data := []int{1, 2, 3, 4, 5}
go worker(data)
go worker(data)
// Each goroutine has independent copy
```

**Python's object semantics require synchronization:**

```python
import threading

lock = threading.Lock()

def worker(data):
    # data is shared object reference
    with lock:  # Must synchronize access
        for i in range(len(data)):
            data[i] *= 2

data = [1, 2, 3, 4, 5]
threading.Thread(target=worker, args=(data,)).start()
threading.Thread(target=worker, args=(data,)).start()
# Both threads share the SAME list object
```

{{< mermaid >}}
flowchart TB
    subgraph go["Go: Value Copies"]
        data1[Original Data]
        copy1[Goroutine 1 Copy]
        copy2[Goroutine 2 Copy]
        
        data1 -.copy.-> copy1
        data1 -.copy.-> copy2
    end
    
    subgraph python["Python: Shared References"]
        data2[Original Data]
        ref1[Thread 1 Reference]
        ref2[Thread 2 Reference]
        
        data2 --- ref1
        data2 --- ref2
    end
    
    style go fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style python fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

---

## Receivers vs Methods: Go's Approach

Go doesn't have methods in the OOP sense. It has **receivers** - functions associated with types.

### The Terminology Matters

**Python/Java methods:**
- Bound to class hierarchy
- Implicit `self`/`this` parameter (the object)
- Dynamic dispatch through vtables
- Can override parent methods

**Go receivers:**
- Bound to any user-defined type
- Explicit receiver parameter (value or pointer)
- Static dispatch (unless through interface)
- No inheritance, no override

### Receiver Example

```go
type Temperature int

// Receiver function (not a "method")
func (t Temperature) Celsius() float64 {
    return float64(t)
}

func (t Temperature) Fahrenheit() float64 {
    return float64(t)*9/5 + 32
}

temp := Temperature(25)
fmt.Println(temp.Celsius())     // 25
fmt.Println(temp.Fahrenheit())  // 77
```

**Key distinction:** The receiver receives the VALUE (or pointer to value), not an object with hidden state.

### Value Receivers vs Pointer Receivers

```go
type Counter struct {
    count int
}

// Value receiver: operates on a copy
func (c Counter) Value() int {
    return c.count
}

// Value receiver that modifies: modifies the COPY
func (c Counter) Increment() {
    c.count++  // Modifies copy, not original
}

// Pointer receiver: operates on the original
func (c *Counter) IncrementPtr() {
    c.count++  // Modifies original
}

c := Counter{count: 0}

c.Increment()  // Copies c, increments copy, discards
fmt.Println(c.count)  // 0 (original unchanged!)

c.IncrementPtr()  // Passes pointer, modifies original
fmt.Println(c.count)  // 1 (modified!)
```

**When to use each:**

| Receiver Type | Use When | Example |
|---------------|----------|---------|
| Value `(t T)` | Small types, no mutation needed | `func (t Temperature) Celsius()` |
| Pointer `(t *T)` | Large types, mutation needed | `func (c *Counter) Increment()` |

{{< mermaid >}}
sequenceDiagram
    participant Original as Original Counter
    participant Copy as Copy (value receiver)
    participant Ptr as Pointer (pointer receiver)
    
    Note over Original: count = 0
    
    Original->>Copy: c.Increment() - passes copy
    Note over Copy: count++ on copy<br/>(count = 1)
    Copy-->>Original: copy discarded
    Note over Original: count still 0
    
    Original->>Ptr: c.IncrementPtr() - passes pointer
    Note over Ptr: count++ on original<br/>(via pointer)
    Ptr-->>Original: modifies original
    Note over Original: count = 1
{{< /mermaid >}}

{{< callout type="warning" >}}
**Common Mistake: Value Receivers Don't Mutate**

```go
type User struct { name string }

func (u User) SetName(name string) {
    u.name = name  // Modifies COPY
}

user := User{name: "Alice"}
user.SetName("Bob")
fmt.Println(user.name)  // Still "Alice"!

// Fix: Use pointer receiver
func (u *User) SetName(name string) {
    u.name = name  // Modifies original
}
```
{{< /callout >}}

---

## Built-In Types: No Receivers Allowed

Go doesn't allow adding receivers to built-in types:

```go
// Can't do this
func (i int) Double() int {  // ERROR
    return i * 2
}
```

**But you can wrap built-in types:**

```go
type MyInt int

func (i MyInt) Double() MyInt {
    return i * 2
}

x := MyInt(5)
fmt.Println(x.Double())  // 10
```

**Python allows methods on everything:**

```python
x = 5
print(x.bit_length())  # 3 (method on integer!)
print((5).__class__)   # <class 'int'>
```

This reflects the philosophical difference: Python's integers are objects with behavior; Go's integers are values you can wrap to add behavior.

---

## Performance Implications

### Stack vs Heap Allocation

**Go values prefer the stack:**

```go
func process() {
    p := Point{1, 2}  // Typically stack-allocated
    // Freed automatically when function returns
}
```

**Python objects require heap allocation:**

```python
def process():
    p = Point(1, 2)  # Always heap-allocated
    # GC must track and free later
```

### Memory Overhead Comparison

**Go struct (16 bytes):**
```
[X: 8 bytes][Y: 8 bytes]
Total: 16 bytes
```

**Python object (80+ bytes):**
```
Object header: 16 bytes
Type pointer: 8 bytes
Dictionary: 48+ bytes (for attributes)
Attribute pointers: 16 bytes (x and y references)
Integer objects: 28 bytes each (x=1, y=2)
Total: 80+ bytes
```

### Copy Performance

| Operation | Go (Value) | Python (Object) |
|-----------|------------|-----------------|
| Create | Stack alloc (fast) | Heap alloc + GC tracking (slow) |
| Copy | memcpy (cheap) | Reference copy (cheap), deep copy (expensive) |
| Access | Direct (no indirection) | Pointer dereference (indirection) |
| Mutation | Safe (copy) | Requires synchronization (shared) |

**Benchmark: 1 million struct copies**

```go
// Go: Copy values
for i := 0; i < 1000000; i++ {
    p2 := p1  // memcpy: ~2ms
}
```

```python
# Python: Copy references (cheap)
for i in range(1000000):
    p2 = p1  # Reference copy: ~5ms

# Python: Deep copy (expensive)
import copy
for i in range(1000000):
    p2 = copy.copy(p1)  # Object creation: ~450ms
```

---

## Concurrency: Values Enable Safety

### The Problem with Shared Objects

**Python requires locks for shared state:**

```python
import threading

class Counter:
    def __init__(self):
        self.count = 0
        self.lock = threading.Lock()
    
    def increment(self):
        with self.lock:  # Must synchronize
            self.count += 1

counter = Counter()

def worker():
    for _ in range(1000):
        counter.increment()

threads = [threading.Thread(target=worker) for _ in range(10)]
for t in threads:
    t.start()
for t in threads:
    t.join()

print(counter.count)  # 10000
```

### Go's Value Solution

**Each goroutine gets its own copy:**

```go
type Counter struct {
    count int
}

func (c *Counter) Increment() {
    c.count++
}

func worker(c Counter, results chan<- int) {
    // c is a COPY - safe to mutate
    for i := 0; i < 1000; i++ {
        c.count++
    }
    results <- c.count
}

counter := Counter{count: 0}
results := make(chan int, 10)

for i := 0; i < 10; i++ {
    go worker(counter, results)  // Passes copy
}

// Collect results from each goroutine
for i := 0; i < 10; i++ {
    fmt.Println(<-results)  // Each goroutine counted 1000
}
```

**When sharing IS needed, use channels or mutexes explicitly:**

```go
type SafeCounter struct {
    mu    sync.Mutex
    count int
}

func (c *SafeCounter) Increment() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

counter := &SafeCounter{}  // Explicit pointer sharing

for i := 0; i < 10; i++ {
    go func() {
        for j := 0; j < 1000; j++ {
            counter.Increment()
        }
    }()
}
```

{{< callout type="success" >}}
**Go's Philosophy: Make Sharing Explicit**

- Default: Values are copied (safe, no synchronization needed)
- Sharing: Use explicit pointers, channels, or mutexes
- Visibility: The code shows where data is shared vs copied

**Result:** Concurrency bugs are easier to spot because sharing is explicit.
{{< /callout >}}

---

## Interfaces: When Values Become Object-Like

Go interfaces create a hybrid: when a value is placed in an interface, it gains object-like behavior with type information.

### Interface Values

```go
type Animal interface {
    Speak() string
}

type Dog struct { name string }

func (d Dog) Speak() string {
    return "Woof"
}

// Value becomes polymorphic through interface
var a Animal = Dog{name: "Fido"}

// Interface value contains:
// - Type information (Dog)
// - Value (Dog{name: "Fido"})
```

**Under the hood, an interface value is:**

```go
type interfaceValue struct {
    type  *typeInfo  // Pointer to type information
    value unsafe.Pointer  // Pointer to actual value
}
```

### Dynamic Dispatch Through Interfaces

```go
type Cat struct { name string }

func (c Cat) Speak() string {
    return "Meow"
}

// Values become polymorphic through interfaces
animals := []Animal{
    Dog{name: "Fido"},
    Cat{name: "Whiskers"},
}

for _, a := range animals {
    fmt.Println(a.Speak())  // Dynamic dispatch
}
// Output:
// Woof
// Meow
```

**But note:** Outside interfaces, they're pure values with no dynamic behavior.

```go
// Direct call: static dispatch
d := Dog{name: "Fido"}
d.Speak()  // Static: compiler knows exact type

// Interface call: dynamic dispatch
var a Animal = d
a.Speak()  // Dynamic: runtime type check
```

For more on Go's interface system, see: [Go Interfaces: The Type System Feature You Implement By Accident]({{< relref "go-interfaces-accidental-implementation.md" >}})

---

## Method Chaining: Why It's Rare in Go

Method chaining (fluent interfaces) is common in OOP languages but rare in Go because of value semantics.

### Method Chaining in Python/Java

```python
# Python: Methods return self reference
class User:
    def set_name(self, name):
        self.name = name
        return self  # Return object reference
    
    def set_age(self, age):
        self.age = age
        return self

# Chaining works naturally
user = User().set_name("Alice").set_age(30)
```

```java
// Java: Builder pattern
User user = new User()
    .setName("Alice")
    .setAge(30)
    .setEmail("alice@example.com");
```

### Go: Value Semantics Break Chaining

```go
type User struct {
    name string
    age  int
}

// Value receiver returns COPY
func (u User) SetName(name string) User {
    u.name = name
    return u  // Returns copy, not original
}

// Chaining doesn't mutate original
user := User{}
user.SetName("Alice").SetName("Bob")
fmt.Println(user.name)  // "" (original unchanged!)

// Pointer receiver enables chaining
func (u *User) SetNamePtr(name string) *User {
    u.name = name
    return u  // Returns same pointer
}

user2 := &User{}
user2.SetNamePtr("Alice").SetNamePtr("Bob")
fmt.Println(user2.name)  // "Bob" (works!)
```

### Error Handling Breaks Chaining

Go's explicit error handling makes chaining awkward:

```go
// Method that can fail must return error
func (u *User) SetEmail(email string) (*User, error) {
    if !isValid(email) {
        return nil, errors.New("invalid email")
    }
    u.email = email
    return u, nil
}

// Can't chain because of error return
user.SetName("Alice").SetEmail("bad@email")
// ERROR: SetEmail returns (*User, error), not *User
```

**Idiomatic Go prefers explicit error checking:**

```go
user := NewUser()
user.SetName("Alice")
user.SetAge(30)

if err := user.SetEmail("alice@example.com"); err != nil {
    return fmt.Errorf("set email failed: %w", err)
}
```

**When chaining DOES appear:**

```go
// Builder pattern (defer errors to Build())
client, err := http.NewClientBuilder().
    WithTimeout(30 * time.Second).
    WithRetries(3).
    Build()  // Error checked here

// Query builders (defer errors to Execute())
results, err := db.Select("*").
    From("users").
    Where("age > ?", 18).
    Execute()  // Error checked here
```

---

## Comparison Table

| Aspect | Go (Values) | Python (Objects) | Java (Classes) |
|--------|-------------|------------------|----------------|
| **Assignment** | Copies value | Copies reference | Copies reference (objects), value (primitives) |
| **Identity** | No identity | `id()` function | `hashCode()` method |
| **Metadata** | No metadata | Object header, type pointer, refcount | Object header, class pointer |
| **Allocation** | Stack-preferred | Always heap | Heap for objects, stack for primitives |
| **Copy cost** | Cheap (memcpy) | Cheap (reference), expensive (deep copy) | Cheap (reference) |
| **Concurrency** | Safe by default (copies) | Requires synchronization | Requires synchronization |
| **Memory overhead** | Zero overhead | High (header + dict) | Moderate (header) |
| **Method dispatch** | Static (direct call) | Dynamic (object lookup) | Dynamic (vtable) |
| **Polymorphism** | Interfaces only | Inheritance + duck typing | Inheritance + interfaces |
| **Mutation** | Requires pointer | Mutates shared object | Mutates shared object |

---

## When Value Semantics Matter Most

### 1. High-Frequency Data Structures

**Go's values shine:**

```go
// Frequent copies of small structs
type Coordinate struct {
    lat, lon float64
}

func distance(a, b Coordinate) float64 {
    // a and b are stack copies - fast
    dx := a.lat - b.lat
    dy := a.lon - b.lon
    return math.Sqrt(dx*dx + dy*dy)
}

// No allocations, no GC pressure
for i := 0; i < 1000000; i++ {
    d := distance(coord1, coord2)
}
```

### 2. Concurrent Processing

**Safe parallelism without locks:**

```go
func processChunk(data []int) int {
    sum := 0
    for _, v := range data {
        sum += v
    }
    return sum
}

// Split work across goroutines
results := make(chan int, 4)

for i := 0; i < 4; i++ {
    chunk := data[i*len(data)/4 : (i+1)*len(data)/4]
    go func(c []int) {
        results <- processChunk(c)
    }(chunk)  // Passes slice header by value
}
```

### 3. Functional Patterns

**Immutability by default:**

```go
type Point struct { X, Y int }

// Pure functions (no mutation)
func add(p1, p2 Point) Point {
    return Point{p1.X + p2.X, p1.Y + p2.Y}
}

func scale(p Point, factor int) Point {
    return Point{p.X * factor, p.Y * factor}
}

// Compose without side effects
p := Point{1, 2}
result := scale(add(p, Point{3, 4}), 2)
// Original p unchanged
```

---

## Putting It Together

Go's "everything is a value" philosophy creates a programming model where:

**Data is copied by default:**
- Assignment copies values
- Function arguments receive copies
- No hidden sharing

**Sharing is explicit:**
- Use pointers when sharing is needed
- Use channels for concurrent communication
- Use mutexes for shared state

**Performance is predictable:**
- Stack allocation when possible
- No hidden allocations
- Cheap copies for small values

**Concurrency is safer:**
- Each goroutine gets copies by default
- No accidental data races from hidden sharing
- Explicit synchronization when needed

**Memory model is simple:**
- Values are just bytes
- No object headers
- No reference counting

This contrasts with Python's "everything is a heap-allocated object with identity" and Java's "everything lives in class hierarchies." Each approach has trade-offs:

**Python's objects:**
- Pros: Rich introspection, dynamic behavior, everything has methods
- Cons: Memory overhead, GC pressure, requires synchronization

**Java's classes:**
- Pros: Strong typing, inheritance hierarchies, clear structure
- Cons: Verbose, heavyweight, requires explicit interfaces

**Go's values:**
- Pros: Simple, fast, safe concurrency, predictable performance
- Cons: No inheritance, manual memory management patterns, explicit copies

The mental model you choose shapes how you think about your program. Go's value philosophy encourages thinking about data flow (values moving through functions) rather than object graphs (references connecting objects).

---

## Further Reading

**Go Philosophy:**
- [Effective Go: Interfaces and Other Types](https://go.dev/doc/effective_go#interfaces)
- [Go Proverbs](https://go-proverbs.github.io/)

**Related Posts:**
- [Go Interfaces: The Type System Feature You Implement By Accident]({{< relref "go-interfaces-accidental-implementation.md" >}})
- [Python's Object Overhead: Why Everything Being an Object Has a Cost]({{< relref "python-object-overhead.md" >}})
