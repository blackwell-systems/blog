# Chapter 11: API Design with JSON - DETAILED OUTLINE

**Target:** 7,000 words  
**Status:** Research and incremental writing phase  
**Foundation:** Chapters 3 (Schema), 5 (JSON-RPC), 8 (Security) provide context

---

## Core Thesis

**The API Design Gap:** JSON is the data format, but that doesn't tell you how to design good APIs. Production APIs need conventions for resources, errors, pagination, versioning, rate limiting, and security.

**Ecosystem response:** REST patterns emerged through practice (not specification):
- **Resource naming:** `/users/{id}` not `/getUser?id=123`
- **HTTP methods:** Semantic meaning (GET is idempotent, POST isn't)
- **Status codes:** 200, 201, 400, 404, 500 communicate intent
- **Pagination:** Cursor-based beats offset-based
- **Versioning:** Multiple strategies, each with trade-offs

**Pattern:** JSON provides syntax, conventions provide semantics.

---

## Structure (7,000 words breakdown)

### 1. REST API Fundamentals (~1,000 words)

**Hook:** Show same functionality designed as RPC vs REST - make REST principles obvious

**RPC-style (what NOT to do):**
```javascript
POST /api/getUser
{"userId": 123}

POST /api/updateUser
{"userId": 123, "email": "new@example.com"}

POST /api/deleteUser
{"userId": 123}
```

**REST-style (idiomatic):**
```javascript
GET /api/users/123

PATCH /api/users/123
{"email": "new@example.com"}

DELETE /api/users/123
```

**Resource naming conventions:**

**Good examples:**
```
GET    /users              # List users
GET    /users/123          # Get specific user
POST   /users              # Create user
PATCH  /users/123          # Update user
DELETE /users/123          # Delete user

GET    /users/123/orders   # User's orders (nested)
GET    /orders?userId=123  # Alternative (query param)
```

**Bad examples:**
```
/getAllUsers              # Verb in URL
/user-list                # Not plural
/users/delete/123         # Action in URL
/users?action=get&id=123  # Should use HTTP methods
```

**HTTP method semantics:**

| Method | Idempotent | Safe | Cache | Use For |
|--------|------------|------|-------|---------|
| GET | Yes | Yes | Yes | Retrieve resource |
| POST | No | No | No | Create resource |
| PUT | Yes | No | No | Replace resource |
| PATCH | No | No | No | Update resource |
| DELETE | Yes | No | No | Delete resource |
| HEAD | Yes | Yes | Yes | Metadata only |
| OPTIONS | Yes | Yes | No | Allowed methods |

**Status code selection:**

**2xx Success:**
- `200 OK` - Standard success
- `201 Created` - Resource created (include Location header)
- `202 Accepted` - Async processing started
- `204 No Content` - Success with no response body

**3xx Redirection:**
- `301 Moved Permanently` - Resource moved
- `304 Not Modified` - Use cached version

**4xx Client Errors:**
- `400 Bad Request` - Invalid request (validation errors)
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Authenticated but not authorized
- `404 Not Found` - Resource doesn't exist
- `409 Conflict` - Resource state conflict
- `422 Unprocessable Entity` - Semantic errors
- `429 Too Many Requests` - Rate limit exceeded

**5xx Server Errors:**
- `500 Internal Server Error` - Unhandled exception
- `502 Bad Gateway` - Upstream server error
- `503 Service Unavailable` - Temporarily down
- `504 Gateway Timeout` - Upstream timeout

**Richardson Maturity Model:**

```
Level 0: Single endpoint, single method (RPC)
Level 1: Multiple resources (/users, /orders)
Level 2: HTTP methods (GET, POST, PUT, DELETE)
Level 3: HATEOAS (hypermedia controls)
```

**HATEOAS example:**
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

### 2. Pagination Patterns (~1,200 words)

**Why pagination matters:**
- Can't return 1M users in single response
- Client can't process huge responses
- Database can't efficiently query without limits

**Pattern 1: Offset-based pagination (simple but flawed)**

**Request:**
```
GET /users?offset=0&limit=20
GET /users?offset=20&limit=20
GET /users?offset=40&limit=20
```

**Response:**
```json
{
  "data": [...],
  "pagination": {
    "offset": 0,
    "limit": 20,
    "total": 1000,
    "hasMore": true
  }
}
```

**Problems:**
- Inefficient for large offsets (database scans all skipped rows)
- Inconsistent results if data changes between requests
- Can miss or duplicate records

**SQL cost:**
```sql
-- Offset 10000 still reads first 10000 rows
SELECT * FROM users
ORDER BY id
LIMIT 20 OFFSET 10000;  -- Slow!
```

**Pattern 2: Cursor-based pagination (production standard)**

**Request:**
```
GET /users?limit=20
GET /users?limit=20&cursor=eyJpZCI6MTIzfQ==
```

**Response:**
```json
{
  "data": [
    {"id": 101, "name": "Alice"},
    {"id": 102, "name": "Bob"}
  ],
  "pagination": {
    "nextCursor": "eyJpZCI6MTAyfQ==",
    "hasMore": true
  }
}
```

**Cursor encoding (Base64 JSON):**
```javascript
// Encode cursor
const cursor = Buffer.from(JSON.stringify({id: 102})).toString('base64');

// Decode cursor
const decoded = JSON.parse(Buffer.from(cursor, 'base64').toString());
```

**SQL implementation:**
```sql
-- First page
SELECT * FROM users
WHERE id > 0
ORDER BY id
LIMIT 20;

-- Next page (cursor id=102)
SELECT * FROM users
WHERE id > 102
ORDER BY id
LIMIT 20;
```

**Benefits:**
- Efficient (uses index on id)
- Consistent (no missed/duplicate records)
- Scales to any dataset size

**Pattern 3: Keyset pagination (explicit cursor)**

**Request:**
```
GET /users?limit=20
GET /users?limit=20&after=102
```

**Response:**
```json
{
  "data": [...],
  "pagination": {
    "after": 122,
    "hasMore": true
  }
}
```

**Comparison:**

| Pattern | Complexity | Performance | Consistency | Use Case |
|---------|------------|-------------|-------------|----------|
| Offset | Simple | Poor (large offsets) | Inconsistent | Admin UIs |
| Cursor | Medium | Excellent | Consistent | Production APIs |
| Keyset | Simple | Excellent | Consistent | Public APIs |

**Real-world examples:**
- **GitHub API:** Cursor-based with Link headers
- **Twitter API:** Cursor-based with since_id/max_id
- **Stripe API:** Cursor-based with starting_after/ending_before

**Link header pagination (GitHub style):**
```http
Link: <https://api.github.com/users?page=2>; rel="next",
      <https://api.github.com/users?page=5>; rel="last"
```

### 3. Error Response Formats (~1,000 words)

**The problem:** Inconsistent error responses make client integration painful

**Bad error responses:**
```json
// Different formats across endpoints
{"error": "Invalid email"}
{"message": "User not found"}
{"errors": ["Name required", "Email invalid"]}
"Internal server error"
```

**Standard error format (RFC 7807 Problem Details):**

```json
{
  "type": "https://api.example.com/errors/validation-error",
  "title": "Validation Error",
  "status": 400,
  "detail": "One or more fields failed validation",
  "instance": "/users",
  "errors": [
    {
      "field": "email",
      "message": "Invalid email format",
      "code": "INVALID_EMAIL"
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

**Error structure components:**

**Required fields:**
- `type` - URI identifying error type (for docs)
- `title` - Human-readable summary
- `status` - HTTP status code (redundant but helpful)

**Optional fields:**
- `detail` - Specific error explanation
- `instance` - URI of specific occurrence
- `errors` - Field-level validation errors (array)
- `requestId` - Trace ID for debugging
- `timestamp` - When error occurred

**Field-level validation errors:**
```json
{
  "status": 400,
  "title": "Validation Error",
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
      "constraint": {"minLength": 8}
    }
  ]
}
```

**Common error codes:**

```javascript
// Error code enum
const ErrorCodes = {
  // Validation (400)
  INVALID_EMAIL: 'INVALID_EMAIL',
  REQUIRED_FIELD: 'REQUIRED_FIELD',
  VALUE_TOO_LONG: 'VALUE_TOO_LONG',
  
  // Authentication (401)
  INVALID_CREDENTIALS: 'INVALID_CREDENTIALS',
  TOKEN_EXPIRED: 'TOKEN_EXPIRED',
  
  // Authorization (403)
  INSUFFICIENT_PERMISSIONS: 'INSUFFICIENT_PERMISSIONS',
  
  // Not Found (404)
  RESOURCE_NOT_FOUND: 'RESOURCE_NOT_FOUND',
  
  // Conflict (409)
  DUPLICATE_EMAIL: 'DUPLICATE_EMAIL',
  RESOURCE_LOCKED: 'RESOURCE_LOCKED',
  
  // Rate Limit (429)
  RATE_LIMIT_EXCEEDED: 'RATE_LIMIT_EXCEEDED',
  
  // Server Error (500)
  INTERNAL_ERROR: 'INTERNAL_ERROR',
  DATABASE_ERROR: 'DATABASE_ERROR'
};
```

**Error middleware (Express):**
```javascript
app.use((err, req, res, next) => {
  const status = err.status || 500;
  
  const errorResponse = {
    type: `https://api.example.com/errors/${err.code}`,
    title: err.message,
    status: status,
    detail: err.detail,
    instance: req.path,
    requestId: req.id,
    timestamp: new Date().toISOString()
  };
  
  // Add validation errors if present
  if (err.validationErrors) {
    errorResponse.errors = err.validationErrors;
  }
  
  // Log server errors (500+)
  if (status >= 500) {
    logger.error('Server error', {
      error: err,
      requestId: req.id,
      stack: err.stack
    });
  }
  
  res.status(status).json(errorResponse);
});
```

### 4. API Versioning Strategies (~1,000 words)

**Why versioning matters:**
- APIs evolve (new fields, changed behavior)
- Can't break existing clients
- Need migration path

**Strategy 1: URL versioning (most common)**

```
GET /v1/users/123
GET /v2/users/123
```

**Pros:**
- Explicit, easy to understand
- Easy to route (different handlers per version)
- Cache-friendly (different URLs)

**Cons:**
- Clutters URL structure
- Must maintain multiple codebases

**Implementation:**
```javascript
// Express routing
app.use('/v1', v1Routes);
app.use('/v2', v2Routes);

