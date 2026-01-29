---
title: "Go's Value Philosophy: Part 3 - Zero Values: Go's Valid-by-Default Philosophy"
date: 2026-01-23
draft: false
series: ["go-value-philosophy"]
seriesOrder: 3
tags: ["go", "golang", "zero-values", "valid-by-default", "null-safety", "memory-model", "default-values", "api-design", "python", "java", "comparison", "nil", "none", "programming-paradigms", "declaration"]
categories: ["programming", "go"]
description: "Deep dive into Go's zero values: how declaration creates valid values, why Go has no uninitialized state, and how this eliminates entire classes of bugs that plague null-based languages."
summary: "In Python, undeclared variables don't exist. In Java, local variables can't be used before assignment. In Go, declaration creates a valid value. There is no uninitialized state - every value works from the moment it's declared."
---

In [Part 1]({{< relref "go-values-not-objects.md" >}}), we explored Go's value philosophy and how it differs from Python's objects and Java's classes. [Part 2]({{< relref "go-values-escape-analysis.md" >}}) revealed how escape analysis makes value semantics performant. Now we address a fundamental question about value semantics:

**What happens when you declare a variable?**

```go
var x int
fmt.Println(x)  // What is x?
```

In Python, undeclared variables don't exist (NameError).
In Java, local variables must be assigned before use (compile error).
In Go, `x` exists immediately as the value `0` - the **zero value** for integers.

**Declaration vs initialization:**
- **Declaration:** Announcing a variable exists and reserving memory for it
- **Initialization:** Giving that variable its first value

{{< mermaid >}}
flowchart LR
    subgraph other["Most Languages"]
        d1[Declaration<br/>Reserve memory] --> i1[Uninitialized state] --> a1[Assignment<br/>First value]
    end
    
    subgraph go["Go"]
        d2[Declaration<br/>Reserve memory] --> i2[Zero value<br/>Immediate value]
    end

    style other fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style go fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

In most languages, these are separate steps. You declare a variable (reserve space), then initialize it (give it a value).

Go merges these: declaration IS initialization. When you declare `var x int`, you don't get uninitialized memory - you get the integer `0`.

Every Go variable is initialized at the moment it's declared.

{{< callout type="info" >}}
**Zero Values: Go's Valid-by-Default Philosophy**

In Go, declaration creates a value. When you write `var x int`, you don't get an uninitialized variable - you get the integer `0`. This is the **zero value** for integers.

Every type in Go has a zero value - the state a variable holds from the moment it's declared. No null, no undefined, no uninitialized memory. Declaration equals instantiation.

This simple design choice removes entire classes of null-related runtime failures and enables API designs impossible in languages where variables can be uninitialized or null.
{{< /callout >}}

---

## Declaration Creates Values

The fundamental difference between Go and other languages is what happens when you declare a variable:

**Go: Declaration creates a valid value**
```go
var x int     // x now holds the value 0
var s string  // s now holds the value "" (empty string)
var b bool    // b now holds the value false

// These are usable immediately:
fmt.Println(x)  // 0
fmt.Println(s)  // ""
fmt.Println(b)  // false
```

**Python: Assignment creates variables**
```python
# Python has no "var x" or "let x" syntax
# Assignment creates the variable
x = 0     # Declaration and initialization happen together
print(x)  # 0

# Can't declare without a value - no equivalent to "var x int"
```

**Java: Local variables forbidden before assignment**
```java
void method() {
    int x;  // Declared but has no value
    System.out.println(x);  // COMPILE ERROR: variable might not have been initialized
    
    x = 0;  // Now has value
    System.out.println(x);  // 0
}
```

{{< callout type="info" >}}
**The key distinction:** In Go, `var` is itself an initialization. Local variables must still be definitely assigned along all control paths - but the `var` form guarantees that assignment happens at declaration. The zero value IS the value, not a placeholder for a future value.
{{< /callout >}}

### The Nil Paradox: How "Valid" Still Includes nil

**Wait - if Go is "valid by default," why does `nil` exist?**

Go's zero value philosophy has a nuance: some types have `nil` as their zero value (pointers, slices, maps, channels, interfaces, functions). This seems contradictory - how can "every value is valid by default" coexist with nil? The answer reveals a fundamental design choice about what "valid" means.

