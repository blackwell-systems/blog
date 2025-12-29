# Chapter 13: Testing JSON Systems

*JSON systems need comprehensive testing strategies that go beyond simple "does it work?" checks. Production systems require validation of schemas, contracts, performance, security, and resilience against malformed input.*

---

JSON's flexibility creates unique testing challenges. Unlike strongly-typed systems where many errors surface at compile time, JSON systems defer validation to runtime. This means comprehensive testing becomes critical for reliability, security, and performance.

Consider this common scenario: An API returns user data that evolves over time. Version 1 has simple fields, but Version 2 adds nested objects and arrays. Without proper testing:

```json
// Version 1: Works fine
{"id": "123", "name": "Alice", "email": "alice@example.com"}

// Version 2: Breaks downstream consumers
{
  "id": "123", 
  "name": "Alice", 
  "email": "alice@example.com",
  "preferences": {
    "notifications": ["email", "sms"],
    "privacy": {"profile": "public", "activity": "private"}
  }
}
```

Client code expecting flat objects suddenly receives nested data. Without schema validation and contract testing, this change propagates as runtime errors throughout the system.

This chapter explores comprehensive testing strategies for JSON systems: schema-based testing that generates valid and invalid data automatically, contract testing that prevents breaking changes, API testing that validates behavior, security testing that prevents attacks, performance testing that ensures scalability, and fuzz testing that finds edge cases.

The goal is building JSON systems that fail fast, fail safely, and provide clear feedback when things go wrong.


![Diagram 1](chapter-13-testing-diagram-1-light.png){width=85%}


## 1. Schema-Based Testing

JSON Schema provides the foundation for systematic testing by defining data contracts that can generate both valid test data and invalid edge cases automatically. This approach scales testing beyond manual examples to comprehensive property-based validation.

### Generating Test Data from Schemas

JSON Schema serves as a machine-readable specification for generating test cases:

```json
{
  "type": "object",
  "required": ["email", "age"],
  "properties": {
    "email": {"type": "string", "format": "email"},
    "age": {"type": "integer", "minimum": 18, "maximum": 120},
    "name": {"type": "string", "minLength": 1, "maxLength": 50},
    "tags": {
      "type": "array",
      "items": {"type": "string"},
      "minItems": 0,
      "maxItems": 10
    },
    "preferences": {
      "type": "object",
      "properties": {
        "newsletter": {"type": "boolean"},
        "theme": {"enum": ["light", "dark", "auto"]}
      }
    }
  },
  "additionalProperties": false
}
```

**Generating valid test data:**

```javascript
const { faker } = require('@faker-js/faker');
const jsf = require('json-schema-faker');

jsf.extend('faker', () => faker);

function generateTestData(schema, count = 100) {
  const testCases = [];
  
  for (let i = 0; i < count; i++) {
    const generated = jsf.generate(schema);
    testCases.push(generated);
  }
  
  return testCases;
}

// Generate 100 valid user objects
const validUsers = generateTestData(userSchema, 100);

// Each generated object follows schema constraints:
// {
//   "email": "margarette.shields@yahoo.com",
//   "age": 42,
//   "name": "Margarette Shields", 
//   "tags": ["developer", "javascript"],
//   "preferences": {
//     "newsletter": true,
//     "theme": "dark"
//   }
// }
```

**Generating invalid test data for edge case testing:**

```javascript
function generateInvalidTestData(schema) {
  const invalidCases = [];
  
  // Missing required fields
  invalidCases.push({
    description: "Missing email field",
    data: { age: 25, name: "Alice" }
  });
  
  // Invalid types
  invalidCases.push({
    description: "Age as string",
    data: { email: "alice@example.com", age: "twenty-five" }
  });
  
  // Constraint violations
  invalidCases.push({
    description: "Age below minimum",
    data: { email: "kid@example.com", age: 12 }
  });
  
  invalidCases.push({
    description: "Email without format",
    data: { email: "not-an-email", age: 25 }
  });
  
  // Additional properties
  invalidCases.push({
    description: "Unexpected field",
    data: { email: "alice@example.com", age: 25, admin: true }
  });
  
  // Array constraint violations
  invalidCases.push({
    description: "Too many tags",
    data: { 
      email: "alice@example.com", 
      age: 25, 
      tags: new Array(15).fill("tag") // Exceeds maxItems: 10
    }
  });
  
  return invalidCases;
}
```

### Property-Based Testing

Property-based testing goes beyond examples to test invariants across generated data:


![Diagram 2](chapter-13-testing-diagram-2-light.png){width=85%}


```javascript
const fc = require('fast-check');
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

const ajv = new Ajv({ allErrors: true });
addFormats(ajv);
const validate = ajv.compile(userSchema);

// Property: All generated valid data should pass schema validation
describe('User Schema Properties', () => {
  test('all generated users should be valid', () => {
    fc.assert(
      fc.property(
        fc.record({
          email: fc.emailAddress(),
          age: fc.integer({ min: 18, max: 120 }),
          name: fc.string({ minLength: 1, maxLength: 50 }),
          tags: fc.array(fc.string(), { maxLength: 10 }),
          preferences: fc.record({
            newsletter: fc.boolean(),
            theme: fc.oneof(fc.constant('light'), fc.constant('dark'), fc.constant('auto'))
          })
        }),
        (user) => {
          // Property: Generated data should always validate
          expect(validate(user)).toBe(true);
          
          // Property: Email should always contain @
          expect(user.email).toContain('@');
          
          // Property: Age should be in valid range
          expect(user.age).toBeGreaterThanOrEqual(18);
          expect(user.age).toBeLessThanOrEqual(120);
          
          // Property: Tags array should not exceed limit
          expect(user.tags.length).toBeLessThanOrEqual(10);
        }
      ),
      { numRuns: 1000 } // Test 1000 generated cases
    );
  });
  
  test('invalid data should fail validation', () => {
    fc.assert(
      fc.property(
        fc.record({
          email: fc.string(), // Not email format
          age: fc.oneof(fc.string(), fc.float()), // Wrong type
        }),
        (invalidUser) => {
          const isValid = validate(invalidUser);
          
          // Property: Invalid data should always fail
          expect(isValid).toBe(false);
          expect(validate.errors).toBeTruthy();
        }
      )
    );
  });
});
```

### Schema Mutation Testing

Test schema robustness by introducing small changes and verifying behavior:

```javascript
function mutateSchema(originalSchema) {
  const mutations = [];
  const schema = JSON.parse(JSON.stringify(originalSchema));
  
  // Mutation 1: Remove required field
  if (schema.required && schema.required.length > 0) {
    const mutation1 = JSON.parse(JSON.stringify(schema));
    mutation1.required = schema.required.slice(1); // Remove first required field
    mutations.push({
      description: "Remove required field",
      schema: mutation1,
      expectation: "Should allow previously invalid data"
    });
  }
  
  // Mutation 2: Tighten constraints
  if (schema.properties.age && schema.properties.age.minimum) {
    const mutation2 = JSON.parse(JSON.stringify(schema));
    mutation2.properties.age.minimum += 10; // Increase minimum age
    mutations.push({
      description: "Tighten age constraint",
      schema: mutation2,
      expectation: "Should reject previously valid data"
    });
  }
  
  // Mutation 3: Change type
  if (schema.properties.tags) {
    const mutation3 = JSON.parse(JSON.stringify(schema));
    mutation3.properties.tags.type = "string"; // Array to string
    mutations.push({
      description: "Change tags type",
      schema: mutation3,
      expectation: "Should reject array tags"
    });
  }
  
  return mutations;
}

describe('Schema Mutation Tests', () => {
  const mutations = mutateSchema(userSchema);
  
  mutations.forEach(({ description, schema, expectation }) => {
    test(`Mutation: ${description}`, () => {
      const validate = ajv.compile(schema);
      
      // Test with data that was valid under original schema
      const originallyValidData = {
        email: "alice@example.com",
        age: 20,
        tags: ["developer"]
      };
      
      const result = validate(originallyValidData);
      
      console.log(`${description}: ${expectation}`);
      console.log(`Result: ${result ? 'VALID' : 'INVALID'}`);
      if (!result) {
        console.log('Errors:', validate.errors);
      }
    });
  });
});
```

### Integration with Testing Frameworks

**Vitest integration with custom matchers:**

```javascript
import { expect } from 'vitest';

// Custom matcher for schema validation
expect.extend({
  toMatchSchema(received, schema) {
    const validate = ajv.compile(schema);
    const isValid = validate(received);
    
    return {
      message: () => 
        isValid 
          ? `Expected data not to match schema`
          : `Expected data to match schema. Errors: ${JSON.stringify(validate.errors, null, 2)}`,
      pass: isValid
    };
  }
});

// Usage in tests
describe('API Response Validation', () => {
  test('user endpoint returns valid data', async () => {
    const response = await fetch('/api/users/123');
    const user = await response.json();
    
    expect(user).toMatchSchema(userSchema);
  });
  
  test('invalid user data is rejected', () => {
    const invalidUser = { email: "not-email", age: "invalid" };
    
    expect(invalidUser).not.toMatchSchema(userSchema);
  });
});
```

**Go testing with generated data:**

```go
package main

import (
    "testing"
    "encoding/json"
    "github.com/stretchr/testify/assert"
    "github.com/brianvoe/gofakeit/v6"
)

type User struct {
    Email string   `json:"email" validate:"required,email"`
    Age   int      `json:"age" validate:"min=18,max=120"`
    Name  string   `json:"name" validate:"min=1,max=50"`
    Tags  []string `json:"tags" validate:"max=10"`
}

func generateValidUser() User {
    return User{
        Email: gofakeit.Email(),
        Age:   gofakeit.Number(18, 120),
        Name:  gofakeit.Name(),
        Tags:  gofakeit.Slice([]string{gofakeit.Word(), gofakeit.Word()}),
    }
}

func TestUserValidation(t *testing.T) {
    // Property-based test: All generated users should be valid
    for i := 0; i < 100; i++ {
        user := generateValidUser()
        
        // Should serialize to JSON without error
        data, err := json.Marshal(user)
        assert.NoError(t, err)
        
        // Should deserialize from JSON without error
        var decoded User
        err = json.Unmarshal(data, &decoded)
        assert.NoError(t, err)
        
        // Should match original data
        assert.Equal(t, user, decoded)
        
        // Should pass business validation
        assert.True(t, isValidUser(user))
    }
}

func TestInvalidUserData(t *testing.T) {
    invalidCases := []struct {
        name string
        user User
    }{
        {"invalid email", User{Email: "not-email", Age: 25}},
        {"age too low", User{Email: "valid@email.com", Age: 12}},
        {"age too high", User{Email: "valid@email.com", Age: 200}},
        {"name too long", User{Email: "valid@email.com", Age: 25, Name: strings.Repeat("a", 100)}},
    }
    
    for _, tc := range invalidCases {
        t.Run(tc.name, func(t *testing.T) {
            assert.False(t, isValidUser(tc.user))
        });
    }
}
```

Schema-based testing creates a foundation for reliable JSON systems by ensuring data contracts are enforced consistently. The combination of generated valid data, targeted invalid cases, property-based invariants, and mutation testing provides comprehensive coverage that scales automatically as schemas evolve.

## 2. Contract Testing with Pact

