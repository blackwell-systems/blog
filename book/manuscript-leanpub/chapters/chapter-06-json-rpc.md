# Chapter 6: JSON-RPC - When REST Isn't Enough

We've covered validation (JSON Schema), storage optimization (JSONB/BSON), and network efficiency (MessagePack/CBOR). Each addressed a different gap in JSON's capabilities as a modular, independent solution.

Now we examine another gap: **protocol conventions**. JSON defines data structure, but doesn't define how remote procedure calls should work. REST emerged as one answer, but its resource-oriented model doesn't fit every problem.

{blurb, class: information}
**What XML Had:** SOAP and XML-RPC (1999-2003)

**XML's approach:** Comprehensive protocol stack with SOAP envelopes, WSDL service definitions, WS-* extensions for security/reliability/transactions, and automatic code generation from schemas.

```xml
<!-- SOAP: Full protocol infrastructure -->
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Header>
    <wsse:Security>...</wsse:Security>
  </soap:Header>
  <soap:Body>
    <tns:GetUser xmlns:tns="http://example.com/users">
      <tns:UserId>123</tns:UserId>
    </tns:GetUser>
  </soap:Body>
</soap:Envelope>
```

**Benefit:** Complete protocol definition, automatic tooling, enterprise features  
**Cost:** Massive complexity, heavyweight infrastructure, steep learning curve

**JSON's approach:** Lightweight protocol conventions (JSON-RPC) - optional structure

**Architecture shift:** Heavyweight protocol -> Lightweight convention, Built-in tooling -> Simple libraries, Enterprise features -> Essential simplicity
{/blurb}

REST dominates web APIs, but its resource-oriented model doesn't fit every problem. How do you represent `transfer_funds(from, to, amount)` as HTTP verbs and URLs? You could force it into `POST /transfers` with a body, but you're fighting the paradigm.

**JSON-RPC solves this:** It's a simple protocol for calling remote functions over any transport (HTTP, WebSockets, Unix sockets). No mental gymnastics to fit actions into resource models.

This chapter covers the JSON-RPC 2.0 specification, implementation patterns, real-world usage (Ethereum, Language Server Protocol, Bitcoin), and when to choose RPC over REST.

## Running Example: User API with JSON-RPC

Our running User API example from Chapter 1 now has validation (Chapter 3) and efficient storage (Chapter 4).

Now JSON-RPC adds the **protocol layer** - structured remote function calls for our User API.

**REST approach (resource-oriented):**
```http
GET    /users/user-5f9d88c          # Get user
PUT    /users/user-5f9d88c          # Update user
POST   /users/user-5f9d88c/follow   # Follow action (forced into REST)
GET    /users/search?q=alice        # Search (not really RESTful)
```

**JSON-RPC approach (action-oriented):**
```json
{"jsonrpc": "2.0", "method": "getUserById", "params": {"id": "user-5f9d88c"}, "id": 1}
{"jsonrpc": "2.0", "method": "updateUser", "params": {"id": "user-5f9d88c", "name": "Alice Smith"}, "id": 2}
{"jsonrpc": "2.0", "method": "followUser", "params": {"followerId": "user-abc123", "followeeId": "user-5f9d88c"}, "id": 3}
{"jsonrpc": "2.0", "method": "searchUsers", "params": {"query": "alice", "filters": {"verified": true}}, "id": 4}
```

**Why JSON-RPC fits user management:** The action-oriented nature of user management reveals itself when you consider operations like `followUser()` - this is fundamentally an action, not a resource manipulation. Complex operations like `searchUsers()` with multi-field filtering become natural function calls rather than awkward URL parameters. JSON-RPC's batch request support lets clients fetch a user, their followers, and their following list in a single round-trip. For real-time features like presence indicators or live notifications, WebSocket transport provides bidirectional communication that REST's request-response model cannot match.

This completes the **protocol layer** for our User API.

---

## The RPC Problem

### Functions Across the Network

Programming is full of function calls:

```javascript
// Local function
const result = calculator.add(5, 3);  // 8
```

Distributed systems need the same concept:

```javascript
// Remote function (same interface)
const result = await remoteCalculator.add(5, 3);  // 8
```

**The challenge:** How do you encode function calls for transmission over the network?

### Why REST Doesn't Always Fit

REST is resource-oriented. It models everything as CRUD operations on resources:

```http
GET    /users/123      # Read
POST   /users          # Create
PUT    /users/123      # Update
DELETE /users/123      # Delete
```

This works well for data-centric APIs. But what about:

- **Actions:** `transferFunds(from, to, amount)`
- **Calculations:** `calculateRoute(origin, destination)`
- **Operations:** `restartServer(serverId)`
- **Queries:** `searchUsers(query, filters, pagination)`

You can force these into REST:

```http
POST /transfers
POST /route-calculations
POST /server-restarts
GET  /users?search=query&filter=...
```

But you're working against the model. The endpoints become verb-heavy, the resource abstraction breaks down, and you end up with a de facto RPC API pretending to be REST.

{blurb, class: warning}
**The REST Contortion Problem:** Many real-world operations violate REST's resource model and require awkward workarounds:

**Batch operations:** How do you "delete 100 users" RESTfully? `DELETE /users?ids=1,2,3...` breaks URI semantics.  
**Transactions:** How do you express "transfer funds AND log transaction AND notify user" as atomic operation?  
**Complex queries:** Search with 10 filters becomes `/users?filter1=x&filter2=y&filter3=z...` (URL length limits).  
**Multi-resource actions:** "Archive project AND notify team AND update dashboard" spans multiple resources.  
**Stateful operations:** "Start build -> monitor progress -> retrieve artifacts" doesn't map to CRUD.

**In JSON-RPC, these are just function calls:**
- `batchDeleteUsers(ids: [1,2,3,...])`
- `transferFunds(from, to, amount, notify: true)`
- `searchUsers(filters: {...})`
- `archiveProject(projectId, options: {...})`
- `startBuild(params) -> pollBuildStatus(buildId) -> getArtifacts(buildId)`

The paradigm matches the problem naturally.
{/blurb}

{blurb, class: information}
**The Cardinality Problem:** REST naturally expresses "all or one" but struggles with "some":
- `GET /users` - all users (collection)
- `GET /users/123` - one user (item)
- `GET /users?ids=1,5,12` - some specific users (awkward, not RESTful)

Try that last one in a code review and your local architect will have opinions.

**Common "RESTful" workarounds teams are forced into:**

**Option 1:** POST with body (violates HTTP semantics)
```http
POST /users/batch-get
{"ids": [1, 5, 12]}
```
Now reads use POST. Not cacheable, not idempotent.

**Option 2:** Create temporary "selection" resources
```http
POST /user-selections -> {"selection_id": "abc"}
GET /user-selections/abc/users
```
Two requests to get some users. Absurdly complex.

**Option 3:** Multiple single requests
```http
GET /users/1
GET /users/5  
GET /users/12
```
3 round trips. Latency compounds.

**Option 4:** Switch to GraphQL
```graphql
query { user1: user(id: 1), user5: user(id: 5) }
```
You've abandoned REST entirely.

**Option 5:** Use query params anyway and endure the code review comments.

RPC treats all cardinalities equally as function parameters:
- `getAllUsers()` - all
- `getUser(id: 123)` - one  
- `getUsers(ids: [1,5,12])` - some (no awkwardness, no arguments)
- `searchUsers(query, filters)` - filtered some

**REST couples URLs to database structure. RPC describes operations:**

REST URLs often mirror database tables:
```
/users     → SELECT * FROM users
/posts     → SELECT * FROM posts
/comments  → SELECT * FROM comments
```
**Problem:** Database refactoring forces API changes. Split a table? Your URL structure breaks. Add a join table? Need new endpoints.

RPC methods hide implementation details:
```javascript
getUserProfile(id)      // Queries: users + posts + followers (3 tables)
searchContent(query)    // Hits: Elasticsearch (not database at all)
processOrder(orderId)   // Touches: 5 microservices across 3 databases
```