// v1Routes
router.get('/users/:id', async (req, res) => {
  const user = await db.users.findById(req.params.id);
  res.json({
    id: user.id,
    name: user.name,
    email: user.email
  });
});

// v2Routes (added new fields)
router.get('/users/:id', async (req, res) => {
  const user = await db.users.findById(req.params.id);
  res.json({
    id: user.id,
    name: user.name,
    email: user.email,
    createdAt: user.created_at,  // New field
    profileUrl: `/users/${user.id}/profile`  // New field
  });
});
```

**Strategy 2: Header versioning**

```http
GET /users/123
Accept: application/vnd.api+json; version=2
```

**Pros:**
- Clean URLs
- Proper use of HTTP semantics

**Cons:**
- Less discoverable
- Harder to test (need header)
- Caching complexity

**Strategy 3: Query parameter versioning**

```
GET /users/123?version=2
```

**Pros:**
- Easy to test
- Explicit in URL

**Cons:**
- Pollutes query params
- Inconsistent with resource filtering

**Deprecation strategy:**

**Deprecation headers:**
```http
HTTP/1.1 200 OK
Deprecation: true
Sunset: Sat, 31 Dec 2024 23:59:59 GMT
Link: <https://api.example.com/v2/users/123>; rel="successor-version"
```

**Deprecation response:**
```json
{
  "data": {...},
  "_deprecated": {
    "version": "v1",
    "sunsetDate": "2024-12-31",
    "migrationGuide": "https://docs.example.com/v1-to-v2",
    "newEndpoint": "https://api.example.com/v2/users/123"
  }
}
```

**Migration timeline:**
```
Month 0: Announce v2, v1 fully supported
Month 3: v1 deprecated warnings added
Month 6: v1 read-only (no POST/PUT/DELETE)
Month 9: v1 sunset (returns 410 Gone)
```

**Semantic versioning for APIs:**
- **Major (v1 → v2):** Breaking changes
- **Minor (v1.1 → v1.2):** Additive changes (backward compatible)
- **Patch (v1.1.0 → v1.1.1):** Bug fixes

### 5. Rate Limiting (~900 words)

**Why rate limiting:**
- Prevent abuse
- Ensure fair usage
- Protect infrastructure

**Standard headers (IETF draft):**
```http
HTTP/1.1 200 OK
RateLimit-Limit: 100
RateLimit-Remaining: 42
RateLimit-Reset: 1642089600
```

**When limit exceeded:**
```http
HTTP/1.1 429 Too Many Requests
RateLimit-Limit: 100
RateLimit-Remaining: 0
RateLimit-Reset: 1642089600
Retry-After: 60

