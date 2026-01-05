# Appendix A: JSON Specification Summary

This appendix provides a comprehensive quick reference for JSON syntax, JSON Schema essentials, JWT structure, HTTP APIs, and binary format comparisons. Use it as a handy guide during development and system design.

## JSON Syntax Quick Reference

### Data Types

JSON supports exactly six data types. Understanding their precise definitions prevents common errors:

**String**
```json
"hello world"
"unicode: \u0048\u0065\u006C\u006C\u006F"
"escaped: \"quotes\" and \\backslashes\\"
""
```

Strings must use double quotes (not single). Common escape sequences include `\"` for quotes, `\\` for backslashes, `\/` for forward slashes, `\b` for backspace, `\f` for form feed, `\n` for newline, `\r` for carriage return, and `\t` for tab. Unicode characters use the escape format `\uXXXX` with four hexadecimal digits.

**Number**
```json
42
-17
3.14159
-2.5e10
1.23E-4
0
```

Numbers cannot have leading zeros except for `0` itself. Decimal points require digits on both sides. Scientific notation uses `e` or `E` with optional `+` or `-` signs. JSON does not support `NaN`, `Infinity`, or `undefined` as number values.

**Boolean**
```json
true
false
```

Boolean values must be lowercase. No other truthy or falsy values exist in JSON.

**null**
```json
null
```

The `null` value represents intentional absence of a value. It is not the same as `undefined`, `0`, or an empty string `""`.

**Object**
```json
{
  "name": "Alice",
  "age": 30,
  "active": true
}
```

Objects are unordered collections of key-value pairs. Keys must be strings. Values can be any JSON type. Trailing commas are not allowed.

**Array**
```json
[1, 2, 3]
["a", "b", "c"]
[{"id": 1}, {"id": 2}]
[]
```

Arrays are ordered lists of values. Values can be any JSON type, and mixed types are allowed within the same array. Trailing commas are not allowed.

### Syntax Rules

**Whitespace**

Four whitespace characters are allowed: space (U+0020), tab (U+0009), line feed (U+000A), and carriage return (U+000D). Whitespace can appear before or after any token and has no significance, unlike Python or YAML where indentation matters.

**Comments**

Standard JSON does not support comments. Some parsers allow them as extensions, but relying on comments makes your JSON non-portable. Use separate documentation or JSON Schema descriptions for explanatory text.

**Nesting**

Objects and arrays can contain other objects and arrays to any depth. The specification imposes no depth limit, though individual implementations may have practical limits. Circular references are not supported.

### Common Gotchas

**Trailing Commas**
```json
// Invalid - trailing comma
{
  "name": "Alice",
  "age": 30,
}

// Valid - no trailing comma
{
  "name": "Alice", 
  "age": 30
}
```

**Undefined Values**
```json
// Invalid - undefined not supported
{"value": undefined}

// Use null instead
{"value": null}

// Or omit the key entirely
{}
```

**Single vs Double Quotes**
```json
// Invalid - single quotes
{'name': 'Alice'}

// Valid - double quotes
{"name": "Alice"}
```

**Numbers Leading Zeros**
```json
// Invalid - leading zero
{"count": 007}

// Valid - no leading zero
{"count": 7}

// Exception - zero itself
{"count": 0}
```

---

## JSON Schema Essentials

JSON Schema provides vocabulary for validating JSON documents. Here are the most commonly used keywords:

### Core Keywords

**type** - Specifies the expected data type
```json
{
  "type": "string"
}

{
  "type": ["string", "null"]
}
```

**required** - Lists required properties for objects
```json
{
  "type": "object",
  "required": ["email", "name"]
}
```

**properties** - Defines schema for object properties
```json
{
  "type": "object",
  "properties": {
    "email": {"type": "string"},
    "age": {"type": "integer"}
  }
}
```

**items** - Defines schema for array elements
```json
{
  "type": "array",
  "items": {"type": "string"}
}
```

### Validation Keywords

**String Validation**
```json
{
  "type": "string",
  "minLength": 1,
  "maxLength": 100,
  "pattern": "^[a-zA-Z0-9]+$",
  "format": "email"
}
```

**Number Validation**
```json
{
  "type": "number",
  "minimum": 0,
  "maximum": 100,
  "exclusiveMinimum": 0,
  "multipleOf": 0.01
}
```

**Array Validation**
```json
{
  "type": "array",
  "minItems": 1,
  "maxItems": 10,
  "uniqueItems": true
}
```