Contract testing ensures that services can communicate reliably by defining and verifying the interfaces between consumers and providers. Unlike integration tests that require running all services, contract tests verify agreements independently, catching breaking changes before they reach production.

### The Contract Testing Problem

Consider a typical microservice interaction where a frontend consumes user data from a backend API:


![Diagram 3](chapter-13-testing-diagram-3-light.png){width=85%}


```javascript
// Frontend expects this response format
const user = await fetch('/api/users/123').then(r => r.json());
// Assumes: { id: "123", name: "Alice", email: "alice@example.com" }

// Later, backend team adds nested structure
// New response: { 
//   id: "123", 
//   profile: { name: "Alice", email: "alice@example.com" },
//   metadata: { lastLogin: "2024-01-15" }
// }

// Frontend code breaks: user.name is undefined
```

Traditional integration tests might catch this, but they're expensive and slow. Contract testing catches interface mismatches without running the full system.

### Consumer-Driven Contract Testing

The consumer defines what it expects from the provider, creating a contract that both sides can verify:

**Consumer Test (Frontend):**

```javascript
const { PactV3, MatchersV3 } = require('@pact-foundation/pact');
const { like, eachLike, regex } = MatchersV3;

const provider = new PactV3({
  consumer: 'UserFrontend',
  provider: 'UserAPI',
  port: 1234,
  host: '127.0.0.1',
});

describe('User API Contract', () => {
  test('should return user data for valid ID', async () => {
    // Define expected interaction
    await provider
      .given('user 123 exists')
      .uponReceiving('a request for user 123')
      .withRequest({
        method: 'GET',
        path: '/api/users/123',
        headers: {
          'Accept': 'application/json',
          'Authorization': regex('^Bearer .+$', 'Bearer valid-token')
        }
      })
      .willRespondWith({
        status: 200,
        headers: {
          'Content-Type': 'application/json'
        },
        body: {
          id: like('123'),
          name: like('Alice Smith'),
          email: regex('^.+@.+$', 'alice@example.com'),
          createdAt: regex('\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z', '2024-01-15T10:30:00Z'),
          preferences: like({
            newsletter: true,
            theme: 'dark'
          })
        }
      });

    // Execute consumer code against mock provider
    const api = new UserAPI('http://127.0.0.1:1234');
    const user = await api.getUser('123');

    // Verify consumer expectations
    expect(user.id).toBe('123');
    expect(user.name).toBe('Alice Smith');
    expect(user.email).toContain('@');
    expect(user.preferences).toHaveProperty('newsletter');
    expect(user.preferences).toHaveProperty('theme');
  });

  test('should handle user not found', async () => {
    await provider
      .given('user 999 does not exist')
      .uponReceiving('a request for non-existent user')
      .withRequest({
        method: 'GET',
        path: '/api/users/999',
        headers: { 'Accept': 'application/json' }
      })
      .willRespondWith({
        status: 404,
        headers: { 'Content-Type': 'application/json' },
        body: {
          error: like('User not found'),
          code: like('USER_NOT_FOUND'),
          status: 404
        }
      });

    const api = new UserAPI('http://127.0.0.1:1234');
    
    await expect(api.getUser('999')).rejects.toThrow('User not found');
  });

  test('should handle authentication errors', async () => {
    await provider
      .given('user 123 exists')
      .uponReceiving('a request without authentication')
      .withRequest({
        method: 'GET',
        path: '/api/users/123',
        headers: { 'Accept': 'application/json' }
        // No Authorization header
      })
      .willRespondWith({
        status: 401,
        headers: { 'Content-Type': 'application/json' },
        body: {
          error: like('Authentication required'),
          code: like('AUTH_REQUIRED')
        }
      });

    const api = new UserAPI('http://127.0.0.1:1234');
    
    await expect(api.getUser('123')).rejects.toThrow('Authentication required');
  });
});
```

**Provider Verification (Backend):**

```javascript
// Provider verifies it can satisfy consumer expectations
const { Verifier } = require('@pact-foundation/pact');
const server = require('../src/server');

describe('User API Provider', () => {
  let app;
  
  beforeAll(async () => {
    app = await server.start(3000);
  });

  afterAll(async () => {
    await server.stop();
  });

  test('validates the expectations of UserFrontend', () => {
    return new Verifier({
      provider: 'UserAPI',
      providerBaseUrl: 'http://localhost:3000',
      
      // Pact files location (shared between consumer and provider)
      pactUrls: [
        path.resolve(__dirname, '../pacts/userfrontend-userapi.json')
      ],
      
      // Provider states - setup data for tests
      stateHandlers: {
        'user 123 exists': async () => {
          await database.users.create({
            id: '123',
            name: 'Alice Smith',
            email: 'alice@example.com',
            createdAt: '2024-01-15T10:30:00Z',
            preferences: { newsletter: true, theme: 'dark' }
          });
        },
        'user 999 does not exist': async () => {
          await database.users.deleteWhere({ id: '999' });
        }
      },
      
      // Request filters for authentication
      requestFilters: [(req, res, next) => {
        // Add valid auth for provider verification
        if (req.path.startsWith('/api/users') && !req.headers.authorization) {
          req.headers.authorization = 'Bearer valid-test-token';
        }
        next();
      }],
      
      // Ensure clean state
      beforeEach: async () => {
        await database.reset();
      }
      
    }).verifyProvider();
  });
});
```

### Advanced Contract Patterns

**Flexible Matching with Type-Based Contracts:**

```javascript
const { like, eachLike, term, regex } = MatchersV3;

// Complex nested objects with flexible matching
const userResponse = {
  id: like('abc-123'),                           // Any string
  profile: {
    name: like('Alice Smith'),                   // Any string
    email: regex('^[^@]+@[^@]+$', 'alice@example.com'), // Email format
    age: like(25),                               // Any number
    avatar: term({                               // Specific values
      generate: 'https://example.com/avatar.jpg',
      matcher: 'https://example\\.com/.*\\.(jpg|png)'
    })
  },
  preferences: like({                            // Any object with this structure
    notifications: eachLike('email'),            // Array of strings
    privacy: {
      profile: term({ generate: 'public', matcher: 'public|private' })
    }
  }),
  orders: eachLike({                             // Array of objects
    id: like('order-123'),
    amount: like(99.99),
    items: eachLike({
      productId: like('prod-456'),
      quantity: like(2)
    })
  }, { min: 1 })                               // At least one order
};
```

**Message Queue Contracts:**

```javascript
// Contract for asynchronous messaging
describe('Order Event Contracts', () => {
  test('order created event', async () => {
    const messagePact = new MessagePactV3({
      consumer: 'OrderProcessor',
      provider: 'OrderService'
    });

    await messagePact
      .expectsToReceive('order created event')
      .withContent({
        eventType: like('order.created'),
        timestamp: regex('\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}Z', '2024-01-15T10:30:00Z'),
        orderId: like('order-123'),
        customerId: like('customer-456'),
        items: eachLike({
          productId: like('prod-789'),
          quantity: like(2),
          price: like(29.99)
        }),
        totalAmount: like(59.98),
        metadata: like({
          source: 'web',
          campaign: 'holiday-sale'
        })
      })
      .withMetadata({
        'content-type': 'application/json',
        'event-source': 'order-service'
      });

    // Verify consumer can handle the message
    const handler = new OrderEventHandler();
    const message = messagePact.contents;
    
    await handler.process(message);
    
    // Verify processing results
    const processedOrder = await orderRepository.findById(message.orderId);
    expect(processedOrder.status).toBe('processing');
  });
});
```

### GraphQL Contract Testing

```javascript
const { GraphQLInteraction } = require('@pact-foundation/pact');

describe('GraphQL User API Contract', () => {
  test('should return user with orders', async () => {
    const graphqlInteraction = new GraphQLInteraction()
      .given('user 123 exists with orders')
      .uponReceiving('get user with orders query')
      .withRequest({
        path: '/graphql',
        method: 'POST'
      })
      .withQuery(`
        query GetUser($id: ID!) {
          user(id: $id) {
            id
            name
            email
            orders {
              id
              total
              status
            }
          }
        }
      `)
      .withVariables({ id: '123' })
      .willRespondWith({
        status: 200,
        headers: { 'Content-Type': 'application/json' },
        body: {
          data: {
            user: {
              id: like('123'),
              name: like('Alice Smith'),
              email: like('alice@example.com'),
              orders: eachLike({
                id: like('order-456'),
                total: like(99.99),
                status: regex('pending|completed|cancelled', 'completed')
              })
            }
          }
        }
      });

    await provider.addInteraction(graphqlInteraction);

    const client = new GraphQLClient('http://127.0.0.1:1234/graphql');
    const result = await client.query(GET_USER_WITH_ORDERS, { id: '123' });

    expect(result.user.id).toBe('123');
    expect(result.user.orders).toHaveLength(1);
    expect(result.user.orders[0]).toHaveProperty('total');
  });
});
```

### Contract Testing in CI/CD

**GitHub Actions Workflow:**

```yaml
name: Contract Tests

on: [push, pull_request]

jobs:
  consumer-contracts:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run consumer contract tests
        run: npm run test:contracts:consumer
      
      - name: Publish contracts to Pact Broker
        if: github.ref == 'refs/heads/main'
        run: npm run pact:publish
        env:
          PACT_BROKER_BASE_URL: ${{ secrets.PACT_BROKER_URL }}
          PACT_BROKER_TOKEN: ${{ secrets.PACT_BROKER_TOKEN }}

  provider-verification:
    runs-on: ubuntu-latest
    needs: consumer-contracts
    strategy:
      matrix:
        consumer: [UserFrontend, AdminDashboard, MobileApp]
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      
      - name: Start test database
        run: docker-compose up -d test-db
      
      - name: Run provider verification
        run: npm run test:contracts:provider
        env:
          PACT_CONSUMER: ${{ matrix.consumer }}
          PACT_BROKER_BASE_URL: ${{ secrets.PACT_BROKER_URL }}
          DATABASE_URL: postgresql://test:test@localhost:5433/testdb
      
      - name: Publish verification results
        run: npm run pact:verify:publish
```

**Contract Evolution Management:**

```javascript
// Backward compatibility verification
describe('Contract Evolution', () => {
  test('new provider version satisfies old consumer contracts', async () => {
    // Test against previous consumer contract versions
    const verifier = new Verifier({
      provider: 'UserAPI',
      providerVersion: process.env.GIT_SHA,
      consumerVersionSelectors: [
        { tag: 'production' },     // Current production version
        { latest: true },          // Latest consumer version
        { deployedOrReleased: true } // All deployed versions
      ],
      enablePending: true,         // Allow testing unreleased contracts
      includeWipPactsSince: '2024-01-01' // Include work-in-progress contracts
    });

    return verifier.verifyProvider();
  });

  test('consumer can handle new provider features gracefully', async () => {
    // Test that consumers ignore unknown fields (forward compatibility)
    const enhancedResponse = {
      id: '123',
      name: 'Alice',
      email: 'alice@example.com',
      // New fields that old consumers should ignore
      socialProfiles: { twitter: '@alice', linkedin: '/in/alice' },
      preferences: {
        newsletter: true,
        theme: 'dark',
        // New preference that old consumers should ignore
        aiAssistant: true
      }
    };

    // Verify old consumer code doesn't break with new fields
    const user = parseUserResponse(enhancedResponse);
    expect(user.id).toBe('123');
    expect(user.name).toBe('Alice');
    // Should not throw errors on unknown fields
  });
});
```

