---
title: "The Complete Guide to Rust Testing: Unit, Integration, Property-Based, and Snapshot Testing"
date: 2025-12-24
draft: false
tags: ["rust", "testing", "unit-testing", "integration-testing", "property-based-testing", "snapshot-testing", "rstest", "proptest", "insta", "doctest", "test-driven-development", "tdd", "software-testing", "test-automation", "cargo", "rust-testing", "end-to-end-testing", "test-strategies", "rust-best-practices", "quality-assurance", "code-coverage"]
categories: ["rust", "tutorials", "best-practices"]
description: "Master Rust testing with this comprehensive guide covering unit tests, integration tests, property-based testing with proptest, snapshot testing with insta, rstest fixtures, and doctests. Learn when to use each approach."
summary: "A complete overview of Rust testing strategies: unit tests, integration tests, property-based testing, snapshot testing, parameterized tests, and doctests. Learn which testing approach fits your needs."
---

Your Rust project needs tests. But which kind? Unit tests? Integration tests? Property-based tests? Snapshot tests?

Here's a comprehensive overview of Rust testing approaches—what each one does, when to use it, and how they work together to build confidence in your code.

## The Testing Landscape

Rust provides built-in testing infrastructure through `cargo test`, but the ecosystem offers specialized tools for different testing needs:

