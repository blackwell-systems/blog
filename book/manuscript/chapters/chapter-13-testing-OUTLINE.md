# Chapter 13: Testing JSON Systems - DETAILED OUTLINE

**Target:** 6,000 words  
**Status:** Research and incremental writing phase  
**Foundation:** Chapters 3 (Schema), 8 (Security), 11 (API Design) provide context

---

## Core Thesis

**The Testing Gap:** JSON systems need comprehensive testing - not just "does it work?" but "does it handle all cases, edge conditions, attacks, and schema changes?"

**Testing layers for JSON systems:**
- **Schema testing:** Does data match contracts?
- **Contract testing:** Do services agree on interfaces?
- **API testing:** Do endpoints behave correctly?
- **Security testing:** Are vulnerabilities prevented?
- **Performance testing:** Does it scale?
- **Fuzz testing:** Does it crash on malformed input?

**Pattern:** Testing is part of the modular ecosystem. JSON provides data, testing ensures reliability.

---

## Structure (6,000 words breakdown)

### 1. Schema-Based Testing (~1,000 words)

**Generating test data from JSON Schema:**

**Schema:**
```json
{
  "type": "object",
  "required": ["email", "age"],
  "properties": {
    "email": {"type": "string", "format": "email"},
    "age": {"type": "integer", "minimum": 18, "maximum": 120},
    "tags": {"type": "array", "items": {"type": "string"}}
  }
}
```

**Generated test cases (JavaScript):**
```javascript
const {faker} = require('@faker-js/faker');
const jsf = require('json-schema-faker');

jsf.extend('faker', () => faker);

// Generate valid test data
const validUser = jsf.generate(userSchema);
// {email: "alice@example.com", age: 42, tags: ["tag1"]}

// Generate invalid test data
const invalidUser = {
  email: "not-an-email",  // Format violation
  age: 15,                // Below minimum
  tags: "should be array" // Type violation
};
```

**Property-based testing (hypothesis/fast-check):**

**JavaScript (fast-check):**
```javascript
const fc = require('fast-check');

test('User email is always valid', () => {
  fc.assert(
    fc.property(
      fc.emailAddress(),
      fc.integer({min: 18, max: 120}),
      (email, age) => {
        const user = {email, age};
        return validate(user) === true;
      }
    )
  );
});

test('Invalid emails always rejected', () => {
  fc.assert(
    fc.property(
      fc.string().filter(s => !s.includes('@')),
      (notEmail) => {
        const user = {email: notEmail, age: 25};
        return validate(user) === false;
      }
    )
  );
});
```

**Python (hypothesis):**
```python
from hypothesis import given, strategies as st
import jsonschema

@given(
    email=st.emails(),
    age=st.integers(min_value=18, max_value=120)
)
def test_valid_users_pass_validation(email, age):
    user = {"email": email, "age": age}
    jsonschema.validate(user, schema)  # Should not raise

@given(
    email=st.text().filter(lambda s: '@' not in s),
    age=st.integers(min_value=0, max_value=17)
)
def test_invalid_users_fail_validation(email, age):
    user = {"email": email, "age": age}
    with pytest.raises(jsonschema.ValidationError):
        jsonschema.validate(user, schema)
```

**Mutation testing schemas:**

Test that schema actually validates what it should:

```javascript
// Original schema requires email
const schema = {
  type: 'object',
  required: ['email'],
  properties: {
    email: {type: 'string', format: 'email'}
  }
};

// Mutation 1: Remove required
const mutated1 = {
  type: 'object',
  properties: {email: {type: 'string', format: 'email'}}
};

// Test: Missing email should fail with original, pass with mutated
test('Schema actually requires email', () => {
  const noEmail = {name: 'Alice'};
  
  expect(validate(noEmail, schema)).toBe(false);
  expect(validate(noEmail, mutated1)).toBe(true);
});
```

### 2. Contract Testing (~1,100 words)

**Consumer-driven contracts with Pact:**