Contract testing bridges the gap between unit tests and full integration tests, providing fast feedback on interface compatibility. By defining contracts from the consumer perspective, teams can evolve services independently while maintaining reliability across distributed systems.

## 3. API Testing Strategies

While schema-based testing validates data structures and contract testing ensures service compatibility, API testing focuses on the behavior of individual endpoints under various conditions. Effective API testing covers the full spectrum from unit-level endpoint testing to comprehensive integration scenarios.


![Diagram 4](chapter-13-testing-diagram-4-light.png){width=85%}


### Unit Testing HTTP Endpoints

API endpoints should be tested in isolation with mocked dependencies to verify request handling, validation logic, and response formatting:

**Node.js endpoint testing with Supertest:**

```javascript
const request = require('supertest');
const app = require('../src/app');

describe('GET /api/users/:id', () => {
  beforeEach(() => {
    // Mock database for isolated testing
    jest.clearAllMocks();
    mockUserService.getUserById.mockClear();
  });

  test('returns user data for valid ID', async () => {
    const mockUser = {
      id: '123',
      name: 'Alice Smith',
      email: 'alice@example.com',
      createdAt: '2024-01-15T10:30:00Z',
      preferences: { newsletter: true, theme: 'dark' }
    };

    mockUserService.getUserById.mockResolvedValue(mockUser);

    const response = await request(app)
      .get('/api/users/123')
      .set('Accept', 'application/json')
      .expect(200)
      .expect('Content-Type', /application\/json/);

    expect(response.body).toMatchObject({
      id: '123',
      name: expect.any(String),
      email: expect.stringMatching(/^[^@]+@[^@]+$/),
      createdAt: expect.stringMatching(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/),
      preferences: expect.objectContaining({
        newsletter: expect.any(Boolean),
        theme: expect.stringMatching(/^(light|dark|auto)$/)
      })
    });

    expect(mockUserService.getUserById).toHaveBeenCalledWith('123');
  });

  test('returns 404 for non-existent user', async () => {
    mockUserService.getUserById.mockResolvedValue(null);

    const response = await request(app)
      .get('/api/users/999')
      .expect(404);

    expect(response.body).toMatchObject({
      status: 404,
      title: 'User Not Found',
      type: 'https://example.com/errors/user-not-found',
      instance: '/api/users/999'
    });
  });

  test('validates authentication requirements', async () => {
    await request(app)
      .get('/api/users/123')
      .expect(401);

    await request(app)
      .get('/api/users/123')
      .set('Authorization', 'Bearer invalid-token')
      .expect(401);
  });

  test('handles server errors gracefully', async () => {
    mockUserService.getUserById.mockRejectedValue(new Error('Database connection failed'));

    const response = await request(app)
      .get('/api/users/123')
      .set('Authorization', 'Bearer valid-token')
      .expect(500);

    expect(response.body).toMatchObject({
      status: 500,
      title: 'Internal Server Error',
      detail: expect.not.stringContaining('Database connection failed') // Error details hidden
    });
  });
});
```

**Go HTTP handler testing:**

```go
package handlers_test

import (
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "strings"
    "testing"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
)

func TestCreateUser(t *testing.T) {
    // Setup mocked user service
    mockService := &MockUserService{}
    handler := NewUserHandler(mockService)

    t.Run("creates user with valid data", func(t *testing.T) {
        userJSON := `{
            "name": "Alice Smith",
            "email": "alice@example.com",
            "age": 28
        }`

        expectedUser := &User{
            ID:    "generated-id",
            Name:  "Alice Smith", 
            Email: "alice@example.com",
            Age:   28,
        }

        mockService.On("CreateUser", mock.AnythingOfType("*User")).Return(expectedUser, nil)

        req := httptest.NewRequest("POST", "/api/users", strings.NewReader(userJSON))
        req.Header.Set("Content-Type", "application/json")
        w := httptest.NewRecorder()

        handler.CreateUser(w, req)

        assert.Equal(t, http.StatusCreated, w.Code)

        var response User
        err := json.Unmarshal(w.Body.Bytes(), &response)
        assert.NoError(t, err)

        assert.Equal(t, expectedUser.Name, response.Name)
        assert.Equal(t, expectedUser.Email, response.Email)
        assert.NotEmpty(t, response.ID)

        mockService.AssertExpectations(t)
    })

    t.Run("rejects invalid JSON", func(t *testing.T) {
        invalidJSON := `{"name": "Alice", "email": }`

        req := httptest.NewRequest("POST", "/api/users", strings.NewReader(invalidJSON))
        req.Header.Set("Content-Type", "application/json")
        w := httptest.NewRecorder()

        handler.CreateUser(w, req)

        assert.Equal(t, http.StatusBadRequest, w.Code)

        var errorResp ErrorResponse
        err := json.Unmarshal(w.Body.Bytes(), &errorResp)
        assert.NoError(t, err)
        assert.Equal(t, 400, errorResp.Status)
        assert.Contains(t, errorResp.Title, "Invalid JSON")
    })

    t.Run("validates required fields", func(t *testing.T) {
        incompleteJSON := `{"name": "Alice"}`

        req := httptest.NewRequest("POST", "/api/users", strings.NewReader(incompleteJSON))
        req.Header.Set("Content-Type", "application/json")
        w := httptest.NewRecorder()

        handler.CreateUser(w, req)

        assert.Equal(t, http.StatusBadRequest, w.Code)

        var errorResp ValidationErrorResponse
        err := json.Unmarshal(w.Body.Bytes(), &errorResp)
        assert.NoError(t, err)

        assert.Contains(t, errorResp.Errors, ValidationError{
            Field: "email",
            Code:  "required",
            Message: "Email is required",
        })
    })
}
```

### API Mocking and External Service Testing

Testing APIs often requires mocking external dependencies to create predictable, fast-running tests:

**JavaScript mocking with Nock:**

```javascript
const nock = require('nock');

describe('External API integration', () => {
  afterEach(() => {
    nock.cleanAll();
  });

  test('handles successful third-party API responses', async () => {
    nock('https://payment-gateway.com')
      .post('/api/charges')
      .matchHeader('authorization', /Bearer .+/)
      .reply(200, {
        id: 'charge_123',
        status: 'succeeded',
        amount: 2999,
        currency: 'usd'
      });

    const result = await paymentService.createCharge({
      amount: 2999,
      currency: 'usd',
      token: 'tok_visa'
    });

    expect(result.status).toBe('succeeded');
    expect(result.id).toBe('charge_123');
  });

  test('retries on temporary failures', async () => {
    nock('https://payment-gateway.com')
      .post('/api/charges')
      .reply(503, { error: 'Service temporarily unavailable' })
      .post('/api/charges')
      .reply(200, { id: 'charge_456', status: 'succeeded' });

    const result = await paymentService.createCharge({
      amount: 1999,
      currency: 'usd',
      token: 'tok_visa'
    });

    expect(result.status).toBe('succeeded');
    expect(result.id).toBe('charge_456');
  });

  test('handles rate limiting properly', async () => {
    nock('https://payment-gateway.com')
      .post('/api/charges')
      .reply(429, 
        { error: 'Rate limit exceeded' },
        { 'Retry-After': '2' }
      )
      .post('/api/charges')
      .delay(2100) // Simulate waiting for retry-after
      .reply(200, { id: 'charge_789', status: 'succeeded' });

    const startTime = Date.now();
    const result = await paymentService.createCharge({
      amount: 4999,
      currency: 'usd',
      token: 'tok_visa'
    });
    const duration = Date.now() - startTime;

    expect(result.status).toBe('succeeded');
    expect(duration).toBeGreaterThan(2000); // Verify retry delay
  });
});
```

### Snapshot Testing for API Responses

Snapshot testing captures API response structures to detect unexpected changes:

```javascript
describe('API response snapshots', () => {
  test('user profile endpoint structure', async () => {
    const response = await request(app)
      .get('/api/users/123/profile')
      .set('Authorization', `Bearer ${validToken}`)
      .expect(200);

    // Normalize dynamic data before snapshot comparison
    const normalizedBody = {
      ...response.body,
      id: expect.any(String),
      createdAt: expect.stringMatching(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/),
      updatedAt: expect.stringMatching(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
    };

    expect(normalizedBody).toMatchSnapshot();
  });

  test('error response format consistency', async () => {
    const response = await request(app)
      .get('/api/users/invalid-id')
      .expect(400);

    expect(response.body).toMatchSnapshot({
      timestamp: expect.any(String),
      traceId: expect.any(String)
    });
  });
});
```

### Integration Testing with Real Dependencies

Integration tests verify that components work together correctly, including database interactions and service dependencies:

```javascript
describe('User management integration tests', () => {
  let testDb, app;

  beforeAll(async () => {
    // Start test database container
    testDb = await startTestDatabase();
    app = createApp({ database: testDb });
  });

  afterAll(async () => {
    await stopTestDatabase(testDb);
  });

  beforeEach(async () => {
    // Clean state for each test
    await testDb.query('TRUNCATE TABLE users CASCADE');
    await testDb.query('TRUNCATE TABLE user_sessions CASCADE');
  });

  test('complete user lifecycle', async () => {
    // Step 1: Create user
    const createResponse = await request(app)
      .post('/api/users')
      .send({
        name: 'Alice Smith',
        email: 'alice@example.com',
        password: 'SecurePassword123!'
      })
      .expect(201);

    const userId = createResponse.body.id;
    expect(userId).toBeTruthy();

    // Step 2: Login to get session
    const loginResponse = await request(app)
      .post('/api/auth/login')
      .send({
        email: 'alice@example.com',
        password: 'SecurePassword123!'
      })
      .expect(200);

    const token = loginResponse.body.token;
    expect(token).toBeTruthy();

    // Step 3: Update profile
    await request(app)
      .patch(`/api/users/${userId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        preferences: {
          newsletter: false,
          theme: 'dark'
        }
      })
      .expect(200);

    // Step 4: Verify complete user data
    const profileResponse = await request(app)
      .get(`/api/users/${userId}`)
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(profileResponse.body).toMatchObject({
      id: userId,
      name: 'Alice Smith',
      email: 'alice@example.com',
      preferences: {
        newsletter: false,
        theme: 'dark'
      }
    });

    // Verify database state directly
    const dbUser = await testDb.query('SELECT * FROM users WHERE id = $1', [userId]);
    expect(dbUser.rows).toHaveLength(1);
    expect(dbUser.rows[0].email).toBe('alice@example.com');
  });

  test('concurrent user creation handling', async () => {
    const email = 'test@example.com';
    
    // Attempt to create duplicate users concurrently
    const createPromises = Array(5).fill().map((_, i) => 
      request(app)
        .post('/api/users')
        .send({
          name: `User ${i}`,
          email: email,
          password: 'Password123!'
        })
    );

    const results = await Promise.allSettled(createPromises);

    // Exactly one should succeed, others should fail with conflict
    const successful = results.filter(r => r.status === 'fulfilled' && r.value.status === 201);
    const conflicts = results.filter(r => r.status === 'fulfilled' && r.value.status === 409);

    expect(successful).toHaveLength(1);
    expect(conflicts.length).toBeGreaterThan(0);

    // Verify only one user exists in database
    const users = await testDb.query('SELECT * FROM users WHERE email = $1', [email]);
    expect(users.rows).toHaveLength(1);
  });
});
```

**Python FastAPI integration testing:**

```python
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