**Benefit:** Refactor backend freely without breaking API contract. Add caching, change storage systems, split services - clients see the same method signature.

**Key Insight:** REST excels at resource manipulation (CRUD). RPC excels at action invocation (function calls). Choose based on your domain - don't force actions into resource models or vice versa. If your API is mostly verbs (calculate, process, execute, transform), RPC is the natural fit.
{/blurb}

### The RPC Renaissance

RPC isn't new - it dates to the 1980s (Sun RPC, CORBA). But modern RPC protocols learned from past failures.

**Old RPC struggled with complexity:** CORBA and SOAP demanded heavyweight specifications that tightly coupled implementations to specific programming languages. Tooling was poor, requiring specialized infrastructure, and XML payloads bloated network traffic. These protocols were technically complete but practically burdensome.

**Modern RPC embraced simplicity:** JSON-RPC 2.0 fits on 8 pages. The specification is language-agnostic, working anywhere JSON works. Excellent libraries exist for every major language, and efficient formats like JSON and Protocol Buffers keep payloads lean. The shift from comprehensive to minimal mirrors the broader architectural pattern we've seen throughout this book.

**Evolution of RPC Protocols Timeline:**

| Year | Protocol | Description | Characteristics |
|------|----------|-------------|-----------------|
| 1984 | Sun RPC (ONC RPC) | Binary protocol, C-centric | First widely adopted RPC |
| 1991 | CORBA | Complex, multi-language | Enterprise-grade, heavyweight |
| 1998 | XML-RPC | Simple HTTP + XML | Human-readable, cross-platform |
| 1999 | SOAP | Enterprise standard, heavyweight | Comprehensive but complex |
| 2005 | JSON-RPC 1.0 | Lightweight alternative | Simple JSON-based RPC |
| 2010 | JSON-RPC 2.0 | Current specification | Simplified and standardized |
| 2015 | gRPC (Google) | Protocol Buffers + HTTP/2 | High-performance, type-safe |
| 2020+ | Modern adoption | Ethereum, LSP, Bitcoin use JSON-RPC | Widespread production use |

---

## What is JSON-RPC?

JSON-RPC 2.0 is a **stateless, light-weight remote procedure call protocol** that uses JSON for [serialization](#).

**Specification:** [jsonrpc.org/spec](https://www.jsonrpc.org/specification)  
**Length:** 8 pages  
**Release:** 2010

{blurb, class: information}
**Protocol vs Architectural Style:** JSON-RPC is a **protocol** (concrete specification with exact message format). REST is an **architectural style** (design principles without exact specification). This is why:
- JSON-RPC compliance is objective: does your message have `jsonrpc`, `method`, `params`, `id`? Yes or no.
- REST compliance is subjective: is this "RESTful enough"? Depends who you ask.
- JSON-RPC has a version number (2.0). REST doesn't (it's conceptual).
- JSON-RPC debates are rare (spec is clear). REST debates are endless (principles are interpretable).

This distinction matters: protocols give clarity, architectural styles give flexibility. Choose based on whether you need strict interoperability (protocol) or design guidance (style).
{/blurb}

### Core Concepts

JSON-RPC's power comes from its deliberate simplicity. Unlike heavyweight protocols that lock you into specific transports or languages, JSON-RPC treats these as implementation details.

**Transport independence** means you choose the right communication channel for your needs. Most implementations use HTTP for its ubiquity and tooling support, but JSON-RPC works equally well over WebSockets when you need bidirectional communication, Unix sockets for efficient local inter-process communication, raw TCP sockets for custom network protocols, or even message queues for asynchronous processing. The protocol itself doesn't care - it's just JSON messages flowing over bytes.

**Statelessness** makes JSON-RPC servers easy to scale. Each request contains everything needed to process it, with no session management or state synchronization between requests. This means you can distribute load across multiple servers without sticky sessions, restart servers without losing state, or even process requests out of order. If your application needs state, manage it explicitly in your data layer - don't hide it in protocol semantics.

The **specification itself** fits on eight pages because it defines only what matters: three message types (request, response, notification), a small set of standard error codes, and batch request support. This minimalism is intentional - everything else is application-specific. No authentication scheme, no transport binding, no encoding rules beyond JSON. The specification tells you how to structure messages, not how to build systems.

**Language agnosticism** follows naturally from the JSON foundation. Any language with JSON support can implement JSON-RPC - no special parsers, no code generation, no IDL compilers. Libraries exist for every major language, but you don't need them. The entire protocol can be implemented in 50 lines of code if needed. This matters for polyglot systems where different services use different languages based on their requirements, not protocol constraints.

### JSON-RPC Request

```json
{
  "jsonrpc": "2.0",
  "method": "subtract",
  "params": [42, 23],
  "id": 1
}
```

**Fields:**
- `jsonrpc` - Protocol version (always "2.0")
- `method` - Function name to call
- `params` - Function arguments (array or object)
- `id` - Request identifier (for matching response)

### JSON-RPC Response (Success)

```json
{
  "jsonrpc": "2.0",
  "result": 19,
  "id": 1
}
```

**Fields:**
- `jsonrpc` - Protocol version
- `result` - Return value
- `id` - Matches request `id`

### JSON-RPC Response (Error)

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32601,
    "message": "Method not found",
    "data": "No method named 'subtract'"
  },
  "id": 1
}
```

**Error object:**
- `code` - Numeric error code
- `message` - Human-readable description
- `data` - Optional additional information

### JSON-RPC Notification

A request without `id` - fire-and-forget:

```json
{
  "jsonrpc": "2.0",
  "method": "logEvent",
  "params": {"level": "info", "message": "User logged in"}
}
```

No response expected or sent. Useful for logging, metrics, non-critical updates.


![JSON-RPC Request Types](chapter-06-json-rpc-diagram-1-light--depreciated.png)
{width: 85%}


---

## Parameter Formats

JSON-RPC supports two parameter styles:

### Positional Parameters (Array)

```json
{
  "jsonrpc": "2.0",
  "method": "subtract",
  "params": [42, 23],
  "id": 1
}
```

Server receives parameters by position:

```javascript
function subtract(a, b) {
  return a - b;  // a=42, b=23
}
```

**Use when:**
- Function has few parameters (1-3)
- Parameter order is obvious
- Compatibility with older clients matters

### Named Parameters (Object)

```json
{
  "jsonrpc": "2.0",
  "method": "subtract",
  "params": {"minuend": 42, "subtrahend": 23},
  "id": 1
}
```

Server receives parameters by name:

```javascript
function subtract({minuend, subtrahend}) {
  return minuend - subtrahend;
}
```

**Use when:**
- Function has many parameters
- Parameter order isn't obvious
- Optional parameters exist
- Self-documenting calls matter

**Recommendation:** Use named parameters for new APIs. They're more maintainable and self-documenting.

---

## Standard Error Codes

JSON-RPC defines standard error codes for common failures:

| Code | Message | Meaning |
|------|---------|---------|
| -32700 | Parse error | Invalid JSON received |
| -32600 | Invalid Request | JSON is not a valid request object |
| -32601 | Method not found | Method does not exist |
| -32602 | Invalid params | Invalid method parameters |
| -32603 | Internal error | Internal JSON-RPC error |
| -32000 to -32099 | Server error | Implementation-defined server errors |

**Application-defined errors** should use codes outside these ranges:

```javascript
const ErrorCodes = {
  UNAUTHORIZED: -32001,
  RATE_LIMIT_EXCEEDED: -32002,
  RESOURCE_NOT_FOUND: -32003,
  VALIDATION_FAILED: -32004,
  INSUFFICIENT_FUNDS: -32005
};
```

{blurb, class: warning}
**Error Code Convention:** Reserve -32000 to -32099 for server errors (infrastructure, not business logic). Use codes starting from -32100 or positive numbers for application-specific errors.
{/blurb}

---

## Batch Requests

Send multiple requests in one HTTP call:

**Request:**
```json
[
  {"jsonrpc": "2.0", "method": "sum", "params": [1,2,4], "id": "1"},
  {"jsonrpc": "2.0", "method": "subtract", "params": [42,23], "id": "2"},
  {"jsonrpc": "2.0", "method": "notify_hello", "params": [7]},
  {"jsonrpc": "2.0", "method": "get_data", "id": "9"}
]
```

**Response:**
```json
[
  {"jsonrpc": "2.0", "result": 7, "id": "1"},
  {"jsonrpc": "2.0", "result": 19, "id": "2"},
  {"jsonrpc": "2.0", "result": ["hello", 5], "id": "9"}
]
```

**Note:** Notification (`notify_hello`) has no response.

**Benefits:**
- Reduced HTTP overhead (3 calls -> 1 request)
- Lower latency (1 round trip instead of 3)
- Atomic batches (all succeed or all fail)
- Better connection utilization

**Use cases:**
- Bulk operations (process 100 items)
- Dependent calls (fetch user, fetch orders for user)
- Dashboard aggregation (fetch multiple widgets)

---

## Implementing a JSON-RPC Server

### Node.js (Express)

```javascript
const express = require('express');
const app = express();