{
  "status": 429,
  "title": "Rate Limit Exceeded",
  "detail": "You have exceeded the rate limit of 100 requests per minute",
  "retryAfter": 60,
  "limit": 100,
  "remaining": 0,
  "resetAt": "2024-01-15T10:31:00Z"
}
```

**Implementation patterns:**

**Token bucket algorithm:**
```javascript
class TokenBucket {
  constructor(capacity, refillRate) {
    this.capacity = capacity;
    this.tokens = capacity;
    this.refillRate = refillRate; // tokens per second
    this.lastRefill = Date.now();
  }
  
  refill() {
    const now = Date.now();
    const elapsed = (now - this.lastRefill) / 1000;
    const tokensToAdd = elapsed * this.refillRate;
    
    this.tokens = Math.min(this.capacity, this.tokens + tokensToAdd);
    this.lastRefill = now;
  }
  
  tryConsume(tokens = 1) {
    this.refill();
    
    if (this.tokens >= tokens) {
      this.tokens -= tokens;
      return true;
    }
    
    return false;
  }
}
```

**Redis-based rate limiting:**
```javascript
async function checkRateLimit(userId, limit, windowSeconds) {
  const key = `ratelimit:${userId}:${Math.floor(Date.now() / 1000 / windowSeconds)}`;
  
  const current = await redis.incr(key);
  
  if (current === 1) {
    await redis.expire(key, windowSeconds);
  }
  
  return {
    allowed: current <= limit,
    remaining: Math.max(0, limit - current),
    resetAt: Math.ceil(Date.now() / 1000 / windowSeconds) * windowSeconds
  };
}
```

**Tiered rate limits:**
```javascript
const rateLimits = {
  free: {limit: 100, window: 3600},      // 100/hour
  basic: {limit: 1000, window: 3600},    // 1000/hour
  premium: {limit: 10000, window: 3600}, // 10000/hour
  enterprise: {limit: 100000, window: 3600} // 100K/hour
};
```

**Distributed rate limiting (multi-server):**
- Use Redis with atomic operations
- Use API gateway (Kong, AWS API Gateway)
- Use dedicated service (rate-limiter microservice)

### 6. Content Negotiation (~800 words)

**Accept headers:**
```http
GET /users/123
Accept: application/json
Accept: application/msgpack
Accept: application/xml
```

**Response:**
```http
HTTP/1.1 200 OK
Content-Type: application/json