@pytest.fixture
def test_db():
    engine = create_engine("postgresql://test:test@localhost:5433/testdb")
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    
    # Create tables
    Base.metadata.create_all(bind=engine)
    
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)

@pytest.fixture
def client(test_db):
    def get_test_db():
        return test_db
    
    app.dependency_overrides[get_db] = get_test_db
    with TestClient(app) as c:
        yield c

def test_user_creation_and_retrieval(client, test_db):
    # Create user
    user_data = {
        "name": "Alice Smith",
        "email": "alice@example.com",
        "age": 28
    }
    
    response = client.post("/api/users", json=user_data)
    assert response.status_code == 201
    
    created_user = response.json()
    assert created_user["name"] == "Alice Smith"
    assert "id" in created_user
    
    # Retrieve user
    user_id = created_user["id"]
    response = client.get(f"/api/users/{user_id}")
    assert response.status_code == 200
    
    retrieved_user = response.json()
    assert retrieved_user["email"] == "alice@example.com"
    
    # Verify database state
    db_user = test_db.query(User).filter(User.id == user_id).first()
    assert db_user is not None
    assert db_user.email == "alice@example.com"
```

### Testing API Error Scenarios

Comprehensive error testing ensures robust error handling and proper error response formats:

```javascript
describe('Error handling', () => {
  test('validates request content types', async () => {
    await request(app)
      .post('/api/users')
      .set('Content-Type', 'application/xml')
      .send('<user><name>Alice</name></user>')
      .expect(415)
      .expect(res => {
        expect(res.body.title).toContain('Unsupported Media Type');
        expect(res.body.detail).toContain('application/json');
      });
  });

  test('handles malformed JSON gracefully', async () => {
    await request(app)
      .post('/api/users')
      .set('Content-Type', 'application/json')
      .send('{"name": "Alice",}') // Trailing comma
      .expect(400)
      .expect(res => {
        expect(res.body.title).toContain('Invalid JSON');
        expect(res.body.detail).not.toContain('SyntaxError'); // Internal error hidden
      });
  });

  test('provides detailed validation errors', async () => {
    const invalidUser = {
      name: '',
      email: 'not-an-email',
      age: 'twenty-five'
    };

    const response = await request(app)
      .post('/api/users')
      .send(invalidUser)
      .expect(400);

    expect(response.body).toMatchObject({
      status: 400,
      title: 'Validation Error',
      errors: [
        { field: 'name', code: 'minLength', message: expect.any(String) },
        { field: 'email', code: 'format', message: expect.any(String) },
        { field: 'age', code: 'type', message: expect.any(String) }
      ]
    });
  });
});
```

`★ Insight ─────────────────────────────────────`
API testing strategies form a pyramid: fast unit tests for individual endpoints at the base, integration tests with real dependencies in the middle, and end-to-end tests at the top. Each layer serves different purposes - unit tests catch logic errors quickly, integration tests verify component interactions, and E2E tests validate complete user flows. The key is maintaining the right balance where most tests are fast and isolated, with fewer but more comprehensive integration tests.
`─────────────────────────────────────────────────`

API testing strategies provide comprehensive validation of endpoint behavior, from isolated unit tests that verify business logic to integration tests that confirm system interactions. By combining mocking for external dependencies, snapshot testing for response structure stability, and real database integration testing, teams can build confidence in API reliability while maintaining fast feedback cycles.

## 4. Security Testing

JSON systems face unique security challenges that require systematic testing to prevent vulnerabilities. Unlike traditional applications where security testing might focus on buffer overflows or memory corruption, JSON systems must defend against injection attacks, authentication bypass, authorization failures, and denial-of-service attacks through malformed data.


![Diagram 5](chapter-13-testing-diagram-5-light.png){width=85%}


### Authentication and Authorization Testing

JWT token validation is critical for JSON API security. Testing must verify proper token handling and prevent common JWT vulnerabilities:

**JWT Security Test Suite:**

```javascript
const jwt = require('jsonwebtoken');
const crypto = require('crypto');

describe('JWT Security Tests', () => {
  const publicKey = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 }).publicKey;
  const privateKey = crypto.generateKeyPairSync('rsa', { modulusLength: 2048 }).privateKey;

  test('rejects none algorithm attack', async () => {
    // Attack: Change algorithm to 'none' to bypass signature verification
    const maliciousToken = jwt.sign(
      { userId: 'admin', role: 'admin' },
      '',
      { algorithm: 'none' }
    );

    const response = await request(app)
      .get('/api/admin/users')
      .set('Authorization', `Bearer ${maliciousToken}`)
      .expect(401);

    expect(response.body.code).toBe('INVALID_TOKEN');
    expect(response.body.title).toContain('Invalid authentication');
  });

  test('prevents algorithm confusion attack', async () => {
    // Attack: Use HMAC with the public key (RS256 -> HS256 confusion)
    const maliciousToken = jwt.sign(
      { userId: 'admin', role: 'admin' },
      publicKey,
      { algorithm: 'HS256' }
    );

    const response = await request(app)
      .get('/api/admin/users')
      .set('Authorization', `Bearer ${maliciousToken}`)
      .expect(401);

    expect(response.body.code).toBe('INVALID_TOKEN');
  });

  test('validates token expiration', async () => {
    const expiredToken = jwt.sign(
      { userId: '123', exp: Math.floor(Date.now() / 1000) - 3600 }, // 1 hour ago
      privateKey,
      { algorithm: 'RS256' }
    );

    await request(app)
      .get('/api/users/123')
      .set('Authorization', `Bearer ${expiredToken}`)
      .expect(401)
      .expect(res => {
        expect(res.body.code).toBe('TOKEN_EXPIRED');
      });
  });

  test('validates audience and issuer claims', async () => {
    const wrongAudienceToken = jwt.sign(
      { 
        userId: '123', 
        aud: 'https://wrong-audience.com',
        iss: 'https://auth.example.com'
      },
      privateKey,
      { algorithm: 'RS256' }
    );

    await request(app)
      .get('/api/users/123')
      .set('Authorization', `Bearer ${wrongAudienceToken}`)
      .expect(401)
      .expect(res => {
        expect(res.body.code).toBe('INVALID_AUDIENCE');
      });
  });

  test('prevents token replay attacks with jti claim', async () => {
    const tokenId = 'unique-token-123';
    
    const token = jwt.sign(
      { userId: '123', jti: tokenId },
      privateKey,
      { algorithm: 'RS256' }
    );

    // First request should succeed
    await request(app)
      .get('/api/users/123')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    // Simulate token blacklisting after logout
    await request(app)
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    // Second request with same token should fail
    await request(app)
      .get('/api/users/123')
      .set('Authorization', `Bearer ${token}`)
      .expect(401)
      .expect(res => {
        expect(res.body.code).toBe('TOKEN_BLACKLISTED');
      });
  });
});
```

**Authorization boundary testing:**

```javascript
describe('Authorization boundary tests', () => {
  test('user cannot access other users data', async () => {
    const userToken = createToken({ userId: '123', role: 'user' });

    // Try to access another user's data
    await request(app)
      .get('/api/users/456')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(403)
      .expect(res => {
        expect(res.body.code).toBe('INSUFFICIENT_PERMISSIONS');
      });
  });

  test('prevents privilege escalation via JSON manipulation', async () => {
    const userToken = createToken({ userId: '123', role: 'user' });

    // Attempt to escalate privileges by modifying role in request
    await request(app)
      .patch('/api/users/123')
      .set('Authorization', `Bearer ${userToken}`)
      .send({
        name: 'Alice',
        role: 'admin'  // Should be ignored/rejected
      })
      .expect(400)
      .expect(res => {
        expect(res.body.title).toContain('Invalid field');
        expect(res.body.errors).toContainEqual({
          field: 'role',
          code: 'forbidden',
          message: 'Cannot modify role'
        });
      });
  });

  test('validates resource ownership', async () => {
    const userToken = createToken({ userId: '123', role: 'user' });
    
    // Create a document owned by user 456
    await testDb.documents.insert({
      id: 'doc-123',
      ownerId: '456',
      title: 'Private Document'
    });

    // User 123 should not be able to access user 456's document
    await request(app)
      .get('/api/documents/doc-123')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(404); // Return 404, not 403, to avoid leaking existence
  });
});
```

### Injection Attack Prevention

JSON systems must defend against various injection attacks that exploit poor input validation:

**SQL Injection via JSON fields:**

```javascript
describe('SQL injection prevention', () => {
  test('prevents SQL injection in search parameters', async () => {
    const maliciousPayload = {
      name: "'; DROP TABLE users; --",
      email: "attacker@evil.com' OR '1'='1"
    };

    const response = await request(app)
      .post('/api/users/search')
      .set('Authorization', validToken)
      .send(maliciousPayload)
      .expect(200); // Should not crash

    // Verify database is intact
    const usersExist = await testDb.query('SELECT COUNT(*) FROM users');
    expect(parseInt(usersExist.rows[0].count)).toBeGreaterThan(0);

    // Verify no SQL errors leaked
    expect(response.body).not.toMatchObject(
      expect.objectContaining({
        error: expect.stringMatching(/sql|syntax|table/i)
      })
    );
  });

  test('prevents NoSQL injection in MongoDB queries', async () => {
    const maliciousPayload = {
      email: { $ne: null }, // Would match all documents
      password: { $regex: ".*" }
    };

    await request(app)
      .post('/api/auth/login')
      .send(maliciousPayload)
      .expect(400)
      .expect(res => {
        expect(res.body.title).toContain('Invalid input format');
        expect(res.body.detail).not.toContain('mongo'); // Hide internal errors
      });
  });

  test('prevents JSON injection in stored procedures', async () => {
    const maliciousUser = {
      name: 'Alice',
      metadata: '{"admin": true}' // Attempt to inject admin flag
    };

    const response = await request(app)
      .post('/api/users')
      .send(maliciousUser)
      .expect(201);

    // Verify metadata is stored as string, not parsed as object
    const user = await testDb.query('SELECT metadata FROM users WHERE id = $1', [response.body.id]);
    expect(typeof user.rows[0].metadata).toBe('string');
    expect(user.rows[0].metadata).toBe('{"admin": true}');
    
    // Verify user doesn't have admin privileges
    const userObj = JSON.parse(user.rows[0].metadata);
    expect(userObj.admin).toBeUndefined();
  });
});
```

**Cross-Site Scripting (XSS) prevention in JSON responses:**

```javascript
describe('XSS prevention', () => {
  test('escapes HTML in JSON user inputs', async () => {
    const xssPayload = {
      name: '<script>alert("XSS")</script>',
      bio: '<img src="x" onerror="alert(1)">'
    };

    const response = await request(app)
      .post('/api/users')
      .send(xssPayload)
      .expect(201);

    // Verify HTML is escaped in response
    expect(response.body.name).toBe('&lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt;');
    expect(response.body.bio).toBe('&lt;img src=&quot;x&quot; onerror=&quot;alert(1)&quot;&gt;');
  });

  test('prevents script injection in error messages', async () => {
    const maliciousInput = {
      email: '<script>fetch("/api/admin/secrets")</script>@evil.com'
    };

    const response = await request(app)
      .post('/api/users')
      .send(maliciousInput)
      .expect(400);

    // Verify error message doesn't contain unescaped script
    expect(response.body.errors[0].message).not.toContain('<script>');
    expect(response.body.errors[0].message).toContain('&lt;script&gt;');
  });
});
```

### Denial of Service (DoS) Prevention

JSON systems must defend against various DoS attacks that exploit parser limitations:

**Deep nesting and large payload protection:**

```javascript
describe('DoS prevention', () => {
  test('rejects deeply nested JSON objects', async () => {
    const maxDepth = 100;
    let nestedObject = {};
    let current = nestedObject;
    
    // Create object with depth > maxDepth
    for (let i = 0; i < maxDepth + 50; i++) {
      current.nested = {};
      current = current.nested;
    }

    await request(app)
      .post('/api/data')
      .send(nestedObject)
      .expect(413)
      .expect(res => {
        expect(res.body.title).toContain('Payload Too Deep');
        expect(res.body.detail).toContain('nesting depth exceeded');
      });
  });

  test('enforces payload size limits', async () => {
    const hugePayload = {
      data: 'x'.repeat(10 * 1024 * 1024) // 10MB string
    };

    await request(app)
      .post('/api/upload')
      .send(hugePayload)
      .expect(413)
      .expect(res => {
        expect(res.body.title).toBe('Payload Too Large');
        expect(res.headers['content-length']).toBeDefined();
      });
  });

  test('limits array size to prevent memory exhaustion', async () => {
    const hugeArray = new Array(1000000).fill('item'); // 1M items

    await request(app)
      .post('/api/items')
      .send({ items: hugeArray })
      .expect(400)
      .expect(res => {
        expect(res.body.title).toContain('Array Too Large');
        expect(res.body.detail).toContain('maximum 10000 items');
      });
  });

  test('prevents billion laughs attack via deeply nested arrays', async () => {
    // Create exponentially expanding structure
    let payload = [[[[[[]]]]]];
    
    // Repeat to create massive expansion when parsed
    for (let i = 0; i < 10; i++) {
      payload = [payload, payload, payload, payload];
    }

    await request(app)
      .post('/api/data')
      .send(payload)
      .expect(413)
      .expect(res => {
        expect(res.body.title).toContain('Malformed Request');
      });
  });
});
```

**Rate limiting verification:**

```javascript
describe('Rate limiting', () => {
  test('enforces per-user API rate limits', async () => {
    const userToken = createToken({ userId: '123' });
    const requests = [];

    // Make 101 requests (assume limit is 100 per minute)
    for (let i = 0; i < 101; i++) {
      requests.push(
        request(app)
          .get('/api/users')
          .set('Authorization', `Bearer ${userToken}`)
      );
    }

    const responses = await Promise.all(requests);
    
    // First 100 should succeed
    const successful = responses.filter(r => r.status === 200);
    expect(successful.length).toBe(100);

    // 101st should be rate limited
    const rateLimited = responses.find(r => r.status === 429);
    expect(rateLimited).toBeDefined();
    expect(rateLimited.headers['retry-after']).toBeDefined();
    expect(rateLimited.headers['x-ratelimit-remaining']).toBe('0');
  });

  test('rate limits apply per endpoint independently', async () => {
    const userToken = createToken({ userId: '123' });
    
    // Exhaust rate limit for /users endpoint
    const userRequests = Array(100).fill().map(() =>
      request(app)
        .get('/api/users')
        .set('Authorization', `Bearer ${userToken}`)
    );
    
    await Promise.all(userRequests);

    // Different endpoint should still be accessible
    await request(app)
      .get('/api/posts')
      .set('Authorization', `Bearer ${userToken}`)
      .expect(200);
  });
});
```

### Security Headers and Content Type Validation

JSON APIs must validate content types and set appropriate security headers:

```javascript
describe('Security headers and content validation', () => {
  test('validates Content-Type header strictly', async () => {
    await request(app)
      .post('/api/users')
      .set('Content-Type', 'text/plain')
      .send('{"name": "Alice"}')
      .expect(415)
      .expect(res => {
        expect(res.body.title).toBe('Unsupported Media Type');
        expect(res.body.detail).toContain('application/json');
      });
  });

  test('sets security headers on all responses', async () => {
    const response = await request(app)
      .get('/api/users')
      .set('Authorization', validToken)
      .expect(200);

    expect(response.headers['x-content-type-options']).toBe('nosniff');
    expect(response.headers['x-frame-options']).toBe('DENY');
    expect(response.headers['x-xss-protection']).toBe('1; mode=block');
    expect(response.headers['strict-transport-security']).toContain('max-age');
    expect(response.headers['content-security-policy']).toBeDefined();
  });

  test('prevents MIME type confusion', async () => {
    // Attempt to upload JavaScript disguised as JSON
    const maliciousContent = 'alert("XSS"); {"name": "Alice"}';

    await request(app)
      .post('/api/upload')
      .set('Content-Type', 'application/json')
      .send(maliciousContent)
      .expect(400)
      .expect(res => {
        expect(res.body.title).toContain('Invalid JSON');
      });
  });

  test('validates JSON schema before processing', async () => {
    const invalidStructure = {
      // Missing required fields
      invalidField: 'should not be here',
      nested: {
        tooDeep: {
          wayTooDeep: 'data'
        }
      }
    };

    await request(app)
      .post('/api/users')
      .send(invalidStructure)
      .expect(400)
      .expect(res => {
        expect(res.body.errors).toContainEqual({
          field: 'invalidField',
          code: 'additionalProperties',
          message: 'Additional properties not allowed'
        });
      });
  });
});
```

**Go security testing example:**

```go
func TestJWTSecurityGo(t *testing.T) {
    tests := []struct {
        name           string
        token          string
        expectedStatus int
        expectedError  string
    }{
        {
            name:           "none algorithm attack",
            token:          createNoneAlgorithmToken(),
            expectedStatus: 401,
            expectedError:  "INVALID_ALGORITHM",
        },
        {
            name:           "expired token",
            token:          createExpiredToken(),
            expectedStatus: 401,
            expectedError:  "TOKEN_EXPIRED",
        },
        {
            name:           "invalid signature",
            token:          createTamperedToken(),
            expectedStatus: 401,
            expectedError:  "INVALID_SIGNATURE",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            req := httptest.NewRequest("GET", "/api/users", nil)
            req.Header.Set("Authorization", "Bearer "+tt.token)
            w := httptest.NewRecorder()

            handler := JWTMiddleware(http.HandlerFunc(getUsersHandler))
            handler.ServeHTTP(w, req)

            assert.Equal(t, tt.expectedStatus, w.Code)

            var errorResp ErrorResponse
            err := json.Unmarshal(w.Body.Bytes(), &errorResp)
            assert.NoError(t, err)
            assert.Equal(t, tt.expectedError, errorResp.Code)
        })
    }
}

