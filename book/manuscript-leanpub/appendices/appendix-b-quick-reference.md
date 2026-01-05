# Appendix B: Quick Reference Guide

This appendix provides ready-to-use examples for common JSON patterns, API designs, and production practices. Copy these patterns directly into your projects and adapt them to your specific needs. Each pattern includes context about when to use it and what problems it solves.

## JSON Schema Validation Examples

### User Registration Schema

Use this schema for user signup endpoints where you need strong password requirements and structured user preferences. The pattern validation ensures data quality from the start.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "User Registration",
  "type": "object",
  "required": ["email", "password", "name"],
  "properties": {
    "email": {
      "type": "string",
      "format": "email",
      "description": "User's email address"
    },
    "password": {
      "type": "string",
      "minLength": 8,
      "pattern": "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]",
      "description": "Password with uppercase, lowercase, number, and special character"
    },
    "name": {
      "type": "string",
      "minLength": 1,
      "maxLength": 100,
      "pattern": "^[\\p{L}\\s'-]+$",
      "description": "Full name"
    },
    "age": {
      "type": "integer",
      "minimum": 13,
      "maximum": 120,
      "description": "User's age (COPPA compliance requires 13+)"
    },
    "preferences": {
      "type": "object",
      "properties": {
        "newsletter": {"type": "boolean", "default": false},
        "theme": {"enum": ["light", "dark", "auto"], "default": "auto"}
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false
}
```

### Product Catalog Schema

Use this for e-commerce products where price structure is important. The nested price object allows for multi-currency support and decimal precision.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Product",
  "type": "object",
  "required": ["id", "name", "price", "category"],
  "properties": {
    "id": {
      "type": "string",
      "pattern": "^prod-[a-zA-Z0-9]{8}$",
      "description": "Product ID with consistent format"
    },
    "name": {
      "type": "string",
      "minLength": 1,
      "maxLength": 200
    },
    "price": {
      "type": "object",
      "required": ["amount", "currency"],
      "properties": {
        "amount": {
          "type": "number",
          "minimum": 0,
          "multipleOf": 0.01,
          "description": "Price in decimal format (e.g., 19.99)"
        },
        "currency": {
          "type": "string",
          "pattern": "^[A-Z]{3}$",
          "description": "ISO 4217 currency code (USD, EUR, GBP)"
        }
      }
    },
    "category": {
      "enum": ["electronics", "clothing", "books", "home", "sports"]
    },
    "tags": {
      "type": "array",
      "items": {"type": "string"},
      "uniqueItems": true,
      "maxItems": 10
    },
    "availability": {
      "type": "object",
      "required": ["inStock", "quantity"],
      "properties": {
        "inStock": {"type": "boolean"},
        "quantity": {"type": "integer", "minimum": 0},
        "restockDate": {"type": "string", "format": "date"}
      }
    }
  }
}
```

### API Response Envelope Schema

Use this envelope pattern for consistent API responses. The meta object provides tracking and pagination context that clients can rely on.

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "API Response",
  "type": "object",
  "required": ["success", "data", "meta"],
  "properties": {
    "success": {"type": "boolean"},
    "data": {
      "oneOf": [
        {"type": "object"},
        {"type": "array"},
        {"type": "null"}
      ]
    },
    "error": {
      "type": "object",
      "properties": {
        "code": {"type": "string"},
        "message": {"type": "string"},
        "details": {"type": "object"}
      }
    },
    "meta": {
      "type": "object",
      "required": ["timestamp", "requestId"],
      "properties": {
        "timestamp": {"type": "string", "format": "date-time"},
        "requestId": {"type": "string"},
        "pagination": {
          "type": "object",
          "properties": {
            "page": {"type": "integer", "minimum": 1},
            "limit": {"type": "integer", "minimum": 1, "maximum": 100},
            "total": {"type": "integer", "minimum": 0},
            "hasNext": {"type": "boolean"}
          }
        }
      }
    }
  }
}
```

---

## Error Response Formats

### RFC 7807 Problem Details

Standard format for HTTP API error responses. Use this for all error scenarios to provide consistent, machine-parseable error information that clients can handle programmatically.

```json
{
  "type": "https://api.example.com/errors/validation-error",
  "title": "Your request parameters didn't validate.",
  "status": 400,
  "detail": "The 'email' field is required but was not provided.",
  "instance": "/users/create",
  "timestamp": "2024-12-17T10:30:00Z",
  "requestId": "req-abc123",
  "errors": [
    {
      "field": "email",
      "code": "required",
      "message": "Email field is required"
    },
    {
      "field": "password",
      "code": "pattern",
      "message": "Password must contain uppercase, lowercase, number, and special character"
    }
  ]
}
```

### Business Logic Error

Use this pattern when business rules fail (insufficient funds, out of stock, etc.). The context object provides specific details about why the operation failed.

```json
{
  "type": "https://api.example.com/errors/insufficient-funds",
  "title": "Insufficient Funds",
  "status": 422,
  "detail": "Account balance is $50.00 but transaction requires $75.00.",
  "instance": "/transactions/create",
  "timestamp": "2024-12-17T10:30:00Z",
  "requestId": "req-def456",
  "context": {
    "accountId": "acc-789",
    "currentBalance": 50.00,
    "requestedAmount": 75.00,
    "currency": "USD"
  }
}
```

### Rate Limiting Error

Return this when clients exceed rate limits. Include retry information so clients can back off appropriately.

```json
{
  "type": "https://api.example.com/errors/rate-limit-exceeded",
  "title": "Rate Limit Exceeded", 
  "status": 429,
  "detail": "You have exceeded the rate limit of 100 requests per hour.",
  "instance": "/api/v1",
  "timestamp": "2024-12-17T10:30:00Z",
  "requestId": "req-ghi789",
  "retryAfter": 1800,
  "limits": {
    "hourly": {
      "limit": 100,
      "remaining": 0,
      "resetTime": "2024-12-17T11:00:00Z"
    }
  }
}
```

---

## Pagination Patterns

### Offset Pagination

Simple implementation but doesn't scale well to large datasets. Use for admin interfaces or small datasets (under 10,000 records) where users need to jump to specific pages.

```json
{
  "data": [
    {"id": 21, "name": "Product 21"},
    {"id": 22, "name": "Product 22"}
  ],
  "pagination": {
    "offset": 20,
    "limit": 10,
    "total": 150,
    "hasNext": true,
    "hasPrev": true
  },
  "links": {
    "next": "/products?offset=30&limit=10",
    "prev": "/products?offset=10&limit=10",
    "first": "/products?offset=0&limit=10",
    "last": "/products?offset=140&limit=10"
  }
}
```

### Cursor Pagination  

Scalable for large datasets but cursors are opaque Base64-encoded values. Use for APIs serving mobile apps or infinite scroll where users move sequentially through results.

```json
{
  "data": [
    {"id": 21, "name": "Product 21", "createdAt": "2024-12-17T10:30:00Z"},
    {"id": 22, "name": "Product 22", "createdAt": "2024-12-17T10:31:00Z"}
  ],
  "pagination": {
    "cursor": "eyJpZCI6MjIsImNyZWF0ZWRBdCI6IjIwMjQtMTItMTdUMTA6MzE6MDBaIn0=",
    "limit": 10,
    "hasNext": true,
    "hasPrev": true
  },
  "links": {
    "next": "/products?cursor=eyJpZCI6MjIsImNyZWF0ZWRBdCI6IjIwMjQtMTItMTdUMTA6MzE6MDBaIn0=&limit=10",
    "prev": "/products?cursor=eyJpZCI6MjAsImNyZWF0ZWRBdCI6IjIwMjQtMTItMTdUMTA6Mjk6MDBaIn0=&limit=10"
  }
}
```

### Keyset Pagination

Best of both worlds: scalable and transparent. Use for APIs where developers need to understand pagination logic and build custom tooling.

```json
{
  "data": [
    {"id": 21, "name": "Product 21", "createdAt": "2024-12-17T10:30:00Z"},
    {"id": 22, "name": "Product 22", "createdAt": "2024-12-17T10:31:00Z"}
  ],
  "pagination": {
    "afterId": 22,
    "afterDate": "2024-12-17T10:31:00Z",
    "limit": 10,
    "hasNext": true
  },
  "links": {
    "next": "/products?afterId=22&afterDate=2024-12-17T10:31:00Z&limit=10"
  }
}
```

---

## JWT Implementation Examples

### JWT Creation (Node.js)

Use this pattern for generating JWTs during login. Keep expiration short (15 minutes) for access tokens and longer (7 days) for refresh tokens.

```javascript
const jwt = require('jsonwebtoken');

function createTokens(user) {
  const accessToken = jwt.sign(
    {
      sub: user.id,
      email: user.email,
      roles: user.roles,
      type: 'access'
    },
    process.env.JWT_SECRET,
    {
      expiresIn: '15m',
      issuer: 'https://api.example.com',
      audience: 'https://app.example.com'
    }
  );

  const refreshToken = jwt.sign(
    {
      sub: user.id,
      type: 'refresh'
    },
    process.env.JWT_REFRESH_SECRET,
    {
      expiresIn: '7d',
      issuer: 'https://api.example.com',
      audience: 'https://app.example.com'
    }
  );

  return { accessToken, refreshToken };
}
```

### JWT Validation (Node.js)

Use this middleware pattern to protect routes. Always specify allowed algorithms explicitly to prevent algorithm confusion attacks.

```javascript
const jwt = require('jsonwebtoken');

function validateJWT(req, res, next) {
  const authHeader = req.headers.authorization;
  
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      type: 'https://api.example.com/errors/missing-auth',
      title: 'Authentication Required',
      status: 401,
      detail: 'Authorization header with Bearer token required'
    });
  }

  const token = authHeader.substring(7);
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET, {
      algorithms: ['HS256'],  // Specify allowed algorithms
      issuer: 'https://api.example.com',
      audience: 'https://app.example.com'
    });

    // Check token type
    if (decoded.type !== 'access') {
      throw new Error('Invalid token type');
    }

    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({
      type: 'https://api.example.com/errors/invalid-token',
      title: 'Invalid Token',
      status: 401,
      detail: error.message
    });
  }
}
```

### JWT Validation (Go)

Idiomatic Go implementation with proper error handling. Use the jwt-go library with algorithm whitelisting.

```go
package middleware