{...}
```

**Format negotiation:**
```javascript
app.get('/users/:id', async (req, res) => {
  const user = await db.users.findById(req.params.id);
  
  res.format({
    'application/json': () => {
      res.json(user);
    },
    'application/msgpack': () => {
      res.type('application/msgpack');
      res.send(msgpack.encode(user));
    },
    'default': () => {
      res.status(406).json({error: 'Not Acceptable'});
    }
  });
});
```

**Compression:**
```http
GET /users
Accept-Encoding: gzip, deflate, br

HTTP/1.1 200 OK
Content-Encoding: gzip
Vary: Accept-Encoding
```

**Language selection:**
```http
GET /users/123
Accept-Language: en-US, es;q=0.8

HTTP/1.1 200 OK
Content-Language: en-US

{
  "message": "User not found"
}
```

### 7. Security Patterns (~1,100 words)

**Building on Chapter 8 (JWT, JWS, JWE)**

**HTTPS enforcement:**
```javascript
// Redirect HTTP to HTTPS
app.use((req, res, next) => {
  if (req.headers['x-forwarded-proto'] !== 'https') {
    return res.redirect(301, `https://${req.hostname}${req.url}`);
  }
  next();
});

// HSTS header
app.use((req, res, next) => {
  res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
  next();
});
```

**CORS configuration:**
```javascript
app.use(cors({
  origin: (origin, callback) => {
    const allowedOrigins = [
      'https://app.example.com',
      'https://admin.example.com'
    ];
    
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

**Input validation (JSON Schema):**
```javascript
const createUserSchema = {
  type: 'object',
  required: ['email', 'password', 'name'],
  properties: {
    email: {
      type: 'string',
      format: 'email',
      maxLength: 255
    },
    password: {
      type: 'string',
      minLength: 8,
      maxLength: 128
    },
    name: {
      type: 'string',
      minLength: 1,
      maxLength: 100
    }
  },
  additionalProperties: false
};

app.post('/users', validate(createUserSchema), async (req, res) => {
  // req.body is validated
  const user = await createUser(req.body);
  res.status(201).json(user);
});
```

**SQL injection prevention:**
```javascript
// BAD - vulnerable to SQL injection
const query = `SELECT * FROM users WHERE email = '${req.body.email}'`;

// GOOD - parameterized query
const query = 'SELECT * FROM users WHERE email = $1';
const result = await db.query(query, [req.body.email]);
```

**XSS prevention in JSON responses:**
```javascript
// Escape user-generated content
function escapeHtml(unsafe) {
  return unsafe
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

// Set Content-Type correctly
res.setHeader('Content-Type', 'application/json; charset=utf-8');
res.setHeader('X-Content-Type-Options', 'nosniff');
```

**Authentication flow (JWT from Chapter 8):**
```javascript
// Protected endpoint
app.get('/users/me', authenticate, async (req, res) => {
  // req.user populated by authenticate middleware
  const user = await db.users.findById(req.user.id);
  res.json(user);
});

// Authenticate middleware
async function authenticate(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  
  if (!token) {
    return res.status(401).json({
      status: 401,
      title: 'Authentication Required',
      detail: 'Authorization header missing'
    });
  }
  
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET, {
      algorithms: ['HS256']
    });
    
    req.user = decoded;
    next();
  } catch (error) {
    return res.status(401).json({
      status: 401,
      title: 'Invalid Token',
      detail: error.message
    });
  }
}
```

---

## Writing Plan

**Phase 1 (Session 1):** Fundamentals + Pagination
- Sections 1-2 (~2,200 words)
- REST principles, resource naming
- Pagination patterns with comparisons

**Phase 2 (Session 2):** Errors + Versioning + Rate Limiting
- Sections 3-5 (~2,900 words)
- Error formats, versioning strategies
- Rate limiting implementations

**Phase 3 (Session 3):** Content Negotiation + Security
- Sections 6-7 (~1,900 words)
- Format negotiation
- Security hardening

---

## Cross-References

**To other chapters:**
- Chapter 3: JSON Schema for request validation
- Chapter 5: MessagePack/CBOR for content negotiation
- Chapter 6: JSON-RPC vs REST comparison
- Chapter 8: JWT authentication, security patterns

**Real-world API references:**
- GitHub API v3 (REST maturity, pagination)
- Stripe API (error handling, versioning)
- Twitter API (cursor pagination)
- AWS APIs (header versioning)
