---
title: "Consistent HTTP Error Handling in Go: A Complete Guide with Chi, Gin, and Echo"
date: 2025-12-06
draft: false
tags: ["go", "golang", "api-design", "error-handling", "http", "rest-api", "chi", "gin", "echo", "middleware"]
description: "Standardize HTTP error responses in Go with err-envelope. Works with net/http, Chi, Gin, and Echo. Get machine-readable error codes, field validation, trace IDs, and retry signals for better API error handling."
summary: "Stop returning errors as plain text. Learn how to implement consistent, structured HTTP error responses in Go with support for Chi router, Gin framework, and Echo framework. Includes field-level validation and trace IDs."
---

Your Go API returns errors in three different formats. Plain text here, JSON there, and a custom structure in another endpoint.

Your mobile app needs three parsing strategies to handle them all.

Here's how to standardize HTTP error handling across your entire Go API—whether you're using net/http, Chi router, Gin framework, or Echo framework.

## The Problem

I was reviewing error handling in a mobile backend and found this pattern repeated across every endpoint:

```go
// Endpoint A
http.Error(w, "Invalid request body", http.StatusBadRequest)

// Endpoint B
json.NewEncoder(w).Encode(map[string]string{
    "error": "User not found",
})

// Endpoint C
json.NewEncoder(w).Encode(struct {
    Message string `json:"message"`
    Code int `json:"code"`
}{
    Message: "Validation failed",
    Code: 400,
})
```

Three different formats. The mobile app had three different parsing strategies. When debugging a user-reported issue, there was no trace ID to find the request in logs.

This is what happens when you build an API endpoint by endpoint without thinking about error responses as a system.

## What Good Looks Like

Every error should have the same shape:

```json
{
  "code": "VALIDATION_FAILED",
  "message": "Invalid input",
  "details": {
    "fields": {
      "email": "must be a valid email"
    }
  },
  "trace_id": "a1b2c3d4e5f6",
  "retryable": false
}
```

**Five fields, each with a job:**

- `code`: Machine-readable identifier (never changes)
- `message`: Human-readable explanation (may evolve)
- `details`: Structured context (field errors, metadata)
- `trace_id`: Request correlation for debugging
- `retryable`: Signal for automatic retry logic

Mobile apps can parse this once and handle every error intelligently. Field validation highlights specific inputs. Trace IDs go in bug reports. Retryable errors get automatic retry logic.

## The Solution