import (
	"errors"
	"net/http"
	"strings"

	"github.com/golang-jwt/jwt/v5"
)

type Claims struct {
	Sub   string   `json:"sub"`
	Email string   `json:"email"`
	Roles []string `json:"roles"`
	Type  string   `json:"type"`
	jwt.RegisteredClaims
}

func ValidateJWT(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := r.Header.Get("Authorization")
		
		if authHeader == "" || !strings.HasPrefix(authHeader, "Bearer ") {
			respondWithError(w, 401, "missing-auth", "Authorization header required")
			return
		}

		tokenString := strings.TrimPrefix(authHeader, "Bearer ")
		
		claims := &Claims{}
		token, err := jwt.ParseWithClaims(tokenString, claims, func(token *jwt.Token) (interface{}, error) {
			// Validate algorithm
			if token.Method.Alg() != "HS256" {
				return nil, errors.New("unexpected signing method")
			}
			return []byte(os.Getenv("JWT_SECRET")), nil
		})

		if err != nil || !token.Valid {
			respondWithError(w, 401, "invalid-token", "Token validation failed")
			return
		}

		if claims.Type != "access" {
			respondWithError(w, 401, "invalid-token", "Invalid token type")
			return
		}

		// Add claims to context
		ctx := context.WithValue(r.Context(), "user", claims)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}