app.use(express.json());

// Define methods
const methods = {
  add: (a, b) => a + b,
  
  subtract: (a, b) => a - b,
  
  multiply: (a, b) => a * b,
  
  divide: (a, b) => {
    if (b === 0) {
      const error = new Error('Division by zero');
      error.code = -32000;
      throw error;
    }
    return a / b;
  },
  
  // Named parameters
  greet: ({name, title}) => {
    return `Hello, ${title} ${name}!`;
  }
};

// JSON-RPC handler
app.post('/rpc', (req, res) => {
  const request = req.body;
  
  // Validate request structure
  if (!request.jsonrpc || request.jsonrpc !== '2.0') {
    return res.json({
      jsonrpc: '2.0',
      error: {code: -32600, message: 'Invalid Request'},
      id: request.id || null
    });
  }
  
  // Handle batch requests
  if (Array.isArray(request)) {
    const responses = request
      .map(req => handleSingleRequest(req))
      .filter(resp => resp !== null); // Filter out notifications
    return res.json(responses);
  }
  
  // Handle single request
  const response = handleSingleRequest(request);
  if (response) {
    res.json(response);
  } else {
    res.status(204).end(); // Notification - no response
  }
});

function handleSingleRequest(request) {
  const {method, params, id} = request;
  
  // Notification - no response
  if (id === undefined) {
    if (methods[method]) {
      try {
        methods[method](...(Array.isArray(params) ? params : [params]));
      } catch (err) {
        // Notifications don't return errors
      }
    }
    return null;
  }
  
  // Check if method exists
  if (!methods[method]) {
    return {
      jsonrpc: '2.0',
      error: {code: -32601, message: 'Method not found'},
      id
    };
  }
  
  // Execute method
  try {
    let args;
    if (Array.isArray(params)) {
      args = params;
    } else if (typeof params === 'object') {
      args = [params]; // Named parameters
    } else {
      args = [];
    }
    
    const result = methods[method](...args);
    
    return {
      jsonrpc: '2.0',
      result,
      id
    };
  } catch (error) {
    return {
      jsonrpc: '2.0',
      error: {
        code: error.code || -32603,
        message: error.message
      },
      id
    };
  }
}

app.listen(3000, () => {
  console.log('JSON-RPC server on http://localhost:3000/rpc');
});
```

### Go (net/rpc/jsonrpc)

```go
package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
)

// MathService provides mathematical operations
type MathService struct{}

// Args for basic math operations
type Args struct {
	A float64 `json:"a"`
	B float64 `json:"b"`
}

// Add two numbers
func (s *MathService) Add(args Args) (float64, error) {
	return args.A + args.B, nil
}

// Subtract two numbers
func (s *MathService) Subtract(args Args) (float64, error) {
	return args.A - args.B, nil
}

// Divide two numbers
func (s *MathService) Divide(args Args) (float64, error) {
	if args.B == 0 {
		return 0, errors.New("division by zero")
	}
	return args.A / args.B, nil
}

// JSON-RPC request structure
type Request struct {
	JsonRPC string          `json:"jsonrpc"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params"`
	ID      interface{}     `json:"id"`
}

// JSON-RPC response structure
type Response struct {
	JsonRPC string      `json:"jsonrpc"`
	Result  interface{} `json:"result,omitempty"`
	Error   *Error      `json:"error,omitempty"`
	ID      interface{} `json:"id"`
}

// Error structure
type Error struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

var mathService = &MathService{}

func handleRPC(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req Request
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, -32700, "Parse error", nil)
		return
	}

	if req.JsonRPC != "2.0" {
		writeError(w, -32600, "Invalid Request", req.ID)
		return
	}

	// Dispatch to method
	var result interface{}
	var err error

	switch req.Method {
	case "add":
		var args Args
		json.Unmarshal(req.Params, &args)
		result, err = mathService.Add(args)
	case "subtract":
		var args Args
		json.Unmarshal(req.Params, &args)
		result, err = mathService.Subtract(args)
	case "divide":
		var args Args
		json.Unmarshal(req.Params, &args)
		result, err = mathService.Divide(args)
	default:
		writeError(w, -32601, "Method not found", req.ID)
		return
	}

	if err != nil {
		writeError(w, -32000, err.Error(), req.ID)
		return
	}

	resp := Response{
		JsonRPC: "2.0",
		Result:  result,
		ID:      req.ID,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func writeError(w http.ResponseWriter, code int, message string, id interface{}) {
	resp := Response{
		JsonRPC: "2.0",
		Error:   &Error{Code: code, Message: message},
		ID:      id,
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK) // JSON-RPC errors use 200 status
	json.NewEncoder(w).Encode(resp)
}

func main() {
	http.HandleFunc("/rpc", handleRPC)
	fmt.Println("JSON-RPC server on http://localhost:8080/rpc")
	http.ListenAndServe(":8080", nil)
}
```

**Python implementation available:** See [companion repository](https://github.com/blackwell-systems/you-dont-know-json) for Flask-based JSON-RPC server with decorator pattern for method registration.

{blurb, class: tip}
**Implementation Checklist:**
- [ ] Validate `jsonrpc` version field
- [ ] Handle both positional and named parameters
- [ ] Support batch requests
- [ ] Handle notifications (no `id` field)
- [ ] Return standard error codes
- [ ] Use HTTP 200 for all JSON-RPC responses (errors included)
- [ ] Set `Content-Type: application/json`
{/blurb}

---

## Implementing a JSON-RPC Client

### JavaScript (Browser/Node.js)

```javascript
class JSONRPCClient {
  constructor(url, options = {}) {
    this.url = url;
    this.requestId = 0;
    this.timeout = options.timeout || 30000;
    this.headers = options.headers || {};
  }
  
  /**
   * Call a remote method
   * @param {string} method - Method name
   * @param {Array|Object} params - Parameters
   * @returns {Promise<any>} Result
   */
  async call(method, params = []) {
    const request = {
      jsonrpc: '2.0',
      method,
      params,
      id: ++this.requestId
    };
    
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);
    
    try {
      const response = await fetch(this.url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...this.headers
        },
        body: JSON.stringify(request),
        signal: controller.signal
      });
      
      clearTimeout(timeoutId);
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }
      
      const data = await response.json();
      
      if (data.error) {
        const error = new Error(data.error.message);
        error.code = data.error.code;
        error.data = data.error.data;
        throw error;
      }
      
      return data.result;
    } catch (error) {
      clearTimeout(timeoutId);
      if (error.name === 'AbortError') {
        throw new Error(`Request timeout after ${this.timeout}ms`);
      }
      throw error;
    }
  }
  
  /**
   * Send a notification (no response expected)
   * @param {string} method - Method name
   * @param {Array|Object} params - Parameters
   */
  notify(method, params = []) {
    const request = {
      jsonrpc: '2.0',
      method,
      params
    };
    
    // Fire and forget
    fetch(this.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...this.headers
      },
      body: JSON.stringify(request)
    }).catch(() => {
      // Ignore errors for notifications
    });
  }
  
  /**
   * Send batch request
   * @param {Array<{method, params}>} calls - Array of calls
   * @returns {Promise<Array>} Array of results
   */
  async batch(calls) {
    const requests = calls.map(call => ({
      jsonrpc: '2.0',
      method: call.method,
      params: call.params || [],
      id: ++this.requestId
    }));
    
    const response = await fetch(this.url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...this.headers
      },
      body: JSON.stringify(requests)
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    
    // Map responses back to call order
    return requests.map(req => {
      const resp = data.find(r => r.id === req.id);
      if (!resp) {
        throw new Error(`No response for request ${req.id}`);
      }
      if (resp.error) {
        const error = new Error(resp.error.message);
        error.code = resp.error.code;
        throw error;
      }
      return resp.result;
    });
  }
}

