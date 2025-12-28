# Chapter 11: API Design with JSON

*JSON is the data format, but that doesn't tell you how to design good APIs. Production APIs need conventions for resources, errors, pagination, versioning, rate limiting, and security.*

---

JSON became the dominant data exchange format for web APIs, but JSON itself is just syntax—it tells you how to represent data, not how to design effective APIs. This chapter bridges that gap, exploring the patterns and conventions that emerged from real-world usage to make JSON-based APIs robust, scalable, and maintainable.

The fundamental challenge is that HTTP and JSON together provide the building blocks but not the blueprint. You can send JSON over HTTP in countless ways, but only certain patterns lead to APIs that are intuitive for clients, reliable under load, and maintainable over time.

Consider these two approaches to the same functionality:

**RPC-style approach (what NOT to do):**
```javascript
POST /api/getUser
{"userId": 123}

POST /api/updateUser
{"userId": 123, "email": "new@example.com"}

POST /api/deleteUser
{"userId": 123}
```

**REST-style approach (idiomatic):**
```javascript
GET /api/users/123

PATCH /api/users/123
{"email": "new@example.com"}

DELETE /api/users/123
```

The difference isn't just stylistic—the REST approach leverages HTTP semantics, enables caching, provides clear resource relationships, and follows patterns that millions of developers already understand.

This chapter examines seven critical areas where conventions transform basic JSON-over-HTTP into production-ready APIs: resource modeling, pagination strategies, error handling, versioning approaches, rate limiting, content negotiation, and security patterns.


![Diagram 1](images/diagrams/chapter-11-api-design-diagram-1.png){width=85%}


## 1. REST API Fundamentals

REST (Representational State Transfer) isn't a formal standard—it's a set of architectural principles that emerged from observing what made web APIs successful. While purist REST implementations are rare, REST-inspired patterns dominate modern API design because they align with how HTTP was designed to work.

### Resource-Oriented Thinking

The foundational shift from RPC to REST is thinking in terms of resources rather than operations. Instead of "what can I do?" ask "what things exist and how do they relate?"

**Resource naming conventions:**

```javascript
// Good examples
GET    /users              // List users
GET    /users/123          // Get specific user
POST   /users              // Create user
PATCH  /users/123          // Update user
DELETE /users/123          // Delete user

GET    /users/123/orders   // User's orders (nested)
GET    /orders?userId=123  // Alternative (query param)
```

**Anti-patterns to avoid:**

```javascript
// Bad examples - don't do this
/getAllUsers              // Verb in URL
/user-list                // Not plural
/users/delete/123         // Action in URL
/users?action=get&id=123  // Should use HTTP methods
```

The URL should identify a resource, not describe an action. The HTTP method provides the verb.

### HTTP Method Semantics

Each HTTP method has specific semantic meaning that affects caching, safety, and idempotency:

| Method | Idempotent | Safe | Cacheable | Use For |
|--------|------------|------|-----------|---------|
| GET | Yes | Yes | Yes | Retrieve resource |
| POST | No | No | No | Create resource |
| PUT | Yes | No | No | Replace entire resource |
| PATCH | No | No | No | Partial update |
| DELETE | Yes | No | No | Remove resource |
| HEAD | Yes | Yes | Yes | Metadata only |
| OPTIONS | Yes | Yes | No | Allowed methods |

**Idempotent** means multiple identical requests have the same effect as a single request. **Safe** means the request doesn't modify server state.

These properties enable critical infrastructure behaviors:

```javascript
// GET requests can be cached aggressively
app.get('/users/:id', cache('1 hour'), async (req, res) => {
  const user = await db.users.findById(req.params.id);
  res.json(user);
});

// POST requests are never cached
app.post('/users', async (req, res) => {
  const user = await db.users.create(req.body);
  res.status(201).json(user);
});

// DELETE is idempotent - same result whether user exists or not
app.delete('/users/:id', async (req, res) => {
  await db.users.deleteById(req.params.id); // No error if already deleted
  res.status(204).send();
});
```

### Status Code Selection

HTTP status codes communicate the outcome without requiring clients to parse response bodies:

**2xx Success codes:**
- `200 OK` - Standard success response
- `201 Created` - Resource created (include `Location` header)
- `202 Accepted` - Async processing started
- `204 No Content` - Success with empty response body

**4xx Client Error codes:**
- `400 Bad Request` - Invalid request format or validation errors
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Authenticated but not authorized
- `404 Not Found` - Resource doesn't exist
- `409 Conflict` - Resource state conflict (duplicate email, etc.)
- `422 Unprocessable Entity` - Semantic validation errors
- `429 Too Many Requests` - Rate limit exceeded

**5xx Server Error codes:**
- `500 Internal Server Error` - Unhandled server exception
- `502 Bad Gateway` - Upstream service error
- `503 Service Unavailable` - Temporarily down for maintenance
- `504 Gateway Timeout` - Upstream service timeout

Choose status codes that enable automated client behavior:

```javascript
// Client can automatically retry 503 but not 400
if (response.status === 503) {
  await delay(response.headers['retry-after'] * 1000);
  return retryRequest();
}

// Client can redirect user to login on 401
if (response.status === 401) {
  window.location = '/login';
}

// Client can show field-specific errors on 422
if (response.status === 422) {
  displayValidationErrors(response.data.errors);
}
```

### Richardson Maturity Model


![Diagram 2](images/diagrams/chapter-11-api-design-diagram-2.png){width=85%}


Leonard Richardson identified four levels of REST maturity:

**Level 0: Single endpoint, single method (RPC)**
```javascript
POST /api
{"method": "getUser", "params": {"id": 123}}
{"method": "updateUser", "params": {"id": 123, "email": "new@example.com"}}
```

**Level 1: Multiple resources**
```javascript
POST /users/123
POST /orders/456
```

**Level 2: HTTP methods**
```javascript
GET /users/123
PATCH /users/123
DELETE /users/123
```

**Level 3: HATEOAS (Hypermedia as the Engine of Application State)**
```json
{
  "id": 123,
  "name": "Alice",
  "email": "alice@example.com",
  "_links": {
    "self": {"href": "/users/123"},
    "orders": {"href": "/users/123/orders"},
    "edit": {"href": "/users/123", "method": "PATCH"},
    "delete": {"href": "/users/123", "method": "DELETE"}
  }
}
```

Most production APIs operate at Level 2, with some Level 3 elements for discoverability. Pure Level 3 is rare due to implementation complexity, but the principles guide good resource design.


![Diagram 3](images/diagrams/chapter-11-api-design-diagram-3.png){width=85%}


### Resource Relationships

Model resource relationships through URL structure and links:

**Nested resources (for ownership):**
```javascript
GET /users/123/orders       // Orders belonging to user 123
POST /users/123/orders      // Create order for user 123
GET /users/123/orders/456   // Specific order for user 123
```

**Query parameters (for filtering):**
```javascript
GET /orders?userId=123      // Orders filtered by user
GET /orders?status=pending  // Orders filtered by status
GET /orders?userId=123&status=pending  // Combined filters
```

**Links in responses (for navigation):**
```json
{
  "id": 456,
  "amount": 99.99,
  "status": "pending",
  "userId": 123,
  "_links": {
    "self": {"href": "/orders/456"},
    "user": {"href": "/users/123"},
    "cancel": {"href": "/orders/456/cancel", "method": "POST"}
  }
}
```