```

### JWT Validation (Python)

Python implementation using PyJWT. Handles exceptions appropriately and validates all required claims.

```python
from functools import wraps
from flask import request, jsonify
import jwt
import os

def require_jwt(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        
        if not auth_header or not auth_header.startswith('Bearer '):
            return jsonify({
                'type': 'https://api.example.com/errors/missing-auth',
                'title': 'Authentication Required',
                'status': 401,
                'detail': 'Authorization header with Bearer token required'
            }), 401

        token = auth_header[7:]
        
        try:
            payload = jwt.decode(
                token,
                os.getenv('JWT_SECRET'),
                algorithms=['HS256'],
                issuer='https://api.example.com',
                audience='https://app.example.com'
            )

            if payload.get('type') != 'access':
                raise jwt.InvalidTokenError('Invalid token type')

            request.user = payload
            return f(*args, **kwargs)
            
        except jwt.ExpiredSignatureError:
            return jsonify({
                'type': 'https://api.example.com/errors/expired-token',
                'title': 'Token Expired',
                'status': 401,
                'detail': 'JWT token has expired'
            }), 401
        except jwt.InvalidTokenError as e:
            return jsonify({
                'type': 'https://api.example.com/errors/invalid-token',
                'title': 'Invalid Token',
                'status': 401,
                'detail': str(e)
            }), 401
    
    return decorated_function
```

---

## JSON Lines Streaming Examples

### Writing JSON Lines (Node.js)

Use this pattern for exporting large datasets or streaming logs. Each record is immediately flushed, enabling real-time processing.

```javascript
const fs = require('fs');
const { pipeline } = require('stream');

async function exportUsers(query) {
  const writeStream = fs.createWriteStream('users-export.jsonl');
  const cursor = db.collection('users').find(query).stream();

  cursor.on('data', (user) => {
    writeStream.write(JSON.stringify(user) + '\n');
  });

  cursor.on('error', (error) => {
    console.error('Export error:', error);
    writeStream.end();
  });

  cursor.on('end', () => {
    writeStream.end();
    console.log('Export complete');
  });
}
```

### Reading JSON Lines (Node.js)

Process large files line-by-line without loading entire file into memory. Handles parse errors gracefully without stopping the stream.

```javascript
const fs = require('fs');
const readline = require('readline');

async function processJSONL(filePath) {
  const fileStream = fs.createReadStream(filePath);
  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });

  let processed = 0;
  let errors = 0;

  for await (const line of rl) {
    if (!line.trim()) continue; // Skip empty lines

    try {
      const record = JSON.parse(line);
      await processRecord(record);
      processed++;
    } catch (error) {
      console.error(`Parse error on line ${processed + errors}:`, error.message);
      errors++;
    }
  }

  console.log(`Processed: ${processed}, Errors: ${errors}`);
}
```

### Reading JSON Lines (Go)

Idiomatic Go implementation using bufio.Scanner for efficient line-by-line reading.

```go
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
)