// Usage examples
const client = new JSONRPCClient('http://localhost:3000/rpc', {
  timeout: 5000,
  headers: {
    'Authorization': 'Bearer token123'
  }
});

// Simple call
const sum = await client.call('add', [5, 3]);
console.log('Sum:', sum);  // 8

// Named parameters
const greeting = await client.call('greet', {name: 'Alice', title: 'Dr.'});
console.log(greeting);  // "Hello, Dr. Alice!"

// Notification
client.notify('logEvent', {level: 'info', message: 'User action'});

// Batch request
const results = await client.batch([
  {method: 'add', params: [1, 2]},
  {method: 'multiply', params: [3, 4]},
  {method: 'subtract', params: [10, 5]}
]);
console.log(results);  // [3, 12, 5]

// Error handling
try {
  await client.call('divide', [10, 0]);
} catch (error) {
  console.error(`Error ${error.code}: ${error.message}`);
}
```

### Go Client

```go
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"sync/atomic"
)

type JSONRPCClient struct {
	url    string
	client *http.Client
	id     int64
}

type Request struct {
	JsonRPC string      `json:"jsonrpc"`
	Method  string      `json:"method"`
	Params  interface{} `json:"params"`
	ID      int64       `json:"id,omitempty"`
}

type Response struct {
	JsonRPC string          `json:"jsonrpc"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *RPCError       `json:"error,omitempty"`
	ID      int64           `json:"id"`
}

type RPCError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
	Data    interface{} `json:"data,omitempty"`
}

func (e *RPCError) Error() string {
	return fmt.Sprintf("JSON-RPC error %d: %s", e.Code, e.Message)
}

func NewClient(url string) *JSONRPCClient {
	return &JSONRPCClient{
		url:    url,
		client: &http.Client{},
	}
}

func (c *JSONRPCClient) Call(method string, params interface{}, result interface{}) error {
	id := atomic.AddInt64(&c.id, 1)
	
	request := Request{
		JsonRPC: "2.0",
		Method:  method,
		Params:  params,
		ID:      id,
	}
	
	body, err := json.Marshal(request)
	if err != nil {
		return err
	}
	
	resp, err := c.client.Post(c.url, "application/json", bytes.NewReader(body))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %d: %s", resp.StatusCode, resp.Status)
	}
	
	var response Response
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return err
	}
	
	if response.Error != nil {
		return response.Error
	}
	
	if result != nil {
		return json.Unmarshal(response.Result, result)
	}
	
	return nil
}

func (c *JSONRPCClient) Notify(method string, params interface{}) {
	request := Request{
		JsonRPC: "2.0",
		Method:  method,
		Params:  params,
	}
	
	body, _ := json.Marshal(request)
	c.client.Post(c.url, "application/json", bytes.NewReader(body))
}

// Usage
func main() {
	client := NewClient("http://localhost:8080/rpc")
	
	// Call method
	var sum float64
	err := client.Call("add", map[string]float64{"a": 5, "b": 3}, &sum)
	if err != nil {
		fmt.Printf("Error: %v\n", err)
		return
	}
	fmt.Printf("Sum: %v\n", sum)
	
	// Notification
	client.Notify("logEvent", map[string]string{
		"level": "info",
		"message": "Application started",
	})
}
```

**Python client:** Similar pattern using `requests` library. See [companion repository](https://github.com/blackwell-systems/you-dont-know-json) for complete implementation.

{height: 85%}
![JSON-RPC Request/Response Lifecycle](chapter-06-json-rpc-diagram-2-light--deprecated.png)
{width: 85%}

---

## JSON-RPC over WebSockets

HTTP is request/response only. WebSockets enable **bidirectional** RPC - servers can call client methods and vice versa.

### Server (Node.js)

```javascript
const WebSocket = require('ws');
const wss = new WebSocket.Server({ port: 8080 });

wss.on('connection', (ws) => {
  console.log('Client connected');
  
  // Handle incoming requests
  ws.on('message', (data) => {
    try {
      const request = JSON.parse(data);
      const response = handleRequest(request);
      if (response) {
        ws.send(JSON.stringify(response));
      }
    } catch (error) {
      ws.send(JSON.stringify({
        jsonrpc: '2.0',
        error: {code: -32700, message: 'Parse error'},
        id: null
      }));
    }
  });
  
  // Server can initiate requests to client
  function notifyClient(event, data) {
    ws.send(JSON.stringify({
      jsonrpc: '2.0',
      method: event,
      params: data
    }));
  }
  
  // Example: Send notification to client every 5 seconds
  const interval = setInterval(() => {
    notifyClient('serverTime', { time: new Date().toISOString() });
  }, 5000);
  
  ws.on('close', () => {
    clearInterval(interval);
    console.log('Client disconnected');
  });
});

function handleRequest(request) {
  const methods = {
    ping: () => 'pong',
    echo: (message) => message,
    getServerInfo: () => ({
      version: '1.0.0',
      uptime: process.uptime()
    })
  };
  
  if (request.id === undefined) {
    // Notification - no response
    if (methods[request.method]) {
      methods[request.method](...(request.params || []));
    }
    return null;
  }
  
  if (!methods[request.method]) {
    return {
      jsonrpc: '2.0',
      error: {code: -32601, message: 'Method not found'},
      id: request.id
    };
  }
  
  try {
    const result = methods[request.method](...(request.params || []));
    return {
      jsonrpc: '2.0',
      result,
      id: request.id
    };
  } catch (error) {
    return {
      jsonrpc: '2.0',
      error: {code: -32000, message: error.message},
      id: request.id
    };
  }
}

console.log('WebSocket JSON-RPC server on ws://localhost:8080');
```

### Client (JavaScript)

```javascript
class JSONRPCWebSocketClient {
  constructor(url) {
    this.url = url;
    this.ws = null;
    this.requestId = 0;
    this.pendingRequests = new Map();
    this.eventHandlers = new Map();
  }
  
  connect() {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.url);
      
      this.ws.onopen = () => {
        console.log('Connected');
        resolve();
      };
      
      this.ws.onerror = (error) => {
        reject(error);
      };
      
      this.ws.onmessage = (event) => {
        const message = JSON.parse(event.data);
        
        if (message.id) {
          // Response to our request
          const pending = this.pendingRequests.get(message.id);
          if (pending) {
            this.pendingRequests.delete(message.id);
            if (message.error) {
              pending.reject(new Error(message.error.message));
            } else {
              pending.resolve(message.result);
            }
          }
        } else {
          // Server-initiated notification
          this.handleNotification(message);
        }
      };
      
      this.ws.onclose = () => {
        console.log('Disconnected');
        // Reject all pending requests
        for (const [id, pending] of this.pendingRequests) {
          pending.reject(new Error('Connection closed'));
        }
        this.pendingRequests.clear();
      };
    });
  }
  
  call(method, params = []) {
    return new Promise((resolve, reject) => {
      const id = ++this.requestId;
      
      this.pendingRequests.set(id, { resolve, reject });
      
      this.ws.send(JSON.stringify({
        jsonrpc: '2.0',
        method,
        params,
        id
      }));
      
      // Timeout after 30 seconds
      setTimeout(() => {
        if (this.pendingRequests.has(id)) {
          this.pendingRequests.delete(id);
          reject(new Error('Request timeout'));
        }
      }, 30000);
    });
  }
  
  notify(method, params = []) {
    this.ws.send(JSON.stringify({
      jsonrpc: '2.0',
      method,
      params
    }));
  }
  
  on(method, handler) {
    this.eventHandlers.set(method, handler);
  }
  
  handleNotification(message) {
    const handler = this.eventHandlers.get(message.method);
    if (handler) {
      handler(...(message.params || []));
    }
  }
  
  close() {
    this.ws.close();
  }
}

// Usage
const client = new JSONRPCWebSocketClient('ws://localhost:8080');

await client.connect();

// Register handler for server notifications
client.on('serverTime', (data) => {
  console.log('Server time:', data.time);
});

// Call server method
const info = await client.call('getServerInfo');
console.log('Server info:', info);

// Send notification to server
client.notify('clientStatus', { status: 'active' });
```

**Use cases for WebSocket JSON-RPC:**
- Real-time dashboards (server pushes updates)
- Live collaboration (bidirectional sync)
- Game servers (low-latency actions)
- Trading platforms (price updates)
- Chat applications
- IoT device control

{blurb, class: information}
**WebSocket Benefits:**
- **Bidirectional:** Server can call client methods
- **Low latency:** No HTTP overhead per message
- **Persistent:** Single connection for multiple calls
- **Efficient:** No repeated headers

**Trade-offs:**
- Connection management complexity
- Not cacheable (unlike HTTP)
- Firewall/proxy challenges
- State management required
{/blurb}

---

## Real-World Use Cases

### 1. Ethereum JSON-RPC

Ethereum nodes expose a JSON-RPC API for blockchain interaction:

```javascript
// Get account balance
const balance = await client.call('eth_getBalance', [
  '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
  'latest'
]);

// Get current block number
const blockNumber = await client.call('eth_blockNumber', []);

// Send transaction
const txHash = await client.call('eth_sendTransaction', [{
  from: '0x...',
  to: '0x...',
  value: '0x9184e72a000', // 10000000000000 wei
  gas: '0x5208'           // 21000 gas
}]);

// Get transaction receipt
const receipt = await client.call('eth_getTransactionReceipt', [txHash]);

// Call smart contract (read-only)
const result = await client.call('eth_call', [{
  to: '0x...',      // Contract address
  data: '0x...'     // Encoded function call
}, 'latest']);
```

**Why Ethereum uses JSON-RPC:**
- Action-oriented (send transaction, get balance)
- Simple for wallet integrations
- Works over HTTP and WebSockets
- Easy to debug (human-readable)
- Wide language support

### 2. Language Server Protocol (LSP)

VS Code, Neovim, and other editors use JSON-RPC for language intelligence:

```json
// Client → Server: Request code completion
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "textDocument/completion",
  "params": {
    "textDocument": {
      "uri": "file:///path/to/file.ts"
    },
    "position": {
      "line": 10,
      "character": 15
    }
  }
}

// Server → Client: Completion results
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "items": [
      {
        "label": "console",
        "kind": 6,
        "detail": "Console object"
      },
      {
        "label": "const",
        "kind": 14,
        "detail": "const keyword"
      }
    ]
  }
}

// Server → Client: Publish diagnostics (notification)
{
  "jsonrpc": "2.0",
  "method": "textDocument/publishDiagnostics",
  "params": {
    "uri": "file:///path/to/file.ts",
    "diagnostics": [
      {
        "range": {
          "start": {"line": 5, "character": 10},
          "end": {"line": 5, "character": 20}
        },
        "severity": 1,
        "message": "Variable 'x' is not defined"
      }
    ]
  }
}
```

**Why LSP uses JSON-RPC:**
- Bidirectional (server sends diagnostics)
- Language-agnostic (any editor, any language server)
- Asynchronous (non-blocking operations)
- Standardized protocol

### 3. Bitcoin Core RPC

Bitcoin nodes expose management via JSON-RPC:

```javascript
// Get blockchain info
const info = await client.call('getblockchaininfo', []);

// Get wallet balance
const balance = await client.call('getbalance', []);

// Send Bitcoin
const txid = await client.call('sendtoaddress', [
  '1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa',  // Address
  0.01,                                    // Amount in BTC
  'Payment for services'                   // Comment
]);

// Generate new address
const address = await client.call('getnewaddress', ['', 'bech32']);

// Get transaction details
const tx = await client.call('gettransaction', [txid]);
```

### 4. Discord Bot API

Discord bots can use JSON-RPC for command handling:

```javascript
// Register command handler
client.on('sendMessage', async ({channelId, content}) => {
  // Send message to Discord channel
  await discord.channels.get(channelId).send(content);
  return {success: true};
});

// Bot receives command from Discord
await rpcClient.call('onMessage', {
  author: 'User#1234',
  content: '!hello',
  channelId: '123456789'
});
```

### 5. Internal Microservices

JSON-RPC for service-to-service communication:

```javascript
// User service
const userService = new JSONRPCClient('http://user-service/rpc');

// Order service calls user service
const user = await userService.call('getUserById', {id: 123});
const address = await userService.call('getUserAddress', {
  userId: 123,
  addressType: 'shipping'
});

// Batch request for efficiency
const [user, orders, preferences] = await userService.batch([
  {method: 'getUserById', params: {id: 123}},
  {method: 'getUserOrders', params: {userId: 123, limit: 10}},
  {method: 'getUserPreferences', params: {userId: 123}}
]);
```

**Benefits for microservices:**
- Simpler than REST for action-oriented APIs
- Batch requests reduce network overhead
- Easy to version (method names like `v2.getUser`)
- Self-documenting method names

---

## JSON-RPC vs REST vs gRPC

### Comparison Table

| Aspect | JSON-RPC | REST | gRPC |
|--------|----------|------|------|
| **Philosophy** | Action-oriented (functions) | Resource-oriented (CRUD) | Action-oriented (services) |
| **Protocol** | JSON over HTTP/WebSocket | HTTP methods + URLs | Protobuf over HTTP/2 |
| **Request format** | JSON with method name | HTTP verb + path | Binary Protobuf |
| **Response format** | JSON result or error | HTTP status + body | Binary Protobuf |
| **Type safety** | No (runtime only) | No | Yes (schema required) |
| **Schema** | Optional (JSON Schema) | Optional (OpenAPI) | Required (`.proto` files) |
| **Batch operations** | Native (array of requests) | Not standardized | Streaming |
| **Bidirectional** | With WebSockets | No | Yes (HTTP/2 streams) |
| **Browser support** | Excellent | Excellent | Limited (gRPC-Web needed) |
| **Human-readable** | Yes | Yes | No (binary) |
| **Performance** | Good | Good | Excellent |
| **Learning curve** | Low | Low | Medium |
| **Tooling** | Moderate | Excellent | Excellent |
| **Versioning** | Method names | URL paths | Protobuf evolution |
| **Caching** | Manual | HTTP caching | Manual |

### When to Use Each

The choice between JSON-RPC, REST, and gRPC isn't ideological - it's practical. Each protocol optimizes for different constraints.

**JSON-RPC shines in action-oriented domains** where operations don't map naturally to resources. If your API surface consists primarily of calculations, transformations, or commands rather than CRUD operations, JSON-RPC's function-call model matches the problem naturally. Internal microservices particularly benefit from this simplicity - when you control both client and server, JSON-RPC's minimal ceremony accelerates development. The protocol's native batch request support eliminates the latency compounding that plagues REST APIs making multiple dependent calls. WebSocket deployments get bidirectional communication without protocol impedance, and rapid prototyping proceeds without schema definition overhead.

**REST remains the right choice for resource-oriented domains** where your API models entities with clear lifecycle operations. Public APIs benefit from REST's ubiquity - developers understand GET/POST/PUT/DELETE without documentation, and the ecosystem of HTTP tooling (caching proxies, CDNs, browser DevTools) works automatically. If your access patterns benefit from HTTP caching semantics, REST gives you this for free. The stateless request/response model aligns perfectly with HTTP's design, and wide client compatibility (including browsers, curl, and every HTTP library ever written) comes standard.

**gRPC targets performance-critical systems** where binary efficiency matters more than human readability. The required Protocol Buffers schemas provide strong typing that catches errors at compile time, not runtime. Schema evolution features enable backward-compatible API changes without versioning gymnastics. Microservice architectures with complex contracts benefit from the generated client libraries that provide type-safe APIs in every language. When throughput, latency, or bandwidth become bottlenecks, gRPC's HTTP/2 streaming and efficient binary encoding deliver measurable improvements.

The protocols aren't mutually exclusive. Production systems routinely combine them based on each API's characteristics.


![API Protocol Selection Decision Tree](chapter-06-json-rpc-diagram-3-light.png)
{width: 85%}


### Hybrid Approaches

Many systems use multiple protocols:

**Example: E-commerce platform**
```
REST:        Public product catalog API
JSON-RPC:    Internal order processing service
gRPC:        High-performance inventory service
WebSockets:  Real-time order status updates
```

**Example: Financial system**
```
REST:        Account management API
JSON-RPC:    Transaction execution service
gRPC:        Market data feeds
WebSockets:  Live price updates
```

Don't feel locked into one protocol. Choose based on each API's characteristics.

---

## Best Practices

Building production JSON-RPC systems requires patterns that go beyond the basic specification. These practices emerge from real-world deployments where simplicity, maintainability, and reliability matter.

### API Design Decisions

**Choose named parameters over positional arrays.** When you write `{"method": "createUser", "params": ["alice", "alice@example.com", 30, true]}`, the next developer reading this code has no idea what `30` and `true` represent without checking documentation. Six months later when you add an optional `verified` parameter, every client needs updates to handle the new positional ordering. Named parameters solve both problems:

```json
{"method": "createUser", "params": {
  "username": "alice",
  "email": "alice@example.com",
  "age": 30,
  "active": true
}}
```

The call documents itself. Optional parameters can be added without breaking existing clients. Parameter order becomes irrelevant. The small verbosity cost pays dividends in maintainability.

**Version your methods from day one.** When your `getUser` method needs breaking changes, you face a dilemma: break existing clients or maintain two code paths. Method versioning solves this by making the version explicit. Embed it in the method name (`v2.getUser`) or pass it as a parameter (`getUser` with `{version: 2, id: 123}`). Both approaches work, but method name versioning makes the version visible in logs and monitoring without parsing parameters. Version early - retrofitting versioning into production APIs with angry clients is unpleasant.

### Error Handling and Resilience

**Establish consistent error codes early.** JSON-RPC reserves the range -32768 to -32000 for standard protocol errors (parse errors, invalid requests, method not found). Your application errors should use either the -32000 to -32099 range or positive integers. The key is consistency - clients can only handle errors programmatically if the codes are predictable:

```javascript
const ErrorCodes = {
  // Standard JSON-RPC codes
  PARSE_ERROR: -32700,
  INVALID_REQUEST: -32600,
  METHOD_NOT_FOUND: -32601,
  INVALID_PARAMS: -32602,
  INTERNAL_ERROR: -32603,
  
  // Application codes (start at -32000 or use positive)
  UNAUTHORIZED: -32001,
  FORBIDDEN: -32002,
  NOT_FOUND: -32003,
  VALIDATION_ERROR: -32004,
  RATE_LIMIT: -32005
};
```

When clients receive `RATE_LIMIT`, they can back off automatically. When they see `UNAUTHORIZED`, they can refresh tokens. Inconsistent error codes force clients to parse error messages as strings - fragile and language-dependent.

**Implement timeouts on both sides.** Long-running operations will eventually hang. Without timeouts, hanging requests accumulate until your connection pool exhausts and the entire service deadlocks. Client-side timeouts prevent cascading failures - if the RPC server is slow, the client fails fast rather than blocking its own request handling. Server-side timeouts protect against runaway operations consuming resources:

```javascript
// Client-side timeout
const result = await client.call('longOperation', {}, {timeout: 60000});

// Server-side timeout
app.post('/rpc', timeout('30s'), handleRPC);
```

Choose timeout values based on realistic operation duration plus network latency. Too short and legitimate requests fail; too long and resource exhaustion isn't prevented.

**Structured logging makes debugging tractable.** When a client reports an error with a specific request, you need to find the corresponding server-side execution quickly. Request IDs tie client and server logs together. Logging method names and durations reveals performance regressions and usage patterns:

```javascript
app.use((req, res, next) => {
  if (req.path === '/rpc') {
    const start = Date.now();
    const requestId = generateId();
    
    console.log('RPC Request', {
      id: requestId,
      method: req.body.method,
      params: req.body.params
    });
    
    res.on('finish', () => {
      console.log('RPC Response', {
        id: requestId,
        duration: Date.now() - start,
        status: res.statusCode
      });
    });
  }
  next();
});
```

Resist the temptation to skip logging parameter values for security - instead sanitize sensitive fields (passwords, tokens) before logging. Debugging production issues without parameter context is needlessly difficult.

### Performance and Efficiency

**Batch requests eliminate latency compounding.** When a client needs data from multiple calls, sequential requests pay the network latency penalty for each one. Three calls with 50ms latency each take 150ms plus processing time. Batch requests collapse this into a single round trip:

```javascript
// Instead of 100 separate requests paying latency penalty each time
for (const id of userIds) {
  await client.call('getUser', {id});
}

// Single batch request - one round trip
const calls = userIds.map(id => ({
  method: 'getUser',
  params: {id}
}));
const users = await client.batch(calls);
```

The server processes requests in parallel and returns all results together. This matters for mobile clients on slow networks where latency dominates, and for high-load services where connection overhead becomes measurable.

**Connection pooling prevents resource exhaustion.** Every HTTP request creates a TCP connection - three-way handshake, TLS negotiation, four-way teardown. For a service making frequent RPC calls, this overhead dominates actual request processing. Connection pooling reuses established connections:

```javascript
const client = new JSONRPCClient('http://api/rpc', {
  agent: new http.Agent({
    keepAlive: true,
    maxSockets: 50
  })
});
```

The `maxSockets` limit prevents a single client from exhausting server connection limits. Keep-alive connections skip the handshake overhead and improve throughput measurably.

### Input Validation and Security

**Validate parameters before executing methods.** Passing invalid data to business logic causes unpredictable failures. Validate early and return the standard `-32602` (Invalid params) error so clients know the problem is their input, not server failure:

```javascript
const schemas = {
  'createUser': {
    username: {type: 'string', minLength: 3, maxLength: 20},
    email: {type: 'string', format: 'email'},
    age: {type: 'number', minimum: 0}
  }
};

function validateParams(method, params) {
  const schema = schemas[method];
  if (!schema) return true;
  
  return validate(params, schema);
}
```

Validation happens before authentication checks, before database queries, before any expensive operations. Fast failure with clear error codes improves both client experience and server efficiency.

**Rate limiting protects against abuse.** Without limits, a malicious or buggy client can overwhelm your service with requests. Rate limiting per client (by IP or API key) provides defense against both accidents and attacks:

```javascript
const rateLimit = require('express-rate-limit');

app.use('/rpc', rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,                  // 100 requests per window
  handler: (req, res) => {
    res.json({
      jsonrpc: '2.0',
      error: {
        code: -32005,
        message: 'Rate limit exceeded'
      },
      id: req.body.id
    });
  }
}));
```

The custom handler returns a proper JSON-RPC error instead of a generic HTTP 429 response. Set limits based on legitimate usage patterns with headroom for bursts - too restrictive and you anger users, too permissive and limits don't protect.

### Documentation

**Document your methods as you would document functions.** Unlike REST where HTTP semantics provide implicit documentation (`GET` means read, `POST` means create), RPC method names are arbitrary. Clear documentation becomes essential:

```javascript
/**
 * Get user by ID
 * @method getUser
 * @param {number} id - User ID
 * @returns {Object} User object with id, username, email
 * @throws {-32003} User not found
 */
methods['getUser'] = async ({id}) => {
  const user = await db.users.findById(id);
  if (!user) {
    const error = new Error('User not found');
    error.code = -32003;
    throw error;
  }
  return user;
};
```

Document parameter types, return values, and error codes. Tools can generate client libraries from this documentation. Future maintainers (including yourself) will appreciate knowing what error code -32003 means without grepping the codebase.

{blurb, class: tip}
**Production Checklist:**
- [ ] Named parameters for all methods
- [ ] Consistent error code scheme
- [ ] Request/response logging
- [ ] Parameter validation
- [ ] Rate limiting
- [ ] Request timeouts (client and server)
- [ ] Authentication middleware
- [ ] Method documentation
- [ ] Batch request support
- [ ] Health check endpoint
{/blurb}

### Production Deployment Patterns

Running JSON-RPC in production requires considerations beyond the basic implementation.

**Load balancing with sticky sessions:**

```nginx
# nginx.conf - Load balance JSON-RPC servers
upstream json_rpc_backend {
    # Sticky sessions based on client IP (for stateful connections)
    ip_hash;
    
    server rpc1.internal:3000 max_fails=3 fail_timeout=30s;
    server rpc2.internal:3000 max_fails=3 fail_timeout=30s;
    server rpc3.internal:3000 max_fails=3 fail_timeout=30s;
}

server {
    listen 443 ssl http2;
    server_name api.example.com;
    
    location /rpc {
        # Rate limiting per client
        limit_req zone=rpc_limit burst=20 nodelay;
        
        proxy_pass http://json_rpc_backend;
        proxy_http_version 1.1;
        
        # Connection reuse
        proxy_set_header Connection "";
        
        # Timeouts for long-running methods
        proxy_read_timeout 60s;
        proxy_send_timeout 60s;
        
        # Add request ID for tracing
        proxy_set_header X-Request-ID $request_id;
    }
}
```

**Health check endpoint:**

```javascript
// Separate health check (not JSON-RPC method)
app.get('/health', async (req, res) => {
  const checks = {
    database: await checkDatabase(),
    redis: await checkRedis(),
    externalAPI: await checkExternalAPI()
  };
  
  const healthy = Object.values(checks).every(c => c.ok);
  
  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'healthy' : 'degraded',
    checks,
    timestamp: new Date().toISOString()
  });
});

async function checkDatabase() {
  try {
    await db.query('SELECT 1');
    return {ok: true};
  } catch (err) {
    return {ok: false, error: err.message};
  }
}
```

**Monitoring and observability:**

```javascript
const { Counter, Histogram } = require('prom-client');

const rpcCallsTotal = new Counter({
  name: 'json_rpc_calls_total',
  help: 'Total JSON-RPC calls',
  labelNames: ['method', 'status']
});

const rpcDuration = new Histogram({
  name: 'json_rpc_duration_seconds',
  help: 'JSON-RPC call duration',
  labelNames: ['method'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5]
});

async function handleRPCWithMetrics(req, res) {
  const start = Date.now();
  const {method} = req.body;
  
  try {
    const result = await handleRPC(req);
    
    // Record success
    rpcCallsTotal.inc({method, status: 'success'});
    rpcDuration.observe({method}, (Date.now() - start) / 1000);
    
    res.json(result);
  } catch (err) {
    // Record failure
    rpcCallsTotal.inc({method, status: 'error'});
    rpcDuration.observe({method}, (Date.now() - start) / 1000);
    
    res.status(500).json({
      jsonrpc: '2.0',
      error: {code: -32603, message: 'Internal error'},
      id: req.body.id
    });
  }
}

// Expose metrics for Prometheus
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});
```

### Performance Optimization

**1. Connection pooling for database calls:**

```javascript
// Bad: Create connection per RPC call
methods.getUser = async ({id}) => {
  const conn = await mysql.createConnection(config);
  const user = await conn.query('SELECT * FROM users WHERE id = ?', [id]);
  await conn.end();
  return user;
};

// Good: Reuse connection pool
const pool = mysql.createPool({
  host: 'db.internal',
  user: 'api',
  password: process.env.DB_PASSWORD,
  database: 'users',
  connectionLimit: 20,        // Max concurrent connections
  queueLimit: 100,            // Max queued requests
  acquireTimeout: 10000       // 10s timeout
});

methods.getUser = async ({id}) => {
  const [user] = await pool.query('SELECT * FROM users WHERE id = ?', [id]);
  return user;
};
```

**2. Method result caching:**

```javascript
const NodeCache = require('node-cache');
const cache = new NodeCache({stdTTL: 60}); // 60s default TTL

methods.getUser = async ({id}) => {
  // Check cache first
  const cacheKey = `user:${id}`;
  let user = cache.get(cacheKey);
  
  if (user) {
    return user; // Cache hit
  }
  
  // Cache miss, fetch from database
  user = await db.users.findById(id);
  cache.set(cacheKey, user, 300); // Cache for 5 minutes
  
  return user;
};

// Invalidate cache on updates
methods.updateUser = async ({id, data}) => {
  await db.users.update(id, data);
  cache.del(`user:${id}`); // Clear cache
  return {success: true};
};
```

**3. Batch request optimization:**

```javascript
// Efficiently handle batch requests with parallel execution
async function handleBatch(requests) {
  // Execute all requests in parallel (not sequential!)
  const results = await Promise.allSettled(
    requests.map(req => handleSingleRequest(req))
  );
  
  // Map results back to responses
  return results.map((result, i) => {
    if (result.status === 'fulfilled') {
      return {
        jsonrpc: '2.0',
        result: result.value,
        id: requests[i].id
      };
    } else {
      return {
        jsonrpc: '2.0',
        error: {code: -32603, message: result.reason.message},
        id: requests[i].id
      };
    }
  });
}
```

**4. Long-running method timeout:**

```javascript
async function executeWithTimeout(method, params, timeoutMs = 30000) {
  return Promise.race([
    method(params),
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error('Method timeout')), timeoutMs)
    )
  ]);
}

methods.expensiveOperation = async (params) => {
  return executeWithTimeout(
    async () => {
      // Long-running operation
      const result = await complexCalculation(params);
      return result;
    },
    params,
    60000  // 60s timeout
  );
};
```

---

## Security Considerations

### 1. Authentication

**Token-based:**
```javascript
app.post('/rpc', authenticateToken, handleRPC);

function authenticateToken(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  
  if (!token) {
    return res.json({
      jsonrpc: '2.0',
      error: {code: -32001, message: 'Unauthorized'},
      id: req.body.id
    });
  }
  
  try {
    req.user = verifyJWT(token);
    next();
  } catch (err) {
    return res.json({
      jsonrpc: '2.0',
      error: {code: -32001, message: 'Invalid token'},
      id: req.body.id
    });
  }
}
```

**Client usage:**
```javascript
const client = new JSONRPCClient('http://api/rpc', {
  headers: {
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...'
  }
});
```

### 2. Authorization

Check permissions per method:

```javascript
const methodPermissions = {
  'getUser': ['user', 'admin'],
  'createUser': ['admin'],
  'deleteUser': ['admin']
};

function authorize(method, user) {
  const required = methodPermissions[method];
  if (!required) return true; // No restrictions
  
  return required.includes(user.role);
}

// In handler
if (!authorize(request.method, req.user)) {
  return {
    jsonrpc: '2.0',
    error: {code: -32002, message: 'Forbidden'},
    id: request.id
  };
}
```

### 3. Input Validation

**Never trust client input:**
```javascript
const Joi = require('joi');

const schemas = {
  'createUser': Joi.object({
    username: Joi.string().alphanum().min(3).max(20).required(),
    email: Joi.string().email().required(),
    age: Joi.number().integer().min(0).max(150)
  })
};

function validateInput(method, params) {
  const schema = schemas[method];
  if (!schema) return {valid: true};
  
  const {error, value} = schema.validate(params);
  return error ? {valid: false, error: error.message} : {valid: true, value};
}
```

### 4. CORS Configuration

```javascript
const cors = require('cors');

app.use('/rpc', cors({
  origin: 'https://yourdomain.com',
  credentials: true,
  methods: ['POST'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));
```

### 5. HTTPS Only

```javascript
// Redirect HTTP to HTTPS
app.use((req, res, next) => {
  if (!req.secure && process.env.NODE_ENV === 'production') {
    return res.redirect(`https://${req.headers.host}${req.url}`);
  }
  next();
});
```

### 6. Prevent Timing Attacks

```javascript
const crypto = require('crypto');

