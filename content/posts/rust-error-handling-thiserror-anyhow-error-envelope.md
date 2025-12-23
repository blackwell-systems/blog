---
title: "Rust Error Handling: thiserror, anyhow, and error-envelope"
date: 2025-12-23
draft: false
tags: ["rust", "error-handling", "thiserror", "anyhow", "error-envelope", "api-design", "web-development", "axum", "rest-api", "http", "architecture", "best-practices", "library-design", "application-development", "type-safety", "debugging", "observability", "ergonomics", "rust-crates", "web-frameworks"]
categories: ["rust", "tutorials", "architecture"]
description: "Understand when to use thiserror, anyhow, and error-envelope in Rust. Learn how these three crates work together to handle errors across application layers, from typed domain logic to HTTP responses."
summary: "Three Rust error handling crates that seem to overlap but fill distinct roles. Learn when to use thiserror for typed errors, anyhow for application code, and error-envelope for HTTP boundaries."
---

Your Rust API has three layers of error handling. Each layer uses a different crate. Your team asks why you need all three.

Here's how `thiserror`, `anyhow`, and `error-envelope` work together to handle errors across application layers--and when you might skip one.

## The Question

"Do we really need thiserror, anyhow, *and* error-envelope? Aren't they all just error handling?"

Yes, they're all error handling. But they solve different problems at different boundaries in your application:

- **`thiserror`** - Defines typed errors in domain logic
- **`anyhow`** - Propagates errors through application code
- **`error-envelope`** - Converts errors to structured HTTP responses

Each layer has different requirements. Understanding these requirements explains why you might use all three--or skip some.

## The Three Layers

{{< mermaid >}}
flowchart TB
    subgraph domain["Domain Layer (Business Logic)"]
        domain_code["Domain Code<br/>───────────<br/>• Define error types<br/>• Pattern matching<br/>• Type-safe errors<br/>• Testing"]
        domain_lib["thiserror"]
    end

    subgraph app["Application Layer (Handlers/Services)"]
        app_code["Application Code<br/>───────────<br/>• Error propagation<br/>• Context chaining<br/>• Flexible handling<br/>• Error conversion"]
        app_lib["anyhow"]
    end

    subgraph http["HTTP Boundary (API Responses)"]
        http_code["HTTP Responses<br/>───────────<br/>• Structured JSON<br/>• Status codes<br/>• Trace IDs<br/>• Client contracts"]
        http_lib["error-envelope"]
    end

    domain_code --> app_code
    app_code --> http_code
    domain_lib -.->|"used by"| domain_code
    app_lib -.->|"used by"| app_code
    http_lib -.->|"used by"| http_code

    style domain fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style app fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style http fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

Each layer has different error handling needs. Let's examine each crate through this lens.

---

## Layer 1: thiserror (Typed Domain Errors)

**Purpose:** Define structured, typed errors in your domain logic.

**Use when:** You want to model specific error cases with pattern matching and exhaustive checking.

### What Problem Does It Solve?

In domain logic, you need to distinguish between different error types. A payment processing module might fail for different reasons:

- Insufficient funds
- Invalid card
- Network timeout
- Fraud detected

Each case requires different handling. Generic error types like `String` or `Box<dyn Error>` lose this information.