I built [err-envelope](https://github.com/blackwell-systems/err-envelope) to standardize this. It's ~300 lines of stdlib-only Go code that gives you:

```go
// Validation errors with field details
if email == "" {
    err := errenvelope.Validation(errenvelope.FieldErrors{
        "email": "is required",
    })
    errenvelope.Write(w, r, err)
    return
}

// Auth errors
if token == "" {
    errenvelope.Write(w, r, errenvelope.Unauthorized("Missing token"))
    return
}

// Downstream service failures
if err := callPaymentService(); err != nil {
    errenvelope.Write(w, r, errenvelope.Downstream("payments", err))
    return
}
```

Every call produces the same structured response. One HTTP header set (`X-Request-Id`), one JSON format, one parsing strategy on the client.

## Getting Started with err-envelope

Installation is a single `go get` command:

```bash
go get github.com/blackwell-systems/err-envelope
```

Works immediately with:
- **stdlib net/http** - Use `errenvelope.Write()` and `errenvelope.TraceMiddleware()` directly
- **Chi router** - Import `github.com/blackwell-systems/err-envelope/integrations/chi`
- **Gin framework** - Import `github.com/blackwell-systems/err-envelope/integrations/gin`
- **Echo framework** - Import `github.com/blackwell-systems/err-envelope/integrations/echo`

Zero dependencies beyond the frameworks themselves. The core package is ~300 lines of stdlib-only Go code.

## Why This Matters for Mobile Apps

**Before err-envelope:**

```kotlin
// Android app with manual error parsing
val errorMsg = when (response.code()) {
    400 -> "Invalid email or password format"
    409 -> "User already exists"
    500 -> "Server error"
    else -> "Unknown error"
}
```

Hardcoded strings. No field-level details. No trace IDs. No retry hints.

**After err-envelope:**

```kotlin
// Android app with structured errors
val error = parseError(response)
when (error.code) {
    "VALIDATION_FAILED" -> {
        // Highlight specific form fields
        error.fieldErrors?.forEach { (field, message) ->
            emailInput.error = message
        }
    }
    "CONFLICT" -> showError(error.message)
}

// Log trace ID for support
Log.e(TAG, "Error trace: ${error.traceId}")

// Smart retry
if (error.retryable) showRetryButton()
```

Field-specific validation. Trace IDs in bug reports. Automatic retry on transient failures.

## The Three Things That Make This Work

### 1. Stable Error Codes

Error codes never change. `VALIDATION_FAILED` will always be `VALIDATION_FAILED`. Client code can depend on these without version coupling.

Messages can evolve ("Invalid input" → "Invalid input data") without breaking clients because code-based logic doesn't parse strings.

### 2. Trace Middleware

```go
handler := errenvelope.TraceMiddleware(mux)
http.ListenAndServe(":8080", handler)
```

Generates or propagates trace IDs. Adds them to errors automatically. Sets `X-Request-Id` header for log correlation.

When a user reports "signup failed," you search logs by trace ID and find the exact request context within seconds.

### 3. Arbitrary Error Mapping

```go
err := database.Query(ctx, query)
errenvelope.Write(w, r, err)  // Automatically converts
```

Maps `context.DeadlineExceeded` → `Timeout`, `context.Canceled` → `Canceled`, unknown errors → `Internal`. You don't have to check error types manually.

## Framework Integration: Chi, Gin, and Echo

err-envelope works with stdlib `net/http` by default, but also provides thin adapters for popular Go web frameworks.

### Chi Router

Chi is `net/http`-native, so you can use `errenvelope.TraceMiddleware` directly. The adapter exists for convenience:

```go
import (
    errchi "github.com/blackwell-systems/err-envelope/integrations/chi"
    "github.com/go-chi/chi/v5"
)

r := chi.NewRouter()
r.Use(errchi.Trace)

r.Get("/user/{id}", func(w http.ResponseWriter, r *http.Request) {
    userID := chi.URLParam(r, "id")
    if userID == "" {
        errenvelope.Write(w, r, errenvelope.BadRequest("User ID required"))
        return
    }
    // ... handler logic
})
```

### Gin Framework

Gin requires a different signature, so the adapter provides `errgin.Write()` that extracts `http.ResponseWriter` and `*http.Request` from `gin.Context`:

```go
import (
    errgin "github.com/blackwell-systems/err-envelope/integrations/gin"
    "github.com/gin-gonic/gin"
)

r := gin.Default()
r.Use(errgin.Trace())

r.GET("/user/:id", func(c *gin.Context) {
    userID := c.Param("id")
    if userID == "" {
        errgin.Write(c, errenvelope.BadRequest("User ID required"))
        return
    }
    // ... handler logic
})
```

### Echo Framework

Echo uses `echo.Context` and expects handlers to return errors. The adapter provides `errecho.Write()` that returns an error for Echo's error handling chain:

```go
import (
    errecho "github.com/blackwell-systems/err-envelope/integrations/echo"
    "github.com/labstack/echo/v4"
)

e := echo.New()
e.Use(errecho.Trace)

e.GET("/user/:id", func(c echo.Context) error {
    userID := c.Param("id")
    if userID == "" {
        return errecho.Write(c, errenvelope.BadRequest("User ID required"))
    }
    // ... handler logic
    return nil
})
```

All three frameworks get the same structured error responses with trace IDs, field validation, and retry signals.

## What I'd Change If I Built This Again

Nothing architectural. But I'd add one thing: an optional `incident_id` field for linking errors to incident tracking systems.

```json
{
  "code": "INTERNAL",
  "message": "Database connection failed",
  "incident_id": "INC-2024-1234",
  "trace_id": "a1b2c3d4",
  "retryable": true
}
```

That's it. The current design is intentionally minimal—five fields, 17 error code constructors, trace middleware. Small enough to understand completely, complete enough to use in production.

## When Not to Use This

If you're already standardized on RFC 9457 Problem Details, don't switch. The two formats can coexist (map between them at API boundaries if needed).

If your API returns errors in ten different ways, this helps. If your errors are already consistent, you don't need another abstraction.

## The Result

I integrated err-envelope into Pipeboard's mobile backend. Replaced 21 `http.Error()` calls with structured responses. Updated the Android app to parse the new format with field-level validation and trace IDs.

Total time: two hours. The mobile app can now highlight which form fields are invalid and include trace IDs in bug reports.

For a library that's ~300 lines, the impact is disproportionate. That's the sign of a good abstraction—small enough to trust, boring enough to adopt, useful enough to keep.

---

**Code:** [github.com/blackwell-systems/err-envelope](https://github.com/blackwell-systems/err-envelope)
**Docs:** [pkg.go.dev](https://pkg.go.dev/github.com/blackwell-systems/err-envelope)
**License:** MIT
