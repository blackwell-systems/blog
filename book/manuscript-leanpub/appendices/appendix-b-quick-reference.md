# Appendix B: Quick Reference Guide

This appendix provides ready-to-use examples for common JSON patterns, API designs, and production practices. Copy these patterns directly into your projects and adapt them to your specific needs.

## JSON Schema Validation Examples

### User Registration Schema
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
      "description": "User's age"
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
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Product",
  "type": "object",
  "required": ["id", "name", "price", "category"],
  "properties": {
    "id": {
      "type": "string",
      "pattern": "^prod-[a-zA-Z0-9]{8}$"
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
          "multipleOf": 0.01
        },
        "currency": {
          "type": "string",
          "pattern": "^[A-Z]{3}$"
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

### API Response Schema
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

## Error Response Formats

### RFC 7807 Problem Details
Standard format for HTTP API error responses:

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

## Pagination Patterns

### Offset Pagination
Simple but doesn't scale well:

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
Scalable but opaque:

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
Scalable and transparent:

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

## Security Headers and Configuration

### Essential Security Headers
Include these headers in all JSON API responses:

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
For APIs accessed from browsers:

```http
Access-Control-Allow-Origin: https://app.example.com
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS
Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With
Access-Control-Allow-Credentials: true
Access-Control-Max-Age: 86400
```

### Rate Limiting Headers
Inform clients about their usage:

```http
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1703774400
Retry-After: 60
```

## Testing Strategy Checklists

### Schema Validation Testing
- [ ] Valid data passes validation
- [ ] Invalid data types are rejected
- [ ] Required fields are enforced
- [ ] Optional fields work correctly
- [ ] Boundary values are tested (min/max lengths, ranges)
- [ ] Pattern matching works correctly
- [ ] Custom formats are validated
- [ ] Error messages are helpful

### API Contract Testing
- [ ] Request/response formats match documentation
- [ ] HTTP status codes are correct
- [ ] Error responses follow standard format
- [ ] Pagination works correctly
- [ ] Filtering and sorting work as expected
- [ ] Rate limiting is enforced
- [ ] Authentication is required where appropriate
- [ ] Authorization rules are enforced

### Security Testing
- [ ] Input validation prevents injection attacks
- [ ] JWT tokens are validated correctly
- [ ] Expired tokens are rejected
- [ ] Malformed tokens are handled safely
- [ ] Rate limiting prevents abuse
- [ ] CORS policies are enforced
- [ ] Sensitive data is not logged
- [ ] Error messages don't leak information

### Performance Testing
- [ ] Response times meet requirements under normal load
- [ ] API handles expected peak traffic
- [ ] Large payloads are processed correctly
- [ ] Pagination performance scales appropriately
- [ ] Database queries are optimized
- [ ] Caching reduces response times
- [ ] Memory usage remains stable
- [ ] No memory leaks under sustained load

### Integration Testing
- [ ] External API calls work correctly
- [ ] Database operations are successful
- [ ] Message queue integration works
- [ ] File upload/download functionality
- [ ] Email notifications are sent
- [ ] Scheduled jobs execute properly
- [ ] Error handling across service boundaries
- [ ] Transaction rollback works correctly

## Configuration Examples

### Application Configuration
```json
{
  "server": {
    "port": 3000,
    "host": "0.0.0.0",
    "timeout": 30000,
    "keepAlive": true
  },
  "database": {
    "host": "${DB_HOST}",
    "port": "${DB_PORT:5432}",
    "name": "${DB_NAME}",
    "username": "${DB_USER}",
    "password": "${DB_PASSWORD}",
    "pool": {
      "min": 2,
      "max": 10,
      "idle": 10000
    }
  },
  "redis": {
    "url": "${REDIS_URL}",
    "prefix": "app:",
    "ttl": 3600
  },
  "logging": {
    "level": "${LOG_LEVEL:info}",
    "format": "json",
    "fields": {
      "service": "user-api",
      "version": "1.2.3"
    }
  },
  "security": {
    "jwt": {
      "secret": "${JWT_SECRET}",
      "expiry": "15m"
    },
    "bcrypt": {
      "rounds": 12
    }
  }
}
```

### Feature Flags Configuration
```json
{
  "features": {
    "newUserFlow": {
      "enabled": true,
      "rollout": 50,
      "rules": [
        {
          "attribute": "region",
          "operator": "in",
          "values": ["US", "CA"],
          "enabled": true
        }
      ]
    },
    "advancedSearch": {
      "enabled": false,
      "rollout": 0
    }
  },
  "experiments": {
    "checkoutOptimization": {
      "enabled": true,
      "variants": {
        "control": {"weight": 50},
        "treatment": {"weight": 50}
      }
    }
  }
}
```