In Java and Python, `null`/`None` represents the absence of an object. Any operation on null crashes. The value is invalid - it can't be used until you explicitly check for null and handle that case.

Go's `nil` is different. It represents a valid zero state that supports specific operations. The type determines which operations work. For some types (slices), nil supports nearly all read operations. For others (maps), nil supports reads but not writes. For pointers, nil can be checked but not dereferenced.

The pattern: Go's nil values have **well-defined, predictable behavior** rather than universal failure.

**Go's nil slice - safe for reading:**
```go
var s []int        // nil slice
fmt.Println(len(s))  // 0 (safe!)
fmt.Println(cap(s))  // 0 (safe!)
s = append(s, 1)     // Works! (allocates backing array)
for _, v := range s {} // Works! (iterates zero times)
```

A nil slice behaves like an empty slice for read operations. You can check its length, iterate over it (which completes immediately), and append to it (which allocates storage on first append). The nil state is the zero state - it's not an error condition requiring defensive checks everywhere.

**Go's nil map - safe for reading, panics on write:**
```go
var m map[string]int  // nil map
fmt.Println(m["key"]) // 0 (safe! returns zero value)
v, ok := m["key"]     // v=0, ok=false (safe!)
for k, v := range m {} // Works! (iterates zero times)

// m["key"] = 1       // PANIC! Must initialize for writes
m = make(map[string]int)
m["key"] = 1          // Works
```

Nil maps support all read operations. Looking up missing keys returns the zero value (matching non-nil map behavior). Iteration works (completes immediately). Only mutation requires initialization. This asymmetry is intentional - reading can't corrupt state, so it's safe. Writing requires storage, so it requires initialization.

**Java's null - crashes on all operations:**
```java
String s = null;
System.out.println(s.length());  // NullPointerException!

Map<String, Integer> m = null;
int value = m.get("key");  // NullPointerException!

List<String> list = null;
int size = list.size();  // NullPointerException!
```

Java's null is universally invalid. Any operation - even queries like `.size()` or `.length()` - throws NullPointerException. Every null reference forces defensive nil checks throughout the codebase. The absence of an object means the variable is completely unusable.

**Why this matters:**

In Java, you write defensive code everywhere:
```java
if (list != null && list.size() > 0) {
    // Use list
}
```

In Go, nil slices work without checks:
```go
if len(slice) > 0 {  // Works even if slice is nil
    // Use slice
}
```

The nil check is built into the operation. `len(nil)` returns 0. This eliminates an entire category of nil checks.

**Nil receivers - methods on nil values:**

Go allows calling methods on nil receivers if the method handles it:

```go
type Tree struct {
    value int
    left  *Tree
    right *Tree
}

func (t *Tree) Sum() int {
    if t == nil {  // Nil check inside method
        return 0
    }
    return t.value + t.left.Sum() + t.right.Sum()
}

var tree *Tree  // nil
sum := tree.Sum()  // Works! Returns 0
```

The method can be called on nil. The method checks if the receiver is nil and handles it. This pattern is impossible in Java (calling methods on null throws NullPointerException) and Python (calling methods on None throws AttributeError).

**Value semantics vs reference semantics:**

The nil distinction maps to Go's deeper type system, which divides types into two categories based on how assignment and copying work.

**Value semantics:** When you assign or pass a variable, you copy the entire value. The variable contains the data directly, not a reference to data stored elsewhere. Modifying the copy doesn't affect the original because they're independent values occupying separate memory.

```go
type Point struct { X, Y int }
p1 := Point{X: 1, Y: 2}
p2 := p1  // Copies the entire struct
p2.X = 10
fmt.Println(p1.X)  // Still 1 (independent copy)
```

Types with value semantics: int, bool, string, arrays, structs. These are never nil - the variable *is* the value, not a reference to the value.

**Reference semantics:** When you assign or pass a variable, you copy a reference (pointer) to shared underlying storage. Multiple variables can reference the same underlying data. Modifying through one reference affects all references because they point to the same storage.