function safeCompare(a, b) {
  // Use constant-time comparison
  return crypto.timingSafeEqual(
    Buffer.from(a),
    Buffer.from(b)
  );
}
```

### 7. Sanitize Error Messages

```javascript
// Don't expose internal details
try {
  await db.query('SELECT * FROM users WHERE id = ?', [id]);
} catch (err) {
  // Bad: exposes database structure
  throw new Error(err.message);
  
  // Good: generic message
  throw new Error('Database error');
}
```

---

## Testing JSON-RPC APIs

### Unit Tests (Server)

```javascript
const request = require('supertest');
const app = require('./app');

describe('JSON-RPC Server', () => {
  test('should add two numbers', async () => {
    const response = await request(app)
      .post('/rpc')
      .send({
        jsonrpc: '2.0',
        method: 'add',
        params: [5, 3],
        id: 1
      });
    
    expect(response.status).toBe(200);
    expect(response.body.result).toBe(8);
    expect(response.body.id).toBe(1);
  });
  
  test('should return error for unknown method', async () => {
    const response = await request(app)
      .post('/rpc')
      .send({
        jsonrpc: '2.0',
        method: 'unknownMethod',
        params: [],
        id: 1
      });
    
    expect(response.body.error.code).toBe(-32601);
    expect(response.body.error.message).toContain('Method not found');
  });
  
  test('should handle batch requests', async () => {
    const response = await request(app)
      .post('/rpc')
      .send([
        {jsonrpc: '2.0', method: 'add', params: [1, 2], id: 1},
        {jsonrpc: '2.0', method: 'subtract', params: [5, 3], id: 2}
      ]);
    
    expect(response.body).toHaveLength(2);
    expect(response.body[0].result).toBe(3);
    expect(response.body[1].result).toBe(2);
  });
  
  test('should handle notifications', async () => {
    const response = await request(app)
      .post('/rpc')
      .send({
        jsonrpc: '2.0',
        method: 'logEvent',
        params: {level: 'info', message: 'test'}
      });
    
    expect(response.status).toBe(204);
  });
});
```

### Integration Tests (Client)

```javascript
const client = new JSONRPCClient('http://localhost:3000/rpc');