**Object Validation**
```json
{
  "type": "object",
  "minProperties": 1,
  "maxProperties": 10,
  "additionalProperties": false
}
```

**Enumeration**
```json
{
  "type": "string",
  "enum": ["red", "green", "blue"]
}
```

### Format Strings

JSON Schema defines several built-in format validators for common string types:

**Date and Time Formats**
```json
{"format": "date-time"}  // 2024-01-15T10:30:00Z
{"format": "date"}       // 2024-01-15
{"format": "time"}       // 10:30:00
{"format": "duration"}   // P3Y6M4DT12H30M5S
```

**Network Formats**
```json
{"format": "email"}      // user@example.com
{"format": "hostname"}   // api.example.com
{"format": "ipv4"}       // 192.168.1.1
{"format": "ipv6"}       // 2001:0db8:85a3::8a2e:0370:7334
{"format": "uri"}        // https://example.com/path
{"format": "uri-reference"}  // /path/to/resource
{"format": "iri"}        // Internationalized URI
{"format": "iri-reference"}  // Internationalized URI reference
```

**Other Formats**
```json
{"format": "uuid"}       // 550e8400-e29b-41d4-a716-446655440000
{"format": "json-pointer"}   // /path/to/field
{"format": "relative-json-pointer"}  // 0/field
{"format": "regex"}      // ^[a-z]+$
```

### Composition Keywords

**allOf** - Must match all schemas
```json
{
  "allOf": [
    {"type": "string"},
    {"minLength": 5}
  ]
}
```

**anyOf** - Must match at least one schema
```json
{
  "anyOf": [
    {"type": "string"},
    {"type": "number"}
  ]
}
```

**oneOf** - Must match exactly one schema
```json
{
  "oneOf": [
    {"type": "string"},
    {"type": "number"}
  ]
}
```

**not** - Must not match schema
```json
{
  "not": {"type": "null"}
}
```

### Advanced Features

**Conditionals** - Apply schemas based on conditions
```json
{
  "type": "object",
  "if": {
    "properties": {"type": {"const": "user"}}
  },
  "then": {
    "required": ["email"]
  },
  "else": {
    "required": ["apiKey"]
  }
}
```

**References** - Reuse schema definitions
```json
{
  "$defs": {
    "user": {
      "type": "object",
      "properties": {
        "name": {"type": "string"}
      }
    }
  },
  "type": "array",
  "items": {"$ref": "#/$defs/user"}
}
```

**Custom Formats** - Extend built-in formats
```json
{
  "type": "string",
  "format": "custom-id"
}
```

---

## JWT Quick Reference

JSON Web Tokens (JWT) consist of three Base64URL-encoded parts separated by dots: Header.Payload.Signature

### JWT Structure

**Header** - Specifies token type and algorithm
```json
{
  "alg": "HS256",
  "typ": "JWT"
}
```

**Payload** - Contains claims (user data and metadata)
```json
{
  "sub": "user-123",
  "name": "Alice",
  "email": "alice@example.com",
  "iat": 1735686000,
  "exp": 1735689600,
  "iss": "https://api.example.com",
  "aud": "https://app.example.com"
}
```

**Signature** - Ensures token integrity
```
HMACSHA256(
  base64UrlEncode(header) + "." + base64UrlEncode(payload),
  secret
)
```

### Standard Claims

**Registered Claims** (defined in RFC 7519)

`iss` (issuer) identifies the principal that issued the JWT. Use a URI or string identifying your authentication service.

`sub` (subject) identifies the principal that is the subject of the JWT. Typically a user ID. Must be unique within the issuer's scope.

`aud` (audience) identifies the recipients that the JWT is intended for. Can be a string or array of strings. Validators should reject tokens where they are not listed as an audience.

`exp` (expiration time) specifies when the JWT expires as a NumericDate (seconds since Unix epoch). Validators should reject expired tokens. Keep expiration short (15 minutes or less for access tokens).

`nbf` (not before) specifies when the JWT becomes valid as a NumericDate. Useful for future-dated tokens. Validators should reject tokens used before this time.

`iat` (issued at) specifies when the JWT was created as a NumericDate. Helps detect tokens issued too long ago and track token age.

`jti` (JWT ID) provides a unique identifier for the JWT. Useful for preventing replay attacks and implementing token revocation.

**Public Claims** (custom application claims)

Define your own claims for application-specific data. Avoid collisions with registered claims. Keep payloads small since JWTs are sent with every request.

### Common Algorithms

**HMAC (Symmetric)**
- `HS256` (HMAC-SHA256) - 256-bit secret key
- `HS384` (HMAC-SHA384) - 384-bit secret key  
- `HS512` (HMAC-SHA512) - 512-bit secret key