{{< mermaid >}}
flowchart TB
    subgraph builtin["Built-in Testing"]
        unit[Unit Tests<br/>───────<br/>cargo test]
        integration[Integration Tests<br/>───────<br/>tests/ directory]
        doc[Doc Tests<br/>───────<br/>/// examples]
    end

    subgraph crates["Testing Crates"]
        rstest[rstest<br/>───────<br/>Fixtures & params]
        proptest[proptest<br/>───────<br/>Property-based]
        insta[insta<br/>───────<br/>Snapshot testing]
    end

    subgraph strategies["Test Strategies"]
        tdd[Test-Driven<br/>Development]
        bdd[Behavior-Driven<br/>Development]
        exploratory[Exploratory<br/>Testing]
    end

    builtin --> strategies
    crates --> strategies

    style builtin fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style crates fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style strategies fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

{{< callout type="info" >}}
**Key Insight:** These testing approaches aren't mutually exclusive. Production Rust projects typically use multiple testing strategies together—unit tests for logic, integration tests for APIs, property-based tests for edge cases, and snapshot tests for complex outputs.
{{< /callout >}}

---

## Part 1: Built-in Testing

Rust's standard library provides three testing mechanisms out of the box.

### Unit Tests

**What they are:** Tests that live alongside your code in the same file, testing individual functions or modules in isolation.

**Type:** Built-in (via `#[cfg(test)]` and `#[test]`)

#### Basic Structure

```rust
// src/calculator.rs
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

pub fn divide(a: i32, b: i32) -> Result<i32, String> {
    if b == 0 {
        return Err("division by zero".to_string());
    }
    Ok(a / b)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        assert_eq!(add(2, 2), 4);
        assert_eq!(add(-1, 1), 0);
        assert_eq!(add(0, 0), 0);
    }

    #[test]
    fn test_divide_success() {
        assert_eq!(divide(10, 2), Ok(5));
        assert_eq!(divide(7, 2), Ok(3));
    }

    #[test]
    fn test_divide_by_zero() {
        assert!(divide(10, 0).is_err());
        assert_eq!(divide(10, 0), Err("division by zero".to_string()));
    }

    #[test]
    #[should_panic(expected = "assertion failed")]
    fn test_panic_behavior() {
        assert_eq!(1, 2);
    }

    #[test]
    #[ignore]
    fn expensive_test() {
        // This test is skipped by default
        // Run with: cargo test -- --ignored
    }
}
```

#### Running Tests

```bash
# Run all tests
cargo test

# Run tests matching a pattern
cargo test divide

# Run ignored tests
cargo test -- --ignored

# Show test output (normally hidden)
cargo test -- --nocapture

# Run tests in parallel (default) or sequentially
cargo test -- --test-threads=1
```

#### Test Organization

{{< mermaid >}}
flowchart TB
    subgraph inline["Inline Tests (#[cfg(test)])"]
        direction TB
        tests1["#[cfg(test)]<br/>mod tests"]
        tests2["#[test]<br/>fn test_add()"]
        tests3["#[test]<br/>fn test_divide()"]
        tests1 --> tests2
        tests1 --> tests3
    end

    subgraph separate["Separate Test Modules"]
        direction TB
        testmod1["tests/mod.rs"]
        testmod2["Private test helpers"]
        testmod3["Shared fixtures"]
        testmod1 --> testmod2
        testmod1 --> testmod3
    end

    inline -.->|"Same file as code"| separate
    separate -.->|"Larger projects"| inline

    style inline fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style separate fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

#### When to Use Unit Tests

**Use unit tests when:**

- + Testing pure functions with clear inputs/outputs
- + Verifying business logic in isolation
- + Testing edge cases (empty inputs, boundary values)
- + Ensuring error handling works correctly
- + You want fast, focused tests

**Skip unit tests when:**

- - Testing requires external dependencies (database, network)
- - Testing UI interactions
- - Testing system integration points

{{< callout type="success" >}}
**Best Practice:** Write unit tests first (TDD style) for complex business logic. The need to write tests will naturally guide you toward more testable designs—pure functions, dependency injection, and clear separation of concerns.
{{< /callout >}}

---

### Integration Tests

**What they are:** Tests that live in the `tests/` directory and test your crate's public API as an external consumer would use it.

**Type:** Built-in (via `tests/` directory)

#### Project Structure

```
my-crate/
├── src/
│   ├── lib.rs
│   └── calculator.rs
├── tests/
│   ├── integration_test.rs
│   ├── api_tests.rs
│   └── common/
│       └── mod.rs        # Shared test utilities
└── Cargo.toml
```

#### Integration Test Example

```rust
// tests/api_tests.rs
use my_crate::Calculator;

#[test]
fn test_calculator_workflow() {
    let calc = Calculator::new();
    
    // Test the public API as a user would
    let result = calc
        .add(5)
        .multiply(2)
        .subtract(3)
        .result();
    
    assert_eq!(result, 7);
}

#[test]
fn test_error_propagation() {
    let calc = Calculator::new();
    
    let result = calc
        .add(10)
        .divide(0)  // Should error
        .result_with_error();
    
    assert!(result.is_err());
    assert_eq!(
        result.unwrap_err().to_string(),
        "division by zero"
    );
}
```

#### Shared Test Utilities

```rust
// tests/common/mod.rs
use my_crate::Database;

pub fn setup_test_db() -> Database {
    Database::in_memory()
        .with_fixtures("test_data.sql")
        .build()
}

pub fn cleanup_test_db(db: Database) {
    db.clear_all_tables();
}
```

```rust
// tests/database_tests.rs
mod common;

#[test]
fn test_user_creation() {
    let db = common::setup_test_db();
    
    let user = db.create_user("alice", "alice@example.com");
    assert!(user.is_ok());
    
    common::cleanup_test_db(db);
}
```

#### Integration vs Unit Tests

| Aspect | Unit Tests | Integration Tests |
|--------|-----------|-------------------|
| **Location** | `src/` with `#[cfg(test)]` | `tests/` directory |
| **Scope** | Single function/module | Multiple modules, public API |
| **Access** | Can test private functions | Only public API |
| **Compilation** | Same binary as code | Separate binary per test file |
| **Speed** | Very fast | Slower (separate compilation) |
| **Dependencies** | Minimal | Can use external resources |

#### When to Use Integration Tests

**Use integration tests when:**

- + Testing how multiple modules work together
- + Verifying public API contracts
- + Testing workflows across module boundaries
- + Ensuring backward compatibility
- + Testing with real external dependencies (databases, files)

**Skip integration tests when:**

- - Testing implementation details
- - Testing private functions
- - You need very fast test execution

{{< callout type="warning" >}}
**Important:** Each file in `tests/` compiles as a separate crate. If you have 10 test files, `cargo test` compiles 10 separate binaries. For large projects, this can slow down compilation. Consider consolidating related tests into fewer files.
{{< /callout >}}

---

### Doc Tests

**What they are:** Code examples in doc comments that are automatically compiled and run as tests.

**Type:** Built-in (via `/// ` doc comments)

#### Basic Doc Test

```rust
/// Adds two numbers together.
///
/// # Examples
///
/// ```
/// use my_crate::add;
///
/// let result = add(2, 2);
/// assert_eq!(result, 4);
/// ```
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}
```

When you run `cargo test`, Rust extracts this code block, compiles it, and runs it.

#### Doc Test Features

```rust
/// Divides two numbers.
///
/// # Examples
///
/// Basic usage:
/// ```
/// use my_crate::divide;
///
/// assert_eq!(divide(10, 2), Ok(5));
/// ```
///
/// Division by zero returns an error:
/// ```
/// use my_crate::divide;
///
/// assert!(divide(10, 0).is_err());
/// ```
///
/// This example should fail to compile (hidden from docs):
/// ```compile_fail
/// use my_crate::divide;
/// let result: String = divide(10, 2);  // Type error
/// ```
///
/// This example is ignored (shown but not run):
/// ```ignore
/// use my_crate::divide;
/// let result = divide(SOME_CONSTANT_NOT_DEFINED, 2);
/// ```
///
/// This example is hidden from documentation:
/// ```
/// # use my_crate::divide;
/// # fn main() {
/// let result = divide(10, 2);
/// # }
/// ```
pub fn divide(a: i32, b: i32) -> Result<i32, String> {
    if b == 0 {
        return Err("division by zero".to_string());
    }
    Ok(a / b)
}
```

#### Doc Test Annotations

| Annotation | Behavior |
|------------|----------|
| **```** | Normal doc test (compiled and run) |
| **```ignore** | Shown in docs but not run |
| **```no_run** | Compiled but not executed (for expensive operations) |
| **```compile_fail** | Must fail to compile (tests error messages) |
| **```should_panic** | Must panic (tests panic behavior) |
| **# hidden line** | Lines starting with `#` are hidden in docs but run in tests |

#### When to Use Doc Tests

**Use doc tests when:**

- + Providing usage examples in documentation
- + Ensuring examples stay up-to-date with code changes
- + Testing that public API is usable
- + Demonstrating error handling patterns