describe('JSON-RPC Client', () => {
  test('should call remote method', async () => {
    const result = await client.call('add', [10, 20]);
    expect(result).toBe(30);
  });
  
  test('should handle errors', async () => {
    await expect(client.call('divide', [10, 0]))
      .rejects.toThrow('Division by zero');
  });
  
  test('should send batch requests', async () => {
    const results = await client.batch([
      {method: 'add', params: [1, 2]},
      {method: 'multiply', params: [3, 4]}
    ]);
    
    expect(results).toEqual([3, 12]);
  });
});
```

### Performance Tests

```javascript
const autocannon = require('autocannon');

// Load test
autocannon({
  url: 'http://localhost:3000/rpc',
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({
    jsonrpc: '2.0',
    method: 'add',
    params: [5, 3],
    id: 1
  }),
  connections: 100,
  duration: 10
}, (err, result) => {
  console.log('Requests/sec:', result.requests.mean);
  console.log('Latency (ms):', result.latency.mean);
});
```

---

## Conclusion: JSON-RPC's Sweet Spot

JSON-RPC fills the gap between REST's resource orientation and gRPC's performance overhead. It's the pragmatic choice for action-oriented APIs.

### What We Learned

**JSON-RPC provides:**
- Simple specification (8 pages)
- Action-oriented paradigm (functions, not resources)
- Transport-agnostic (HTTP, WebSockets, any byte stream)
- Batch request support (reduce network overhead)
- Bidirectional communication (with WebSockets)
- Wide adoption (Ethereum, LSP, Bitcoin)

**Key patterns:**
- Named parameters over positional
- Standard error codes for consistency
- Batch requests for efficiency
- WebSockets for real-time bidirectional RPC
- Middleware for auth, logging, rate limiting

**When to use JSON-RPC:** Internal microservices benefit from JSON-RPC's simplicity - no need for the ceremonial REST conventions that public APIs require. Action-oriented domains like financial calculations, batch operations, or workflow automation map naturally to function calls rather than resource manipulations. Real-time applications gain bidirectional communication through WebSocket transport, enabling server-initiated updates without polling overhead. Systems requiring batch operations can bundle multiple calls into single requests, dramatically reducing network round-trips. Rapid prototyping proceeds faster without designing URL hierarchies or debating HTTP verb semantics - just define methods and call them.

**When to avoid JSON-RPC:** Public-facing REST APIs benefit from REST's widespread understanding and standardization - developers already know how to work with REST, and tooling like OpenAPI provides excellent documentation. Resource-oriented CRUD operations map naturally to HTTP verbs, making REST the more intuitive choice. Performance-critical systems processing millions of requests per second should consider gRPC, which offers significantly lower latency through HTTP/2 and Protocol Buffers. Applications requiring strong compile-time type safety benefit from gRPC's code generation from .proto definitions, catching type errors before runtime.

**JSON-RPC demonstrates the modular pattern once again:** it's a protocol layer that works with any serialization format (JSON, MessagePack, CBOR) and any transport (HTTP, WebSockets, IPC). Each component evolves independently.

But protocols and efficient encoding don't solve every problem. What about processing datasets too large to fit in memory? Standard JSON arrays require loading everything at once - fundamentally incompatible with streaming.

Chapter 7 explores JSON Lines - another modular solution that enables streaming by adding one simple convention: separate JSON objects with newlines. No parser changes needed, no new format, just a pattern that unlocks streaming for log processing, data pipelines, and big data workflows.

**Next:** Chapter 7 - JSON Lines: Processing Gigabytes Without Running Out of Memory

---

## Further Reading

**Code Examples:**
- [Companion Repository](https://github.com/blackwell-systems/you-dont-know-json) - JSON-RPC server and client with batch requests, error handling, and notifications

**Specifications:**
- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)
- [JSON-RPC over WebSocket](https://github.com/ethereum/wiki/wiki/JSON-RPC-over-WebSocket)

**Real-World Implementations:**
- [Ethereum JSON-RPC API](https://ethereum.org/en/developers/docs/apis/json-rpc/)
- [Language Server Protocol](https://microsoft.github.io/language-server-protocol/)
- [Bitcoin Core RPC](https://developer.bitcoin.org/reference/rpc/)

**Libraries:**
- [jayson (Node.js)](https://github.com/tedeh/jayson)
- [gorilla/rpc (Go)](https://github.com/gorilla/rpc)
- [python-jsonrpc (Python)](https://github.com/pavlov99/python-jsonrpc)

**Related:**
- [Understanding Protocol Buffers: Part 1](#)
- [Serialization Explained](#)
