---
title: "Go's Value Philosophy: Part 1 - Why Everything Is a Value, Not an Object"
date: 2026-01-22
draft: false
series: ["go-value-philosophy"]
seriesOrder: 1
tags: ["go", "golang", "values", "objects", "memory-model", "philosophy", "python", "java", "comparison", "concurrency", "stack-allocation", "heap-allocation", "programming-paradigms", "type-systems", "performance", "mental-models"]
categories: ["programming", "go"]
description: "Deep dive into Go's value-oriented design philosophy and how it differs from Python's everything-is-an-object and Java's everything-is-a-class approaches. Understand how this fundamental choice affects memory, concurrency, and performance."
summary: "In Python, everything is an object. In Java, everything is a class. In Go, everything is a value. These are fundamental design philosophies that shape how you write concurrent code, manage memory, and reason about performance."
---

You've heard the mantras:

- **Python:** "Everything is an object"
- **Java:** "Everything is a class"
- **Go:** "Everything is a value"

{{< callout type="info" >}}
**These Are Design Philosophies, Not Marketing Slogans**

These statements describe fundamental design choices that shape every line of code you write. Understanding what "everything is a value" means in Go reveals why Go's concurrency model works, why it's fast, and why it feels different from object-oriented languages.
{{< /callout >}}

This post explores the mental model behind values, contrasts it with objects and classes, and shows how Go's value philosophy enables safe concurrency and predictable performance.

---

## Three Mental Models for Programming

### Python: Everything Is an Object

In Python, even the integer `5` is a heap-allocated object. This means every value has three characteristics:

**1. Identity** - A unique memory address that distinguishes it from other values  
**2. Methods** - Functions you can call on the value (like `.bit_length()` on integers)  
**3. Reference semantics** - Assignment copies references, not data (multiple variables can point to the same object)

```python
# Everything is an object with identity
x = 5
y = 5

print(id(x))  # Object identity (memory address)
print(type(5))  # <class 'int'> - even integers are classes

# Integers have methods (functions bound to the value)
print((5).bit_length())  # 3

# Functions are objects
def greet():
    pass

print(type(greet))  # <class 'function'>
greet.custom_attr = 42  # Can add attributes to functions!
```

**Objects have identity separate from value:**

In Python, two objects can contain identical data but remain distinct entities in memory. Each object has a unique identity (memory address) that persists regardless of its contents.

```python
a = [1, 2, 3]
b = [1, 2, 3]

print(a == b)  # True (equal values - same contents)
print(a is b)  # False (different identity - different objects in memory)

# Identity is the memory address
print(id(a))  # 140234567890123
print(id(b))  # 140234567890456 (different!)

# Changing one doesn't affect the other
a.append(4)
print(b)  # [1, 2, 3] (unchanged - separate objects)
```

**All assignments are reference assignments:**

When you assign one variable to another in Python, you're copying the reference (pointer) to the object, not the object itself. Both variables point to the same object in memory, so changes through one variable affect the other.

```python
class Point:
    def __init__(self, x, y):
        self.x, self.y = x, y

p1 = Point(1, 2)
p2 = p1  # p2 = reference to same object p1 references

# Both variables point to the SAME object
print(id(p1))  # 140234567890789
print(id(p2))  # 140234567890789 (identical!)

# Mutating through p2 affects p1 (same object)
p2.x = 10
print(p1.x)  # 10 (p1 affected!)

# To get independent copies, you must explicitly copy
import copy
p3 = copy.copy(p1)  # Now p3 is a separate object
p3.x = 20
print(p1.x)  # 10 (p1 unaffected - different objects)
```

### Java: Everything Is a Class

Java's famous boilerplate verbosity comes from organizing all code into classes. Even the `main()` entry point requires a class wrapper - you can't write a function without wrapping it in a class first.

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

Only references have identity. In Python, objects have identity (memory address) because everything is a reference. In Go, values are just data with no identity separate from their contents.

```go
a := Point{1, 2}
b := Point{1, 2}

fmt.Println(a == b)  // true (same value)
// No "is" operator - only == exists
// No id() function - values don't have identity

// Python: Objects (references) have both value and identity
// Python: a == b (value equality) vs a is b (identity equality)
// Go:     Values only have value equality (a == b)
```

**When you need identity in Go, use explicit pointers:**