```go
s1 := []int{1, 2, 3}
s2 := s1  // Copies the slice header (pointer to backing array)
s2[0] = 10
fmt.Println(s1[0])  // Now 10 (shared backing array)
```

Types with reference semantics: pointers, slices, maps, channels, interfaces, functions. These can be nil because the reference can point to nothing (no underlying storage allocated yet).

Go makes this distinction explicit in the type system. Unlike Java (where everything is a reference) or Python (where everything is a reference to an object), Go's type tells you whether assignment copies the value or copies a reference. This clarity eliminates entire classes of bugs around unexpected sharing.

**The design choice:**

Go could have made slices and maps work like structs - always allocated, never nil. But that would waste memory (empty map still allocates) and eliminate useful patterns (distinguishing between "not set" and "set to empty"). 

Go could have made nil crash on all operations like Java's null. But that would require defensive nil checks everywhere, defeating the zero value philosophy.

Instead, Go chose a middle ground: nil exists, but it's a valid zero state with predictable behavior. Types define which operations work on nil. This preserves the zero value philosophy while acknowledging that some types need to represent "not yet allocated."

Because declaration equals initialization, every variable can be safely used from the moment it's declared. Value types support all operations. Types with nil zero values support read operations - only mutation requires explicit initialization. This removes entire classes of null-related runtime failures while maintaining Go's commitment to valid-by-default values.

## What Are Zero Values?

Because declaration equals initialization, every type needs a concrete value to hold at the moment of declaration. This is the **zero value**.

For most types, zero values support all operations. For types with `nil` as their zero value (pointers, slices, maps, channels, interfaces, functions), read operations work but writes may require explicit initialization.

### Built-in Types

| Type | Zero Value | Usability |
|------|------------|-----------|
| `bool` | `false` | Immediately usable |
| `int`, `int8`, `int16`, `int32`, `int64` | `0` | Immediately usable |
| `uint`, `uint8`, `uint16`, `uint32`, `uint64` | `0` | Immediately usable |
| `float32`, `float64` | `0.0` | Immediately usable |
| `string` | `""` (empty string) | Immediately usable |
| `pointer` | `nil` | Safe to check, unsafe to dereference |
| `slice` | `nil` | Safe to read (length 0), can append |
| `map` | `nil` | Safe to read, must initialize to write |
| `channel` | `nil` | Blocks forever on send/receive; `close(nil)` panics |
| `interface` | `nil` | Safe to check, unsafe to call methods |
| `function` | `nil` | Safe to check, unsafe to call |

**Example:**

```go
var (
    b bool       // false
    i int        // 0
    f float64    // 0.0
    s string     // ""
    p *int       // nil
    slice []int  // nil
    m map[string]int  // nil
)

fmt.Println(b)  // false
fmt.Println(i)  // 0
fmt.Println(f)  // 0
fmt.Println(s)  // "" (empty, but valid string)
fmt.Println(len(slice))  // 0 (nil slice has length 0)
```

---

## Contrast with Other Languages

### Python: No Default Values

Python requires explicit initialization or raises `NameError`:

```python
# Error: name 'x' is not defined
print(x)

# Must initialize explicitly
x = 0
print(x)  # 0

# Class fields default to None (not zero!)
class Counter:
    pass

c = Counter()
print(c.count)  # AttributeError: no attribute 'count'

# Must initialize in __init__
class Counter:
    def __init__(self):
        self.count = 0  # Explicit initialization required
```

### Java: Split Behavior

Java has different rules for local variables vs fields:

```java
public class Example {
    int field;  // Defaults to 0 (field)
    
    void method() {
        int local;  // ERROR: must be initialized before use
        // System.out.println(local);  // Compile error
        
        int initialized = 0;  // Must explicitly initialize
        System.out.println(initialized);  // OK
    }
    
    void useField() {
        System.out.println(field);  // OK - fields default to 0
    }
}
```

Java objects default to `null`:

```java
public class Container {
    String name;  // Defaults to null (not empty string!)
    
    void print() {
        System.out.println(name.length());  // NullPointerException!
    }
}
```

### Go: Consistent Zero Values

Go applies zero values uniformly:

```go
// All valid immediately
var x int        // 0
var s string     // ""
var found bool   // false

func process() {
    var count int  // 0 (no initialization needed)
    count++
    fmt.Println(count)  // 1
}

type Config struct {
    Timeout int
    Retries int
}

var c Config  // {Timeout: 0, Retries: 0}
// Immediately usable, no nil checks needed
```

---

## Why Zero Values Matter

### 1. Eliminate Null Pointer Exceptions

**Java's null problem:**

```java
String name = null;  // Common default
System.out.println(name.toUpperCase());  // NullPointerException!

// Must check everywhere
if (name != null) {
    System.out.println(name.toUpperCase());
}
```

**Go's zero value solution:**

```go
var name string  // "" (empty string, not nil)
fmt.Println(strings.ToUpper(name))  // "" (works fine, no panic)

// No nil checks needed for value types
```

Because declaration equals initialization, value types like int, bool, string, and structs are never nil - they hold concrete zero values from the moment they're declared.

### 2. Simpler Struct Initialization

**Python requires boilerplate:**

```python
class Config:
    def __init__(self):
        self.timeout = 30  # Must explicitly initialize
        self.retries = 3
        self.enabled = True
        self.prefix = ""
        
c = Config()  # Must call __init__
```

**Go's zero values reduce boilerplate:**

```go
type Config struct {
    Timeout int     // 0 by default
    Retries int     // 0 by default
    Enabled bool    // false by default
    Prefix  string  // "" by default
}

// Zero value struct is valid
var c Config  // {Timeout: 0, Retries: 0, Enabled: false, Prefix: ""}

// Override only what you need
c2 := Config{
    Timeout: 30,
    Retries: 3,
    Enabled: true,
}
// Prefix stays "" (zero value)
```

### 3. Enable "Ready to Use" Types

Zero values enable types that work without explicit initialization:

```go
// sync.Mutex: zero value is ready to use
var mu sync.Mutex
mu.Lock()   // Works immediately!
mu.Unlock()

// bytes.Buffer: zero value is ready to use
var buf bytes.Buffer
buf.WriteString("hello")  // Works immediately!
fmt.Println(buf.String())  // "hello"

// strings.Builder: zero value is ready to use
var sb strings.Builder
sb.WriteString("world")  // Works immediately!
```

Compare to Java:

```java
// Must explicitly construct
StringBuilder sb = new StringBuilder();  // Must initialize
sb.append("hello");
```

---

## The Nil Exception

Not all zero values are non-nil. Some types have `nil` as their zero value:

**Types with nil zero values:**
- Pointers: `*T`
- Slices: `[]T`
- Maps: `map[K]V`
- Channels: `chan T`
- Interfaces: `interface{}`
- Functions: `func()`

### Safe Nil Behavior

Go's nil has predictable behavior:

```go
// Nil slice: safe to read, can append
var s []int  // nil
fmt.Println(len(s))  // 0 (safe)
s = append(s, 1)     // Works! (allocates backing array)

// Nil map: safe to read, panics on write
var m map[string]int  // nil
fmt.Println(m["key"])  // 0 (safe, returns zero value)
m["key"] = 1          // PANIC! Must initialize first

// Must initialize maps explicitly
m = make(map[string]int)
m["key"] = 1  // Works
```

### Nil Receivers

Methods can be called on nil receivers:

```go
type Tree struct {
    value int
    left  *Tree
    right *Tree
}

func (t *Tree) Sum() int {
    if t == nil {  // Nil check
        return 0
    }
    return t.value + t.left.Sum() + t.right.Sum()
}

var tree *Tree  // nil
sum := tree.Sum()  // Works! Returns 0
```

This pattern is impossible in Java (NullPointerException) and Python (AttributeError).

---

## Struct Zero Values: Composition

Struct zero values are the zero values of their fields:

```go
type Point struct {
    X, Y int
}

type Line struct {
    Start Point
    End   Point
}

var line Line
// line = Line{
//     Start: Point{X: 0, Y: 0},
//     End:   Point{X: 0, Y: 0},
// }

fmt.Println(line.Start.X)  // 0
```

**Nested structs compose their zero values:**