Choose based on the relationship strength:
- Use nested URLs for strong ownership (user's orders)
- Use query parameters for filtering (orders by status)  
- Use links for navigation and actions (cancel order)

This resource-oriented approach scales naturally as APIs grow, provides intuitive patterns for client developers, and leverages HTTP's caching and routing infrastructure effectively.

## 2. Pagination Patterns

When your API returns collections of resources, you face an immediate scalability problem: you can't return a million users in a single response. Pagination solves this by breaking large result sets into manageable chunks, but the pagination strategy you choose has profound implications for performance, consistency, and client complexity.


![Diagram 4](images/diagrams/chapter-11-api-design-diagram-4.png){width=85%}


### The Pagination Problem

Consider a simple user listing endpoint:

```javascript
GET /users
```

Without pagination, this works fine when you have 50 users. But what happens when you have 50,000? Or 50 million? The problems compound:

- **Server memory**: Loading massive result sets into memory can crash your application
- **Network transfer**: Large responses are slow and expensive
- **Client processing**: Browsers and mobile apps can't handle huge JSON arrays
- **Database performance**: `SELECT * FROM users` without limits kills database performance

Pagination isn't optional for production APIs—it's a fundamental requirement.

### Pattern 1: Offset-Based Pagination

The simplest pagination approach uses `offset` and `limit` parameters, mirroring SQL's `OFFSET` and `LIMIT` clauses:

**Request pattern:**
```javascript
GET /users?offset=0&limit=20     // First page
GET /users?offset=20&limit=20    // Second page
GET /users?offset=40&limit=20    // Third page
```

**Response structure:**
```json
{
  "data": [
    {"id": 1, "name": "Alice", "email": "alice@example.com"},
    {"id": 2, "name": "Bob", "email": "bob@example.com"}
  ],
  "pagination": {
    "offset": 0,
    "limit": 20,
    "total": 1000,
    "hasMore": true,
    "next": "/users?offset=20&limit=20",
    "prev": null
  }
}
```

**Simple implementation:**
```javascript
app.get('/users', async (req, res) => {
  const offset = parseInt(req.query.offset) || 0;
  const limit = Math.min(parseInt(req.query.limit) || 20, 100);
  
  const [users, total] = await Promise.all([
    db.users.findMany({
      skip: offset,
      take: limit,
      orderBy: { id: 'asc' }
    }),
    db.users.count()
  ]);
  
  res.json({
    data: users,
    pagination: {
      offset,
      limit,
      total,
      hasMore: offset + limit < total,
      next: offset + limit < total ? `/users?offset=${offset + limit}&limit=${limit}` : null,
      prev: offset > 0 ? `/users?offset=${Math.max(0, offset - limit)}&limit=${limit}` : null
    }
  });
});
```

**Why offset-based pagination is problematic:**

The fatal flaw becomes clear when you examine the underlying SQL:

```sql
-- Page 1: Fast
SELECT * FROM users ORDER BY id LIMIT 20 OFFSET 0;

-- Page 500: Slow! Database must read and discard first 10,000 rows
SELECT * FROM users ORDER BY id LIMIT 20 OFFSET 10000;
```

Additional problems:
- **Inconsistent results**: If data changes between requests, users can be skipped or duplicated
- **Performance degradation**: Each page gets slower as offset increases
- **No efficient deep pagination**: Jumping to page 10,000 is prohibitively expensive

### Pattern 2: Cursor-Based Pagination

Cursor-based pagination eliminates offset problems by using the last seen item as the starting point for the next query:

**Request pattern:**
```javascript
GET /users?limit=20                              // First page
GET /users?limit=20&cursor=eyJpZCI6MjB9         // Subsequent pages
```

**Response structure:**
```json
{
  "data": [
    {"id": 21, "name": "Charlie", "email": "charlie@example.com"},
    {"id": 22, "name": "Diana", "email": "diana@example.com"}
  ],
  "pagination": {
    "nextCursor": "eyJpZCI6NDB9",
    "hasMore": true,
    "next": "/users?limit=20&cursor=eyJpZCI6NDB9"
  }
}
```

**Cursor implementation:**
```javascript
function encodeCursor(data) {
  return Buffer.from(JSON.stringify(data)).toString('base64');
}

function decodeCursor(cursor) {
  return JSON.parse(Buffer.from(cursor, 'base64').toString());
}

app.get('/users', async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 20, 100);
  let whereClause = {};
  
  if (req.query.cursor) {
    const cursorData = decodeCursor(req.query.cursor);
    whereClause = { id: { gt: cursorData.id } };
  }
  
  const users = await db.users.findMany({
    where: whereClause,
    take: limit + 1, // Get one extra to check if there are more
    orderBy: { id: 'asc' }
  });
  
  const hasMore = users.length > limit;
  const data = hasMore ? users.slice(0, -1) : users;
  
  const response = {
    data,
    pagination: {
      hasMore
    }
  };
  
  if (hasMore && data.length > 0) {
    response.pagination.nextCursor = encodeCursor({ id: data[data.length - 1].id });
    response.pagination.next = `/users?limit=${limit}&cursor=${response.pagination.nextCursor}`;
  }
  
  res.json(response);
});
```

**SQL efficiency:**
```sql
-- All pages are equally fast - uses index on id
SELECT * FROM users WHERE id > 20 ORDER BY id LIMIT 21;
SELECT * FROM users WHERE id > 40 ORDER BY id LIMIT 21;
SELECT * FROM users WHERE id > 60 ORDER BY id LIMIT 21;
```

### Pattern 3: Keyset Pagination

Keyset pagination is a simpler variant of cursor-based pagination that exposes the cursor value directly:

**Request pattern:**
```javascript
GET /users?limit=20           // First page
GET /users?limit=20&after=40  // After user ID 40
```

**Benefits of keyset over opaque cursors:**
- **Simpler for clients**: No base64 encoding/decoding
- **URL hackable**: Developers can construct URLs manually
- **Cache-friendly**: Clearer cache keys

**Implementation:**
```javascript
app.get('/users', async (req, res) => {
  const limit = Math.min(parseInt(req.query.limit) || 20, 100);
  const after = req.query.after ? parseInt(req.query.after) : 0;
  
  const users = await db.users.findMany({
    where: { id: { gt: after } },
    take: limit + 1,
    orderBy: { id: 'asc' }
  });
  
  const hasMore = users.length > limit;
  const data = hasMore ? users.slice(0, -1) : users;
  
  res.json({
    data,
    pagination: {
      after: data.length > 0 ? data[data.length - 1].id : after,
      hasMore,
      next: hasMore ? `/users?limit=${limit}&after=${data[data.length - 1].id}` : null
    }
  });
});
```

### Pagination Strategy Comparison

| Strategy | Performance | Consistency | Complexity | Use Cases |
|----------|-------------|-------------|------------|-----------|
| Offset | Poor (degrades) | Inconsistent | Simple | Admin interfaces, small datasets |
| Cursor | Excellent | Consistent | Medium | Public APIs, real-time feeds |
| Keyset | Excellent | Consistent | Simple | RESTful APIs, sequential data |

### Real-World Examples

**GitHub API** (Link header pagination):
```http
Link: <https://api.github.com/users?since=135>; rel="next",
      <https://api.github.com/users{?since}>; rel="first"
```

**Twitter API** (cursor-based):
```json
{
  "users": [...],
  "next_cursor": 1374004777531007833,
  "previous_cursor": 0
}
```

**Stripe API** (keyset with starting_after):
```javascript
GET /v1/charges?limit=10&starting_after=ch_1234567890
```

### Advanced Pagination Considerations

**Sorting and pagination:**
```javascript
// Multi-column cursor for complex sorting
GET /users?sort=created_at,id&cursor=eyJjcmVhdGVkX2F0IjoiMjAyNC0wMS0xNSIsImlkIjoxMjN9

// Cursor encoding for multiple fields
function encodeCursor(data) {
  return Buffer.from(JSON.stringify({
    created_at: data.created_at,
    id: data.id
  })).toString('base64');
}
```

**Bidirectional pagination:**
```javascript
GET /messages?before=cursor123&limit=20  // Previous messages
GET /messages?after=cursor123&limit=20   // Next messages
```

**Estimated totals (performance optimization):**
```javascript
// Instead of exact count, provide estimates for large datasets
{
  "data": [...],
  "pagination": {
    "hasMore": true,
    "estimatedTotal": "10K+",  // Avoid expensive COUNT() queries
    "next": "..."
  }
}
```

Choose your pagination strategy based on your specific requirements: offset for simplicity in admin tools, cursor for performance in public APIs, and keyset for the best balance of simplicity and efficiency.


![Diagram 5](images/diagrams/chapter-11-api-design-diagram-5.png){width=85%}


## 3. Error Response Formats

Nothing frustrates developers more than inconsistent error responses. When your API returns errors in different formats across endpoints, clients must implement custom error handling for every operation. Standardized error formats make APIs predictable and enable generic error handling code.


![Diagram 6](images/diagrams/chapter-11-api-design-diagram-6.png){width=85%}


### The Inconsistency Problem

Consider these actual error responses from different endpoints in the same API:

```json
// Endpoint 1: String message
"User not found"

// Endpoint 2: Object with 'error' field
{"error": "Invalid email address"}

// Endpoint 3: Object with 'message' field
{"message": "Password too short", "code": 400}

// Endpoint 4: Array of strings
["Name is required", "Email must be valid", "Password too short"]

// Endpoint 5: Nested validation object
{
  "errors": {
    "email": ["Invalid format", "Already exists"],
    "password": ["Too short", "Must contain numbers"]
  }
}
```

Each format requires different client-side handling, making error management a nightmare. A standardized approach solves this.

### RFC 7807: Problem Details for HTTP APIs

RFC 7807 defines a standard format for HTTP error responses that has gained widespread adoption:

```json
{
  "type": "https://api.example.com/errors/validation-error",
  "title": "Validation Error",
  "status": 400,
  "detail": "One or more fields failed validation",
  "instance": "/users",
  "timestamp": "2024-01-15T10:30:00Z",
  "requestId": "req-abc123"
}
```

**Required fields:**
- `type` - URI identifying the error type (for documentation)
- `title` - Human-readable summary
- `status` - HTTP status code (redundant but helpful)

**Optional fields:**
- `detail` - Specific explanation for this occurrence
- `instance` - URI where this specific error occurred
- Custom fields for additional context


![Diagram 7](images/diagrams/chapter-11-api-design-diagram-7.png){width=85%}


### Field-Level Validation Errors

For form validation, extend the RFC 7807 format with field-specific details:

```json
{
  "type": "https://api.example.com/errors/validation-error",
  "title": "Validation Error",
  "status": 400,
  "detail": "Multiple fields failed validation",
  "instance": "/users",
  "errors": [
    {
      "field": "email",
      "message": "Invalid email format",
      "code": "INVALID_EMAIL",
      "rejectedValue": "not-an-email"
    },
    {
      "field": "password",
      "message": "Must be at least 8 characters",
      "code": "PASSWORD_TOO_SHORT",
      "rejectedValue": "123",
      "constraint": {"minLength": 8}
    },
    {
      "field": "age",
      "message": "Must be at least 18",
      "code": "AGE_TOO_LOW",
      "rejectedValue": 15
    }
  ],
  "requestId": "req-abc123",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

This format provides:
- **Machine-readable codes**: Enable automated error handling
- **Human-readable messages**: Display directly to users
- **Constraint details**: Help clients build better validation
- **Rejected values**: Aid debugging (be careful with sensitive data)

### Error Code System

Establish a consistent error code taxonomy:

```javascript
const ErrorCodes = {
  // Validation (400)
  INVALID_EMAIL: 'INVALID_EMAIL',
  REQUIRED_FIELD: 'REQUIRED_FIELD',
  VALUE_TOO_LONG: 'VALUE_TOO_LONG',
  VALUE_TOO_SHORT: 'VALUE_TOO_SHORT',
  INVALID_FORMAT: 'INVALID_FORMAT',
  
  // Authentication (401)
  INVALID_CREDENTIALS: 'INVALID_CREDENTIALS',
  TOKEN_EXPIRED: 'TOKEN_EXPIRED',
  TOKEN_MALFORMED: 'TOKEN_MALFORMED',
  
  // Authorization (403)
  INSUFFICIENT_PERMISSIONS: 'INSUFFICIENT_PERMISSIONS',
  ACCOUNT_SUSPENDED: 'ACCOUNT_SUSPENDED',
  FEATURE_NOT_AVAILABLE: 'FEATURE_NOT_AVAILABLE',
  
  // Not Found (404)
  RESOURCE_NOT_FOUND: 'RESOURCE_NOT_FOUND',
  ENDPOINT_NOT_FOUND: 'ENDPOINT_NOT_FOUND',
  
  // Conflict (409)
  DUPLICATE_EMAIL: 'DUPLICATE_EMAIL',
  RESOURCE_LOCKED: 'RESOURCE_LOCKED',
  CONCURRENT_MODIFICATION: 'CONCURRENT_MODIFICATION',
  
  // Rate Limit (429)
  RATE_LIMIT_EXCEEDED: 'RATE_LIMIT_EXCEEDED',
  QUOTA_EXCEEDED: 'QUOTA_EXCEEDED',
  
  // Server Error (500)
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  DATABASE_ERROR: 'DATABASE_ERROR',
  SERVICE_UNAVAILABLE: 'SERVICE_UNAVAILABLE'
};
```

Machine-readable codes enable smart client behavior:

```javascript
// Client-side error handling
function handleApiError(error) {
  switch (error.code) {
    case 'TOKEN_EXPIRED':
      return refreshTokenAndRetry();
    
    case 'RATE_LIMIT_EXCEEDED':
      const retryAfter = error.retryAfter || 60;
      return delayAndRetry(retryAfter * 1000);
    
    case 'DUPLICATE_EMAIL':
      showFieldError('email', 'This email is already registered');
      break;
    
    case 'INSUFFICIENT_PERMISSIONS':
      redirectToUpgrade();
      break;
    
    default:
      showGenericError(error.message);
  }
}
```

### Error Middleware Implementation

Centralize error formatting in middleware to ensure consistency:

```javascript
// Express error handling middleware
app.use((err, req, res, next) => {
  const status = err.status || 500;
  
  const errorResponse = {
    type: `https://api.example.com/errors/${err.code || 'internal-error'}`,
    title: getErrorTitle(err),
    status: status,
    instance: req.originalUrl,
    requestId: req.id,
    timestamp: new Date().toISOString()
  };
  
  // Add detail if provided
  if (err.detail || err.message) {
    errorResponse.detail = err.detail || err.message;
  }
  
  // Add validation errors if present
  if (err.validationErrors && err.validationErrors.length > 0) {
    errorResponse.errors = err.validationErrors.map(validationError => ({
      field: validationError.field,
      message: validationError.message,
      code: validationError.code,
      rejectedValue: validationError.rejectedValue
    }));
  }
  
  // Add retry information for rate limits
  if (status === 429) {
    const retryAfter = Math.ceil((err.resetTime - Date.now()) / 1000);
    res.set('Retry-After', retryAfter.toString());
    errorResponse.retryAfter = retryAfter;
  }
  
  // Log server errors (5xx) but not client errors (4xx)
  if (status >= 500) {
    logger.error('Server error', {
      error: err,
      requestId: req.id,
      url: req.originalUrl,
      method: req.method,
      stack: err.stack
    });
  } else {
    logger.warn('Client error', {
      error: err.message,
      requestId: req.id,
      url: req.originalUrl,
      status: status
    });
  }
  
  res.status(status).json(errorResponse);
});

function getErrorTitle(err) {
  const titles = {
    400: 'Bad Request',
    401: 'Unauthorized',
    403: 'Forbidden', 
    404: 'Not Found',
    409: 'Conflict',
    422: 'Validation Error',
    429: 'Too Many Requests',
    500: 'Internal Server Error',
    502: 'Bad Gateway',
    503: 'Service Unavailable'
  };
  
  return err.title || titles[err.status] || 'Unknown Error';
}
```

### Creating Custom Error Classes

Define error classes that work with your middleware:

```javascript
class ApiError extends Error {
  constructor(message, status, code, detail = null) {
    super(message);
    this.status = status;
    this.code = code;
    this.detail = detail;
    this.validationErrors = [];
  }
  
  addValidationError(field, message, code, rejectedValue = null) {
    this.validationErrors.push({
      field,
      message,
      code,
      rejectedValue
    });
    return this;
  }
}

class ValidationError extends ApiError {
  constructor(message = 'Validation failed') {
    super(message, 422, 'VALIDATION_ERROR');
  }
}

class NotFoundError extends ApiError {
  constructor(resource = 'Resource') {
    super(`${resource} not found`, 404, 'RESOURCE_NOT_FOUND');
  }
}

class ConflictError extends ApiError {
  constructor(message, code = 'CONFLICT') {
    super(message, 409, code);
  }
}
```

**Usage in route handlers:**

```javascript
app.post('/users', async (req, res, next) => {
  try {
    const validationError = new ValidationError();
    
    if (!req.body.email) {
      validationError.addValidationError('email', 'Email is required', 'REQUIRED_FIELD');
    } else if (!isValidEmail(req.body.email)) {
      validationError.addValidationError('email', 'Invalid email format', 'INVALID_EMAIL', req.body.email);
    }
    
    if (!req.body.password) {
      validationError.addValidationError('password', 'Password is required', 'REQUIRED_FIELD');
    } else if (req.body.password.length < 8) {
      validationError.addValidationError('password', 'Must be at least 8 characters', 'PASSWORD_TOO_SHORT', req.body.password);
    }
    
    if (validationError.validationErrors.length > 0) {
      throw validationError;
    }
    
    // Check for duplicate email
    const existingUser = await User.findByEmail(req.body.email);
    if (existingUser) {
      throw new ConflictError('Email already exists', 'DUPLICATE_EMAIL');
    }
    
    const user = await User.create(req.body);
    res.status(201).json(user);
    
  } catch (error) {
    next(error);
  }
});
```

### Context-Specific Error Information

Add relevant context to help clients recover from errors:

```json
{
  "type": "https://api.example.com/errors/rate-limit-exceeded",
  "title": "Rate Limit Exceeded", 
  "status": 429,
  "detail": "You have exceeded your rate limit of 1000 requests per hour",
  "retryAfter": 60,
  "limit": {
    "requests": 1000,
    "window": 3600,
    "remaining": 0,
    "resetAt": "2024-01-15T11:00:00Z"
  },
  "upgradeUrl": "https://example.com/upgrade",
  "requestId": "req-abc123"
}
```

```json
{
  "type": "https://api.example.com/errors/insufficient-permissions",
  "title": "Insufficient Permissions",
  "status": 403,
  "detail": "Your account level does not have access to this feature",
  "requiredPermission": "users:delete",
  "currentPermissions": ["users:read", "users:create"],
  "upgradeUrl": "https://example.com/upgrade",
  "supportUrl": "https://example.com/contact"
}
```

This rich error context enables sophisticated client behavior: automatic retries, graceful degradation, helpful user messages, and clear paths to resolution.

Consistent error formats transform error handling from a tedious per-endpoint task into a standardized system that scales across your entire API.


![Diagram 8](images/diagrams/chapter-11-api-design-diagram-8.png){width=85%}


## 4. API Versioning Strategies

APIs evolve constantly—new features, changed behavior, improved performance, security fixes. But you can't break existing clients when you ship updates. API versioning provides a migration path that keeps old clients working while enabling new features. The versioning strategy you choose affects everything from URL structure to client complexity to operational overhead.

### The Breaking Change Problem

Consider this seemingly innocent change:

```json
// Version 1: User object
{
  "id": 123,
  "name": "Alice Smith",
  "email": "alice@example.com"
}

// Version 2: Split name field
{
  "id": 123,
  "firstName": "Alice",
  "lastName": "Smith",
  "email": "alice@example.com"
}
```

This "improvement" breaks every client that expects a `name` field. Without versioning, you have two bad options:
1. **Break all clients**: Ship the change and force everyone to update immediately
2. **Never improve**: Keep the suboptimal `name` field forever

Versioning provides a third option: run both versions simultaneously while clients migrate.

### Strategy 1: URL Versioning

The most common approach embeds version information in the URL path:

```javascript
GET /v1/users/123
GET /v2/users/123
GET /v3/users/123
```

**Implementation patterns:**

```javascript
// Express routing approach
const app = express();

app.use('/v1', require('./routes/v1'));
app.use('/v2', require('./routes/v2'));
app.use('/v3', require('./routes/v3'));

// v1/users.js
router.get('/users/:id', async (req, res) => {
  const user = await db.users.findById(req.params.id);
  res.json({
    id: user.id,
    name: user.name,
    email: user.email
  });
});

// v2/users.js
router.get('/users/:id', async (req, res) => {
  const user = await db.users.findById(req.params.id);
  res.json({
    id: user.id,
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email,
    name: `${user.firstName} ${user.lastName}` // Backward compatibility
  });
});
```

**Pros:**
- **Explicit**: Version is immediately visible in URLs
- **Cacheable**: Different URLs cache independently
- **Tooling**: Easy to route and proxy
- **Documentation**: Clear separation of API versions

**Cons:**
- **URL pollution**: `/v1/users` vs `/users` inconsistency
- **Code duplication**: Must maintain multiple implementations
- **Resource fragmentation**: Same resource at different URLs

**Real-world examples:**
```javascript
// GitHub API
GET https://api.github.com/v3/users/octocat

// Stripe API
GET https://api.stripe.com/v1/charges/ch_123

// Twitter API  
GET https://api.twitter.com/2/tweets/123
```

### Strategy 2: Header Versioning

Place version information in HTTP headers:

```http
GET /users/123
Accept: application/vnd.api+json; version=2
```

**Implementation:**

```javascript
app.get('/users/:id', async (req, res) => {
  const version = getVersionFromHeaders(req);
  const user = await db.users.findById(req.params.id);
  
  if (version === '1') {
    res.json({
      id: user.id,
      name: user.name,
      email: user.email
    });
  } else if (version === '2') {
    res.json({
      id: user.id,
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email
    });
  } else {
    res.status(400).json({
      error: 'Unsupported API version',
      supportedVersions: ['1', '2']
    });
  }
});

function getVersionFromHeaders(req) {
  const accept = req.headers.accept || '';
  const versionMatch = accept.match(/version=(\d+)/);
  return versionMatch ? versionMatch[1] : '1';
}
```

**Alternative header approaches:**

```http
# Custom version header
GET /users/123
API-Version: 2

# Content type with version
GET /users/123  
Accept: application/vnd.myapi.v2+json

# Custom accept parameter
GET /users/123
Accept: application/json; version=2
```

**Pros:**
- **Clean URLs**: No version pollution in paths
- **HTTP semantics**: Proper use of content negotiation
- **Flexible**: Can specify version per request

**Cons:**
- **Less discoverable**: Version hidden in headers
- **Caching complexity**: Must vary cache by headers
- **Testing difficulty**: Harder to test different versions

### Strategy 3: Query Parameter Versioning

Pass version as a query parameter:

```javascript
GET /users/123?version=2
GET /users/123?v=2
GET /users/123?api-version=2
```

**Implementation:**

```javascript
app.get('/users/:id', async (req, res) => {
  const version = req.query.version || req.query.v || '1';
  const user = await db.users.findById(req.params.id);
  
  const transformer = versionTransformers[version];
  if (!transformer) {
    return res.status(400).json({
      error: `Unsupported API version: ${version}`,
      supportedVersions: Object.keys(versionTransformers)
    });
  }
  
  res.json(transformer(user));
});

const versionTransformers = {
  '1': (user) => ({
    id: user.id,
    name: user.name,
    email: user.email
  }),
  
  '2': (user) => ({
    id: user.id,
    firstName: user.firstName,
    lastName: user.lastName,
    email: user.email
  })
};
```

**Pros:**
- **Simple**: Easy to add to any request
- **Testable**: Easy to modify URLs for testing
- **Visible**: Version appears in logs and URLs

**Cons:**
- **Query pollution**: Mixes versioning with filtering
- **Caching**: Complicates cache key generation
- **Inconsistency**: Doesn't follow REST resource conventions

### Deprecation and Migration Strategy

Regardless of versioning approach, you need a clear deprecation timeline:

**Phase 1: Announcement (Months 0-3)**
```http
HTTP/1.1 200 OK
X-API-Version: v1
X-API-Deprecation: true  
X-API-Sunset: 2024-12-31
Link: <https://docs.example.com/migration/v1-to-v2>; rel="migrate"
```

**Phase 2: Warning headers (Months 3-6)**
```http
HTTP/1.1 200 OK
X-API-Version: v1
Warning: 299 api.example.com "API v1 deprecated, migrate to v2 by 2024-12-31"
Sunset: Tue, 31 Dec 2024 23:59:59 GMT
```

**Phase 3: Response body warnings (Months 6-9)**
```json
{
  "data": {...},
  "_deprecated": {
    "version": "v1",
    "sunsetDate": "2024-12-31",
    "migrationGuide": "https://docs.example.com/migration/v1-to-v2",
    "newEndpoint": "https://api.example.com/v2/users/123"
  }
}
```

**Phase 4: Sunset (Month 9+)**
```http
HTTP/1.1 410 Gone
Content-Type: application/json

{
  "type": "https://api.example.com/errors/version-sunset",
  "title": "API Version No Longer Supported",
  "status": 410,
  "detail": "API v1 was sunset on 2024-12-31",
  "migrationGuide": "https://docs.example.com/migration/v1-to-v2",
  "supportedVersions": ["v2", "v3"]
}
```

### Semantic Versioning for APIs

Adapt semantic versioning principles for APIs:

**MAJOR.MINOR.PATCH**
- **MAJOR**: Breaking changes (remove fields, change behavior)
- **MINOR**: Additive changes (new fields, new endpoints)  
- **PATCH**: Bug fixes (no API surface changes)

```javascript
// v1.0.0 → v1.1.0: Added optional field (backward compatible)
{
  "id": 123,
  "name": "Alice",
  "email": "alice@example.com",
  "createdAt": "2024-01-15T10:30:00Z"  // New field
}

// v1.1.0 → v2.0.0: Removed field (breaking change)
{
  "id": 123,
  "firstName": "Alice",
  "lastName": "Smith", 
  "email": "alice@example.com",
  "createdAt": "2024-01-15T10:30:00Z"
  // "name" field removed - breaking change
}
```

### Version-Aware Middleware

Centralize version handling:

```javascript
function versionMiddleware(req, res, next) {
  // Extract version from URL, header, or query
  let version = '1'; // default
  
  if (req.path.startsWith('/v')) {
    version = req.path.split('/')[1].substring(1);
  } else if (req.headers['api-version']) {
    version = req.headers['api-version'];
  } else if (req.query.version) {
    version = req.query.version;
  }
  
  // Validate version
  const supportedVersions = ['1', '2', '3'];
  if (!supportedVersions.includes(version)) {
    return res.status(400).json({
      error: 'Unsupported API version',
      requestedVersion: version,
      supportedVersions: supportedVersions
    });
  }
  
  req.apiVersion = version;
  res.setHeader('X-API-Version', version);
  
  // Add deprecation warnings
  if (version === '1') {
    res.setHeader('X-API-Deprecation', 'true');
    res.setHeader('X-API-Sunset', '2024-12-31');
    res.setHeader('Warning', '299 api.example.com "Version 1 deprecated"');
  }
  
  next();
}
```

### Choosing Your Strategy

| Strategy | Best For | Avoid When |
|----------|----------|-----------|
| URL versioning | Public APIs, clear separation | URL aesthetics matter |
| Header versioning | Enterprise APIs, pure REST | Simple clients, caching complexity |
| Query parameter | Internal APIs, gradual rollout | Resource-heavy endpoints |

Most successful APIs use URL versioning for major versions and headers for minor versions:

```javascript
// Major versions in URL, minor in headers
GET /v2/users/123
API-Version: 2.3

// Or combine both approaches
GET /v2/users/123?version=2.3
```

The key is consistency: pick one primary strategy and stick to it across your entire API surface.


![Diagram 9](images/diagrams/chapter-11-api-design-diagram-9.png){width=85%}


## 5. Rate Limiting

Rate limiting prevents abuse, ensures fair resource usage, and protects your infrastructure from overload. Without rate limiting, a single client can monopolize your API, causing poor performance for everyone else. The challenge is implementing rate limiting that's effective, fair, and provides clear feedback to clients.

### Why Rate Limiting Matters

Consider an API without rate limits:

```javascript
// Client makes 10,000 requests in 10 seconds
for (let i = 0; i < 10000; i++) {
  fetch('/api/users').then(response => console.log(response));
}
```

This can cause:
- **Server overload**: Database connections exhausted, memory issues
- **Service degradation**: Slow responses for all users
- **Infrastructure costs**: Excessive compute and bandwidth usage  
- **Unfair resource distribution**: One client impacts others

Rate limiting solves these problems by setting boundaries on request frequency.

### Standard Rate Limit Headers

The IETF draft standard defines headers that clients can use to manage their request rate:

```http
HTTP/1.1 200 OK
RateLimit-Limit: 1000
RateLimit-Remaining: 742
RateLimit-Reset: 1642089600
```

**Header meanings:**
- `RateLimit-Limit`: Maximum requests allowed in the time window
- `RateLimit-Remaining`: Requests left in current window  
- `RateLimit-Reset`: Unix timestamp when the window resets

**When limit is exceeded:**

```http
HTTP/1.1 429 Too Many Requests
RateLimit-Limit: 1000
RateLimit-Remaining: 0
RateLimit-Reset: 1642089600
Retry-After: 60

{
  "type": "https://api.example.com/errors/rate-limit-exceeded",
  "title": "Rate Limit Exceeded",
  "status": 429,
  "detail": "You have exceeded your rate limit of 1000 requests per hour",
  "retryAfter": 60,
  "limit": {
    "requests": 1000,
    "window": 3600,
    "remaining": 0,
    "resetAt": "2024-01-15T11:00:00Z"
  },
  "requestId": "req-abc123"
}
```

### Token Bucket Algorithm

The token bucket algorithm provides smooth rate limiting with burst capacity:

```javascript
class TokenBucket {
  constructor(capacity, refillRate, refillPeriod = 1000) {
    this.capacity = capacity;           // Maximum tokens
    this.tokens = capacity;             // Current tokens
    this.refillRate = refillRate;       // Tokens added per period
    this.refillPeriod = refillPeriod;   // Period in milliseconds
    this.lastRefill = Date.now();
  }
  
  refill() {
    const now = Date.now();
    const elapsed = now - this.lastRefill;
    const periods = Math.floor(elapsed / this.refillPeriod);
    
    if (periods > 0) {
      const tokensToAdd = periods * this.refillRate;
      this.tokens = Math.min(this.capacity, this.tokens + tokensToAdd);
      this.lastRefill = now;
    }
  }
  
  tryConsume(tokens = 1) {
    this.refill();
    
    if (this.tokens >= tokens) {
      this.tokens -= tokens;
      return {
        allowed: true,
        remaining: this.tokens,
        resetTime: this.lastRefill + this.refillPeriod
      };
    }
    
    return {
      allowed: false,
      remaining: this.tokens,
      resetTime: this.lastRefill + this.refillPeriod
    };
  }
}

// Usage example
const bucket = new TokenBucket(100, 10, 1000); // 100 capacity, 10 tokens/second

const result = bucket.tryConsume(5);
if (result.allowed) {
  console.log('Request allowed, remaining:', result.remaining);
} else {
  console.log('Request denied, try again at:', new Date(result.resetTime));
}
```


![Diagram 10](images/diagrams/chapter-11-api-design-diagram-10.png){width=85%}


### Redis-Based Distributed Rate Limiting

For multi-server deployments, use Redis for shared rate limiting state:

```javascript
const redis = require('redis');
const client = redis.createClient();

async function checkRateLimit(userId, limit, windowSeconds) {
  const now = Math.floor(Date.now() / 1000);
  const window = Math.floor(now / windowSeconds);
  const key = `ratelimit:${userId}:${window}`;
  
  // Use Redis pipeline for atomic operations
  const pipeline = client.pipeline();
  pipeline.incr(key);
  pipeline.expire(key, windowSeconds);
  
  const results = await pipeline.exec();
  const current = results[0][1];
  
  return {
    allowed: current <= limit,
    remaining: Math.max(0, limit - current),
    resetTime: (window + 1) * windowSeconds
  };
}

// Sliding window implementation
async function slidingWindowRateLimit(userId, limit, windowSeconds) {
  const now = Date.now();
  const windowStart = now - (windowSeconds * 1000);
  const key = `ratelimit:sliding:${userId}`;
  
  // Remove old entries and add current request
  const pipeline = client.pipeline();
  pipeline.zremrangebyscore(key, '-inf', windowStart);
  pipeline.zadd(key, now, `${now}-${Math.random()}`);
  pipeline.zcard(key);
  pipeline.expire(key, windowSeconds);
  
  const results = await pipeline.exec();
  const count = results[2][1];
  
  return {
    allowed: count <= limit,
    remaining: Math.max(0, limit - count),
    resetTime: now + (windowSeconds * 1000)
  };
}
```

### Rate Limiting Middleware

Implement rate limiting as Express middleware:

```javascript
function rateLimitMiddleware(options = {}) {
  const {
    limit = 100,
    windowMs = 60 * 1000, // 1 minute
    keyGenerator = (req) => req.ip,
    store = new Map(), // In-memory store (use Redis in production)
    skipSuccessfulRequests = false,
    skipFailedRequests = false
  } = options;
  
  return async (req, res, next) => {
    const key = keyGenerator(req);
    const now = Date.now();
    const windowStart = now - windowMs;
    
    // Clean up old entries
    const requests = store.get(key) || [];
    const validRequests = requests.filter(time => time > windowStart);
    
    if (validRequests.length >= limit) {
      // Rate limit exceeded
      const resetTime = Math.ceil((validRequests[0] + windowMs) / 1000);
      
      res.setHeader('RateLimit-Limit', limit);
      res.setHeader('RateLimit-Remaining', 0);
      res.setHeader('RateLimit-Reset', resetTime);
      res.setHeader('Retry-After', Math.ceil((validRequests[0] + windowMs - now) / 1000));
      
      return res.status(429).json({
        type: 'https://api.example.com/errors/rate-limit-exceeded',
        title: 'Rate Limit Exceeded',
        status: 429,
        detail: `Rate limit of ${limit} requests per ${windowMs/1000} seconds exceeded`,
        retryAfter: Math.ceil((validRequests[0] + windowMs - now) / 1000)
      });
    }
    
    // Add current request
    validRequests.push(now);
    store.set(key, validRequests);
    
    // Set rate limit headers
    res.setHeader('RateLimit-Limit', limit);
    res.setHeader('RateLimit-Remaining', limit - validRequests.length);
    res.setHeader('RateLimit-Reset', Math.ceil((now + windowMs) / 1000));
    
    // Handle response to conditionally count the request
    const originalEnd = res.end;
    res.end = function(...args) {
      const shouldSkip = (
        (skipSuccessfulRequests && res.statusCode < 400) ||
        (skipFailedRequests && res.statusCode >= 400)
      );
      
      if (shouldSkip) {
        // Remove this request from count
        const updated = store.get(key) || [];
        const index = updated.lastIndexOf(now);
        if (index !== -1) {
          updated.splice(index, 1);
          store.set(key, updated);
        }
      }
      
      originalEnd.apply(this, args);
    };
    
    next();
  };
}

// Usage
app.use(rateLimitMiddleware({
  limit: 100,
  windowMs: 60 * 1000,
  keyGenerator: (req) => req.user?.id || req.ip,
  skipSuccessfulRequests: false,
  skipFailedRequests: true
}));
```

### Tiered Rate Limits

Different user tiers deserve different limits:

```javascript
const rateLimits = {
  free: { requests: 100, window: 3600 },      // 100/hour
  basic: { requests: 1000, window: 3600 },    // 1K/hour  
  premium: { requests: 10000, window: 3600 }, // 10K/hour
  enterprise: { requests: 100000, window: 3600 } // 100K/hour
};

function getTierLimits(user) {
  return rateLimits[user?.tier || 'free'];
}

function tierBasedRateLimit(req, res, next) {
  const user = req.user;
  const limits = getTierLimits(user);
  
  // Apply user-specific rate limit
  const userLimit = rateLimitMiddleware({
    limit: limits.requests,
    windowMs: limits.window * 1000,
    keyGenerator: () => `user:${user?.id || 'anonymous'}`
  });
  
  userLimit(req, res, next);
}
```

### Advanced Rate Limiting Patterns

**Endpoint-specific limits:**
```javascript
const endpointLimits = {
  '/api/search': { limit: 10, window: 60000 },    // Expensive search
  '/api/upload': { limit: 5, window: 60000 },     // Resource-intensive
  '/api/users': { limit: 100, window: 60000 }     // Standard CRUD
};

function dynamicRateLimit(req, res, next) {
  const endpoint = req.route?.path || req.path;
  const limits = endpointLimits[endpoint] || { limit: 50, window: 60000 };
  
  const limiter = rateLimitMiddleware(limits);
  limiter(req, res, next);
}
```

**Adaptive rate limiting:**
```javascript
function adaptiveRateLimit(req, res, next) {
  const serverLoad = getServerLoad(); // CPU/memory metrics
  const baseLimit = 1000;
  
  let adjustedLimit;
  if (serverLoad > 0.8) {
    adjustedLimit = baseLimit * 0.5; // Reduce by 50% under high load
  } else if (serverLoad < 0.3) {
    adjustedLimit = baseLimit * 1.5; // Increase by 50% under low load
  } else {
    adjustedLimit = baseLimit;
  }
  
  const limiter = rateLimitMiddleware({ limit: adjustedLimit });
  limiter(req, res, next);
}
```

Rate limiting is essential infrastructure that protects your API while providing clear feedback to clients about usage boundaries. Choose algorithms and implementation strategies that match your traffic patterns and infrastructure capabilities.


![Diagram 11](images/diagrams/chapter-11-api-design-diagram-11.png){width=85%}


## 6. Content Negotiation

Content negotiation allows APIs to serve different representations of the same resource based on client preferences. While JSON dominates API responses, supporting multiple formats and enabling compression can significantly improve performance and accommodate diverse client needs.

### HTTP Accept Headers

Clients specify preferred content types through the `Accept` header:

```http
GET /users/123
Accept: application/json

GET /users/123  
Accept: application/msgpack

GET /users/123
Accept: application/xml
```

The server responds with the appropriate format and sets the `Content-Type` header:

```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8

{"id": 123, "name": "Alice"}
```

### Format Negotiation Implementation

Express provides built-in content negotiation through `res.format()`:

```javascript
app.get('/users/:id', async (req, res) => {
  const user = await db.users.findById(req.params.id);
  
  if (!user) {
    return res.status(404).json({
      type: 'https://api.example.com/errors/not-found',
      title: 'User Not Found',
      status: 404
    });
  }
  
  res.format({
    'application/json': () => {
      res.json({
        id: user.id,
        name: user.name,
        email: user.email,
        createdAt: user.created_at
      });
    },
    
    'application/msgpack': () => {
      const msgpack = require('msgpack5')();
      const data = {
        id: user.id,
        name: user.name,
        email: user.email,
        createdAt: user.created_at
      };
      res.type('application/msgpack');
      res.send(msgpack.encode(data));
    },
    
    'application/xml': () => {
      const xml = `<?xml version="1.0"?>
        <user>
          <id>${user.id}</id>
          <name>${user.name}</name>
          <email>${user.email}</email>
          <createdAt>${user.created_at}</createdAt>
        </user>`;
      res.type('application/xml');
      res.send(xml);
    },
    
    'default': () => {
      res.status(406).json({
        type: 'https://api.example.com/errors/not-acceptable',
        title: 'Not Acceptable',
        status: 406,
        detail: 'Supported formats: application/json, application/msgpack, application/xml',
        supportedTypes: ['application/json', 'application/msgpack', 'application/xml']
      });
    }
  });
});
```

### Binary Format Support

For performance-critical applications, support binary formats like MessagePack (from Chapter 5):

```javascript
const msgpack = require('msgpack5')();

function formatResponse(data, acceptHeader) {
  if (acceptHeader.includes('application/msgpack')) {
    return {
      contentType: 'application/msgpack',
      body: msgpack.encode(data)
    };
  }
  
  if (acceptHeader.includes('application/cbor')) {
    const cbor = require('cbor');
    return {
      contentType: 'application/cbor', 
      body: cbor.encode(data)
    };
  }
  
  // Default to JSON
  return {
    contentType: 'application/json; charset=utf-8',
    body: JSON.stringify(data)
  };
}

app.get('/api/data', async (req, res) => {
  const data = await getLargeDataset();
  const format = formatResponse(data, req.headers.accept || '');
  
  res.set('Content-Type', format.contentType);
  res.send(format.body);
});
```

### Compression Negotiation

Compression can dramatically reduce response sizes. Handle `Accept-Encoding` headers:

```http
GET /users
Accept-Encoding: gzip, deflate, br

HTTP/1.1 200 OK
Content-Encoding: gzip
Content-Type: application/json
Vary: Accept-Encoding

[compressed JSON data]
```

**Express compression middleware:**

```javascript
const compression = require('compression');

app.use(compression({
  level: 6,    // Compression level (1-9, 6 is good balance)
  threshold: 1024,  // Only compress responses > 1KB
  filter: (req, res) => {
    // Don't compress if client doesn't accept encoding
    if (req.headers['x-no-compression']) {
      return false;
    }
    
    // Don't compress images, videos, or already compressed data
    const type = res.getHeader('Content-Type');
    if (type && (
      type.startsWith('image/') || 
      type.startsWith('video/') ||
      type.includes('zip') ||
      type.includes('gzip')
    )) {
      return false;
    }
    
    return compression.filter(req, res);
  }
}));
```

### Quality Values and Preferences

Clients can specify preferences using quality values (q-values):

```http
Accept: application/json;q=1.0, application/msgpack;q=0.8, application/xml;q=0.5
Accept-Encoding: gzip;q=1.0, deflate;q=0.6, *;q=0.1
Accept-Language: en-US;q=1.0, en;q=0.8, es;q=0.5
```

**Parse and handle q-values:**

```javascript
function parseAccept(acceptHeader) {
  if (!acceptHeader) return [];
  
  return acceptHeader
    .split(',')
    .map(item => item.trim())
    .map(item => {
      const [type, ...params] = item.split(';');
      const qMatch = params.find(p => p.trim().startsWith('q='));
      const q = qMatch ? parseFloat(qMatch.split('=')[1]) : 1.0;
      
      return { type: type.trim(), q };
    })
    .sort((a, b) => b.q - a.q); // Sort by preference (highest first)
}

function selectBestFormat(acceptHeader, supportedFormats) {
  const accepted = parseAccept(acceptHeader);
  
  for (const pref of accepted) {
    if (supportedFormats.includes(pref.type)) {
      return pref.type;
    }
    
    // Handle wildcards
    if (pref.type === '*/*' || pref.type === 'application/*') {
      return supportedFormats[0]; // Return first supported format
    }
  }
  
  return null; // No acceptable format
}

app.get('/users/:id', async (req, res) => {
  const user = await db.users.findById(req.params.id);
  const supportedFormats = ['application/json', 'application/msgpack', 'application/xml'];
  const selectedFormat = selectBestFormat(req.headers.accept, supportedFormats);
  
  if (!selectedFormat) {
    return res.status(406).json({
      error: 'Not Acceptable',
      supportedFormats
    });
  }
  
  // Generate response in selected format
  const response = formatUserResponse(user, selectedFormat);
  res.set('Content-Type', selectedFormat);
  res.send(response);
});
```

### Language Negotiation

Support internationalization through `Accept-Language`:

```http
GET /users/123
Accept-Language: es-ES, es;q=0.8, en;q=0.5

HTTP/1.1 200 OK
Content-Language: es-ES

{
  "id": 123,
  "mensaje": "Usuario encontrado",
  "nombre": "Alicia"
}
```

**Implementation:**

```javascript
const messages = {
  'en': {
    userNotFound: 'User not found',
    validationError: 'Validation error'
  },
  'es': {
    userNotFound: 'Usuario no encontrado', 
    validationError: 'Error de validación'
  },
  'fr': {
    userNotFound: 'Utilisateur non trouvé',
    validationError: 'Erreur de validation'
  }
};

function selectLanguage(acceptLanguage, supported = ['en']) {
  const preferences = parseAccept(acceptLanguage);
  
  for (const pref of preferences) {
    const lang = pref.type.split('-')[0]; // Get base language (en from en-US)
    if (supported.includes(lang)) {
      return lang;
    }
  }
  
  return supported[0]; // Default language
}

function localize(key, language = 'en') {
  return messages[language]?.[key] || messages.en[key] || key;
}

app.get('/users/:id', async (req, res) => {
  const user = await db.users.findById(req.params.id);
  const language = selectLanguage(req.headers['accept-language'], ['en', 'es', 'fr']);
  
  if (!user) {
    return res.status(404).json({
      type: 'https://api.example.com/errors/not-found',
      title: localize('userNotFound', language),
      status: 404
    });
  }
  
  res.set('Content-Language', language);
  res.json({
    id: user.id,
    name: user.name,
    email: user.email
  });
});
```

### Caching with Content Negotiation

Content negotiation complicates caching. Use the `Vary` header to indicate which request headers affect the response:

```javascript
app.get('/users/:id', (req, res) => {
  // Response varies based on these headers
  res.set('Vary', 'Accept, Accept-Encoding, Accept-Language');
  
  // ... generate appropriate response
});
```

**Cache key generation:**

```javascript
function generateCacheKey(req) {
  const base = req.originalUrl;
  const accept = req.headers.accept || 'application/json';
  const encoding = req.headers['accept-encoding'] || '';
  const language = req.headers['accept-language'] || 'en';
  
  return `${base}:${accept}:${encoding}:${language}`;
}
```

Content negotiation enables APIs to serve optimal representations while maintaining a single endpoint. Balance format support with implementation complexity, focusing on the formats that provide the most value for your specific use case.


![Diagram 12](images/diagrams/chapter-11-api-design-diagram-12.png){width=85%}


## 7. Security Patterns

Security isn't an afterthought in API design—it's a foundational requirement that affects every aspect of your implementation. Building on the JWT patterns from Chapter 8, this section covers the essential security layers that protect your API and its users from common attacks and vulnerabilities.

### HTTPS Enforcement

HTTPS isn't optional for APIs—it's the foundation of API security. All data should be encrypted in transit:

```javascript
// Redirect HTTP to HTTPS in production
app.use((req, res, next) => {
  if (process.env.NODE_ENV === 'production' && req.headers['x-forwarded-proto'] !== 'https') {
    return res.redirect(301, `https://${req.hostname}${req.url}`);
  }
  next();
});

// Set security headers
app.use((req, res, next) => {
  // Force HTTPS for future requests
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
  
  // Prevent content type sniffing
  res.setHeader('X-Content-Type-Options', 'nosniff');
  
  // Enable XSS filtering
  res.setHeader('X-XSS-Protection', '1; mode=block');
  
  // Control framing (prevent clickjacking)
  res.setHeader('X-Frame-Options', 'DENY');
  
  next();
});
```

### CORS Configuration

Cross-Origin Resource Sharing (CORS) controls which domains can access your API:

```javascript
const cors = require('cors');

app.use(cors({
  origin: (origin, callback) => {
    // Allow requests from specific domains
    const allowedOrigins = [
      'https://app.example.com',
      'https://admin.example.com',
      'https://mobile.example.com'
    ];
    
    // Allow requests with no origin (mobile apps, Postman, etc.)
    if (!origin) return callback(null, true);
    
    if (allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS policy'), false);
    }
  },
  credentials: true,  // Allow cookies and authentication headers
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: [
    'Origin',
    'X-Requested-With', 
    'Content-Type',
    'Accept',
    'Authorization',
    'X-API-Key'
  ],
  exposedHeaders: ['X-Total-Count', 'X-RateLimit-Remaining'], // Headers clients can access
  maxAge: 86400  // Cache preflight requests for 24 hours
}));
```

### Input Validation and Sanitization

Never trust client input. Validate and sanitize all data using JSON Schema (from Chapter 3):

```javascript
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

const ajv = new Ajv({ allErrors: true });
addFormats(ajv);

const createUserSchema = {
  type: 'object',
  required: ['email', 'password', 'name'],
  additionalProperties: false,  // Reject unknown fields
  properties: {
    email: {
      type: 'string',
      format: 'email',
      maxLength: 255
    },
    password: {
      type: 'string',
      minLength: 8,
      maxLength: 128,
      pattern: '^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]+$' // Strong password
    },
    name: {
      type: 'string',
      minLength: 1,
      maxLength: 100,
      pattern: '^[a-zA-Z\\s\\-\\.\']+$'  // Only letters, spaces, hyphens, dots, apostrophes
    },
    age: {
      type: 'integer',
      minimum: 13,
      maximum: 120
    }
  }
};

function validateInput(schema) {
  const validate = ajv.compile(schema);
  
  return (req, res, next) => {
    const valid = validate(req.body);
    
    if (!valid) {
      const errors = validate.errors.map(error => ({
        field: error.instancePath.slice(1) || error.params?.missingProperty || 'root',
        message: error.message,
        code: error.keyword.toUpperCase(),
        rejectedValue: error.data
      }));
      
      return res.status(400).json({
        type: 'https://api.example.com/errors/validation-error',
        title: 'Validation Error',
        status: 400,
        detail: 'Request body validation failed',
        errors: errors
      });
    }
    
    next();
  };
}

// Usage
app.post('/users', validateInput(createUserSchema), async (req, res) => {
  // req.body is now validated and safe to use
  const user = await createUser(req.body);
  res.status(201).json(user);
});
```

### SQL Injection Prevention

Always use parameterized queries, never string concatenation:

```javascript
// DANGEROUS - vulnerable to SQL injection
const query = `SELECT * FROM users WHERE email = '${req.body.email}'`;
const result = await db.query(query);

// SAFE - parameterized query
const query = 'SELECT * FROM users WHERE email = $1';
const result = await db.query(query, [req.body.email]);

// SAFE - ORM/query builder (Prisma example)
const user = await db.user.findUnique({
  where: { email: req.body.email }
});

// SAFE - prepared statements
const stmt = await db.prepare('SELECT * FROM users WHERE email = ?');
const result = await stmt.get(req.body.email);
```

### Authentication and Authorization

Building on Chapter 8's JWT patterns, implement robust authentication:

```javascript
const jwt = require('jsonwebtoken');

// Authentication middleware
async function authenticate(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  
  if (!token) {
    return res.status(401).json({
      type: 'https://api.example.com/errors/authentication-required',
      title: 'Authentication Required',
      status: 401,
      detail: 'Authorization header with Bearer token is required'
    });
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET, {
      algorithms: ['HS256'],
      issuer: 'api.example.com',
      audience: 'api.example.com'
    });
    
    // Check if token is blacklisted
    const isBlacklisted = await checkTokenBlacklist(decoded.jti);
    if (isBlacklisted) {
      throw new Error('Token has been revoked');
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

// Authorization middleware
function authorize(permissions) {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        type: 'https://api.example.com/errors/authentication-required',
        title: 'Authentication Required',
        status: 401
      });
    }
    
    const userPermissions = req.user.permissions || [];
    const hasPermission = permissions.every(permission => 
      userPermissions.includes(permission)
    );
    
    if (!hasPermission) {
      return res.status(403).json({
        type: 'https://api.example.com/errors/insufficient-permissions',
        title: 'Insufficient Permissions',
        status: 403,
        detail: `Required permissions: ${permissions.join(', ')}`,
        userPermissions: userPermissions
      });
    }
    
    next();
  };
}