Use HMAC when both issuer and validator share a secret key. Fast and simple but requires secure key distribution.

**RSA (Asymmetric)**
- `RS256` (RSA-SHA256) - Minimum 2048-bit key
- `RS384` (RSA-SHA384) - Minimum 2048-bit key
- `RS512` (RSA-SHA512) - Minimum 2048-bit key

Use RSA when issuer and validator are different services. Issuer signs with private key, validators verify with public key. Slower than HMAC but better for distributed systems.

**ECDSA (Asymmetric)**
- `ES256` (ECDSA-SHA256) - P-256 curve
- `ES384` (ECDSA-SHA384) - P-384 curve
- `ES512` (ECDSA-SHA512) - P-521 curve

Use ECDSA for smaller signatures than RSA with equivalent security. Gaining popularity for mobile and IoT applications.

---

## HTTP Status Codes for JSON APIs

Choose status codes that enable automated client behavior. These are the codes most relevant for JSON-based APIs:

### 2xx Success

`200 OK` indicates standard success response with body content. Use for successful GET, PUT, PATCH requests that return data.

`201 Created` indicates resource was successfully created. Include `Location` header with new resource URI. Use for successful POST requests that create resources.

`202 Accepted` indicates request accepted for asynchronous processing. Return status endpoint or job ID. Use for long-running operations processed in background.

`204 No Content` indicates success with no response body. Use for successful DELETE requests or updates where no content needs to be returned.

### 4xx Client Errors

`400 Bad Request` indicates invalid request format or validation errors. Return detailed error information about what was invalid.

`401 Unauthorized` indicates authentication required. Client must provide valid credentials. Include `WWW-Authenticate` header specifying the required authentication scheme.

`403 Forbidden` indicates client is authenticated but not authorized for this resource. Do not use 404 to hide existence of protected resources.

`404 Not Found` indicates resource does not exist. Use when resource ID is invalid or resource was deleted.

`405 Method Not Allowed` indicates HTTP method not supported for this endpoint. Include `Allow` header listing supported methods.

`409 Conflict` indicates resource state conflict. Use for duplicate entries, version conflicts, or business rule violations.

`415 Unsupported Media Type` indicates request Content-Type not supported. Specify supported types in error message.

`422 Unprocessable Entity` indicates request was well-formed but contains semantic errors. Use for validation failures where syntax is correct but business rules fail.

`429 Too Many Requests` indicates rate limit exceeded. Include `Retry-After` header specifying when client can retry.

### 5xx Server Errors

`500 Internal Server Error` indicates unhandled server exception. Log full details server-side but return generic message to client for security.

`502 Bad Gateway` indicates upstream service returned invalid response. Use when proxying requests to other services.

`503 Service Unavailable` indicates service temporarily down. Include `Retry-After` header if downtime duration is known. Use during maintenance or when overwhelmed.

`504 Gateway Timeout` indicates upstream service timeout. Use when proxied request exceeds timeout threshold.

---

## Content-Type Headers

Specify the correct Content-Type for JSON variants to enable proper client handling:

### JSON Variants

**application/json** - Standard JSON format. Use for all API responses and requests unless specific variant is needed. Most widely supported.

**application/json; charset=utf-8** - JSON with explicit UTF-8 encoding. Recommended for maximum compatibility though UTF-8 is implied by JSON specification.

**application/ld+json** - JSON-LD (Linked Data). Use for semantic web applications and graph data structures.

**application/geo+json** - GeoJSON for geographic data. Use for location-based services and mapping applications.

**application/json-patch+json** - JSON Patch format (RFC 6902). Use for PATCH requests specifying incremental updates.

**application/merge-patch+json** - JSON Merge Patch format (RFC 7386). Alternative PATCH format for simpler update operations.

**application/problem+json** - RFC 7807 Problem Details. Use for structured error responses across all error status codes.

### JSON Lines and Streaming

**application/x-ndjson** or **application/jsonlines** - Newline Delimited JSON. Use for streaming responses and log files. Each line is a complete JSON object.

**application/stream+json** - JSON streaming for server-sent events. Use for real-time updates and event streams.

### Binary Formats

**application/msgpack** - MessagePack binary format. Smaller and faster than JSON while maintaining similar structure.

**application/cbor** - CBOR (Concise Binary Object Representation). IETF standard for binary JSON-like format.

**application/x-protobuf** - Protocol Buffers. Use with gRPC and high-performance internal APIs.