**Consumer test (Frontend):**
```javascript
const { Pact } = require('@pact-foundation/pact');
const axios = require('axios');

const provider = new Pact({
  consumer: 'WebApp',
  provider: 'UserAPI'
});

describe('User API contract', () => {
  beforeAll(() => provider.setup());
  afterAll(() => provider.finalize());
  
  test('GET /users/:id returns user', async () => {
    await provider.addInteraction({
      state: 'user 123 exists',
      uponReceiving: 'a request for user 123',
      withRequest: {
        method: 'GET',
        path: '/users/123',
        headers: {Accept: 'application/json'}
      },
      willRespondWith: {
        status: 200,
        headers: {'Content-Type': 'application/json'},
        body: {
          id: '123',
          name: 'Alice',
          email: 'alice@example.com'
        }
      }
    });
    
    const response = await axios.get('http://localhost:1234/users/123');
    expect(response.data.email).toBe('alice@example.com');
  });
});
```

**Provider verification (Backend):**
```javascript
const { Verifier } = require('@pact-foundation/pact');

describe('Pact Verification', () => {
  test('validates contracts', async () => {
    await new Verifier({
      providerBaseUrl: 'http://localhost:3000',
      pactUrls: ['./pacts/webapp-userapi.json'],
      stateHandlers: {
        'user 123 exists': async () => {
          await db.users.insert({
            id: '123',
            name: 'Alice',
            email: 'alice@example.com'
          });
        }
      }
    }).verifyProvider();
  });
});
```

**Breaking change detection:**

```javascript
// Contract specifies required fields
const contract = {
  response: {
    body: {
      id: string,
      name: string,
      email: string  // Consumer requires this
    }
  }
};

// Provider removes email field → verification fails
// Catches breaking change before deployment
```

**Contract evolution:**
```javascript
// Add optional field (backwards compatible)
const contractV2 = {
  response: {
    body: {
      id: string,
      name: string,
      email: string,
      phone: optional(string)  // New optional field - safe
    }
  }
};
```

**Go contract testing:**
```go
// Consumer expectations
type UserResponse struct {
    ID    string `json:"id"`
    Name  string `json:"name"`
    Email string `json:"email"`
}

func TestUserAPIContract(t *testing.T) {
    pact := dsl.Pact{
        Consumer: "UserService",
        Provider: "UserAPI",
    }
    
    pact.AddInteraction().
        Given("User 123 exists").
        UponReceiving("A request for user 123").
        WithRequest(dsl.Request{
            Method: "GET",
            Path:   "/users/123",
        }).
        WillRespondWith(dsl.Response{
            Status: 200,
            Body:   UserResponse{},
        })
    
    // Verify provider honors contract
    pact.Verify(t)
}
```

### 3. API Testing Strategies (~1,000 words)

**Unit testing endpoints:**

**Node.js (Express + Supertest):**
```javascript
const request = require('supertest');
const app = require('./app');

describe('GET /users/:id', () => {
  test('returns 200 and user data', async () => {
    const response = await request(app)
      .get('/users/123')
      .expect(200)
      .expect('Content-Type', /json/);
    
    expect(response.body).toMatchObject({
      id: '123',
      name: expect.any(String),
      email: expect.stringMatching(/@/)
    });
  });
  
  test('returns 404 for nonexistent user', async () => {
    await request(app)
      .get('/users/999')
      .expect(404)
      .expect(res => {
        expect(res.body.status).toBe(404);
        expect(res.body.title).toContain('Not Found');
      });
  });
  
  test('validates authentication', async () => {
    await request(app)
      .get('/users/123')
      .set('Authorization', 'Bearer invalid-token')
      .expect(401);
  });
});
```