Identity means "unique location in memory" - does this data structure occupy its own distinct memory address? In Go, pointers provide this concept explicitly.

```go
p1 := &Point{1, 2}  // Allocate Point at memory address 0x1234
p2 := &Point{1, 2}  // Allocate Point at different address 0x5678

fmt.Println(p1 == p2)  // false (different memory addresses - different identity)
fmt.Println(*p1 == *p2)  // true (same contents - value equality)

// Share identity by copying the pointer
p3 := p1  // p3 now points to same address (0x1234)
fmt.Println(p1 == p3)  // true (same memory address - same identity)

// Modifying through one pointer affects the other (shared identity)
p3.X = 100
fmt.Println(p1.X)  // 100 (same Point in memory)
```

{{< callout type="success" >}}
**Identity Equivalence Across Languages**

Go's pointer equality (`p1 == p2`) is equivalent to:
- Python's `is` operator: `a is b`
- Python's identity comparison: `id(a) == id(b)`
- Java's reference equality: `a == b` (for objects)

All check the same thing: "Do these references point to the same memory location?"

The difference: Python/Java check identity by default. Go requires explicit pointers to get identity semantics.
{{< /callout >}}

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

## The Unifying Concept: References vs Values

Behind the philosophical differences ("everything is an object" vs "everything is a class" vs "everything is a value") lies a fundamental choice about **what gets copied when you assign a variable**.

### The Real Question Every Language Answers

When you write `b = a`, what actually gets copied?

**Option 1: Copy the reference (pointer)**
- Result: Both variables point to the same data in memory
- Mutations through `b` affect `a` (they share state)
- Memory overhead: object headers, garbage collection tracking
- Languages: Python (always), Java (for objects), C# (for classes)

**Option 2: Copy the value (data)**
- Result: Both variables have independent copies of the data
- Mutations to `b` don't affect `a` (no sharing)
- Memory overhead: minimal (just the data itself)
- Languages: Go (by default), Java (for primitives), C (structs)

### How Languages Present This Choice

{{< callout type="info" >}}
**Three Philosophies, One Choice: What Gets Copied?**

**Python's "everything is an object"** = References by default
- `x = 5` creates a reference to an integer object (heap-allocated)
- Assignment copies references (shared state by default)
- Explicit `copy.copy()` needed for independent copies

**Java's "everything is a class"** = Split model
- Objects are references, primitives are values
- Creates friction: boxing/unboxing, different semantics for `int` vs `Integer`
- Designed for performance: primitives avoid heap overhead

**Go's "everything is a value"** = Values by default
- `p2 = p1` copies the data (independent copies by default)
- Explicit pointers (`*Point`) for references (shared state when needed)
- Makes sharing visible in the code through `&` and `*`

**The pattern:** All three support both references and values. They differ in which is implicit (easy) and which requires explicit syntax (intentional).

**The spectrum:**
```
Reference-heavy ←────────────────────────→ Value-heavy

Python              Java              Go               C/Rust
(always refs)       (split)           (values          (raw values
                                      + pointers)      + unsafe)

Implicit sharing ←──────────────────→ Explicit sharing
Dynamic dispatch ←──────────────────→ Static dispatch
Heap by default  ←──────────────────→ Stack preferred
High overhead    ←──────────────────→ Zero overhead
```

Languages exist on a spectrum from "references by default" to "values by default." Moving right trades convenience (implicit sharing) for performance (stack allocation) and explicitness (visible sharing).
{{< /callout >}}

### Why This Matters

The reference-vs-value choice determines:

1. **Concurrency safety:** Values don't need synchronization (independent copies). References require locks or channels when shared between goroutines/threads.

2. **Performance characteristics:** Values can live on the stack (fast allocation/deallocation). References typically require heap allocation and garbage collection.

3. **Mental model:** With references, you reason about object identity and shared state. With values, you reason about data flow and transformations.

4. **API design:** Languages with default references encourage mutation (modify shared state). Languages with default values encourage immutability (return modified copies).

**The key insight:** Python, Java, and Go all support both references and values. The difference is which one is the **default** and which requires explicit syntax. Go inverts the common pattern by making values implicit and references explicit.

### Objects Are Not Just Pointers to Structs

A common misconception: "Objects are just structs with a pointer, right?" Not quite. Objects carry metadata that Go values (even pointer-based ones) don't have.