type Record struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	// Add other fields
}

func ProcessJSONL(filePath string) error {
	file, err := os.Open(filePath)
	if err != nil {
		return err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	processed := 0
	errors := 0

	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}

		var record Record
		if err := json.Unmarshal([]byte(line), &record); err != nil {
			fmt.Printf("Parse error on line %d: %v\n", processed+errors, err)
			errors++
			continue
		}

		if err := processRecord(record); err != nil {
			fmt.Printf("Processing error: %v\n", err)
			errors++
			continue
		}

		processed++
	}

	if err := scanner.Err(); err != nil {
		return err
	}

	fmt.Printf("Processed: %d, Errors: %d\n", processed, errors)
	return nil
}
```

---

## API Versioning Examples

### URL Versioning

Most explicit versioning strategy. Use this when you need clear separation between API versions and want versioning visible in URLs.

```
GET /api/v1/users
GET /api/v2/users

Response (v1):
{
  "users": [
    {"id": 1, "name": "Alice", "email": "alice@example.com"}
  ]
}

Response (v2):
{
  "data": [
    {
      "id": 1,
      "name": "Alice",
      "email": "alice@example.com",
      "profile": {"avatar": "https://..."}
    }
  ],
  "meta": {"version": "2.0", "timestamp": "2024-01-15T10:30:00Z"}
}
```

### Header Versioning

Keeps URLs clean but requires clients to set headers. Use when you want to evolve APIs without changing URLs.

```
GET /api/users
Accept: application/vnd.example.v1+json

GET /api/users  
Accept: application/vnd.example.v2+json

Response Headers:
Content-Type: application/vnd.example.v2+json
API-Version: 2.0
```

### Deprecation Response

Return deprecation warnings in headers to guide clients toward newer versions.

```
HTTP/1.1 200 OK
Deprecation: true
Sunset: Sun, 31 Dec 2024 23:59:59 GMT
Link: </api/v2/users>; rel="successor-version"
Warning: 299 - "API v1 is deprecated and will be removed on 2024-12-31"

{
  "data": [...],
  "_deprecation": {
    "deprecated": true,
    "sunsetDate": "2024-12-31",
    "successor": "/api/v2/users",
    "message": "Please migrate to v2 by December 31, 2024"
  }
}
```

---

## Webhook Payload Formats

### Event Notification Payload

Use this structure for webhook events. Include enough context for receivers to process events without additional API calls.

```json
{
  "id": "evt_1234567890",
  "type": "order.completed",
  "version": "1.0",
  "timestamp": "2024-01-15T10:30:00Z",
  "data": {
    "orderId": "ord-abc123",
    "customerId": "cus-789",
    "amount": 99.99,
    "currency": "USD",
    "items": [
      {
        "productId": "prod-xyz",
        "quantity": 2,
        "price": 49.99
      }
    ]
  },
  "metadata": {
    "environment": "production",
    "source": "checkout-service",
    "requestId": "req-456"
  }
}
```

### Webhook Security Headers

Verify webhook authenticity using HMAC signatures. Include timestamp to prevent replay attacks.

```
POST /webhooks/orders
X-Webhook-Signature: sha256=5f1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b
X-Webhook-Timestamp: 1705315800
X-Webhook-ID: evt_1234567890
Content-Type: application/json