```go
type Config struct {
    Server   ServerConfig
    Database DatabaseConfig
}

type ServerConfig struct {
    Port    int
    Timeout int
}

type DatabaseConfig struct {
    MaxConns int
    IdleTime int
}

var cfg Config
// All fields recursively zero-valued:
// cfg.Server.Port = 0
// cfg.Server.Timeout = 0
// cfg.Database.MaxConns = 0
// cfg.Database.IdleTime = 0
```

---

## Designing for Zero Values

### Pattern 1: Zero Value is Ready to Use

Design types so their zero value is immediately functional:

```go
// Good: Zero value works
type Cache struct {
    mu    sync.RWMutex
    items map[string][]byte  // nil is fine
}

func (c *Cache) Get(key string) ([]byte, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    
    val, ok := c.items[key]  // nil map returns zero value
    return val, ok
}

func (c *Cache) Set(key string, val []byte) {
    c.mu.Lock()
    defer c.mu.Unlock()
    
    if c.items == nil {  // Lazy initialization
        c.items = make(map[string][]byte)
    }
    c.items[key] = val
}

// Usage: zero value works
var cache Cache  // No New() function needed
cache.Set("key", []byte("value"))
```

### Pattern 2: Constructor for Complex Setup

When zero value isn't sufficient, provide a constructor:

```go
type Server struct {
    addr    string
    handler http.Handler
    logger  *log.Logger
}

// Zero value isn't useful (no address, no handler)
func NewServer(addr string, handler http.Handler) *Server {
    return &Server{
        addr:    addr,
        handler: handler,
        logger:  log.Default(),  // Provide defaults
    }
}
```

### Pattern 3: Validate in Methods

Defer initialization until first use:

```go
type DB struct {
    conn *sql.DB
}

func (db *DB) Query(query string) (*sql.Rows, error) {
    if db.conn == nil {
        return nil, errors.New("database not connected")
    }
    return db.conn.Query(query)
}

func (db *DB) Connect(dsn string) error {
    conn, err := sql.Open("postgres", dsn)
    if err != nil {
        return err
    }
    db.conn = conn
    return nil
}
```

---

## Comparison: Initialization Patterns

### Python: Explicit Initialization Required

```python
class Buffer:
    def __init__(self):
        self.data = []  # Must initialize
        self.size = 0
        
    def append(self, item):
        self.data.append(item)
        self.size += 1

# Must call constructor
buf = Buffer()  # __init__ runs
buf.append(42)
```

### Java: Constructors or Null

```java
public class Buffer {
    private List<Integer> data;  // null by default
    
    public Buffer() {
        this.data = new ArrayList<>();  // Must initialize
    }
    
    public void append(int item) {
        if (data == null) {  // Defensive check
            data = new ArrayList<>();
        }
        data.add(item);
    }
}

// Must construct
Buffer buf = new Buffer();
buf.append(42);
```

### Go: Zero Value Composability

```go
type Buffer struct {
    data []int  // nil slice (zero value)
    size int    // 0 (zero value)
}

func (b *Buffer) Append(item int) {
    b.data = append(b.data, item)  // append works on nil slice
    b.size++
}

// Zero value works
var buf Buffer  // No constructor needed
buf.Append(42)  // Just works
```

---

## Zero Values and Memory Safety

Zero values make Go's memory model predictable:

```go
type Cache struct {
    data map[string]string  // nil
    mu   sync.RWMutex       // Zero value ready
}

// Zero value is safe (won't panic, won't corrupt memory)
var c Cache
c.mu.Lock()    // Works (zero value mutex is valid)
_ = c.data["x"]  // Returns "" (nil map returns zero value)
c.mu.Unlock()

// Only writes need initialization
c.data = make(map[string]string)
c.data["x"] = "value"  // Now writes work
```

**Contrast with C (uninitialized memory):**

```c
int x;  // Contains garbage (whatever was in memory)
printf("%d\n", x);  // Undefined behavior!

// Must explicitly initialize
int y = 0;
```

**Contrast with Java (null references):**

```java
String name;  // null
System.out.println(name.length());  // NullPointerException!

// Must check or initialize
String name = "";
```

**Go guarantees:** Variables are always initialized to their zero value. No uninitialized memory, no accidental null dereferences for value types.