**Python object in memory:**
```
Variable on stack: [pointer]
                      ↓
Heap-allocated object: [ref_count | type_pointer | __dict__ | data]
                        (8 bytes)   (8 bytes)      (48+ bytes) (varies)
```

Every Python object has:
- Reference count (for garbage collection)
- Type pointer (links to class definition)
- Attribute dictionary (stores instance attributes)
- Then finally the actual data

**Java object in memory:**
```
Variable on stack: [reference]
                      ↓
Heap-allocated object: [mark_word | class_pointer | data]
                        (8 bytes)  (8 bytes)        (varies)
```

Every Java object has:
- Mark word (GC info, lock state, hash code)
- Class pointer (links to class metadata)
- Then the actual data

**Go value (stack-allocated):**
```
Variable on stack: [data]
                    (just the data, no metadata, no pointer)
```

**Go pointer:**
```
Variable on stack: [pointer]
                      ↓
Heap-allocated struct: [data]
                        (just the data, no metadata!)
```

**The crucial difference:** Go pointers point directly to data with zero metadata overhead. Python/Java references point to structures that wrap the data in metadata.

**Size comparison for storing two integers:**

```go
// Go value
type Point struct { X, Y int }
// Memory: 16 bytes (8 bytes × 2 integers)

// Go pointer
p := &Point{1, 2}
// Memory: 8 bytes (pointer) + 16 bytes (data) = 24 bytes total

// Python
class Point:
    def __init__(self, x, y):
        self.x, self.y = x, y
p = Point(1, 2)
// Memory: ~80+ bytes
//   8 bytes (variable pointer)
//   16 bytes (object header)
//   48 bytes (attribute dictionary)
//   28 bytes (int object for x)
//   28 bytes (int object for y)
```

**What this means:**

When Go uses pointers, you get reference semantics (shared state, identity) without object overhead. The pointer references raw data, not a metadata-wrapped object. This is why Go can use pointers liberally for large structs without the memory overhead that Python/Java objects carry.

### What Is an Object Really? Class vs Object

Understanding the implementation difference between classes and objects clarifies what "everything is an object" actually costs.

**Class (compile-time + runtime metadata):**
- Template defining field layout and method locations
- Method table (vtable): function pointers for dynamic dispatch
- Type information for runtime reflection
- **One per type** - all instances share the same class metadata

**Object (runtime instance):**
- Header pointing to its class
- Instance data (the actual field values)
- **Many per class** - each instantiation creates a new object

**Python example:**

```python
class Point:
    def __init__(self, x, y):
        self.x, self.y = x, y
    
    def distance(self):
        return (self.x**2 + self.y**2)**0.5

# Class metadata (stored once in memory):
# ┌─────────────────────────────┐
# │ Class: Point                │
# │ - __dict__: {'x': ..., ...} │
# │ - Methods: distance → 0x1234│
# └─────────────────────────────┘

# Object instances (many created):
p1 = Point(10, 20)
p2 = Point(30, 40)

# Each object:
# ┌─────────────────────────────┐
# │ Object header               │
# │ - type pointer → Point class│ ← Links to class metadata
# │ - reference count           │
# │ Instance data:              │
# │ - __dict__: {x: 10, y: 20}  │
# └─────────────────────────────┘
```

**Method call mechanism (vtable dispatch):**

```python
p1.distance()

# Runtime process:
# 1. Follow p1 (pointer to object in memory)
# 2. Read object header's type pointer → Point class
# 3. Look up 'distance' in Point class vtable (method table)
# 4. Call function at that address with self=p1 (dynamic dispatch)
```

**What is a vtable?** A vtable (virtual method table) is an array of function pointers stored in the class metadata. Every method in the class has an entry in the vtable pointing to its implementation. When you call a method on an object, the runtime follows the object's class pointer, looks up the method in that class's vtable, and calls the function it points to.

**Why vtables exist - polymorphism:**

```python
class Animal:
    def speak(self): print("...")

class Dog(Animal):
    def speak(self): print("Woof")

class Cat(Animal):
    def speak(self): print("Meow")

# Each class has its own vtable:
# Animal vtable: speak → address of Animal.speak
# Dog vtable:    speak → address of Dog.speak
# Cat vtable:    speak → address of Cat.speak

animal = Dog()  # Declared as base type, actually Dog
animal.speak()  # Prints "Woof" - runtime looks up Dog.speak in vtable

# Compiler doesn't know animal is Dog (could be Cat)
# Runtime follows: animal → Dog object → Dog class → vtable → Dog.speak
```