// Usage
app.get('/users', authenticate, authorize(['users:read']), async (req, res) => {
  const users = await getUsers();
  res.json(users);
});

app.delete('/users/:id', authenticate, authorize(['users:delete']), async (req, res) => {
  await deleteUser(req.params.id);
  res.status(204).send();
});
```

### XSS Prevention in JSON Responses

Even JSON APIs can be vulnerable to XSS if not handled properly:

```javascript
// Set proper content type and security headers
app.use((req, res, next) => {
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  next();
});

// Escape user-generated content in JSON responses
function escapeHtml(unsafe) {
  return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function sanitizeResponseData(data) {
  if (typeof data === 'string') {
    return escapeHtml(data);
  }
  
  if (Array.isArray(data)) {
    return data.map(sanitizeResponseData);
  }
  
  if (data && typeof data === 'object') {
    const sanitized = {};
    for (const [key, value] of Object.entries(data)) {
      sanitized[key] = sanitizeResponseData(value);
    }
    return sanitized;
  }
  
  return data;
}
```

### API Key Management

For service-to-service authentication, implement API key patterns:

```javascript
async function validateApiKey(req, res, next) {
  const apiKey = req.headers['x-api-key'] || req.query.apiKey;
  
  if (!apiKey) {
    return res.status(401).json({
      type: 'https://api.example.com/errors/api-key-required',
      title: 'API Key Required',
      status: 401,
      detail: 'X-API-Key header or apiKey query parameter required'
    });
  }
  
  try {
    // Hash the API key for database lookup (store hashed keys, not plaintext)
    const hashedKey = crypto.createHash('sha256').update(apiKey).digest('hex');
    const keyInfo = await db.apiKeys.findUnique({
      where: { hashedKey: hashedKey, active: true }
    });
    
    if (!keyInfo) {
      throw new Error('Invalid API key');
    }
    
    // Check rate limits for this API key
    const rateLimitResult = await checkApiKeyRateLimit(keyInfo.id);
    if (!rateLimitResult.allowed) {
      return res.status(429).json({
        type: 'https://api.example.com/errors/rate-limit-exceeded',
        title: 'Rate Limit Exceeded',
        status: 429,
        detail: 'API key rate limit exceeded'
      });
    }
    
    req.apiKey = keyInfo;
    req.client = keyInfo.client;
    next();
    
  } catch (error) {
    return res.status(401).json({
      type: 'https://api.example.com/errors/invalid-api-key',
      title: 'Invalid API Key',
      status: 401,
      detail: error.message
    });
  }
}
```

### Security Monitoring and Logging

Monitor for security threats and log security events:

```javascript
const winston = require('winston');

const securityLogger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  defaultMeta: { service: 'api-security' },
  transports: [
    new winston.transports.File({ filename: 'security.log' })
  ]
});