func TestInputSanitizationGo(t *testing.T) {
    maliciousInputs := []struct {
        name     string
        payload  User
        expected string
    }{
        {
            name: "script tag injection",
            payload: User{
                Name: "<script>alert('xss')</script>",
                Email: "test@example.com",
            },
            expected: "&lt;script&gt;alert(&#39;xss&#39;)&lt;/script&gt;",
        },
        {
            name: "SQL injection attempt", 
            payload: User{
                Name: "'; DROP TABLE users; --",
                Email: "test@example.com",
            },
            expected: "&#39;; DROP TABLE users; --",
        },
    }

    for _, tt := range maliciousInputs {
        t.Run(tt.name, func(t *testing.T) {
            sanitized := sanitizeInput(tt.payload.Name)
            assert.Equal(t, tt.expected, sanitized)
        })
    }
}
```

`★ Insight ─────────────────────────────────────`
Security testing for JSON systems requires a layered approach that mirrors the OWASP Top 10 but adapted for JSON-specific vulnerabilities. The key insight is that JSON's flexibility becomes a security weakness without proper validation - what makes JSON easy to work with (loose typing, nested structures, dynamic content) also makes it vulnerable to injection, DoS, and privilege escalation attacks. Comprehensive security testing must validate every input boundary, authenticate every request properly, and limit resource consumption to prevent abuse.
`─────────────────────────────────────────────────`

Security testing for JSON systems requires systematic verification of authentication, authorization, input validation, and resource protection. By testing for JWT vulnerabilities, injection attacks, DoS prevention, and proper security headers, teams can build robust defenses against the unique attack vectors that target JSON APIs and data processing systems.

## 5. Performance and Load Testing

JSON systems face unique performance challenges related to parsing overhead, serialization costs, and memory usage patterns. Unlike binary formats, JSON's text-based nature creates CPU-intensive operations that scale poorly without careful optimization. Performance testing must verify that systems maintain acceptable response times and throughput under realistic load conditions.


![Diagram 6](chapter-13-testing-diagram-6-light.png){width=85%}


### Load Testing with k6

k6 provides excellent support for JSON API load testing with built-in JavaScript runtime and comprehensive metrics collection:

**Basic load testing script:**

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

// Custom metrics for JSON-specific performance
const jsonParseTime = new Trend('json_parse_time', true);
const largePayloadRate = new Rate('large_payload_rate');
const authenticationFailures = new Counter('auth_failures');

export const options = {
  stages: [
    { duration: '2m', target: 10 },   // Warm up
    { duration: '5m', target: 50 },   // Ramp up to 50 users
    { duration: '10m', target: 100 }, // Ramp up to 100 users  
    { duration: '10m', target: 100 }, // Stay at 100 users
    { duration: '5m', target: 50 },   // Ramp down to 50 users
    { duration: '2m', target: 0 },    // Ramp down to 0 users
  ],
  
  // Performance thresholds
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'], // 95% under 500ms, 99% under 1s
    http_req_failed: ['rate<0.01'],                  // Error rate < 1%
    http_reqs: ['rate>20'],                         // Throughput > 20 req/s
    json_parse_time: ['p(95)<50'],                  // JSON parsing < 50ms p95
    large_payload_rate: ['rate<0.1'],               // Large payloads < 10%
  }
};

export function setup() {
  // Authenticate and get token for load testing
  const loginResponse = http.post('https://api.example.com/auth/login', 
    JSON.stringify({
      email: 'loadtest@example.com',
      password: 'LoadTest123!'
    }), 
    { headers: { 'Content-Type': 'application/json' } }
  );
  
  check(loginResponse, {
    'authentication successful': (r) => r.status === 200,
  });
  
  return { token: loginResponse.json('token') };
}

export default function(data) {
  const headers = {
    'Authorization': `Bearer ${data.token}`,
    'Accept': 'application/json',
    'Content-Type': 'application/json'
  };

  // Test 1: List users endpoint (read-heavy)
  const listStart = Date.now();
  const listResponse = http.get('https://api.example.com/api/users?limit=20', { headers });
  const listDuration = Date.now() - listStart;
  
  check(listResponse, {
    'list users status is 200': (r) => r.status === 200,
    'list users has pagination': (r) => r.json('pagination') !== null,
    'list users response size reasonable': (r) => r.body.length < 50000,
  });
  
  if (listResponse.status === 200) {
    jsonParseTime.add(listDuration);
    largePayloadRate.add(listResponse.body.length > 10000);
  } else {
    authenticationFailures.add(1);
  }

  sleep(1);

  // Test 2: Create user endpoint (write-heavy)
  const createPayload = {
    name: `LoadTest User ${__VU}-${__ITER}`,
    email: `loadtest+${__VU}${__ITER}@example.com`,
    age: Math.floor(Math.random() * 50) + 18,
    preferences: {
      newsletter: Math.random() > 0.5,
      theme: ['light', 'dark', 'auto'][Math.floor(Math.random() * 3)]
    },
    metadata: {
      source: 'load-test',
      iteration: __ITER,
      virtualUser: __VU,
      timestamp: new Date().toISOString()
    }
  };

  const createResponse = http.post('https://api.example.com/api/users',
    JSON.stringify(createPayload),
    { headers }
  );

  check(createResponse, {
    'create user status is 201': (r) => r.status === 201,
    'create user returns ID': (r) => r.json('id') !== null,
    'create user response time OK': (r) => r.timings.duration < 1000,
  });

  sleep(2);

  // Test 3: Update user endpoint (mixed read/write)
  if (createResponse.status === 201) {
    const userId = createResponse.json('id');
    const updatePayload = {
      preferences: {
        newsletter: !createPayload.preferences.newsletter,
        theme: 'auto'
      }
    };

    const updateResponse = http.patch(`https://api.example.com/api/users/${userId}`,
      JSON.stringify(updatePayload),
      { headers }
    );

    check(updateResponse, {
      'update user status is 200': (r) => r.status === 200,
      'update persisted correctly': (r) => 
        r.json('preferences.newsletter') === !createPayload.preferences.newsletter,
    });
  }

  sleep(1);
}