This indirection (object → class → vtable → function) enables polymorphism but costs performance: pointer dereferences and cache misses.

**Java example:**

```java
class Point {
    int x, y;
    double distance() { return Math.sqrt(x*x + y*y); }
}

Point p = new Point();
p.distance();

// Runtime:
// 1. Follow p (reference to object)
// 2. Read object header's class pointer
// 3. Look up distance() in vtable
// 4. Call method (dynamic dispatch through vtable)
```

**Go - no classes at all:**

```go
type Point struct { X, Y int }

func (p Point) Distance() float64 {
    return math.Sqrt(float64(p.X*p.X + p.Y*p.Y))
}

// NO class metadata exists at runtime
// NO method table
// NO vtable lookup
// Just data layout known at compile time

p := Point{10, 20}
// Memory: [10][20] (16 bytes, no header, no type pointer)

p.Distance()
// Compile-time: resolves to function Distance(p Point)
// Direct function call, no dynamic dispatch
// No runtime type lookup needed
// No vtable - compiler knows exact type
```

**Go avoids vtables for concrete types:**

```go
type Dog struct { name string }
type Cat struct { name string }

func (d Dog) Speak() { fmt.Println("Woof") }
func (c Cat) Speak() { fmt.Println("Meow") }

dog := Dog{name: "Fido"}
dog.Speak()  // Direct call: Speak(dog)
             // Compiler knows dog is Dog
             // No vtable, no indirection

// Polymorphism requires explicit interfaces:
type Animal interface {
    Speak()
}

var animal Animal = Dog{name: "Fido"}
animal.Speak()  // NOW uses dynamic dispatch
                // Interface value contains type info + vtable
                // Only when you explicitly use interfaces
```

**The key difference:** Go uses vtables **only when you ask for polymorphism** (interfaces). Python/Java use vtables **always** (every method call on every object).

### Performance Implications Summary

| Aspect | Python/Java (Objects) | Go (Values) | Go (Interfaces) |
|--------|----------------------|-------------|-----------------|
| Class metadata | Stored at runtime | Compile-time only | Stored for interface types |
| Method dispatch | Dynamic (vtable) | Static (direct call) | Dynamic (interface table) |
| Instance header | Required (16+ bytes) | None (0 bytes) | Interface wrapper (16 bytes) |
| Method call cost | ~5-10ns (vtable lookup) | ~1ns (direct call) | ~2-3ns (interface dispatch) |
| Memory overhead | High (headers + metadata) | Zero | Only when using interfaces |

**What "everything is an object/value" means in practice:**

**Python/Java:**
- Every instance has runtime header → class metadata → vtable
- Every method call: pointer dereference + vtable lookup + indirect call
- Performance cost paid whether you need polymorphism or not

**Go values:**
- No runtime type information, no headers, no vtables
- Method calls resolved at compile time → direct function calls
- Zero overhead for the common case (concrete types)

**Go interfaces (opt-in objects):**
- Explicit syntax (`var a Animal = dog`) wraps value in interface
- Interface contains type pointer + value pointer
- Method calls use dynamic dispatch through interface table
- Pay for polymorphism only when you explicitly ask for it

### Connection to Pass-by-Value vs Pass-by-Reference

This same choice applies to function parameters. When you pass an argument to a function, what gets passed?

**Pass-by-value:** The function receives a **copy** of the data
```go
func modify(p Point) {
    p.X = 100  // Modifies the copy
}

p := Point{1, 2}
modify(p)
fmt.Println(p.X)  // 1 (original unchanged)
```

**Pass-by-reference:** The function receives a **reference** to the original data
```go
func modify(p *Point) {
    p.X = 100  // Modifies through pointer
}

p := Point{1, 2}
modify(&p)  // Pass pointer explicitly
fmt.Println(p.X)  // 100 (original modified)
```

**How languages handle function calls:**

**Python:** Technically "pass-by-value of references." Since everything is already a reference, you pass a copy of the reference. The function can mutate the object but can't change which object the caller's variable references.
```python
def modify(point):
    point.x = 100  # Works! Mutates object through reference

p = Point(1, 2)
modify(p)
print(p.x)  # 100 (original object modified)

def try_reassign(point):
    point = Point(999, 999)  # Only changes local reference

p = Point(1, 2)
try_reassign(p)
print(p.x)  # 1 (caller's reference unchanged)
```