// Signature verification pseudocode:
// signature = HMAC-SHA256(secret, timestamp + "." + body)
// compare signature with X-Webhook-Signature header using constant-time comparison
```

---

## Batch Request Patterns

### JSON-RPC Batch

Send multiple operations in single HTTP request. Use for reducing network overhead when performing related operations.

```json
[
  {
    "jsonrpc": "2.0",
    "method": "getUser",
    "params": {"id": "user-123"},
    "id": 1
  },
  {
    "jsonrpc": "2.0",
    "method": "getUserOrders",
    "params": {"userId": "user-123", "limit": 10},
    "id": 2
  },
  {
    "jsonrpc": "2.0",
    "method": "getUserPreferences",
    "params": {"userId": "user-123"},
    "id": 3
  }
]

// Response
[
  {
    "jsonrpc": "2.0",
    "result": {"id": "user-123", "name": "Alice"},
    "id": 1
  },
  {
    "jsonrpc": "2.0",
    "result": {"orders": [...]},
    "id": 2
  },
  {
    "jsonrpc": "2.0",
    "result": {"preferences": {...}},
    "id": 3
  }
]
```

### GraphQL-Style Batch

Request multiple resources with field selection. Use when clients need fine-grained control over response shape.

```json
{
  "operations": [
    {
      "operation": "getUser",
      "id": "user-123",
      "fields": ["id", "name", "email", "profile.avatar"]
    },
    {
      "operation": "getUserOrders",
      "userId": "user-123",
      "fields": ["id", "total", "status", "items.name"],
      "limit": 5
    }
  ]
}

// Response
{
  "results": [
    {
      "operation": "getUser",
      "data": {
        "id": "user-123",
        "name": "Alice",
        "email": "alice@example.com",
        "profile": {"avatar": "https://..."}
      }
    },
    {
      "operation": "getUserOrders",
      "data": [
        {
          "id": "ord-1",
          "total": 99.99,
          "status": "completed",
          "items": [{"name": "Product A"}]
        }
      ]
    }
  ]
}
```

---

## Security Headers and Configuration

### Essential Security Headers

Include these headers in all JSON API responses to prevent common attacks.

```http
Content-Type: application/json; charset=utf-8
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
X-XSS-Protection: 1; mode=block
Strict-Transport-Security: max-age=31536000; includeSubDomains
Content-Security-Policy: default-src 'self'; script-src 'self' 'unsafe-inline'
Cache-Control: no-store, no-cache, must-revalidate
Pragma: no-cache
```

### CORS Configuration

For APIs accessed from browsers, configure CORS carefully. Never use `*` for credentials-enabled requests.

```http
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With
Access-Control-Allow-Credentials: true
Access-Control-Max-Age: 86400
```

### Rate Limiting Headers

Inform clients about their usage using standard rate limit headers.

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1703774400
Retry-After: 60
```

---

## Testing Strategy Checklists

### Schema Validation Testing

Ensure your schemas catch all invalid data before it reaches business logic.

- [ ] Valid data passes validation
- [ ] Invalid data types are rejected (string where number expected, etc.)
- [ ] Required fields are enforced (missing fields cause clear errors)
- [ ] Optional fields work correctly (can be omitted without errors)
- [ ] Boundary values are tested (min/max lengths, numeric ranges)
- [ ] Pattern matching works correctly (email, phone, custom formats)
- [ ] Custom formats are validated (UUIDs, dates, application-specific IDs)
- [ ] Error messages are helpful (specify field name and constraint violated)
- [ ] Nested object validation works (deep property validation)
- [ ] Array validation enforces size and uniqueness constraints

### API Contract Testing

Verify your API matches its documented behavior and handles all edge cases.

- [ ] Request/response formats match OpenAPI documentation
- [ ] HTTP status codes are correct (200, 201, 400, 404, 500, etc.)
- [ ] Error responses follow RFC 7807 format consistently
- [ ] Pagination works correctly (offset, cursor, and keyset variants)
- [ ] Filtering and sorting work as expected (query parameters parsed correctly)
- [ ] Rate limiting is enforced (429 returned when limit exceeded)
- [ ] Authentication is required where appropriate (401 for protected routes)
- [ ] Authorization rules are enforced (403 for insufficient permissions)
- [ ] Content negotiation works (Accept header controls response format)
- [ ] API versioning works correctly (v1 vs v2 behavior differs as expected)