**Go (httptest):**
```go
func TestGetUser(t *testing.T) {
    req := httptest.NewRequest("GET", "/users/123", nil)
    w := httptest.NewRecorder()
    
    handler := http.HandlerFunc(GetUserHandler)
    handler.ServeHTTP(w, req)
    
    assert.Equal(t, 200, w.Code)
    
    var user User
    json.Unmarshal(w.Body.Bytes(), &user)
    assert.Equal(t, "123", user.ID)
    assert.NotEmpty(t, user.Email)
}

func TestGetUserNotFound(t *testing.T) {
    req := httptest.NewRequest("GET", "/users/999", nil)
    w := httptest.NewRecorder()
    
    handler := http.HandlerFunc(GetUserHandler)
    handler.ServeHTTP(w, req)
    
    assert.Equal(t, 404, w.Code)
    
    var errorResp ErrorResponse
    json.Unmarshal(w.Body.Bytes(), &errorResp)
    assert.Equal(t, 404, errorResp.Status)
}
```

**Mocking JSON responses:**

**JavaScript (nock):**
```javascript
const nock = require('nock');

test('handles API errors gracefully', async () => {
  nock('https://api.example.com')
    .get('/users/123')
    .reply(500, {
      status: 500,
      title: 'Internal Server Error'
    });
  
  await expect(fetchUser('123')).rejects.toThrow('Server error');
});

test('retries on transient failures', async () => {
  nock('https://api.example.com')
    .get('/users/123')
    .reply(503)
    .get('/users/123')
    .reply(200, {id: '123', name: 'Alice'});
  
  const user = await fetchUser('123');
  expect(user.name).toBe('Alice');
});
```

**Snapshot testing:**
```javascript
test('API response structure unchanged', async () => {
  const response = await request(app).get('/users/123');
  expect(response.body).toMatchSnapshot();
});
```

### 4. Security Testing (~800 words)

**JWT validation testing:**

```javascript
describe('JWT security', () => {
  test('rejects none algorithm', () => {
    const malicious = createToken({alg: 'none'});
    expect(() => verifyToken(malicious)).toThrow('Invalid algorithm');
  });
  
  test('rejects algorithm confusion', () => {
    const malicious = createTokenHS256WithPublicKey();
    expect(() => verifyToken(malicious, publicKey)).toThrow();
  });
  
  test('rejects expired tokens', () => {
    const expired = createToken({exp: Date.now() - 1000});
    expect(() => verifyToken(expired)).toThrow('Token expired');
  });
  
  test('validates audience claim', () => {
    const wrongAud = createToken({aud: 'https://wrong.com'});
    expect(() => verifyToken(wrongAud)).toThrow('Invalid audience');
  });
});
```

**Injection attack testing:**

```javascript
test('prevents SQL injection via JSON', async () => {
  const malicious = {
    email: "' OR '1'='1",
    password: "anything"
  };
  
  const response = await request(app)
    .post('/login')
    .send(malicious)
    .expect(401);
  
  // Should fail authentication, not expose SQL error
  expect(response.body.title).not.toContain('SQL');
});

test('prevents JSON injection in user profile', async () => {
  const malicious = {
    bio: '{"admin": true}'  // Attempt to inject JSON
  };
  
  const response = await request(app)
    .patch('/users/me')
    .set('Authorization', `Bearer ${userToken}`)
    .send(malicious);
  
  // Bio should be stored as string, not parsed
  const user = await db.users.find(userId);
  expect(typeof user.bio).toBe('string');
  expect(user.admin).toBeUndefined();
});
```

**Rate limiting verification:**
```javascript
test('enforces rate limits', async () => {
  // Send 101 requests (limit is 100)
  const requests = Array(101).fill().map(() => 
    request(app).get('/users')
  );
  
  const responses = await Promise.all(requests);
  
  // Last request should be rate-limited
  const lastResponse = responses[100];
  expect(lastResponse.status).toBe(429);
  expect(lastResponse.headers['ratelimit-remaining']).toBe('0');
});
```

### 5. Performance Testing (~800 words)

**Load testing with k6:**