// Security monitoring middleware
app.use((req, res, next) => {
  // Log authentication attempts
  const originalEnd = res.end;
  res.end = function(...args) {
    if (req.path.includes('/auth/') || req.headers.authorization) {
      securityLogger.info({
        event: 'auth_attempt',
        ip: req.ip,
        userAgent: req.headers['user-agent'],
        path: req.path,
        statusCode: res.statusCode,
        timestamp: new Date().toISOString()
      });
    }
    
    // Log failed authentication
    if (res.statusCode === 401 || res.statusCode === 403) {
      securityLogger.warn({
        event: 'auth_failure',
        ip: req.ip,
        path: req.path,
        statusCode: res.statusCode,
        timestamp: new Date().toISOString()
      });
    }
    
    originalEnd.apply(this, args);
  };
  
  next();
});

// Rate limiting for security (separate from API rate limits)
const securityRateLimit = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  message: {
    type: 'https://api.example.com/errors/too-many-requests',
    title: 'Too Many Requests',
    status: 429,
    detail: 'Too many requests from this IP, please try again later'
  },
  standardHeaders: true,
  legacyHeaders: false
});

app.use('/auth/', securityRateLimit);
```

These security patterns create multiple layers of protection that work together to secure your API. Remember that security is an ongoing process—regularly audit your code, update dependencies, and stay informed about new vulnerabilities and best practices.


![Diagram 13](images/diagrams/chapter-11-api-design-diagram-13.png){width=85%}


## Conclusion

This chapter has covered the essential patterns that transform basic JSON-over-HTTP into production-ready APIs. By implementing REST principles, standardized pagination, consistent error handling, thoughtful versioning, rate limiting, content negotiation, and comprehensive security, you create APIs that are not only functional but delightful for developers to use.

The patterns presented here aren't theoretical—they've been battle-tested across thousands of production APIs from companies like GitHub, Stripe, and Twitter. Choose the approaches that fit your specific requirements, but always prioritize consistency and developer experience.

As you design your APIs, remember that today's internal API often becomes tomorrow's public API. Building with these patterns from the start saves significant refactoring effort and provides a foundation that can scale with your needs.

The next chapter explores how these API patterns apply in large-scale data pipeline architectures, where JSON serves as the lingua franca for distributed systems processing millions of events per second.