**Skip doc tests when:**

- - Testing complex setup/teardown
- - Testing private implementation details
- - You need parameterized tests
- - Examples would be too long for documentation

{{< callout type="info" >}}
**Key Insight:** Doc tests serve dual purposes—they're executable documentation and regression tests. When your API changes in a breaking way, doc tests will fail, forcing you to update examples.
{{< /callout >}}

---

## Part 2: Testing Crates

The Rust ecosystem provides specialized testing libraries for advanced scenarios.

### rstest: Fixtures and Parameterized Tests

**What it is:** A testing framework that adds fixtures, parameterized tests, and test case generation.

**Type:** Crate ([rstest](https://crates.io/crates/rstest))

#### Why rstest?

Standard Rust tests require duplicating setup code:

```rust
// Without rstest - repetitive
#[test]
fn test_parse_valid_json() {
    let input = r#"{"name": "Alice"}"#;
    let result = parse_json(input);
    assert!(result.is_ok());
}

#[test]
fn test_parse_invalid_json() {
    let input = r#"{"name": "Alice""#;  // Missing closing brace
    let result = parse_json(input);
    assert!(result.is_err());
}

#[test]
fn test_parse_empty_json() {
    let input = "{}";
    let result = parse_json(input);
    assert!(result.is_ok());
}
```

With rstest, you can parameterize:

```rust
use rstest::rstest;

#[rstest]
#[case(r#"{"name": "Alice"}"#, true)]
#[case(r#"{"name": "Alice""#, false)]  // Missing brace
#[case("{}", true)]
#[case("", false)]
#[case("null", true)]
fn test_parse_json(#[case] input: &str, #[case] should_succeed: bool) {
    let result = parse_json(input);
    assert_eq!(result.is_ok(), should_succeed);
}
```

#### Fixtures

```rust
use rstest::*;

#[fixture]
fn database() -> Database {
    Database::in_memory()
        .with_fixtures("test_data.sql")
        .build()
}

#[fixture]
fn sample_user() -> User {
    User {
        id: 1,
        name: "Alice".to_string(),
        email: "alice@example.com".to_string(),
    }
}

#[rstest]
fn test_user_creation(database: Database, sample_user: User) {
    let result = database.insert_user(&sample_user);
    assert!(result.is_ok());
    
    let retrieved = database.get_user(sample_user.id);
    assert_eq!(retrieved.unwrap(), sample_user);
}

#[rstest]
fn test_user_update(database: Database, mut sample_user: User) {
    database.insert_user(&sample_user).unwrap();
    
    sample_user.name = "Bob".to_string();
    database.update_user(&sample_user).unwrap();
    
    let updated = database.get_user(sample_user.id).unwrap();
    assert_eq!(updated.name, "Bob");
}
```

#### Parameterized Tests with Tables

```rust
use rstest::rstest;

#[rstest]
#[case(0, 0, 0)]
#[case(1, 1, 2)]
#[case(5, 5, 10)]
#[case(-1, 1, 0)]
#[case(100, -50, 50)]
fn test_add(#[case] a: i32, #[case] b: i32, #[case] expected: i32) {
    assert_eq!(add(a, b), expected);
}
```

Or with `#[values]` for combinations:

```rust
#[rstest]
fn test_user_validation(
    #[values("alice", "bob", "charlie")] name: &str,
    #[values("alice@example.com", "bob@test.org")] email: &str,
) {
    // This generates 3 × 2 = 6 test cases
    let user = User::new(name, email);
    assert!(user.validate().is_ok());
}
```

#### Async Tests

```rust
use rstest::rstest;

#[fixture]
async fn api_client() -> ApiClient {
    ApiClient::new("http://localhost:8080").await
}

#[rstest]
#[tokio::test]
async fn test_fetch_user(#[future] api_client: ApiClient) {
    let client = api_client.await;
    let user = client.get_user(1).await.unwrap();
    assert_eq!(user.id, 1);
}
```

#### When to Use rstest

**Use rstest when:**

- + Testing the same logic with different inputs
- + You need reusable test fixtures
- + Setting up complex test data
- + Testing combinations of parameters
- + You want readable, table-driven tests

**Skip rstest when:**

- - Standard `#[test]` is sufficient
- - You're testing randomized inputs (use proptest)
- - You want property-based testing


---

### proptest: Property-Based Testing

**What it is:** A framework for property-based testing—generating random inputs to find edge cases you didn't think of.

**Type:** Crate ([proptest](https://crates.io/crates/proptest))

#### Example-Based vs Property-Based Testing

**Example-based testing (standard):**

```rust
#[test]
fn test_sort() {
    assert_eq!(sort(vec![3, 1, 2]), vec![1, 2, 3]);
    assert_eq!(sort(vec![]), vec![]);
    assert_eq!(sort(vec![1]), vec![1]);
}
```

You test specific examples. But what about:
- Negative numbers?
- Very large numbers?
- Duplicate elements?
- Already sorted lists?

**Property-based testing:**

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_sort_properties(input in prop::collection::vec(any::<i32>(), 0..100)) {
        let sorted = sort(input.clone());
        
        // Property 1: Output length equals input length
        prop_assert_eq!(sorted.len(), input.len());
        
        // Property 2: Output is sorted
        for i in 1..sorted.len() {
            prop_assert!(sorted[i - 1] <= sorted[i]);
        }
        
        // Property 3: Output contains same elements as input
        let mut sorted_copy = sorted.clone();
        let mut input_copy = input.clone();
        sorted_copy.sort();
        input_copy.sort();
        prop_assert_eq!(sorted_copy, input_copy);
    }
}
```

proptest generates 100 random `Vec<i32>` inputs (default) and checks that your properties hold for all of them.

#### Shrinking: Finding Minimal Failing Cases

When a property test fails, proptest automatically "shrinks" the input to find the smallest example that still fails:

```rust
proptest! {
    #[test]
    fn test_buggy_function(x in 0..1000i32, y in 0..1000i32) {
        // Buggy: fails when x == 42 and y == 7
        prop_assert!(buggy_function(x, y));
    }
}
```

Output:
```
Test failed for (x = 42, y = 7)
minimal failing case: x = 42, y = 7
shrunk 15 times
```

Instead of showing you the random input that initially failed (say, `x = 842, y = 307`), proptest shrinks it down to the simplest case.

#### Common Property Patterns

**1. Roundtrip properties (serialize/deserialize):**

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn test_json_roundtrip(user in any::<User>()) {
        let json = serde_json::to_string(&user).unwrap();
        let decoded: User = serde_json::from_str(&json).unwrap();
        prop_assert_eq!(user, decoded);
    }
}
```

**2. Idempotence (applying twice = applying once):**

```rust
proptest! {
    #[test]
    fn test_normalize_idempotent(input in ".*") {
        let once = normalize(&input);
        let twice = normalize(&once);
        prop_assert_eq!(once, twice);
    }
}
```

**3. Inverse operations:**

```rust
proptest! {
    #[test]
    fn test_encode_decode_inverse(data in prop::collection::vec(any::<u8>(), 0..100)) {
        let encoded = base64_encode(&data);
        let decoded = base64_decode(&encoded).unwrap();
        prop_assert_eq!(data, decoded);
    }
}
```

**4. Invariants:**

```rust
proptest! {
    #[test]
    fn test_hashmap_invariants(
        ops in prop::collection::vec((any::<String>(), any::<i32>()), 0..100)
    ) {
        let mut map = HashMap::new();
        
        for (key, value) in ops {
            map.insert(key.clone(), value);
            
            // Invariant: inserted key must be retrievable
            prop_assert_eq!(map.get(&key), Some(&value));
        }
    }
}
```

#### Custom Generators

```rust
use proptest::prelude::*;

#[derive(Debug, Clone)]
struct Email(String);

fn valid_email() -> impl Strategy<Value = Email> {
    "[a-z]{3,10}@[a-z]{3,10}\\.(com|org|net)"
        .prop_map(Email)
}

proptest! {
    #[test]
    fn test_email_validation(email in valid_email()) {
        prop_assert!(validate_email(&email.0).is_ok());
    }
}
```

#### When to Use proptest

**Use proptest when:**

- + Testing parsers, serializers, encoders
- + Testing mathematical properties (commutativity, associativity)
- + Finding edge cases in algorithms
- + Testing invariants across operations
- + Verifying roundtrip properties

**Skip proptest when:**

- - Testing specific business rules (use example-based tests)
- - Properties are hard to express
- - Random inputs aren't meaningful (e.g., testing database migrations)

{{< callout type="success" >}}
**Best Practice:** Use property-based testing alongside example-based tests. Examples document expected behavior, properties catch unexpected edge cases.
{{< /callout >}}


---

### insta: Snapshot Testing

**What it is:** A testing framework that captures and compares output snapshots, making it easy to test complex outputs.

**Type:** Crate ([insta](https://crates.io/crates/insta))

#### The Snapshot Testing Workflow

{{< mermaid >}}
sequenceDiagram
    participant Developer
    participant Test
    participant Snapshot

    Note over Developer,Snapshot: First Run (No snapshot exists)
    Developer->>Test: cargo test
    Test->>Snapshot: Create new snapshot
    Test-->>Developer: Test passes

    Note over Developer,Snapshot: Code Change
    Developer->>Test: Modify output
    Developer->>Test: cargo test
    Test->>Snapshot: Compare with existing
    Test-->>Developer: Snapshot mismatch

    Developer->>Test: cargo insta review
    Note over Developer: Review diff in UI
    
    alt Accept Changes
        Developer->>Snapshot: Update snapshot
        Note over Snapshot: New snapshot saved
    else Reject Changes
        Developer->>Test: Fix code
    end

    style Developer fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style Test fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style Snapshot fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

#### Basic Snapshot Test

```rust
use insta::assert_snapshot;

#[test]
fn test_render_user_profile() {
    let user = User {
        id: 1,
        name: "Alice".to_string(),
        email: "alice@example.com".to_string(),
        bio: Some("Rust developer".to_string()),
    };
    
    let html = render_user_profile(&user);
    assert_snapshot!(html);
}
```

First run creates `snapshots/test_name.snap`:

```snap
---
source: tests/user_tests.rs
expression: html
---
<div class="profile">
  <h1>Alice</h1>
  <p>alice@example.com</p>
  <p class="bio">Rust developer</p>
</div>
```

Subsequent runs compare output against this snapshot. If the output changes, the test fails.

#### Reviewing Changes

When a snapshot test fails:

```bash
# Review all snapshot changes interactively
cargo insta review

# Accept all changes
cargo insta accept

# Reject all changes
cargo insta reject
```

The `cargo insta review` command opens an interactive UI showing:
- Old snapshot (left)
- New output (right)
- Diff highlighting changes

You can accept or reject each change individually.

#### Snapshot Types

**1. Basic snapshots:**

```rust
assert_snapshot!(output);
```

**2. Named snapshots:**

```rust
#[test]
fn test_multiple_scenarios() {
    assert_snapshot!("scenario_1", render_scenario_1());
    assert_snapshot!("scenario_2", render_scenario_2());
}
```

**3. Inline snapshots (in source code):**

```rust
#[test]
fn test_inline() {
    let result = format_number(1234567);
    insta::assert_snapshot!(result, @"1,234,567");
}
```

The expected value is stored inline—cargo insta updates the `@"..."` string when you accept changes.

**4. JSON snapshots:**

```rust
use insta::assert_json_snapshot;

#[test]
fn test_api_response() {
    let response = api_call();
    assert_json_snapshot!(response, {
        ".timestamp" => "[timestamp]",  // Redact dynamic fields
        ".request_id" => "[uuid]",
    });
}
```

**5. Debug snapshots:**

```rust
use insta::assert_debug_snapshot;

#[test]
fn test_complex_struct() {
    let data = build_complex_data();
    assert_debug_snapshot!(data);
}
```

Uses `Debug` formatting instead of `Display`.

#### Redacting Dynamic Values

```rust
use insta::assert_json_snapshot;
use serde_json::json;

#[test]
fn test_user_api() {
    let response = json!({
        "user": {
            "id": 123,
            "name": "Alice",
            "created_at": "2025-01-15T10:30:00Z",
            "session_token": "abc123xyz"
        }
    });
    
    assert_json_snapshot!(response, {
        ".user.created_at" => "[timestamp]",
        ".user.session_token" => "[token]",
    });
}
```

Snapshot:
```json
{
  "user": {
    "id": 123,
    "name": "Alice",
    "created_at": "[timestamp]",
    "session_token": "[token]"
  }
}
```

#### When to Use Snapshot Testing

**Use snapshot testing when:**

- + Testing complex outputs (HTML, JSON, formatted text)
- + Testing CLI output
- + Testing rendered templates
- + Testing API responses
- + Output structure is more important than exact values
- + You want to catch unintended output changes

**Skip snapshot testing when:**

- - Testing simple values (use `assert_eq!`)
- - Output is highly dynamic (timestamps, UUIDs)
- - You need precise value assertions
- - Output format changes frequently

{{< callout type="warning" >}}
**Important:** Snapshot tests are only as good as the reviews. Don't blindly accept all changes with `cargo insta accept`. Review diffs carefully—snapshot tests can hide regressions if you're not paying attention.
{{< /callout >}}

---

## Part 3: Test Strategies and Patterns

### The Testing Pyramid

{{< mermaid >}}
graph TB
    subgraph pyramid["Test Distribution"]
        direction TB
        e2e["End-to-End Tests<br/>───────<br/>Few, slow, expensive<br/>Test entire system"]
        integration["Integration Tests<br/>───────<br/>Moderate count, moderate speed<br/>Test module interactions"]
        unit["Unit Tests<br/>───────<br/>Many, fast, cheap<br/>Test individual functions"]
    end

    style e2e fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style integration fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style unit fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**Recommended distribution:**
- **70% unit tests** - Fast, focused, test business logic
- **20% integration tests** - Test module boundaries
- **10% end-to-end tests** - Test critical user flows

### Test Organization Patterns

#### Pattern 1: Inline Tests

```rust
// src/calculator.rs
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_add() {
        assert_eq!(add(2, 2), 4);
    }
}
```

**Use when:**
- Small modules
- Tests are simple
- You want tests close to code

#### Pattern 2: Separate Test Modules

```rust
// src/calculator.rs
pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

// src/calculator/tests.rs
#[cfg(test)]
use super::*;

#[test]
fn test_add() {
    assert_eq!(add(2, 2), 4);
}

#[test]
fn test_add_negative() {
    assert_eq!(add(-1, 1), 0);
}

// ... many more tests
```

```rust
// src/calculator.rs
mod calculator;
#[cfg(test)]
mod tests;
```

**Use when:**
- Many tests
- Complex test setup
- Want to separate test code visually

#### Pattern 3: Integration Test Suites

```
tests/
├── common/
│   └── mod.rs           # Shared utilities
├── api_tests.rs         # API endpoint tests
├── database_tests.rs    # Database integration
└── auth_tests.rs        # Authentication flows
```

**Use when:**
- Testing public API
- Testing multiple modules together
- Need separate compilation units

### Test-Driven Development (TDD) in Rust

{{< mermaid >}}
flowchart LR
    red[Write Failing Test<br/>───────<br/>Red]
    green[Make Test Pass<br/>───────<br/>Green]
    refactor[Improve Code<br/>───────<br/>Refactor]

    red --> green
    green --> refactor
    refactor --> red

    style red fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style green fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style refactor fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

**Example TDD session:**

```rust
// Step 1: Write failing test (RED)
#[test]
fn test_user_registration() {
    let result = register_user("alice", "alice@example.com");
    assert!(result.is_ok());
}
// Error: function `register_user` not found

// Step 2: Make it compile and pass (GREEN)
pub fn register_user(name: &str, email: &str) -> Result<User, String> {
    Ok(User {
        name: name.to_string(),
        email: email.to_string(),
    })
}
// Test passes

// Step 3: Add validation test (RED)
#[test]
fn test_invalid_email() {
    let result = register_user("alice", "not-an-email");
    assert!(result.is_err());
}
// Test fails - no validation

// Step 4: Add validation (GREEN)
pub fn register_user(name: &str, email: &str) -> Result<User, String> {
    if !email.contains('@') {
        return Err("Invalid email".to_string());
    }
    
    Ok(User {
        name: name.to_string(),
        email: email.to_string(),
    })
}
// Tests pass

// Step 5: Refactor (REFACTOR)
pub fn register_user(name: &str, email: &str) -> Result<User, String> {
    validate_email(email)?;
    
    Ok(User {
        name: name.to_string(),
        email: email.to_string(),
    })
}

fn validate_email(email: &str) -> Result<(), String> {
    if !email.contains('@') {
        return Err("Invalid email".to_string());
    }
    Ok(())
}
// Tests still pass, code is cleaner
```

### Mocking and Test Doubles

Rust doesn't have built-in mocking, but you can use traits for dependency injection:

```rust
// Production code
pub trait EmailService {
    fn send(&self, to: &str, subject: &str, body: &str) -> Result<(), String>;
}

pub struct SmtpEmailService {
    host: String,
}

impl EmailService for SmtpEmailService {
    fn send(&self, to: &str, subject: &str, body: &str) -> Result<(), String> {
        // Real SMTP implementation
        Ok(())
    }
}

pub struct UserService<E: EmailService> {
    email_service: E,
}

impl<E: EmailService> UserService<E> {
    pub fn register_user(&self, email: &str) -> Result<(), String> {
        // Business logic
        self.email_service.send(
            email,
            "Welcome",
            "Thanks for registering"
        )
    }
}
```

```rust
// Test code
#[cfg(test)]
mod tests {
    use super::*;

    struct MockEmailService {
        emails_sent: std::cell::RefCell<Vec<String>>,
    }

    impl MockEmailService {
        fn new() -> Self {
            Self {
                emails_sent: std::cell::RefCell::new(Vec::new()),
            }
        }

        fn emails_sent(&self) -> Vec<String> {
            self.emails_sent.borrow().clone()
        }
    }

    impl EmailService for MockEmailService {
        fn send(&self, to: &str, _subject: &str, _body: &str) -> Result<(), String> {
            self.emails_sent.borrow_mut().push(to.to_string());
            Ok(())
        }
    }

    #[test]
    fn test_user_registration_sends_email() {
        let email_service = MockEmailService::new();
        let user_service = UserService {
            email_service: &email_service,
        };

        user_service.register_user("alice@example.com").unwrap();

        assert_eq!(email_service.emails_sent(), vec!["alice@example.com"]);
    }
}
```

Alternatively, use the [mockall](https://crates.io/crates/mockall) crate for automatic mock generation:

```rust
use mockall::{automock, predicate::*};

#[automock]
pub trait EmailService {
    fn send(&self, to: &str, subject: &str, body: &str) -> Result<(), String>;
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_with_mockall() {
        let mut mock = MockEmailService::new();
        
        mock.expect_send()
            .with(eq("alice@example.com"), eq("Welcome"), always())
            .times(1)
            .returning(|_, _, _| Ok(()));

        let user_service = UserService {
            email_service: mock,
        };

        user_service.register_user("alice@example.com").unwrap();
    }
}
```

---

## Part 4: Decision Framework

### Choosing the Right Test Type

{{< mermaid >}}
flowchart TD
    start[What are you testing?]

    start --> scope{Scope?}

    scope -->|Single function| pure{Pure function?}
    scope -->|Multiple modules| integration[Integration Test]
    scope -->|Entire system| e2e[End-to-End Test]

    pure -->|Yes| unit[Unit Test]
    pure -->|No, has dependencies| mock[Unit Test + Mocks]

    unit --> inputs{Input space?}
    
    inputs -->|Specific examples| standard["Standard test"]
    inputs -->|Many similar cases| rstest[rstest]
    inputs -->|Random/properties| proptest[proptest]

    standard --> output{Output type?}
    rstest --> output
    proptest --> output

    output -->|Simple value| assert["assert_eq!"]
    output -->|Complex structure| snapshot[insta snapshot]
    output -->|Documentation| doctest[Doc test]

    style unit fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style integration fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style proptest fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style snapshot fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### Testing Strategy by Component Type

| Component Type | Recommended Approach |
|----------------|---------------------|
| **Pure functions** | Unit tests, proptest for properties |
| **Parsers** | Unit tests + proptest roundtrips + snapshot tests |
| **API endpoints** | Integration tests + snapshot tests for responses |
| **Database queries** | Integration tests with test database |
| **Business logic** | Unit tests (TDD), rstest for scenarios |
| **CLI tools** | Integration tests + snapshot tests for output |
| **Libraries (public API)** | Doc tests + integration tests |

### Test Coverage Guidelines

```bash
# Install cargo-tarpaulin for coverage
cargo install cargo-tarpaulin

# Generate coverage report
cargo tarpaulin --out Html
```

**Coverage targets:**
- **Critical paths**: 90%+ coverage
- **Business logic**: 80%+ coverage
- **Utility functions**: 70%+ coverage
- **Infrastructure code**: 50%+ coverage (often hard to unit test)

{{< callout type="warning" >}}
**Important:** 100% coverage doesn't mean bug-free code. Coverage measures **lines executed**, not **behaviors tested**. A function with 100% coverage can still have logical errors if your test cases don't cover edge cases.
{{< /callout >}}

---

## Part 5: Real-World Testing Patterns

### Testing Async Code

```rust
#[tokio::test]
async fn test_async_function() {
    let result = fetch_user(1).await;
    assert!(result.is_ok());
}

#[tokio::test(flavor = "multi_thread", worker_threads = 2)]
async fn test_concurrent_requests() {
    let (r1, r2) = tokio::join!(
        fetch_user(1),
        fetch_user(2)
    );
    assert!(r1.is_ok() && r2.is_ok());
}
```

### Testing Error Cases

```rust
#[test]
fn test_error_scenarios() {
    // Test specific error types
    let err = parse_date("invalid").unwrap_err();
    assert!(matches!(err, ParseError::InvalidFormat));

    // Test error messages
    let err = divide(10, 0).unwrap_err();
    assert_eq!(err.to_string(), "division by zero");

    // Test error conversions
    let io_error = std::io::Error::new(std::io::ErrorKind::NotFound, "file not found");
    let app_error: AppError = io_error.into();
    assert!(matches!(app_error, AppError::FileNotFound(_)));
}
```

### Testing Database Code

```rust
use sqlx::SqlitePool;

#[sqlx::test]
async fn test_create_user(pool: SqlitePool) -> sqlx::Result<()> {
    let user_id = create_user(&pool, "alice", "alice@example.com").await?;
    
    let user = sqlx::query!("SELECT * FROM users WHERE id = ?", user_id)
        .fetch_one(&pool)
        .await?;
    
    assert_eq!(user.name, "alice");
    assert_eq!(user.email, "alice@example.com");
    
    Ok(())
}
```

The `#[sqlx::test]` macro automatically:
- Creates a fresh database for each test
- Runs migrations
- Cleans up after the test

### Testing Web APIs (Axum Example)

```rust
use axum_test::TestServer;

#[tokio::test]
async fn test_create_user_endpoint() {
    let app = create_app();
    let server = TestServer::new(app).unwrap();

    let response = server
        .post("/users")
        .json(&serde_json::json!({
            "name": "Alice",
            "email": "alice@example.com"
        }))
        .await;

    assert_eq!(response.status_code(), 201);
    
    let user: User = response.json();
    assert_eq!(user.name, "Alice");
}

#[tokio::test]
async fn test_validation_errors() {
    let app = create_app();
    let server = TestServer::new(app).unwrap();

    let response = server
        .post("/users")
        .json(&serde_json::json!({
            "name": "",  // Invalid: empty name
            "email": "not-an-email"  // Invalid: bad email
        }))
        .await;

    assert_eq!(response.status_code(), 400);
    
    let error: ErrorResponse = response.json();
    assert_eq!(error.code, "VALIDATION_FAILED");
}
```

### Benchmarking (Criterion)

```rust
use criterion::{black_box, criterion_group, criterion_main, Criterion};

fn fibonacci(n: u64) -> u64 {
    match n {
        0 => 0,
        1 => 1,
        n => fibonacci(n - 1) + fibonacci(n - 2),
    }
}

fn criterion_benchmark(c: &mut Criterion) {
    c.bench_function("fib 20", |b| b.iter(|| fibonacci(black_box(20))));
}

criterion_group!(benches, criterion_benchmark);
criterion_main!(benches);
```

Run with:
```bash
cargo bench
```

---

## Part 6: Best Practices and Common Pitfalls

### Do's

**1. Test behavior, not implementation:**

```rust
// Bad: testing implementation details
#[test]
fn test_internal_state() {
    let calc = Calculator::new();
    assert_eq!(calc.internal_buffer, vec![]);  // Testing private field
}

// Good: testing behavior
#[test]
fn test_calculation_result() {
    let calc = Calculator::new();
    assert_eq!(calc.add(2).result(), 2);
}
```

**2. Use descriptive test names:**

```rust
// Bad
#[test]
fn test1() { ... }

// Good
#[test]
fn test_divide_by_zero_returns_error() { ... }
```

**3. Follow Arrange-Act-Assert pattern:**

```rust
#[test]
fn test_user_registration() {
    // Arrange
    let email = "alice@example.com";
    let name = "Alice";
    
    // Act
    let result = register_user(name, email);
    
    // Assert
    assert!(result.is_ok());
    let user = result.unwrap();
    assert_eq!(user.email, email);
}
```

**4. Test edge cases:**

```rust
#[rstest]
#[case(vec![], vec![])]  // Empty input
#[case(vec![1], vec![1])]  // Single element
#[case(vec![1, 1, 1], vec![1, 1, 1])]  // Duplicates
#[case(vec![3, 2, 1], vec![1, 2, 3])]  // Reverse sorted
fn test_sort_edge_cases(#[case] input: Vec<i32>, #[case] expected: Vec<i32>) {
    assert_eq!(sort(input), expected);
}
```

### Don'ts

**1. Don't test the standard library:**

```rust
// Bad: testing Vec behavior
#[test]
fn test_vec_push() {
    let mut v = vec![];
    v.push(1);
    assert_eq!(v.len(), 1);  // This is testing Vec, not your code
}
```

**2. Don't write flaky tests:**

```rust
// Bad: depends on timing
#[tokio::test]
async fn test_cache_expiration() {
    cache.set("key", "value", Duration::from_millis(100));
    tokio::time::sleep(Duration::from_millis(50)).await;
    assert!(cache.get("key").is_some());  // Might fail if system is slow
}

// Good: use test utilities
#[tokio::test]
async fn test_cache_expiration() {
    let mut time = MockTime::new();
    let cache = Cache::new(time.clone());
    
    cache.set("key", "value", Duration::from_secs(10));
    time.advance(Duration::from_secs(5));
    assert!(cache.get("key").is_some());
    
    time.advance(Duration::from_secs(10));
    assert!(cache.get("key").is_none());
}
```

**3. Don't ignore failing tests:**

```rust
// Bad: sweeping problems under the rug
#[test]
#[ignore]  // "I'll fix this later"
fn test_broken_feature() {
    assert_eq!(buggy_function(), expected);
}
```

**4. Don't test everything in integration tests:**

```rust
// Bad: testing business logic in integration tests
// tests/api_test.rs
#[test]
fn test_complex_calculation_edge_cases() {
    // 100 lines of calculation edge cases
    // These should be unit tests!
}

// Good: integration tests focus on integration
#[test]
fn test_api_endpoint_returns_calculation() {
    let response = api_call("/calculate?a=2&b=2");
    assert_eq!(response.status(), 200);
    assert!(response.body().contains("result"));
}
```

---

## Comparison Table

| Approach | Speed | Scope | Use Case | Crate |
|----------|-------|-------|----------|-------|
| **Unit Tests** | Very fast | Single function | Business logic, algorithms | Built-in |
| **Integration Tests** | Moderate | Multiple modules | Public API, workflows | Built-in |
| **Doc Tests** | Moderate | Documentation | Usage examples | Built-in |
| **rstest** | Fast | Parameterized | Table-driven tests, fixtures | rstest |
| **proptest** | Slow | Property-based | Finding edge cases, invariants | proptest |
| **insta** | Fast | Snapshot | Complex outputs, regression | insta |
| **E2E Tests** | Very slow | Entire system | Critical user flows | Custom |

---

## Conclusion

Rust testing isn't one-size-fits-all. The right approach depends on what you're testing:

**Quick Reference:**

**Need to test business logic?**
→ **Unit tests** with `#[test]`

**Testing the same logic with different inputs?**
→ **rstest** for parameterized tests

**Need to find edge cases you didn't think of?**
→ **proptest** for property-based testing

**Testing complex output (HTML, JSON, formatted text)?**
→ **insta** for snapshot testing

**Testing how modules work together?**
→ **Integration tests** in `tests/`

**Providing documentation examples?**
→ **Doc tests** in `/// ` comments

**Testing critical user workflows?**
→ **End-to-end tests** (custom framework)

### Key Takeaways

1. **Start with unit tests** - They're fast, focused, and catch bugs early

2. **Use multiple testing strategies** - Unit tests for logic, integration tests for APIs, proptest for edge cases, snapshots for complex outputs

3. **Test behavior, not implementation** - Tests should validate what your code does, not how it does it

4. **Write tests first (TDD)** - For complex logic, writing tests first guides better design

5. **Don't aim for 100% coverage** - Aim for 100% of critical paths and meaningful scenarios

6. **Review snapshot changes carefully** - Snapshot tests can hide regressions if you blindly accept changes

7. **Properties reveal assumptions** - If you can't express your code as properties, it might be too complex

The best Rust projects use all of these approaches together. Unit tests form the foundation, integration tests verify module boundaries, property-based tests catch edge cases, and snapshot tests catch output regressions.

---

**Further Reading:**

- [Rust Book: Testing](https://doc.rust-lang.org/book/ch11-00-testing.html)
- [rstest documentation](https://docs.rs/rstest/)
- [proptest book](https://altsysrq.github.io/proptest-book/)
- [insta documentation](https://docs.rs/insta/)
- [Test organization patterns](https://matklad.github.io/2021/02/27/delete-cargo-integration-tests.html)

---

*Have questions or suggestions? Found an error? [Open an issue on GitHub](https://github.com/blackwell-systems/blog/issues) or connect on [Twitter/X](https://twitter.com/blackwellsystems).*