```javascript
// load-test.js
import http from 'k6/http';
import {check, sleep} from 'k6';

export const options = {
  stages: [
    {duration: '30s', target: 100},  // Ramp to 100 users
    {duration: '1m', target: 100},   // Stay at 100
    {duration: '30s', target: 0}     // Ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% under 500ms
    http_req_failed: ['rate<0.01']    // Error rate < 1%
  }
};

export default function() {
  const response = http.get('https://api.example.com/users');
  
  check(response, {
    'status is 200': (r) => r.status === 200,
    'response is JSON': (r) => r.headers['Content-Type'].includes('application/json'),
    'has pagination': (r) => JSON.parse(r.body).pagination !== undefined
  });
  
  sleep(1);
}
```

**Benchmarking serialization:**

**Go benchmarks:**
```go
func BenchmarkJSONMarshal(b *testing.B) {
    user := User{ID: "123", Name: "Alice", Email: "alice@example.com"}
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        json.Marshal(user)
    }
}

func BenchmarkMessagePackMarshal(b *testing.B) {
    user := User{ID: "123", Name: "Alice", Email: "alice@example.com"}
    
    b.ResetTimer()
    for i := 0; i < b.N; i++ {
        msgpack.Marshal(user)
    }
}

// Results:
// BenchmarkJSONMarshal-8         1000000    1052 ns/op
// BenchmarkMessagePackMarshal-8  2000000     654 ns/op
```

**Memory profiling:**
```javascript
// Measure memory usage
const {performance} = require('perf_hooks');

test('large JSON parsing memory', async () => {
  const before = process.memoryUsage().heapUsed;
  
  // Parse 10MB JSON file
  const data = JSON.parse(fs.readFileSync('large.json', 'utf8'));
  
  const after = process.memoryUsage().heapUsed;
  const used = (after - before) / 1024 / 1024; // MB
  
  console.log(`Memory used: ${used.toFixed(2)} MB`);
  expect(used).toBeLessThan(100); // Assert reasonable limit
});
```

**Throughput testing:**
```bash
# Apache Bench
ab -n 10000 -c 100 https://api.example.com/users

# Results:
# Requests per second: 1523.45 [#/sec]
# Time per request: 65.639 [ms] (mean)
# Time per request: 0.656 [ms] (mean, across all concurrent requests)
```

### 6. Fuzz Testing (~700 words)

**Generating malformed JSON:**

**Go fuzzing (Go 1.18+):**
```go
func FuzzJSONParser(f *testing.F) {
    // Seed corpus
    f.Add(`{"name":"Alice"}`)
    f.Add(`{"age":30}`)
    f.Add(`[]`)
    
    f.Fuzz(func(t *testing.T, input string) {
        var result interface{}
        
        // Should not crash, even on malformed input
        _ = json.Unmarshal([]byte(input), &result)
    })
}

// Run: go test -fuzz=FuzzJSONParser -fuzztime=30s
```

**Malformed JSON test cases:**