For practical purposes, Python behaves like pass-by-reference since you can mutate objects through the reference you receive.

**Java:** Pass-by-value, but for objects the "value" is a reference (confusing!). You're copying the reference, not the object.
```java
void modify(Point point) {
    point.x = 100;  // Modifies original (reference copied, but points to same object)
}

Point p = new Point(1, 2);
modify(p);
System.out.println(p.x);  // 100 (original modified)
```

**Go:** Pass-by-value (always). Functions receive copies unless you explicitly pass pointers.
```go
// Receives copy (no effect on original)
func modifyValue(p Point) {
    p.X = 100
}

// Receives pointer (affects original)
func modifyPointer(p *Point) {
    p.X = 100
}
```

The assignment semantics (reference vs value) determine the default parameter passing behavior. Languages with reference semantics naturally pass references to functions. Go's value semantics mean everything is copied unless you explicitly use pointers.

### The Primitive vs Object Question

This raises an important question: Is everything in Go a "primitive" since everything behaves like a value?

**Python:** No primitives at all. Everything is a reference to a heap-allocated object with identity.
```python
x = 42
type(x)  # <class 'int'> - even integers are objects
id(x)    # Every value has identity
x.bit_length()  # Integers have methods
```

**Java:** Explicit split between primitives and objects.
```java
int x = 42;          // Primitive (value type, stack, no methods)
Integer y = 42;      // Object (reference type, heap, has methods)

// Different behavior:
int a = 5;
int b = a;           // Copy value
b = 10;              // a unchanged

Integer c = new Integer(5);
Integer d = c;       // Copy reference
d = 10;              // Wait, this creates new Integer, doesn't modify c
```

Java's primitive/object split creates complexity: boxing/unboxing, different semantics, performance tradeoffs.

**Go:** No primitive/object distinction. Everything follows value semantics, but you're not limited to simple types.
```go
// All of these behave the same way (value semantics):
x := 42                    // Built-in type
p := Point{1, 2}           // User-defined struct
m := MyInt(10)             // Type alias
s := []int{1, 2, 3}        // Slice (value, but contains reference to array)

// All copied on assignment:
x2 := x  // Copy
p2 := p  // Copy (entire struct)
m2 := m  // Copy
s2 := s  // Copy (slice header, not underlying array)
```

**The key insight:**

- **Python:** Everything is an object (reference semantics everywhere)
- **Java:** Split model (primitives are values, objects are references)
- **Go:** Everything behaves like values by default (uniform semantics, explicit pointers for references)

Go doesn't need a primitive type system because value semantics work for complex types too. A struct with 10 fields behaves just like an integer - copied on assignment, no identity, stack-allocatable. Java needed primitives for performance (avoiding heap allocation), but Go achieves this through escape analysis instead.

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

Go's "everything is a value" philosophy creates a programming model where data is copied by default. Assignment copies values, function arguments receive copies, and there's no hidden sharing. When sharing is needed, it's explicit through pointers, channels, or mutexes. This makes performance predictable through stack allocation and cheap copies, while keeping concurrency safer since each goroutine gets its own copies by default.

The memory model stays simple: values are just bytes with no object headers or reference counting. This contrasts sharply with Python's heap-allocated objects with identity and Java's class hierarchies with inheritance.

**The trade-offs:**

Python's objects provide rich introspection and dynamic behavior at the cost of memory overhead and synchronization complexity. Java's classes offer strong typing and clear structure but demand verbose boilerplate and explicit interfaces. Go's values deliver simplicity and safe concurrency but require explicit copying and forego inheritance entirely.

The mental model you choose shapes how you think about your program. Go's value philosophy encourages thinking about data flow (values moving through functions) rather than object graphs (references connecting objects).

---

## Further Reading

**Go Philosophy:**
- [Effective Go: Interfaces and Other Types](https://go.dev/doc/effective_go#interfaces)
- [Go Proverbs](https://go-proverbs.github.io/)

**Related Posts:**
- [Go Interfaces: The Type System Feature You Implement By Accident]({{< relref "go-interfaces-accidental-implementation.md" >}})
- [Python's Object Overhead: Why Everything Being an Object Has a Cost]({{< relref "python-object-overhead.md" >}})