### Example: Payment Module

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum PaymentError {
    #[error("Insufficient funds: need ${required}, have ${available}")]
    InsufficientFunds { required: f64, available: f64 },

    #[error("Invalid card number: {0}")]
    InvalidCard(String),

    #[error("Payment gateway timeout after {0}s")]
    Timeout(u64),

    #[error("Fraud detected: {reason}")]
    FraudDetected { reason: String },

    #[error("Database error")]
    Database(#[from] sqlx::Error),
}

pub fn process_payment(amount: f64, card: &str) -> Result<Receipt, PaymentError> {
    if amount > get_balance()? {
        return Err(PaymentError::InsufficientFunds {
            required: amount,
            available: get_balance()?,
        });
    }

    if !validate_card(card) {
        return Err(PaymentError::InvalidCard(card.to_string()));
    }

    // ... payment logic
    Ok(Receipt { /* ... */ })
}
```

### What You Get

**1. Pattern matching:**
```rust
match process_payment(100.0, card) {
    Ok(receipt) => println!("Paid: {}", receipt.id),
    Err(PaymentError::InsufficientFunds { required, available }) => {
        println!("Need ${} more", required - available);
    }
    Err(PaymentError::InvalidCard(number)) => {
        println!("Card {} is invalid", number);
    }
    Err(PaymentError::Timeout(duration)) => {
        println!("Timeout after {}s, please retry", duration);
    }
    Err(e) => println!("Payment failed: {}", e),
}
```

**2. Automatic `From` conversions:**
```rust
// The #[from] attribute generates:
impl From<sqlx::Error> for PaymentError {
    fn from(err: sqlx::Error) -> Self {
        PaymentError::Database(err)
    }
}

// Now you can use ? with sqlx::Error
fn get_balance() -> Result<f64, PaymentError> {
    let row = sqlx::query("SELECT balance FROM accounts")
        .fetch_one(&pool)
        .await?; // Automatically converts sqlx::Error to PaymentError
    Ok(row.get("balance"))
}
```

**3. Automatic `Display` implementation:**
```rust
// The #[error("...")] attribute generates Display
println!("{}", PaymentError::Timeout(30));
// Output: "Payment gateway timeout after 30s"
```

**4. Automatic `Error` trait:**
```rust
// thiserror implements std::error::Error for you
fn log_error(err: &dyn std::error::Error) {
    eprintln!("Error: {}", err);
}

log_error(&PaymentError::InvalidCard("1234".into()));
```

### When NOT to Use thiserror

- **One-off errors:** If you only return errors from a few functions and don't need pattern matching, `Result<T, String>` is simpler.
- **Generic error propagation:** In application glue code where you just want to bubble errors up, `anyhow` is more ergonomic.
- **HTTP responses:** thiserror errors need conversion to HTTP formats--that's where `error-envelope` comes in.

{{< callout type="info" >}}
**Key Insight:** `thiserror` is about **defining error types**, not handling them. It generates boilerplate (`Display`, `Error` trait, `From` conversions) so you can focus on modeling your domain's failure modes.
{{< /callout >}}

---

## Layer 2: anyhow (Flexible Error Propagation)

**Purpose:** Ergonomically propagate and enrich errors through application code.

**Use when:** You want to bubble up errors with context without writing `From` impls for every type combination.

### What Problem Does It Solve?

In application code (HTTP handlers, service layers, orchestration), you call functions from different modules that return different error types:

```rust
// Without anyhow, you need explicit conversions
fn handle_checkout(order_id: &str) -> Result<(), CheckoutError> {
    let order = fetch_order(order_id)
        .map_err(|e| CheckoutError::Database(e))?; // Manual conversion

    let payment = process_payment(order.amount, &order.card)
        .map_err(|e| CheckoutError::Payment(e))?; // Manual conversion

    let shipment = create_shipment(&order)
        .map_err(|e| CheckoutError::Shipment(e))?; // Manual conversion

    Ok(())
}
```

Every error type needs explicit conversion. Every new dependency requires a new enum variant and `From` impl.

### Example: Application Handler

```rust
use anyhow::{Context, Result};

async fn handle_checkout(order_id: &str) -> Result<CheckoutResponse> {
    // Just use ? - anyhow handles conversion automatically
    let order = fetch_order(order_id)
        .await
        .context(format!("Failed to fetch order {}", order_id))?;

    let payment = process_payment(order.amount, &order.card)
        .await
        .context("Payment processing failed")?;

    let shipment = create_shipment(&order)
        .await
        .context("Shipment creation failed")?;

    Ok(CheckoutResponse { /* ... */ })
}
```

No manual error conversions. No enum variants for every possible error type. Just add context and propagate with `?`.

### What You Get

**1. Automatic error conversion:**
```rust
// anyhow::Error accepts any type that implements std::error::Error
fn process_user(id: u64) -> anyhow::Result<User> {
    let db_row = sqlx::query("SELECT * FROM users WHERE id = ?")
        .bind(id)
        .fetch_one(&pool)
        .await?; // sqlx::Error → anyhow::Error (automatic)

    let user: User = serde_json::from_str(&db_row.data)?; // serde_json::Error → anyhow::Error (automatic)

    Ok(user)
}
```

**2. Context chaining:**
```rust
use anyhow::Context;

fn load_config() -> anyhow::Result<Config> {
    let path = "config.toml";
    let contents = std::fs::read_to_string(path)
        .context(format!("Failed to read config file: {}", path))?;

    let config: Config = toml::from_str(&contents)
        .context("Failed to parse TOML")?;

    Ok(config)
}

// Error output shows the full chain:
// Error: Failed to read config file: config.toml
//
// Caused by:
//     No such file or directory (os error 2)
```

**3. Convenient error creation:**
```rust
use anyhow::{anyhow, bail};

fn validate_email(email: &str) -> anyhow::Result<()> {
    if !email.contains('@') {
        bail!("Invalid email: {}", email);
    }
    Ok(())
}

fn authenticate(token: &str) -> anyhow::Result<User> {
    if token.is_empty() {
        return Err(anyhow!("Missing authentication token"));
    }
    // ... auth logic
}
```

**4. Downcasting for specific handling:**
```rust
match result {
    Err(e) if e.downcast_ref::<PaymentError>().is_some() => {
        let payment_err = e.downcast_ref::<PaymentError>().unwrap();
        match payment_err {
            PaymentError::InsufficientFunds { .. } => {
                // Handle specifically
            }
            _ => {}
        }
    }
    Err(e) => eprintln!("Other error: {}", e),
    Ok(_) => {}
}
```

### When NOT to Use anyhow

- **Libraries:** Library crates should use typed errors (`thiserror`) so users can match on specific cases. `anyhow::Error` is opaque--users can't pattern match on it.
- **When you need exhaustive matching:** If you need to handle every error case differently, use `thiserror` enums.
- **HTTP responses:** `anyhow::Error` gives you strings, not structured HTTP responses with status codes and trace IDs.

{{< callout type="warning" >}}
**Important:** `anyhow` is for **application code**, not **library code**. Libraries should expose typed errors (via `thiserror`) so users can handle specific cases. Applications can use `anyhow` internally because they're the final consumer of errors.
{{< /callout >}}

---

## Layer 3: error-envelope (HTTP Responses)

**Purpose:** Convert errors into consistent, structured HTTP responses.

**Use when:** You need to return errors from HTTP endpoints in a machine-readable format with status codes, trace IDs, and retry signals.

### What Problem Does It Solve?

HTTP clients need:
- **Stable codes:** Machine-readable identifiers (`VALIDATION_FAILED`, not "validation failed")
- **Status codes:** Correct HTTP status (400, 404, 500, etc.)
- **Structured details:** Field-level validation errors, not just strings
- **Trace IDs:** Request correlation for debugging
- **Retry hints:** Should the client retry this error?

`thiserror` and `anyhow` don't provide any of this. They give you error *messages*, not HTTP *responses*.

### Example: Axum Handler

```rust
use axum::{Json, extract::Path};
use error_envelope::Error;

async fn get_user(
    Path(user_id): Path<u64>
) -> Result<Json<User>, Error> {
    // Application layer returns anyhow::Error
    let user = fetch_user(user_id).await?; // anyhow::Error → Error (via From)

    Ok(Json(user))
}

async fn fetch_user(id: u64) -> anyhow::Result<User> {
    let row = sqlx::query("SELECT * FROM users WHERE id = ?")
        .bind(id)
        .fetch_optional(&pool)
        .await
        .context("Database query failed")?;

    match row {
        Some(row) => Ok(row.into()),
        None => Err(anyhow!("User not found")),
    }
}
```

With `error-envelope`'s `anyhow-support` feature enabled, `anyhow::Error` automatically converts to `error_envelope::Error`. When returned from the handler, Axum's `IntoResponse` converts it to:

```json
{
  "code": "INTERNAL",
  "message": "User not found",
  "status": 500,
  "trace_id": "req-abc123",
  "retryable": false
}
```

### Custom Error Mapping

For more control, wrap errors with domain-specific logic:

```rust
use error_envelope::{Error, Code};

async fn get_user(
    Path(user_id): Path<u64>
) -> Result<Json<User>, Error> {
    let user = fetch_user(user_id)
        .await
        .map_err(|e| map_to_http(e, request_id()))?;

    Ok(Json(user))
}

fn map_to_http(err: anyhow::Error, trace_id: String) -> Error {
    let err_str = err.to_string().to_lowercase();

    if err_str.contains("not found") {
        return Error::not_found("User not found")
            .with_trace_id(trace_id)
            .with_retryable(false);
    }

    if err_str.contains("timeout") {
        return Error::timeout("Database timeout")
            .with_trace_id(trace_id)
            .with_retryable(true);
    }

    // Default: Use From<anyhow::Error> trait
    Error::from(err).with_trace_id(trace_id)
}
```

### What You Get

**1. Structured JSON errors:**
```json
{
  "code": "NOT_FOUND",
  "message": "User not found",
  "status": 404,
  "trace_id": "req-abc123",
  "retryable": false
}
```

**2. Field-level validation:**
```rust
use error_envelope::Error;
use validator::Validate;

#[derive(Validate)]
struct CreateUser {
    #[validate(email)]
    email: String,
    #[validate(length(min = 8))]
    password: String,
}

async fn create_user(
    Json(payload): Json<CreateUser>
) -> Result<Json<User>, Error> {
    if let Err(validation_errors) = payload.validate() {
        let mut field_errors = std::collections::HashMap::new();
        for (field, errors) in validation_errors.field_errors() {
            field_errors.insert(
                field.to_string(),
                errors[0].message.as_ref().unwrap().to_string()
            );
        }
        return Err(Error::validation(field_errors));
    }

    // ... create user
}
```

Response:
```json
{
  "code": "VALIDATION_FAILED",
  "message": "Validation failed",
  "details": {
    "fields": {
      "email": "Invalid email format",
      "password": "Must be at least 8 characters"
    }
  },
  "status": 400,
  "retryable": false
}
```

**3. Automatic trace ID propagation:**
```rust
use axum::middleware;

let app = Router::new()
    .route("/users/:id", get(get_user))
    .layer(middleware::from_fn(trace_middleware));

// Middleware extracts or generates trace IDs
async fn trace_middleware(
    req: Request,
    next: Next,
) -> Response {
    let trace_id = req
        .headers()
        .get("X-Request-ID")
        .and_then(|v| v.to_str().ok())
        .unwrap_or_else(|| Uuid::new_v4().to_string());

    // Store in request extensions
    req.extensions_mut().insert(TraceId(trace_id.clone()));

    let mut response = next.run(req).await;
    response.headers_mut().insert(
        "X-Request-ID",
        trace_id.parse().unwrap()
    );
    response
}
```

**4. Retry signals:**
```rust
// Client can check retryable flag
if error.retryable {
    // Retry with exponential backoff
} else {
    // Show error to user, don't retry
}
```

### When NOT to Use error-envelope

- **Non-HTTP services:** If you're not building HTTP APIs, you don't need HTTP-specific error formatting.
- **Already standardized on RFC 9457 Problem Details:** Don't switch formats mid-project. The two can coexist with adapters if needed.
- **CLI tools:** Command-line tools typically log errors to stderr, not return JSON.

{{< callout type="success" >}}
**Best Practice:** Use `error-envelope` at the **HTTP boundary only**. Internal application code can use `anyhow`, domain logic can use `thiserror`. At the handler layer, convert everything to `error_envelope::Error` for consistent client responses.
{{< /callout >}}

---

## How They Work Together

Here's a complete example showing all three crates in a real Axum API:

### Domain Layer (thiserror)

```rust
// src/domain/payment.rs
use thiserror::Error;

#[derive(Error, Debug)]
pub enum PaymentError {
    #[error("Insufficient funds: need ${required}, have ${available}")]
    InsufficientFunds { required: f64, available: f64 },

    #[error("Invalid card: {0}")]
    InvalidCard(String),

    #[error("Payment timeout")]
    Timeout,

    #[error("Database error")]
    Database(#[from] sqlx::Error),
}

pub fn validate_payment(amount: f64, card: &str) -> Result<(), PaymentError> {
    if amount <= 0.0 {
        return Err(PaymentError::InvalidCard("Amount must be positive".into()));
    }
    // ... validation logic
    Ok(())
}
```

### Application Layer (anyhow)

```rust
// src/services/checkout.rs
use anyhow::{Context, Result};

pub async fn process_checkout(order_id: u64) -> Result<Receipt> {
    // Fetch order from database
    let order = fetch_order(order_id)
        .await
        .context(format!("Failed to fetch order {}", order_id))?;

    // Validate payment (returns PaymentError, converts to anyhow::Error)
    validate_payment(order.amount, &order.card)
        .context("Payment validation failed")?;

    // Process payment
    let payment = charge_card(order.amount, &order.card)
        .await
        .context("Card charge failed")?;

    // Create shipment
    let shipment = create_shipment(&order)
        .await
        .context("Shipment creation failed")?;

    Ok(Receipt {
        order_id,
        payment_id: payment.id,
        shipment_id: shipment.id,
    })
}
```

### HTTP Layer (error-envelope)

```rust
// src/handlers/checkout.rs
use axum::{Json, extract::Path};
use error_envelope::Error;

pub async fn checkout_handler(
    Path(order_id): Path<u64>
) -> Result<Json<Receipt>, Error> {
    // Call application layer (returns anyhow::Result)
    let receipt = process_checkout(order_id)
        .await
        .map_err(|e| map_checkout_error(e))?;

    Ok(Json(receipt))
}

fn map_checkout_error(err: anyhow::Error) -> Error {
    let err_str = err.to_string().to_lowercase();
    let trace_id = uuid::Uuid::new_v4().to_string();

    // Map domain errors to HTTP responses
    if err_str.contains("insufficient funds") {
        return Error::new(
            error_envelope::Code::UnprocessableEntity,
            402,
            "Payment failed due to insufficient funds"
        )
        .with_trace_id(trace_id)
        .with_retryable(false);
    }

    if err_str.contains("invalid card") {
        return Error::bad_request("Invalid payment information")
            .with_trace_id(trace_id)
            .with_retryable(false);
    }

    if err_str.contains("timeout") {
        return Error::timeout("Payment processing timed out")
            .with_trace_id(trace_id)
            .with_retryable(true);
    }

    // Default: internal error
    Error::from(err).with_trace_id(trace_id)
}
```

### Complete Flow

{{< mermaid >}}
sequenceDiagram
    participant Client
    participant Handler as HTTP Handler
    participant Service as Service Layer
    participant Domain as Domain Logic

    Note over Handler: error-envelope
    Note over Service: anyhow
    Note over Domain: thiserror

    Client->>Handler: POST /checkout/123
    Handler->>Service: process_checkout(123)
    Service->>Domain: validate_payment(100.0, card)
    
    alt Domain Error
        Domain-->>Service: PaymentError::InsufficientFunds
        Service-->>Handler: anyhow::Error (with context)
        Handler->>Handler: map_checkout_error()
        Handler-->>Client: JSON error response
    else Success
        Domain-->>Service: Ok(())
        Service->>Service: charge_card()
        Service-->>Handler: Ok(Receipt)
        Handler-->>Client: JSON success
    end
{{< /mermaid >}}

**Error flow breakdown:**

1. **Domain layer** (`thiserror`) detects insufficient funds → returns typed `PaymentError::InsufficientFunds`
2. **Service layer** (`anyhow`) adds context → converts to `anyhow::Error` with "Payment validation failed" message
3. **HTTP handler** (`error-envelope`) maps error to HTTP response → returns structured JSON with `402 Payment Required` status

Each layer adds value without duplicating work.

---

## Decision Framework: When to Use Each

### Use thiserror When:

+ You're writing a **library** that others will depend on
+ You need **pattern matching** on error types
+ You want **exhaustive error handling** (compiler checks all cases)
+ You have **domain-specific errors** with clear variants
+ You need to **convert between error types** frequently

### Use anyhow When:

+ You're writing **application code** (not a library)
+ You want **ergonomic error propagation** with `?`
+ You need to **add context** to errors as they bubble up
+ You're **orchestrating** calls to multiple services/modules
+ You don't need to **match on specific error types**

### Use error-envelope When:

+ You're building **HTTP APIs** (REST, GraphQL, etc.)
+ You need **structured JSON error responses**
+ You want **consistent status codes** across endpoints
+ You need **trace IDs** for debugging and log correlation
+ You want **retry signals** for client-side error handling
+ You're using **Axum** (or other Rust web frameworks)

### Skip One If:

- **Skip thiserror:** Simple scripts or applications where all errors are treated the same (just log and exit)
- **Skip anyhow:** Libraries or systems where you need full type information about errors
- **Skip error-envelope:** Non-HTTP services (gRPC, CLI tools, background jobs)

---

## Common Patterns

### Pattern 1: Library with thiserror Only

```rust
// Library crate: only thiserror
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ConfigError {
    #[error("File not found: {0}")]
    FileNotFound(String),

    #[error("Parse error: {0}")]
    ParseError(String),

    #[error(transparent)]
    Io(#[from] std::io::Error),
}

pub fn load_config(path: &str) -> Result<Config, ConfigError> {
    let contents = std::fs::read_to_string(path)?; // io::Error → ConfigError
    let config = parse_config(&contents)?;
    Ok(config)
}
```

**Why:** Libraries should expose typed errors so users can match on specific cases.

### Pattern 2: CLI Tool with anyhow Only

```rust
// CLI tool: only anyhow
use anyhow::{Context, Result};

fn main() -> Result<()> {
    let config = load_config("app.toml")
        .context("Failed to load configuration")?;

    let data = fetch_data(&config.api_url)
        .context("Failed to fetch data from API")?;

    process_data(&data)
        .context("Data processing failed")?;

    println!("Success!");
    Ok(())
}
```

**Why:** CLI tools just need to print errors to stderr. No need for structured types.

### Pattern 3: Web API with All Three

```rust
// Web API: thiserror + anyhow + error-envelope

// Domain (thiserror)
#[derive(Error, Debug)]
pub enum UserError {
    #[error("User not found: {0}")]
    NotFound(u64),
    
    #[error("Invalid email: {0}")]
    InvalidEmail(String),
}

// Service (anyhow)
pub async fn get_user(id: u64) -> anyhow::Result<User> {
    let user = db::find_user(id)
        .await
        .context(format!("Failed to fetch user {}", id))?;
    
    Ok(user)
}

// Handler (error-envelope)
pub async fn user_handler(
    Path(id): Path<u64>
) -> Result<Json<User>, Error> {
    let user = get_user(id)
        .await
        .map_err(|e| {
            if e.to_string().contains("not found") {
                Error::not_found(format!("User {} not found", id))
            } else {
                Error::from(e)
            }
        })?;
    
    Ok(Json(user))
}
```

**Why:** Domain uses typed errors, services use flexible propagation, HTTP layer returns structured responses.

### Pattern 4: Hybrid with Smart Mapping

```rust
use error_envelope::Error;

// Smart error mapper that inspects anyhow::Error
fn map_error(err: anyhow::Error, trace_id: String) -> Error {
    // Try downcasting to specific types
    if let Some(payment_err) = err.downcast_ref::<PaymentError>() {
        return match payment_err {
            PaymentError::InsufficientFunds { .. } => {
                Error::new(Code::UnprocessableEntity, 402, "Insufficient funds")
            }
            PaymentError::InvalidCard(_) => {
                Error::bad_request("Invalid card")
            }
            PaymentError::Timeout => {
                Error::timeout("Payment timeout")
            }
            _ => Error::internal("Payment processing failed"),
        }
        .with_trace_id(trace_id);
    }

    // String matching as fallback
    let err_str = err.to_string().to_lowercase();
    if err_str.contains("not found") {
        return Error::not_found("Resource not found").with_trace_id(trace_id);
    }

    // Default
    Error::from(err).with_trace_id(trace_id)
}
```

**Why:** Preserves domain error structure while providing HTTP-friendly responses.

---

## Comparison Table

| Feature | thiserror | anyhow | error-envelope |
|---------|-----------|--------|----------------|
| **Primary Use Case** | Domain errors | Error propagation | HTTP responses |
| **Pattern Matching** | Yes (enums) | No (opaque) | No (opaque) |
| **Context Chaining** | Manual | Built-in | Manual |
| **HTTP Status Codes** | No | No | Yes |
| **Structured JSON** | No | No | Yes |
| **Trace IDs** | No | No | Yes |
| **Retry Signals** | No | No | Yes |
| **Type Safety** | High | Low | Medium |
| **Ergonomics** | Medium | High | Medium |
| **For Libraries** | Yes | No | No |
| **For Applications** | Yes | Yes | Yes (HTTP only) |
| **Dependencies** | Minimal | Minimal | Axum (optional) |
| **Learning Curve** | Low | Low | Low |

---

## Real-World Example: Dormir Adapter

The [Dormir hotel booking adapter](https://github.com/blackwell-systems/dormir) uses all three:

**Domain layer (thiserror):**
```rust
// Define adapter-specific errors
#[derive(Error, Debug)]
pub enum AdapterError {
    #[error("Property not found: {0}")]
    PropertyNotFound(String),

    #[error("Invalid date range: {0} to {1}")]
    InvalidDateRange(String, String),
}
```

**Service layer (anyhow):**
```rust
pub async fn search_properties(
    query: SearchQuery
) -> anyhow::Result<SearchResponse> {
    let properties = channel_manager
        .search(query)
        .await
        .context("Channel manager search failed")?;

    Ok(SearchResponse { properties })
}
```

**HTTP layer (error-envelope):**
```rust
use error_envelope::Error;

async fn search_handler(
    Json(query): Json<SearchQuery>
) -> Result<Json<SearchResponse>, Error> {
    let response = search_properties(query)
        .await
        .map_err(|e| adapter_error(e, request_id()))?;

    Ok(Json(response))
}

fn adapter_error(err: anyhow::Error, trace_id: String) -> Error {
    let err_str = err.to_string().to_lowercase();

    if err_str.contains("not found") {
        return Error::not_found("Property not found")
            .with_trace_id(trace_id)
            .with_retryable(false);
    }

    if err_str.contains("timeout") {
        return Error::timeout("Request timed out")
            .with_trace_id(trace_id)
            .with_retryable(true);
    }

    Error::from(err).with_trace_id(trace_id)
}
```

**Why this works:**
- Domain logic uses typed errors for business rules
- Service layer adds context without boilerplate
- HTTP handlers return consistent JSON responses

Total lines of error handling code: ~80 lines for complete error management across 6 HTTP endpoints.

---

## Migration Path: Adding error-envelope to Existing Code

If you already use `thiserror` and `anyhow`, adding `error-envelope` is straightforward:

### Step 1: Add Dependencies

```toml
[dependencies]
error-envelope = { version = "0.2", features = ["axum-support", "anyhow-support"] }
```

### Step 2: Update Handler Signatures

```rust
// Before
async fn get_user(
    Path(id): Path<u64>
) -> Result<Json<User>, (StatusCode, String)> {
    match fetch_user(id).await {
        Ok(user) => Ok(Json(user)),
        Err(e) => Err((StatusCode::INTERNAL_SERVER_ERROR, e.to_string()))
    }
}

// After
use error_envelope::Error;

async fn get_user(
    Path(id): Path<u64>
) -> Result<Json<User>, Error> {
    let user = fetch_user(id).await?; // anyhow::Error → Error
    Ok(Json(user))
}
```

### Step 3: Add Error Mapping

```rust
async fn get_user(
    Path(id): Path<u64>
) -> Result<Json<User>, Error> {
    let user = fetch_user(id)
        .await
        .map_err(|e| map_to_http(e))?;

    Ok(Json(user))
}

fn map_to_http(err: anyhow::Error) -> Error {
    let trace_id = uuid::Uuid::new_v4().to_string();

    // Map based on error content
    if err.to_string().contains("not found") {
        return Error::not_found("User not found").with_trace_id(trace_id);
    }

    Error::from(err).with_trace_id(trace_id)
}
```

### Step 4: Test Client Response

```bash
curl -v http://localhost:3000/users/999

# Response:
# HTTP/1.1 404 Not Found
# Content-Type: application/json
# X-Request-ID: 550e8400-e29b-41d4-a716-446655440000
#
# {
#   "code": "NOT_FOUND",
#   "message": "User not found",
#   "status": 404,
#   "trace_id": "550e8400-e29b-41d4-a716-446655440000",
#   "retryable": false
# }
```

**Migration time:** ~1 hour for a typical service with 10-20 endpoints.

---

## FAQ

### Q: Can I use anyhow in libraries?

**A:** You can, but you shouldn't. Library users can't pattern match on `anyhow::Error` to handle specific cases. Use `thiserror` to expose typed errors.

### Q: Can I use error-envelope without anyhow?

**A:** Yes. You can convert `thiserror` errors directly to `error_envelope::Error`:

```rust
impl From<PaymentError> for error_envelope::Error {
    fn from(err: PaymentError) -> Self {
        match err {
            PaymentError::InsufficientFunds { .. } => {
                Error::new(Code::UnprocessableEntity, 402, err.to_string())
            }
            PaymentError::Timeout => {
                Error::timeout(err.to_string())
            }
            _ => Error::internal(err.to_string()),
        }
    }
}
```

### Q: Do I need all three for a simple API?

**A:** No. For a prototype or simple service:
- Skip `thiserror` if you don't need typed errors
- Use `anyhow` for error propagation
- Use `error-envelope` at the HTTP boundary

You can always add `thiserror` later when domain errors become more complex.

### Q: What about other web frameworks (Actix, Rocket)?

**A:** `error-envelope` currently supports Axum via the `axum-support` feature. For other frameworks, implement the conversion manually:

```rust
// Actix example
impl actix_web::ResponseError for error_envelope::Error {
    fn error_response(&self) -> HttpResponse {
        HttpResponse::build(StatusCode::from_u16(self.status()).unwrap())
            .json(self)
    }
}
```

### Q: Can I use error-envelope with GraphQL?

**A:** Yes. GraphQL errors are structured similarly:

```rust
use async_graphql::{Error as GraphQLError, ErrorExtensions};

impl From<error_envelope::Error> for GraphQLError {
    fn from(err: error_envelope::Error) -> Self {
        GraphQLError::new(err.message.clone())
            .extend_with(|_, e| {
                e.set("code", err.code.as_str());
                e.set("trace_id", err.trace_id.unwrap_or_default());
            })
    }
}
```

---

## Key Takeaways

1. **Different layers, different needs:** Domain logic needs typed errors, application code needs ergonomic propagation, HTTP boundaries need structured responses.

2. **Not redundant:** `thiserror`, `anyhow`, and `error-envelope` solve different problems at different layers. They complement rather than compete.

3. **Progressive adoption:** Start with `anyhow` for application code. Add `thiserror` when domain errors need structure. Add `error-envelope` when HTTP responses need consistency.

4. **Library vs Application:** Libraries should use `thiserror` (typed errors), applications can use `anyhow` (flexible propagation), both can use `error-envelope` at HTTP boundaries.

5. **Conversion is cheap:** `anyhow::Error` converts to `error_envelope::Error` automatically with the `anyhow-support` feature. `thiserror` errors convert with custom `From` impls.

6. **Trace IDs matter:** Structured errors with trace IDs make debugging production issues exponentially faster. `error-envelope` adds this automatically.

The three crates aren't redundant--they're specialized tools for different stages of error handling. Understanding when to use each makes Rust error handling both ergonomic and robust.

---

**Code Examples:**
- [Dormir adapter](https://github.com/blackwell-systems/dormir) - Real-world usage of all three
- [error-envelope](https://github.com/blackwell-systems/error-envelope) - HTTP error responses for Rust
- [thiserror](https://github.com/dtolnay/thiserror) - Typed error definitions
- [anyhow](https://github.com/dtolnay/anyhow) - Flexible error handling

**License:** MIT