### Security Testing

Protect against common JSON API vulnerabilities.

- [ ] Input validation prevents injection attacks (SQL, NoSQL, command injection)
- [ ] JWT tokens are validated correctly (signature, expiration, audience)
- [ ] Expired tokens are rejected (exp claim enforced)
- [ ] Malformed tokens are handled safely (don't leak internal errors)
- [ ] Rate limiting prevents abuse (brute force attacks blocked)
- [ ] CORS policies are enforced (unauthorized origins blocked)
- [ ] Sensitive data is not logged (passwords, tokens excluded from logs)
- [ ] Error messages don't leak information (no stack traces in production)
- [ ] File upload size limits prevent DoS (max payload size enforced)
- [ ] Nested JSON depth limits prevent parser DoS attacks

### Performance Testing

Ensure your API scales under realistic load conditions.

- [ ] Response times meet requirements under normal load (p50, p95, p99)
- [ ] API handles expected peak traffic (Black Friday, product launches)
- [ ] Large payloads are processed correctly (10MB+ requests don't crash)
- [ ] Pagination performance scales appropriately (page 1000 as fast as page 1)
- [ ] Database queries are optimized (indexes on filtered/sorted fields)
- [ ] Caching reduces response times (Redis/CDN effective)
- [ ] Memory usage remains stable (no memory leaks under sustained load)
- [ ] Connection pooling works correctly (database connections reused)
- [ ] Concurrent request handling scales (N requests take ~same time as 1)
- [ ] Background job processing doesn't block API responses

### Integration Testing

Verify your API works correctly with external dependencies.

- [ ] External API calls work correctly (third-party services respond)
- [ ] Database operations are successful (CRUD operations work)
- [ ] Message queue integration works (Kafka, RabbitMQ, SQS messages sent)
- [ ] File upload/download functionality (S3, blob storage operations)
- [ ] Email notifications are sent (SMTP, SendGrid, SES work)
- [ ] Scheduled jobs execute properly (cron tasks run on schedule)
- [ ] Error handling across service boundaries (upstream failures handled gracefully)
- [ ] Transaction rollback works correctly (database consistency maintained)
- [ ] Webhook deliveries succeed (POST to external URLs work)
- [ ] Circuit breakers prevent cascading failures (failing services isolated)

---

## Configuration Examples

### Application Configuration

Use environment variable substitution for secrets and environment-specific values. Never commit secrets to version control.

```json
{
  "server": {
    "port": 3000,
    "host": "0.0.0.0",
    "timeout": 30000,
    "keepAlive": true,
    "bodyLimit": "10mb"
  },
  "database": {
    "host": "${DB_HOST}",
    "port": "${DB_PORT:5432}",
    "name": "${DB_NAME}",
    "username": "${DB_USER}",
    "password": "${DB_PASSWORD}",
    "ssl": "${DB_SSL:true}",
    "pool": {
      "min": 2,
      "max": 10,
      "idle": 10000,
      "acquireTimeout": 30000
    }
  },
  "redis": {
    "url": "${REDIS_URL}",
    "prefix": "app:",
    "ttl": 3600,
    "maxRetries": 3
  },
  "logging": {
    "level": "${LOG_LEVEL:info}",
    "format": "json",
    "fields": {
      "service": "user-api",
      "version": "1.2.3",
      "environment": "${NODE_ENV:production}"
    }
  },
  "security": {
    "jwt": {
      "secret": "${JWT_SECRET}",
      "expiry": "15m",
      "refreshExpiry": "7d"
    },
    "bcrypt": {
      "rounds": 12
    },
    "rateLimit": {
      "windowMs": 900000,
      "max": 100
    }
  },
  "integrations": {
    "stripe": {
      "apiKey": "${STRIPE_API_KEY}",
      "webhookSecret": "${STRIPE_WEBHOOK_SECRET}"
    },
    "sendgrid": {
      "apiKey": "${SENDGRID_API_KEY}",
      "fromEmail": "noreply@example.com"
    }
  }
}
```

### Environment-Specific Configurations

Maintain separate configs for each environment. Use identical structure but different values.

**config/development.json**
```json
{
  "server": {
    "port": 3000,
    "debug": true
  },
  "database": {
    "host": "localhost",
    "name": "myapp_dev",
    "pool": {
      "max": 5
    }
  },
  "logging": {
    "level": "debug",
    "prettyPrint": true
  },
  "security": {
    "rateLimit": {
      "enabled": false
    }
  }
}
```

**config/production.json**
```json
{
  "server": {
    "port": 8080,
    "debug": false
  },
  "database": {
    "host": "${DB_HOST}",
    "name": "${DB_NAME}",
    "ssl": true,
    "pool": {
      "max": 20
    }
  },
  "logging": {
    "level": "info",
    "prettyPrint": false
  },
  "security": {
    "rateLimit": {
      "enabled": true,
      "max": 100
    }
  },
  "monitoring": {
    "sentry": {
      "dsn": "${SENTRY_DSN}"
    },
    "datadog": {
      "apiKey": "${DATADOG_API_KEY}"
    }
  }
}
```

### Feature Flags Configuration

Control feature rollout without code deployments. Use percentage-based rollouts and targeting rules.

```json
{
  "features": {
    "newCheckoutFlow": {
      "enabled": true,
      "rollout": 50,
      "description": "Redesigned checkout with one-click payment",
      "rules": [
        {
          "attribute": "region",
          "operator": "in",
          "values": ["US", "CA"],
          "enabled": true
        },
        {
          "attribute": "userType",
          "operator": "equals",
          "value": "beta_tester",
          "enabled": true
        }
      ]
    },
    "advancedSearch": {
      "enabled": false,
      "rollout": 0,
      "description": "Elasticsearch-powered search with filters"
    },
    "socialLogin": {
      "enabled": true,
      "rollout": 100,
      "providers": ["google", "github", "apple"]
    }
  },
  "experiments": {
    "checkoutButtonColor": {
      "enabled": true,
      "variants": {
        "control": {"weight": 50, "color": "blue"},
        "treatment": {"weight": 50, "color": "green"}
      },
      "metrics": ["conversion_rate", "revenue_per_user"]
    }
  },
  "killSwitches": {
    "externalPaymentGateway": {
      "enabled": true,
      "reason": "Fallback to internal processing if gateway fails"
    }
  }
}
```

---

## Monitoring and Observability

### Structured Logging Format

Use consistent JSON logging format for easy parsing and analysis.

```json
{
  "timestamp": "2024-01-15T10:30:00.123Z",
  "level": "info",
  "message": "User created successfully",
  "service": "user-api",
  "version": "1.2.3",
  "environment": "production",
  "requestId": "req-abc123",
  "userId": "user-456",
  "duration": 45,
  "statusCode": 201,
  "method": "POST",
  "path": "/api/v1/users",
  "userAgent": "Mozilla/5.0...",
  "ip": "192.168.1.100",
  "context": {
    "email": "alice@example.com",
    "registrationSource": "mobile_app"
  }
}
```

### Error Logging Format

Include stack traces and context for debugging but never log sensitive data.

```json
{
  "timestamp": "2024-01-15T10:30:00.123Z",
  "level": "error",
  "message": "Database connection failed",
  "service": "user-api",
  "version": "1.2.3",
  "environment": "production",
  "requestId": "req-def789",
  "error": {
    "name": "DatabaseConnectionError",
    "message": "Connection timeout after 30000ms",
    "code": "ETIMEDOUT",
    "stack": "Error: Connection timeout...\n    at...",
    "host": "db.example.com",
    "port": 5432
  },
  "context": {
    "operation": "getUserById",
    "userId": "user-789",
    "retryAttempt": 3
  }
}
```

### Metrics Payload

Report application metrics for monitoring dashboards.

```json
{
  "timestamp": "2024-01-15T10:30:00Z",
  "service": "user-api",
  "metrics": {
    "requests": {
      "total": 15234,
      "success": 14890,
      "errors": 344,
      "rate": 253.9
    },
    "latency": {
      "p50": 45,
      "p95": 120,
      "p99": 250,
      "max": 1200
    },
    "database": {
      "connections": {
        "active": 8,
        "idle": 2,
        "waiting": 0
      },
      "queryTime": {
        "avg": 12.5,
        "max": 150
      }
    },
    "cache": {
      "hits": 8920,
      "misses": 1102,
      "hitRate": 89.0
    }
  }
}
```