**application/avro** - Apache Avro. Use with Kafka and big data pipelines.

---

## Common JSON API Patterns

### Pagination Response

**Offset-Based**
```json
{
  "data": [...],
  "pagination": {
    "offset": 20,
    "limit": 20,
    "total": 150
  }
}
```

**Cursor-Based**
```json
{
  "data": [...],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIzfQ==",
    "has_more": true
  }
}
```

### Error Response (RFC 7807)

```json
{
  "type": "https://api.example.com/errors/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "detail": "Email format is invalid",
  "instance": "/users/create",
  "errors": [
    {
      "field": "email",
      "message": "Must be valid email format"
    }
  ]
}
```

### Envelope Pattern

```json
{
  "success": true,
  "data": {...},
  "meta": {
    "timestamp": "2024-01-15T10:30:00Z",
    "request_id": "abc-123",
    "version": "v1"
  }
}
```

### HAL (Hypertext Application Language)

```json
{
  "_links": {
    "self": {"href": "/users/123"},
    "orders": {"href": "/users/123/orders"}
  },
  "id": "123",
  "name": "Alice"
}
```

---

## JSON Lines Format

JSON Lines (also called JSONL or NDJSON) consists of newline-separated JSON objects. Each line is a valid JSON value, typically an object.

**Format Rules**

Each line contains exactly one JSON value, typically an object. Lines are separated by newline characters (`\n`). No trailing comma after the last object. Files use `.jsonl` or `.ndjson` extension.

**Example**
```jsonl
{"id": 1, "name": "Alice", "email": "alice@example.com"}
{"id": 2, "name": "Bob", "email": "bob@example.com"}
{"id": 3, "name": "Carol", "email": "carol@example.com"}
```

**Use Cases**

Streaming logs where each log entry is one line. Data exports handling millions of records. Kafka messages where each message is one line. Big data processing allowing parallel processing by splitting on newlines.

---

## Binary Format Comparison

When JSON's performance characteristics don't meet your needs, several binary alternatives provide different trade-offs:

| Format | Size Reduction | Speed Improvement | Schema Required | Primary Use Case |
|--------|---------------|-------------------|-----------------|------------------|
| **JSON** | Baseline | Baseline | Optional | APIs, Configuration, Human-readable data |
| **MessagePack** | ~20% smaller | ~2x faster | No | API optimization, Caching, Redis storage |
| **CBOR** | ~25% smaller | ~2x faster | No | IoT devices, Embedded systems, Constrained environments |
| **Protocol Buffers** | ~40% smaller | ~10x faster | Required | gRPC services, Internal APIs, High-performance systems |
| **Apache Avro** | ~35% smaller | ~5x faster | Required | Big data pipelines, Kafka, Schema evolution |
| **FlatBuffers** | ~30% smaller | ~100x faster | Required | Game development, Real-time systems, Zero-copy access |
| **Apache Parquet** | ~60% smaller | Variable | Required | Analytics, Data warehousing, Columnar storage |

### When to Choose Each Format

**Stick with JSON when** human readability matters, debugging is frequent, schema flexibility is important, performance is adequate, or ecosystem integration is critical.

**Choose MessagePack when** you need moderate performance gains, schema flexibility must be preserved, migration from JSON should be easy, or Redis and similar systems are involved.

**Choose CBOR when** working with constrained devices, standards compliance matters (IETF RFC 7049), you need better number representation than JSON, or IoT and embedded contexts apply.

**Choose Protocol Buffers when** maximum performance is critical, strong typing is beneficial, code generation is acceptable, or gRPC adoption is planned.

**Choose Apache Avro when** schema evolution is critical, working with Kafka or Hadoop ecosystems, you need dynamic typing with schemas, or big data processing is the primary use case.

**Choose FlatBuffers when** zero-copy access is required, memory usage must be minimized, real-time performance is critical, or game development and similar constraints apply.

**Choose Parquet when** analytics workloads dominate, columnar access patterns exist, data compression is critical, or integration with analytics tools matters.

### Migration Strategies

**Gradual Migration:** Introduce binary format for internal services first. Keep JSON for external APIs. Use gateways to translate between formats. Migrate service-by-service based on performance needs.

**Dual Format Support:** Design APIs to support multiple content types. Use Content-Type headers for negotiation. Generate schemas for both formats from single source. Test both paths thoroughly.

**Schema-First Approach:** Define schemas in neutral format like JSON Schema or OpenAPI. Generate code for all target formats. Version schemas independently from implementations. Use schema registries for runtime validation.