export function teardown(data) {
  // Cleanup: logout and invalidate tokens
  http.post('https://api.example.com/auth/logout', null, {
    headers: { 'Authorization': `Bearer ${data.token}` }
  });
}
```

**Memory and parsing performance testing:**

```javascript
import { describe, expect, test } from 'k6';

export default function() {
  describe('JSON parsing performance', () => {
    test('large JSON payload parsing', () => {
      const largeObject = {
        users: new Array(1000).fill().map((_, i) => ({
          id: `user-${i}`,
          name: `User ${i}`,
          email: `user${i}@example.com`,
          preferences: {
            notifications: new Array(10).fill(`setting-${i}`),
            privacy: { level: 'standard', analytics: true }
          }
        }))
      };

      const jsonString = JSON.stringify(largeObject);
      console.log(`JSON payload size: ${(jsonString.length / 1024).toFixed(2)} KB`);

      const parseStart = performance.now();
      const parsed = JSON.parse(jsonString);
      const parseTime = performance.now() - parseStart;

      expect(parseTime, 'parse time').to.be.below(100); // Should parse in <100ms
      expect(parsed.users.length, 'correct user count').to.equal(1000);
    });

    test('deep nested object performance', () => {
      let deepObject = { value: 'leaf' };
      
      // Create 50 levels of nesting
      for (let i = 0; i < 50; i++) {
        deepObject = { 
          level: i, 
          child: deepObject,
          metadata: `Level ${i} metadata`
        };
      }

      const jsonString = JSON.stringify(deepObject);
      const parseStart = performance.now();
      const parsed = JSON.parse(jsonString);
      const parseTime = performance.now() - parseStart;

      expect(parseTime, 'deep nesting parse time').to.be.below(50);
      expect(parsed.level, 'top level correct').to.equal(49);
    });
  });
}
```

### Benchmark Testing for Serialization Performance

Different serialization approaches have dramatically different performance characteristics:

**Node.js benchmark comparison:**

```javascript
const Benchmark = require('benchmark');
const msgpack = require('@msgpack/msgpack');

const testData = {
  users: Array(1000).fill().map((_, i) => ({
    id: `user-${i}`,
    name: `User Name ${i}`,
    email: `user${i}@example.com`,
    age: 20 + (i % 50),
    preferences: {
      newsletter: i % 2 === 0,
      theme: ['light', 'dark', 'auto'][i % 3],
      notifications: {
        email: true,
        push: i % 3 === 0,
        sms: false
      }
    },
    metadata: {
      createdAt: new Date().toISOString(),
      tags: [`tag-${i}`, `category-${i % 10}`],
      score: Math.random() * 100
    }
  }))
};

const suite = new Benchmark.Suite('Serialization Performance');

suite
  .add('JSON.stringify', function() {
    JSON.stringify(testData);
  })
  .add('JSON.stringify + parse', function() {
    const json = JSON.stringify(testData);
    JSON.parse(json);
  })
  .add('MessagePack encode', function() {
    msgpack.encode(testData);
  })
  .add('MessagePack encode + decode', function() {
    const packed = msgpack.encode(testData);
    msgpack.decode(packed);
  })
  .on('cycle', function(event) {
    console.log(String(event.target));
    
    // Log memory usage
    const memUsage = process.memoryUsage();
    console.log(`  Heap Used: ${(memUsage.heapUsed / 1024 / 1024).toFixed(2)} MB`);
    console.log(`  Heap Total: ${(memUsage.heapTotal / 1024 / 1024).toFixed(2)} MB`);
  })
  .on('complete', function() {
    console.log('Fastest is ' + this.filter('fastest').map('name'));
    
    // Size comparison
    const jsonSize = Buffer.byteLength(JSON.stringify(testData), 'utf8');
    const msgpackSize = msgpack.encode(testData).length;
    
    console.log(`\nSize comparison:`);
    console.log(`JSON: ${(jsonSize / 1024).toFixed(2)} KB`);
    console.log(`MessagePack: ${(msgpackSize / 1024).toFixed(2)} KB`);
    console.log(`Compression ratio: ${(msgpackSize / jsonSize * 100).toFixed(1)}%`);
  })
  .run({ async: true });
```

**Go benchmarking for JSON vs alternatives:**

```go
package main

import (
    "encoding/json"
    "testing"
    "github.com/vmihailenco/msgpack/v5"
    "github.com/goccy/go-json"
)

type User struct {
    ID          string            `json:"id" msgpack:"id"`
    Name        string            `json:"name" msgpack:"name"`
    Email       string            `json:"email" msgpack:"email"`
    Age         int               `json:"age" msgpack:"age"`
    Preferences map[string]string `json:"preferences" msgpack:"preferences"`
    Tags        []string          `json:"tags" msgpack:"tags"`
}

func generateTestUsers(count int) []User {
    users := make([]User, count)
    for i := 0; i < count; i++ {
        users[i] = User{
            ID:    fmt.Sprintf("user-%d", i),
            Name:  fmt.Sprintf("User %d", i),
            Email: fmt.Sprintf("user%d@example.com", i),
            Age:   20 + (i % 50),
            Preferences: map[string]string{
                "theme":      "dark",
                "newsletter": "true",
            },
            Tags: []string{fmt.Sprintf("tag-%d", i), "active"},
        }
    }
    return users
}

func BenchmarkStdJSONMarshal(b *testing.B) {
    users := generateTestUsers(1000)
    b.ResetTimer()
    
    for i := 0; i < b.N; i++ {
        _, err := json.Marshal(users)
        if err != nil {
            b.Fatal(err)
        }
    }
}

func BenchmarkStdJSONUnmarshal(b *testing.B) {
    users := generateTestUsers(1000)
    data, _ := json.Marshal(users)
    b.ResetTimer()
    
    for i := 0; i < b.N; i++ {
        var result []User
        err := json.Unmarshal(data, &result)
        if err != nil {
            b.Fatal(err)
        }
    }
}

func BenchmarkGoccyJSONMarshal(b *testing.B) {
    users := generateTestUsers(1000)
    b.ResetTimer()
    
    for i := 0; i < b.N; i++ {
        _, err := gojson.Marshal(users)
        if err != nil {
            b.Fatal(err)
        }
    }
}

func BenchmarkGoccyJSONUnmarshal(b *testing.B) {
    users := generateTestUsers(1000)
    data, _ := gojson.Marshal(users)
    b.ResetTimer()
    
    for i := 0; i < b.N; i++ {
        var result []User
        err := gojson.Unmarshal(data, &result)
        if err != nil {
            b.Fatal(err)
        }
    }
}

func BenchmarkMsgPackMarshal(b *testing.B) {
    users := generateTestUsers(1000)
    b.ResetTimer()
    
    for i := 0; i < b.N; i++ {
        _, err := msgpack.Marshal(users)
        if err != nil {
            b.Fatal(err)
        }
    }
}

func BenchmarkMsgPackUnmarshal(b *testing.B) {
    users := generateTestUsers(1000)
    data, _ := msgpack.Marshal(users)
    b.ResetTimer()
    
    for i := 0; i < b.N; i++ {
        var result []User
        err := msgpack.Unmarshal(data, &result)
        if err != nil {
            b.Fatal(err)
        }
    }
}

// Memory allocation benchmarks
func BenchmarkJSONMarshalMemory(b *testing.B) {
    users := generateTestUsers(1000)
    b.ReportAllocs()
    b.ResetTimer()
    
    for i := 0; i < b.N; i++ {
        json.Marshal(users)
    }
}

func BenchmarkMsgPackMarshalMemory(b *testing.B) {
    users := generateTestUsers(1000)
    b.ReportAllocs()
    b.ResetTimer()
    
    for i := 0; i < b.N; i++ {
        msgpack.Marshal(users)
    }
}