---

## When Zero Values Don't Suffice

Zero values work when the default state is genuinely useful - an empty string, a count of zero, an unlocked mutex. But not all types have a meaningful default. Some types exist to wrap external resources (database connections, file handles). Others represent domain concepts that require specific values to be valid (email addresses, API keys). Still others need configuration before they can do anything useful (HTTP clients, loggers).

For these types, the zero value exists but isn't usable. An HTTP client with no endpoint can't make requests. A database wrapper with no connection can't query. An email address that's an empty string violates business logic.

When zero values don't suffice, Go provides constructors - functions (typically named `New*`) that return properly initialized values. This preserves Go's zero value model while acknowledging that some types need explicit setup.

The decision comes down to: **Can this type do something useful with all fields set to their zero values?** If yes, make it work. If no, require a constructor.

### Requires Configuration

```go
type Client struct {
    endpoint string
    apiKey   string
    timeout  time.Duration
}

// Zero value not useful (no endpoint, no API key)
func NewClient(endpoint, apiKey string) *Client {
    return &Client{
        endpoint: endpoint,
        apiKey:   apiKey,
        timeout:  30 * time.Second,  // Sensible default
    }
}
```

### Requires External Resources

```go
type Database struct {
    conn *sql.DB  // nil (requires connection)
}

// Can't provide zero value for external resource
func Open(dsn string) (*Database, error) {
    conn, err := sql.Open("postgres", dsn)
    if err != nil {
        return nil, err
    }
    return &Database{conn: conn}, nil
}
```

### Requires Validation

```go
type Email string

// Zero value ("") is technically valid but semantically wrong
func NewEmail(addr string) (Email, error) {
    if !strings.Contains(addr, "@") {
        return "", errors.New("invalid email")
    }
    return Email(addr), nil
}
```

---

## The Standard Library's Approach

Go's standard library demonstrates zero value design:

### sync.Mutex: Zero Value Ready

```go
type Counter struct {
    mu    sync.Mutex  // Zero value works
    count int
}

var c Counter  // No initialization needed
c.mu.Lock()
c.count++
c.mu.Unlock()
```

### bytes.Buffer: Zero Value Ready

```go
var buf bytes.Buffer  // Zero value ready
buf.WriteString("hello")
fmt.Println(buf.String())  // "hello"
```

### http.Server: Constructor Required

```go
// Zero value not useful (no handler, no address)
server := &http.Server{
    Addr:    ":8080",
    Handler: mux,
}
server.ListenAndServe()
```

**The pattern:** If a type can be useful with zero values, make it so. If it requires configuration or external resources, provide a constructor (`New*` function).

---

## Putting It Together

Go's zero value philosophy stems directly from its value model. In languages where variables are references to objects, uninitialized variables either error (Python) or hold null (Java). In Go, where variables are values, uninitialized variables hold the zero value of their type.

This creates a programming model where declaration equals initialization. No separate steps, no null checks for value types, no uninitialized memory. Every variable is immediately valid and safe to use, even if not explicitly initialized.

**The tradeoffs:**

Python's explicit initialization prevents accidentally using uninitialized state but requires boilerplate constructors. Java's null defaults enable lazy initialization but introduce null pointer exceptions. Go's zero values provide safety and simplicity but require thoughtful API design to ensure zero values are actually useful.

The mental model: In Go, absence of explicit initialization doesn't mean "uninitialized" or "null." It means "initialized to the most reasonable default for this type." This shifts error handling from defensive nil checks to validating business logic instead.

---

## Further Reading

**Go Initialization:**
- [Effective Go: Allocation with new](https://go.dev/doc/effective_go#allocation_new)
- [Effective Go: Constructors and composite literals](https://go.dev/doc/effective_go#composite_literals)

**Related Posts:**
- [Part 1: Go's Value Philosophy]({{< relref "go-values-not-objects.md" >}})
- [Part 2: Escape Analysis and Performance]({{< relref "go-values-escape-analysis.md" >}})

---

## Next in Series

**Part 4: Slices, Maps, and Channels - The Hybrid Types** - Coming soon. Learn why these types look like values but behave like references, and how this affects your code.