```javascript
const malformedCases = [
  '{',                       // Incomplete
  '{"name": }',              // Missing value
  '{"name": "Alice"',        // Missing closing brace
  '{"name": "Alice",}',      // Trailing comma (invalid JSON)
  '{name: "Alice"}',         // Unquoted key
  "{'name': 'Alice'}",       // Single quotes
  '{"name": undefined}',     // Undefined
  '{"a":' + 'x'.repeat(1e6) + '}',  // Huge string
  '[' + '1,'.repeat(1e6) + '1]',    // Huge array
  '{"a":{"b":'.repeat(1000) + '{}' + '}'.repeat(1000)  // Deep nesting
];

describe('Parser handles malformed JSON', () => {
  malformedCases.forEach((input, i) => {
    test(`case ${i}: doesn't crash`, () => {
      expect(() => JSON.parse(input)).toThrow();
      // Throws error, doesn't crash process
    });
  });
});
```

**Deep recursion attack:**
```javascript
test('rejects deeply nested JSON (DoS prevention)', () => {
  const depth = 10000;
  const nested = '{"a":'.repeat(depth) + '{}' + '}'.repeat(depth);
  
  expect(() => {
    JSON.parse(nested);
  }).toThrow(/depth|recursion|stack/i);
});
```

**Large payload attack:**
```javascript
test('rejects huge payloads', async () => {
  const huge = {data: 'x'.repeat(10 * 1024 * 1024)}; // 10MB
  
  await request(app)
    .post('/users')
    .send(huge)
    .expect(413); // Payload Too Large
});
```

### 7. Integration Testing (~600 words)

**Testing with real database:**

```javascript
describe('User API integration tests', () => {
  let db;
  
  beforeAll(async () => {
    // Start test database (Docker)
    db = await startTestDB();
  });
  
  afterAll(async () => {
    await stopTestDB(db);
  });
  
  beforeEach(async () => {
    // Clean state for each test
    await db.query('TRUNCATE users CASCADE');
  });
  
  test('creates user and retrieves it', async () => {
    // Create
    const createRes = await request(app)
      .post('/users')
      .send({name: 'Alice', email: 'alice@example.com'})
      .expect(201);
    
    const userId = createRes.body.id;
    
    // Retrieve
    const getRes = await request(app)
      .get(`/users/${userId}`)
      .expect(200);
    
    expect(getRes.body.email).toBe('alice@example.com');
  });
});
```

**Python integration tests:**
```python
import pytest
from fastapi.testclient import TestClient

@pytest.fixture
def client(test_db):
    app.dependency_overrides[get_db] = lambda: test_db
    with TestClient(app) as c:
        yield c

def test_create_and_get_user(client, test_db):
    # Create user
    response = client.post('/users', json={
        'name': 'Alice',
        'email': 'alice@example.com'
    })
    assert response.status_code == 201
    user_id = response.json()['id']
    
    # Retrieve user
    response = client.get(f'/users/{user_id}')
    assert response.status_code == 200
    assert response.json()['email'] == 'alice@example.com'
```

**Testing JSON transformation pipelines:**
```javascript
test('pipeline transforms data correctly', async () => {
  const input = [
    {id: 1, firstName: 'Alice', lastName: 'Smith'},
    {id: 2, firstName: 'Bob', lastName: 'Jones'}
  ];
  
  const output = await runPipeline(input);
  
  expect(output).toEqual([
    {userId: 1, fullName: 'Alice Smith'},
    {userId: 2, fullName: 'Bob Jones'}
  ]);
});
```

### 8. CI/CD Integration (~500 words)

**GitHub Actions workflow:**

```yaml
name: API Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: 18
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run unit tests
        run: npm test
      
      - name: Run integration tests
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://postgres:test@localhost:5432/test
      
      - name: Run contract tests
        run: npm run test:pact
      
      - name: Verify Pact contracts
        run: npm run pact:verify
      
      - name: Run load tests
        run: npm run test:load
      
      - name: Upload coverage
        uses: codecov/codecov-action@v3
```

**Test pyramid for JSON APIs:**

```
        /\
       /  \
      / E2E \        10% - Full system tests
     /--------\
    /          \
   / Integration \   30% - API + database
  /--------------\
 /                \
/  Unit Tests      \ 60% - Business logic
--------------------
```

---

## Writing Plan

**Phase 1 (Session 1):** Schema + Contract Testing
- Sections 1-2 (~2,100 words)
- Property-based testing
- Contract testing with Pact

**Phase 2 (Session 2):** API + Security Testing
- Sections 3-4 (~1,800 words)
- Endpoint testing
- Security vulnerability tests

**Phase 3 (Session 3):** Performance + Integration + CI/CD
- Sections 5-8 (~2,100 words)
- Load testing
- Integration patterns
- Pipeline integration

---

## Cross-References

**To other chapters:**
- Chapter 3: JSON Schema (basis for schema-based testing)
- Chapter 8: Security (JWT validation testing)
- Chapter 11: API Design (patterns to test)
- Chapter 12: Data Pipelines (pipeline testing)