// Example benchmark results:
// BenchmarkStdJSONMarshal-8        1000    1052847 ns/op   245760 B/op    2001 allocs/op
// BenchmarkGoccyJSONMarshal-8      2000     524123 ns/op   122880 B/op    1001 allocs/op
// BenchmarkMsgPackMarshal-8        3000     351456 ns/op    81920 B/op     501 allocs/op
```

### Database Performance Testing with JSON

JSON database operations often become bottlenecks in web applications:

**PostgreSQL JSON performance testing:**

```javascript
describe('PostgreSQL JSON performance', () => {
  let db;
  
  beforeAll(async () => {
    db = await createTestDB();
    
    // Create test table with JSON column
    await db.query(`
      CREATE TABLE user_profiles (
        id SERIAL PRIMARY KEY,
        user_id VARCHAR(50) UNIQUE NOT NULL,
        profile JSONB NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    
    // Create indexes for common JSON queries
    await db.query(`
      CREATE INDEX idx_profile_email ON user_profiles 
      USING GIN ((profile->'email'))
    `);
    
    await db.query(`
      CREATE INDEX idx_profile_preferences ON user_profiles 
      USING GIN ((profile->'preferences'))
    `);
  });

  test('bulk JSON insert performance', async () => {
    const users = Array(1000).fill().map((_, i) => ({
      user_id: `user-${i}`,
      profile: {
        name: `User ${i}`,
        email: `user${i}@example.com`,
        preferences: {
          newsletter: i % 2 === 0,
          theme: ['light', 'dark'][i % 2]
        },
        metadata: {
          signupSource: 'performance-test',
          tags: [`tag-${i % 10}`, 'test-user']
        }
      }
    }));

    const startTime = Date.now();
    
    // Use batch insert for better performance
    const values = users.map((user, i) => 
      `($${i*2+1}, $${i*2+2}::jsonb)`
    ).join(',');
    
    const params = users.flatMap(u => [u.user_id, JSON.stringify(u.profile)]);
    
    await db.query(`
      INSERT INTO user_profiles (user_id, profile) 
      VALUES ${values}
    `, params);
    
    const duration = Date.now() - startTime;
    console.log(`Bulk insert of 1000 JSON records: ${duration}ms`);
    
    expect(duration).toBeLessThan(1000); // Should complete in under 1 second
  });

  test('JSON query performance', async () => {
    // Test 1: Simple JSON field access
    const simpleQueryStart = Date.now();
    const emailResults = await db.query(`
      SELECT user_id, profile->>'email' as email 
      FROM user_profiles 
      WHERE profile->>'email' LIKE '%500@%'
    `);
    const simpleQueryDuration = Date.now() - simpleQueryStart;
    
    expect(simpleQueryDuration).toBeLessThan(100);
    expect(emailResults.rows.length).toBeGreaterThan(0);

    // Test 2: Complex JSON path queries
    const complexQueryStart = Date.now();
    const themeResults = await db.query(`
      SELECT user_id, profile->'preferences'->>'theme' as theme
      FROM user_profiles 
      WHERE profile->'preferences'->>'newsletter' = 'true'
      AND profile->'metadata'->>'signupSource' = 'performance-test'
    `);
    const complexQueryDuration = Date.now() - complexQueryStart;
    
    expect(complexQueryDuration).toBeLessThan(200);
    expect(themeResults.rows.length).toBe(500); // Half the users

    console.log(`Simple JSON query: ${simpleQueryDuration}ms`);
    console.log(`Complex JSON query: ${complexQueryDuration}ms`);
  });

  test('JSON aggregation performance', async () => {
    const aggregationStart = Date.now();
    
    const stats = await db.query(`
      SELECT 
        COUNT(*) as total_users,
        COUNT(CASE WHEN profile->'preferences'->>'newsletter' = 'true' THEN 1 END) as newsletter_subscribers,
        jsonb_object_keys(profile->'preferences') as preference_keys,
        COUNT(DISTINCT profile->'preferences'->>'theme') as unique_themes
      FROM user_profiles
      GROUP BY profile->'preferences'
    `);
    
    const aggregationDuration = Date.now() - aggregationStart;
    
    expect(aggregationDuration).toBeLessThan(300);
    console.log(`JSON aggregation query: ${aggregationDuration}ms`);
  });
});
```

### API Response Time Distribution Analysis

Understanding response time distributions helps identify performance bottlenecks:

```javascript
// Response time analysis script for production monitoring
const responseTimes = [];

export default function() {
  const start = Date.now();
  
  const response = http.get('https://api.example.com/api/users', {
    headers: { 'Authorization': `Bearer ${token}` }
  });
  
  const duration = Date.now() - start;
  responseTimes.push(duration);
  
  check(response, {
    'status is 200': (r) => r.status === 200,
  });
  
  if (responseTimes.length % 100 === 0) {
    analyzePerformance();
  }
}

function analyzePerformance() {
  responseTimes.sort((a, b) => a - b);
  
  const p50 = percentile(responseTimes, 50);
  const p75 = percentile(responseTimes, 75);
  const p90 = percentile(responseTimes, 90);
  const p95 = percentile(responseTimes, 95);
  const p99 = percentile(responseTimes, 99);
  
  console.log(`Performance Distribution (n=${responseTimes.length}):`);
  console.log(`  P50 (median): ${p50}ms`);
  console.log(`  P75: ${p75}ms`);
  console.log(`  P90: ${p90}ms`);
  console.log(`  P95: ${p95}ms`);
  console.log(`  P99: ${p99}ms`);
  
  // Alert if performance degrades
  if (p95 > 500) {
    console.warn('⚠️  P95 response time exceeded 500ms threshold');
  }
  
  if (p99 > 1000) {
    console.warn('⚠️  P99 response time exceeded 1000ms threshold');
  }
}

function percentile(arr, p) {
  const index = Math.ceil((p / 100) * arr.length) - 1;
  return arr[index];
}
```

**Continuous performance monitoring:**

```yaml
# docker-compose.yml for performance monitoring stack
version: '3.8'
services:
  api:
    image: myapp:latest
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://user:pass@db:5432/myapp
    
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
      
  grafana:
    image: grafana/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    ports:
      - "3000:3000"
    
  k6:
    image: loadimpact/k6
    volumes:
      - ./performance-tests:/scripts
    command: run --out statsd /scripts/api-load-test.js
```

`★ Insight ─────────────────────────────────────`
Performance testing for JSON systems reveals that the text-based nature of JSON creates CPU bottlenecks that don't exist with binary formats. The key insight is that JSON performance degrades non-linearly with payload size and nesting depth - a 10x increase in data size might result in 50x slower parsing. This means performance testing must include realistic data volumes and structures, not just synthetic small payloads. Load testing tools like k6 excel at JSON testing because they provide JavaScript runtime for complex payload generation and response validation.
`─────────────────────────────────────────────────`

Performance and load testing for JSON systems requires understanding the unique characteristics of text-based serialization and the performance implications of parsing, validation, and database operations. By combining load testing tools, benchmarking frameworks, and continuous monitoring, teams can ensure their JSON APIs maintain acceptable performance under real-world conditions and identify bottlenecks before they impact users.

## 6. Fuzz Testing and CI/CD Integration

Fuzz testing discovers edge cases and vulnerabilities by feeding systems unexpected, malformed, or randomly generated inputs. For JSON systems, fuzzing can uncover parser bugs, memory leaks, security vulnerabilities, and performance degradation under extreme conditions. Integrating comprehensive testing into CI/CD pipelines ensures that quality checks run automatically on every change.

### Fuzzing JSON Parsers and Validators

Modern fuzzing tools can generate vast amounts of test cases to explore unexpected code paths:


![Diagram 7](chapter-13-testing-diagram-7-light.png){width=85%}


**Go fuzzing with the built-in fuzzer (Go 1.18+):**

```go
package main

import (
    "encoding/json"
    "testing"
)

func FuzzJSONParser(f *testing.F) {
    // Seed corpus with known interesting cases
    f.Add(`{"name":"Alice","age":30}`)
    f.Add(`{"nested":{"deep":{"value":42}}}`)
    f.Add(`{"array":[1,2,3,4,5]}`)
    f.Add(`{"empty":{}}`)
    f.Add(`{"null_value":null}`)
    f.Add(`{"boolean":true,"false_val":false}`)
    f.Add(`{"float":3.14159,"negative":-42}`)
    f.Add(`{"unicode":"Hello, 世界"}`)
    
    f.Fuzz(func(t *testing.T, input string) {
        var result interface{}
        
        // The parser should never crash, even on malformed input
        err := json.Unmarshal([]byte(input), &result)
        
        // Either succeeds and produces valid result, or fails gracefully
        if err == nil {
            // If parsing succeeded, re-marshaling should work
            marshaled, marshalErr := json.Marshal(result)
            if marshalErr != nil {
                t.Errorf("Round-trip failed: unmarshal succeeded but marshal failed: %v", marshalErr)
            }
            
            // Re-parsing the marshaled output should produce the same result
            var roundTrip interface{}
            if unmarshalErr := json.Unmarshal(marshaled, &roundTrip); unmarshalErr != nil {
                t.Errorf("Round-trip parse failed: %v", unmarshalErr)
            }
        }
        // If err != nil, that's fine - malformed JSON should be rejected
    })
}

func FuzzJSONSchemaValidation(f *testing.F) {
    schema := `{
        "type": "object",
        "required": ["name", "email"],
        "properties": {
            "name": {"type": "string", "minLength": 1, "maxLength": 100},
            "email": {"type": "string", "format": "email"},
            "age": {"type": "integer", "minimum": 0, "maximum": 150}
        },
        "additionalProperties": false
    }`
    
    // Seed with valid and invalid examples
    f.Add(`{"name":"Alice","email":"alice@example.com","age":30}`)
    f.Add(`{"name":"","email":"invalid","age":-5}`)
    f.Add(`{"name":"Bob","email":"bob@test.com"}`)
    
    f.Fuzz(func(t *testing.T, input string) {
        // Validation should never crash
        isValid, err := validateJSONSchema(input, schema)
        
        if err != nil {
            // Validation errors are OK, but should be graceful
            if err.Error() == "" {
                t.Error("Validation error should have descriptive message")
            }
        }
        
        if isValid {
            // If data is valid, it should parse correctly
            var parsed map[string]interface{}
            if parseErr := json.Unmarshal([]byte(input), &parsed); parseErr != nil {
                t.Errorf("Valid schema but unparseable JSON: %v", parseErr)
            }
        }
    })
}

// Run fuzzing with: go test -fuzz=FuzzJSONParser -fuzztime=30s
```

**JavaScript fuzzing with custom generators:**

```javascript
const fc = require('fast-check');

describe('JSON fuzzing tests', () => {
  test('fuzz test JSON parsing with random strings', () => {
    fc.assert(
      fc.property(fc.string({ minLength: 0, maxLength: 1000 }), (randomString) => {
        try {
          const parsed = JSON.parse(randomString);
          
          // If parsing succeeded, result should be serializable
          const reserialized = JSON.stringify(parsed);
          expect(typeof reserialized).toBe('string');
          
          // Round-trip should preserve data
          const reparsed = JSON.parse(reserialized);
          expect(reparsed).toEqual(parsed);
          
        } catch (error) {
          // SyntaxError is expected for malformed JSON
          expect(error).toBeInstanceOf(SyntaxError);
        }
      }),
      { numRuns: 1000 }
    );
  });

  test('fuzz test with structured JSON mutations', () => {
    // Start with valid JSON and mutate it
    const baseJSON = {
      name: 'Alice',
      age: 30,
      preferences: {
        newsletter: true,
        theme: 'dark'
      },
      tags: ['user', 'premium']
    };

    fc.assert(
      fc.property(
        fc.record({
          // Mutate string fields with various edge cases
          name: fc.oneof(
            fc.string(),
            fc.constant(''),
            fc.constant(null),
            fc.constant(undefined),
            fc.string({ minLength: 10000, maxLength: 10000 }), // Very long string
            fc.constantFrom('\0', '\n', '\r', '\t', '"', '\\', '\u0001')
          ),
          
          // Mutate numeric fields
          age: fc.oneof(
            fc.integer(),
            fc.float(),
            fc.constant(Number.MAX_SAFE_INTEGER),
            fc.constant(Number.MIN_SAFE_INTEGER),
            fc.constant(Infinity),
            fc.constant(-Infinity),
            fc.constant(NaN),
            fc.constant('not a number')
          ),
          
          // Mutate nested objects
          preferences: fc.oneof(
            fc.object(),
            fc.constant(null),
            fc.constant('not an object'),
            fc.array(fc.anything()),
            fc.record({
              newsletter: fc.anything(),
              theme: fc.anything()
            })
          ),
          
          // Mutate arrays
          tags: fc.oneof(
            fc.array(fc.anything()),
            fc.constant(null),
            fc.constant('not an array'),
            fc.object()
          )
        }),
        
        (mutatedObject) => {
          try {
            // Attempt to serialize the mutated object
            const jsonString = JSON.stringify(mutatedObject);
            
            // If serialization succeeded, parsing should work
            const parsed = JSON.parse(jsonString);
            
            // Basic structure validation
            expect(typeof parsed).toBe('object');
            
          } catch (error) {
            // Some mutations may create unserializable objects
            // This is acceptable behavior
          }
        }
      ),
      { numRuns: 500 }
    );
  });
  
  test('fuzz test deeply nested structures', () => {
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100 }),
        fc.string({ minLength: 1, maxLength: 50 }),
        (depth, content) => {
          // Create deeply nested object
          let nested = content;
          for (let i = 0; i < depth; i++) {
            nested = { [`level${i}`]: nested };
          }
          
          try {
            const jsonString = JSON.stringify(nested);
            const parsed = JSON.parse(jsonString);
            
            // Verify we can traverse the structure
            let current = parsed;
            for (let i = 0; i < depth; i++) {
              expect(current).toHaveProperty(`level${i}`);
              current = current[`level${i}`];
            }
            expect(current).toBe(content);
            
          } catch (error) {
            // Deep nesting might hit stack limits - that's acceptable
            if (depth > 50) {
              expect(error.message).toMatch(/stack|depth|recursion/i);
            } else {
              throw error; // Unexpected error for reasonable depth
            }
          }
        }
      ),
      { numRuns: 200 }
    );
  });
});
```

### Malformed JSON Test Cases

Systematic testing of malformed JSON helps ensure robust error handling:

```javascript
const malformedTestCases = [
  // Syntax errors
  { input: '{', description: 'Incomplete object' },
  { input: '[', description: 'Incomplete array' },
  { input: '{"name": }', description: 'Missing value' },
  { input: '{"name": "Alice",}', description: 'Trailing comma in object' },
  { input: '[1, 2, 3,]', description: 'Trailing comma in array' },
  { input: '{name: "Alice"}', description: 'Unquoted key' },
  { input: "{'name': 'Alice'}", description: 'Single quotes' },
  { input: '{"name": undefined}', description: 'Undefined value' },
  { input: '{"name": "Alice" "age": 30}', description: 'Missing comma' },
  
  // Structure errors
  { input: '{"name": "Alice"}}', description: 'Extra closing brace' },
  { input: '[1, 2, 3]]', description: 'Extra closing bracket' },
  { input: '{"a": {"b": }', description: 'Nested incomplete object' },
  
  // Type confusion
  { input: 'function(){return "Alice"}', description: 'Function as JSON' },
  { input: 'new Date()', description: 'Constructor call' },
  { input: '/regex/gi', description: 'Regular expression' },
  
  // Control characters
  { input: '{"name": "Alice\x00"}', description: 'Null byte in string' },
  { input: '{"name": "Alice\n\r\t"}', description: 'Newlines in string' },
  { input: '{\x01"name": "Alice"}', description: 'Control character in key' },
  
  // Unicode edge cases
  { input: '{"name": "\uDC00"}', description: 'Invalid unicode surrogate' },
  { input: '{"name": "\uD800"}', description: 'Unpaired high surrogate' },
  { input: '{"name": "\\u"}', description: 'Incomplete unicode escape' },
  
  // Number edge cases
  { input: '{"age": 01}', description: 'Leading zero in number' },
  { input: '{"price": .5}', description: 'Number starting with decimal' },
  { input: '{"value": 1.}', description: 'Number ending with decimal' },
  { input: '{"inf": Infinity}', description: 'Infinity literal' },
  { input: '{"nan": NaN}', description: 'NaN literal' },
  
  // Large payloads
  { 
    input: '{"huge": "' + 'x'.repeat(10 * 1024 * 1024) + '"}', 
    description: '10MB string value' 
  },
  { 
    input: '[' + '1,'.repeat(1000000) + '1]', 
    description: '1M item array' 
  },
  {
    input: '{' + '"a":'.repeat(1000) + '{}' + '}'.repeat(1000),
    description: 'Deeply nested objects'
  }
];

describe('Malformed JSON handling', () => {
  malformedTestCases.forEach(({ input, description }) => {
    test(`handles ${description}`, () => {
      expect(() => {
        JSON.parse(input);
      }).toThrow();
      
      // API should handle malformed JSON gracefully
      return request(app)
        .post('/api/data')
        .set('Content-Type', 'application/json')
        .send(input)
        .expect(400)
        .expect(res => {
          expect(res.body.title).toContain('Invalid JSON');
          expect(res.body.detail).not.toContain('SyntaxError'); // Hide internal errors
        });
    });
  });
});
```

### CI/CD Pipeline Integration

Comprehensive testing automation ensures consistent quality across all changes:


![Diagram 8](chapter-13-testing-diagram-8-light.png){width=85%}


**GitHub Actions workflow for comprehensive JSON system testing:**

```yaml
name: Comprehensive Testing Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  lint-and-format:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run ESLint
        run: npm run lint
      
      - name: Check code formatting
        run: npm run format:check
      
      - name: Validate JSON schemas
        run: npm run validate:schemas

  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run unit tests
        run: npm test
        env:
          CI: true
      
      - name: Upload test coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage/lcov.info
          flags: unittests

  schema-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run schema-based tests
        run: npm run test:schema
      
      - name: Run property-based tests
        run: npm run test:property

  integration-tests:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: testpass
          POSTGRES_DB: testdb
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432
      
      redis:
        image: redis:7
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379
    
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run database migrations
        run: npm run db:migrate
        env:
          DATABASE_URL: postgresql://postgres:testpass@localhost:5432/testdb
      
      - name: Run integration tests
        run: npm run test:integration
        env:
          DATABASE_URL: postgresql://postgres:testpass@localhost:5432/testdb
          REDIS_URL: redis://localhost:6379

  contract-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run consumer contract tests
        run: npm run test:pact:consumer
      
      - name: Publish contracts
        if: github.ref == 'refs/heads/main'
        run: npm run pact:publish
        env:
          PACT_BROKER_BASE_URL: ${{ secrets.PACT_BROKER_URL }}
          PACT_BROKER_TOKEN: ${{ secrets.PACT_BROKER_TOKEN }}
      
      - name: Run provider verification
        run: npm run test:pact:provider
        env:
          PACT_BROKER_BASE_URL: ${{ secrets.PACT_BROKER_URL }}
          PACT_BROKER_TOKEN: ${{ secrets.PACT_BROKER_TOKEN }}

  security-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run security tests
        run: npm run test:security
      
      - name: SAST scanning
        uses: github/super-linter@v4
        env:
          DEFAULT_BRANCH: main
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          VALIDATE_JSON: true
          VALIDATE_JAVASCRIPT_ES: true
      
      - name: Dependency vulnerability scan
        run: npm audit --audit-level moderate

  performance-tests:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' || contains(github.event.pull_request.labels.*.name, 'performance')
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup k6
        uses: grafana/setup-k6@v1
      
      - name: Start test environment
        run: |
          docker-compose -f docker-compose.test.yml up -d
          sleep 30  # Wait for services to be ready
      
      - name: Run load tests
        run: k6 run --out json=performance-results.json tests/performance/api-load-test.js
      
      - name: Parse performance results
        run: |
          npm run parse-k6-results performance-results.json > performance-summary.md
      
      - name: Comment performance results
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const summary = fs.readFileSync('performance-summary.md', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Performance Test Results\n\n${summary}`
            });

  fuzz-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Go
        uses: actions/setup-go@v4
        with:
          go-version: '1.21'
      
      - name: Run Go fuzz tests
        run: |
          cd backend
          go test -fuzz=FuzzJSONParser -fuzztime=2m
          go test -fuzz=FuzzJSONSchemaValidation -fuzztime=2m
      
      - name: Setup Node.js for JS fuzzing
        uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
      
      - name: Install dependencies
        run: npm ci
      
      - name: Run JavaScript fuzz tests
        run: npm run test:fuzz

  deployment-readiness:
    runs-on: ubuntu-latest
    needs: [lint-and-format, unit-tests, schema-tests, integration-tests, contract-tests, security-tests]
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Check all tests passed
        run: echo "All test suites passed - ready for deployment"
      
      - name: Trigger deployment
        uses: repository-dispatch@v1
        with:
          token: ${{ secrets.DEPLOYMENT_TOKEN }}
          event-type: deploy-production
          client-payload: |
            {
              "sha": "${{ github.sha }}",
              "ref": "${{ github.ref }}"
            }
```

**Test organization and configuration:**

```javascript
// package.json test scripts
{
  "scripts": {
    "test": "jest --coverage",
    "test:unit": "jest --testPathPattern=unit",
    "test:integration": "jest --testPathPattern=integration --runInBand",
    "test:schema": "jest --testPathPattern=schema",
    "test:property": "jest --testPathPattern=property",
    "test:security": "jest --testPathPattern=security",
    "test:pact:consumer": "jest --testPathPattern=pact/consumer",
    "test:pact:provider": "jest --testPathPattern=pact/provider",
    "test:fuzz": "jest --testPathPattern=fuzz --testTimeout=60000",
    "test:performance": "k6 run tests/performance/load-test.js",
    "test:all": "npm run test && npm run test:integration && npm run test:security",
    
    "lint": "eslint src/ tests/",
    "format:check": "prettier --check src/ tests/",
    "format:fix": "prettier --write src/ tests/",
    "validate:schemas": "ajv validate --all-errors schemas/*.json"
  }
}
```

**Continuous monitoring and alerting:**

```yaml
# monitoring/alerts.yml - Prometheus alerting rules
groups:
  - name: json-api-performance
    rules:
      - alert: HighJSONParseLatency
        expr: histogram_quantile(0.95, rate(json_parse_duration_seconds_bucket[5m])) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High JSON parsing latency detected"
          description: "95th percentile JSON parsing latency is above 100ms"
      
      - alert: JSONValidationErrors
        expr: rate(json_validation_errors_total[5m]) > 0.1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High rate of JSON validation errors"
          description: "JSON validation error rate is above 10%"
      
      - alert: LargeJSONPayloads
        expr: histogram_quantile(0.95, rate(json_payload_size_bytes_bucket[5m])) > 1048576
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Large JSON payloads detected"
          description: "95th percentile JSON payload size exceeds 1MB"
```

`★ Insight ─────────────────────────────────────`
Fuzz testing and CI/CD integration represent the final layer of a comprehensive JSON testing strategy. The key insight is that JSON systems fail in unexpected ways - parsers can crash on malformed input, validators can be bypassed with edge cases, and performance can degrade catastrophically with pathological inputs. Fuzzing discovers these edge cases automatically by generating millions of test cases that human testers would never think to create. When integrated into CI/CD pipelines, this testing becomes a safety net that catches regressions before they reach production, ensuring that JSON systems remain robust as they evolve.
`─────────────────────────────────────────────────`

Fuzz testing and CI/CD integration complete the comprehensive testing strategy for JSON systems. By systematically generating malformed inputs and edge cases, fuzzing discovers vulnerabilities that traditional testing misses. When combined with automated pipelines that run schema validation, contract tests, security scans, and performance benchmarks on every change, teams can deploy JSON systems with confidence that they will handle real-world conditions reliably and securely.

**Testing brings the JSON ecosystem full circle** - validating that all the modular pieces (schemas, binary formats, protocols, streaming, security) work correctly in combination. Comprehensive testing transforms JSON's flexibility from a liability (anything parses) into an asset (validated, reliable systems).

We've now covered the complete JSON ecosystem: its architecture, all major technical layers, practical application patterns, and testing strategies. One question remains: **where is JSON going?** Chapter 14 looks forward - emerging patterns, JSON's limitations that still lack solutions, and the technologies that may eventually succeed it.

**Next:** Chapter 14 - The Future of JSON and Beyond
