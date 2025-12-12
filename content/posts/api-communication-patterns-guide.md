---
title: "The Complete Guide to API Communication Patterns: REST, GraphQL, WebSocket, gRPC, and More"
date: 2025-12-11
draft: false
tags: ["api", "rest", "graphql", "websocket", "grpc", "webhook", "rpc", "http", "communication-patterns", "architecture", "microservices", "real-time", "server-sent-events", "message-queues", "mqtt", "soap", "webrtc", "system-design", "software-architecture", "backend", "distributed-systems", "api-design"]
categories: ["programming", "architecture"]
description: "A comprehensive guide to API communication patterns including REST, GraphQL, WebSocket, gRPC, webhooks, and message queues. Learn when to use each pattern with diagrams, examples, and decision frameworks."
summary: "Master API communication patterns: REST, GraphQL, WebSocket, gRPC, webhooks, message queues, and more. Complete guide with diagrams, code examples, and decision frameworks for choosing the right pattern."
---

Modern applications need to communicate—with browsers, mobile apps, microservices, and third-party systems. But with so many communication patterns available (REST, GraphQL, WebSocket, gRPC, webhooks, message queues, and more), how do you choose the right one?

This guide breaks down **14 communication patterns**, explaining what each one is, when to use it, and how it compares to alternatives. Whether you're building a real-time chat app, a microservices architecture, or a public API, you'll learn which pattern fits your needs.

{{< callout type="info" >}}
**Key Insight:** These patterns aren't competing technologies—they're **complementary tools** for different communication needs. REST for standard APIs, webhooks for event notifications, WebSocket for real-time bidirectional chat, gRPC for high-performance microservices. The best architectures use multiple patterns together.
{{< /callout >}}

## The Evolution of API Communication

Before diving into specifics, let's see how we got here:

{{< mermaid >}}
timeline
    title Evolution of API Communication Patterns
    1990s : HTTP/1.0
          : CGI Scripts
          : Form POST/GET
    2000s : REST becomes popular
          : SOAP/XML dominates enterprise
          : AJAX enables dynamic pages
    2010s : WebSocket standardized
          : JSON replaces XML
          : Microservices rise
          : GraphQL released
    2015+ : gRPC introduced
          : HTTP/2 adoption
          : Event-driven architectures
          : Serverless/Lambda patterns
    2020+ : HTTP/3 (QUIC)
          : WebRTC maturity
          : Real-time everything
          : Edge computing
{{< /mermaid >}}

---

## Understanding the Landscape

Communication patterns fall into three broad categories:

{{< mermaid >}}
flowchart TB
    subgraph sync["Request-Response (Synchronous)"]
        rest[REST APIs]
        graphql[GraphQL]
        rpc[RPC/gRPC]
        soap[SOAP]
    end

    subgraph realtime["Real-Time Communication"]
        polling[Polling]
        longpoll[Long Polling]
        sse[Server-Sent Events]
        ws[WebSocket]
        webrtc[WebRTC]
    end

    subgraph async["Event-Driven (Asynchronous)"]
        webhook[Webhooks]
        mq[Message Queues]
        mqtt[MQTT]
    end

    style sync fill:#80AADD,stroke:#4a5568,color:#f8f8ff
    style realtime fill:#33D17A,stroke:#4a5568,color:#f8f8ff
    style async fill:#FFB300,stroke:#4a5568,color:#f8f8ff
{{< /mermaid >}}

{{< callout type="warning" >}}
**Important Distinction:** Not all of these are protocols. **REST** is an architectural style, **webhook** is a pattern, **WebSocket** is a protocol, **RPC** is a paradigm, and **gRPC** is a framework. They solve communication problems at different levels of abstraction.
{{< /callout >}}

---

## Part 1: Request-Response Patterns

These patterns follow a simple model: client sends a request, server sends a response, connection closes.

### REST (Representational State Transfer)

**What it is:** Architectural style for building APIs using HTTP and standard methods.

**Type:** Architectural style (uses HTTP protocol)

{{< mermaid >}}
sequenceDiagram
    participant Client
    participant Server

    Client->>Server: GET /users/123
    Note over Server: Retrieve user data
    Server-->>Client: 200 OK<br/>{id: 123, name: "Alice"}

    Client->>Server: POST /users<br/>{name: "Bob"}
    Note over Server: Create new user
    Server-->>Client: 201 Created<br/>{id: 124, name: "Bob"}

    Client->>Server: PUT /users/123<br/>{name: "Alice Smith"}
    Note over Server: Update user
    Server-->>Client: 200 OK<br/>{id: 123, name: "Alice Smith"}

    Client->>Server: DELETE /users/124
    Note over Server: Delete user
    Server-->>Client: 204 No Content
{{< /mermaid >}}

**Core Principles:**

1. **Resource-based URLs**: `/users`, `/orders/123`, not `/getUser` or `/createOrder`
2. **HTTP methods**: GET (read), POST (create), PUT (update), DELETE (remove)
3. **Stateless**: Each request contains all needed information
4. **Standard status codes**: 200 OK, 404 Not Found, 500 Internal Server Error
5. **Multiple representations**: JSON, XML, HTML

**Example:**

```bash
# Get all users
GET https://api.example.com/users
Response: 200 OK
[
  {"id": 1, "name": "Alice"},
  {"id": 2, "name": "Bob"}
]

# Get specific user
GET https://api.example.com/users/1
Response: 200 OK
{"id": 1, "name": "Alice", "email": "alice@example.com"}

# Create user
POST https://api.example.com/users
Body: {"name": "Charlie", "email": "charlie@example.com"}
Response: 201 Created
{"id": 3, "name": "Charlie", "email": "charlie@example.com"}

# Update user
PUT https://api.example.com/users/3
Body: {"name": "Charles", "email": "charlie@example.com"}
Response: 200 OK
{"id": 3, "name": "Charles", "email": "charlie@example.com"}

# Delete user
DELETE https://api.example.com/users/3
Response: 204 No Content
```

**When to use:**

- ✅ Public APIs for web/mobile apps
- ✅ Standard CRUD operations
- ✅ When you want HTTP caching
- ✅ Simple, predictable API design
- ❌ Complex query requirements (consider GraphQL)
- ❌ High-performance microservices (consider gRPC)

---

### GraphQL

**What it is:** Query language that lets clients request exactly the data they need.

**Type:** Query language + protocol (usually over HTTP)

{{< mermaid >}}
sequenceDiagram
    participant Client
    participant GraphQL Server
    participant Database

    Note over Client: Traditional REST<br/>Multiple requests needed
    Client->>GraphQL Server: GET /users/123
    GraphQL Server->>Database: Query user
    Database-->>GraphQL Server: User data
    GraphQL Server-->>Client: {id, name, email}

    Client->>GraphQL Server: GET /users/123/posts
    GraphQL Server->>Database: Query posts
    Database-->>GraphQL Server: Posts data
    GraphQL Server-->>Client: [{title, body}...]

    Note over Client: GraphQL<br/>Single request
    Client->>GraphQL Server: query {<br/>  user(id: 123) {<br/>    name<br/>    posts {<br/>      title<br/>    }<br/>  }<br/>}
    GraphQL Server->>Database: Query user + posts
    Database-->>GraphQL Server: Combined data
    GraphQL Server-->>Client: Exactly what was requested
{{< /mermaid >}}

**Query Example:**

```graphql
# Client specifies exactly what it needs
query {
  user(id: 123) {
    name
    email
    posts(limit: 5) {
      title
      createdAt
      comments(limit: 3) {
        author
        text
      }
    }
  }
}
```

**Response:**

```json
{
  "data": {
    "user": {
      "name": "Alice",
      "email": "alice@example.com",
      "posts": [
        {
          "title": "Getting Started with GraphQL",
          "createdAt": "2025-01-15",
          "comments": [
            {"author": "Bob", "text": "Great post!"},
            {"author": "Charlie", "text": "Thanks for sharing"}
          ]
        }
      ]
    }
  }
}
```

**REST vs GraphQL:**

| Aspect | REST | GraphQL |
|--------|------|---------|
| **Endpoints** | Multiple (`/users`, `/posts`, `/comments`) | Single (`/graphql`) |
| **Data fetching** | Fixed response structure | Client specifies fields |
| **Over-fetching** | Common (get unneeded fields) | Eliminated |
| **Under-fetching** | Requires multiple requests | Single request |
| **Versioning** | URL versioning (`/v1/users`) | Schema evolution |
| **Caching** | HTTP caching built-in | More complex |

**When to use:**

- ✅ Mobile apps needing minimal data transfer
- ✅ Complex, nested data requirements
- ✅ Multiple clients needing different data shapes
- ✅ Rapid frontend development
- ❌ Simple CRUD (REST is simpler)
- ❌ Need HTTP caching out of the box

---

### RPC (Remote Procedure Call)

**What it is:** Calling functions on a remote server as if they were local.

**Type:** Paradigm (multiple protocol implementations: JSON-RPC, XML-RPC, gRPC)

{{< mermaid >}}
sequenceDiagram
    participant Client Code
    participant RPC Framework
    participant Network
    participant Server

    Note over Client Code: Looks like local function call
    Client Code->>RPC Framework: result = multiply(5, 7)
    Note over RPC Framework: Marshal arguments
    RPC Framework->>Network: {method: "multiply", params: [5, 7]}
    Network->>Server: Network transport
    Note over Server: Execute function
    Server->>Network: {result: 35}
    Network->>RPC Framework: Network transport
    Note over RPC Framework: Unmarshal result
    RPC Framework-->>Client Code: return 35
    Note over Client Code: Feels like local call!
{{< /mermaid >}}

**Comparison with REST:**

```python
# REST approach
response = requests.post('https://api.example.com/users',
                        json={'name': 'Alice', 'email': 'alice@example.com'})
user = response.json()

# RPC approach (looks like local function)
user = server.createUser(name='Alice', email='alice@example.com')
```

**When to use:**

- ✅ Internal microservices communication
- ✅ When you want function-call semantics
- ✅ Backend-to-backend communication
- ❌ Public APIs (REST is more standard)
- ❌ Need resource-based modeling

---

### gRPC (Google RPC)

**What it is:** High-performance RPC framework using Protocol Buffers and HTTP/2.

**Type:** Framework + protocol

{{< mermaid >}}
flowchart LR
    subgraph client["Client (Any Language)"]
        proto1[".proto<br/>Contract"]
        stub["Generated<br/>Client Stub"]
    end

    subgraph network["Network Layer"]
        http2["HTTP/2<br/>Multiplexing<br/>Streaming"]
        protobuf["Protocol Buffers<br/>Binary Serialization"]
    end

    subgraph server["Server (Any Language)"]
        proto2[".proto<br/>Contract"]
        impl["Service<br/>Implementation"]
    end

    proto1 -.->|same contract| proto2
    stub -->|serialize| protobuf
    protobuf --> http2
    http2 -->|deserialize| impl
    impl -->|response| http2
    http2 --> protobuf
    protobuf -->|result| stub

    style client fill:#80AADD,stroke:#4a5568,color:#f8f8ff
    style network fill:#33D17A,stroke:#4a5568,color:#f8f8ff
    style server fill:#FFB300,stroke:#4a5568,color:#f8f8ff
{{< /mermaid >}}

**Contract Definition (`.proto` file):**

```protobuf
syntax = "proto3";

service UserService {
  rpc GetUser(UserId) returns (User);
  rpc ListUsers(Empty) returns (stream User);  // Server streaming
  rpc CreateUser(stream UserData) returns (User);  // Client streaming
  rpc ChatStream(stream Message) returns (stream Message);  // Bidirectional
}

message UserId {
  int32 id = 1;
}

message User {
  int32 id = 1;
  string name = 2;
  string email = 3;
}
```

**Client Code (Python):**

```python
import grpc
from user_pb2 import UserId
from user_pb2_grpc import UserServiceStub

# Create channel
channel = grpc.insecure_channel('localhost:50051')
stub = UserServiceStub(channel)

# Call remote function (feels local!)
response = stub.GetUser(UserId(id=123))
print(f"User: {response.name}, {response.email}")

# Server streaming example
for user in stub.ListUsers(Empty()):
    print(f"User: {user.name}")
```

**gRPC vs REST Performance:**

{{< mermaid >}}
graph LR
    subgraph rest["REST/JSON"]
        r1["JSON Serialization<br/>~1000 bytes"]
        r2["HTTP/1.1<br/>New connection per request"]
        r3["Text-based parsing"]
    end

    subgraph grpc["gRPC/Protobuf"]
        g1["Protobuf Serialization<br/>~200 bytes<br/>(5x smaller)"]
        g2["HTTP/2<br/>Multiplexed streams"]
        g3["Binary parsing"]
    end

    rest -->|Latency| slower["Higher latency<br/>More bandwidth"]
    grpc -->|Latency| faster["7-10x faster<br/>Lower bandwidth"]

    style rest fill:#F26E74,stroke:#4a5568,color:#f8f8ff
    style grpc fill:#33D17A,stroke:#4a5568,color:#f8f8ff
{{< /mermaid >}}

**When to use:**

- ✅ Microservices communication
- ✅ High-performance requirements
- ✅ Streaming data (logs, metrics, real-time updates)
- ✅ Polyglot environments (Go, Python, Java, etc.)
- ❌ Browser clients (limited support, use gRPC-Web)
- ❌ Simple public APIs (REST is more accessible)

---

### SOAP (Simple Object Access Protocol)

**What it is:** XML-based protocol with strict contracts (WSDL) for enterprise systems.

**Type:** Protocol (over HTTP, usually)

**Characteristics:**

- Extremely verbose (XML for everything)
- Strong typing via WSDL contracts
- Built-in security (WS-Security)
- Transaction support
- Legacy enterprise standard

**Example SOAP Message:**

```xml
<?xml version="1.0"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <GetUser xmlns="http://example.com/users">
      <UserId>123</UserId>
    </GetUser>
  </soap:Body>
</soap:Envelope>
```

**When to use:**

- ✅ Legacy enterprise systems
- ✅ Banking/financial systems (compliance requirements)
- ✅ When WS-* standards are required
- ❌ New projects (use REST or gRPC instead)
- ❌ Mobile/web apps (too heavyweight)

{{< callout type="info" >}}
**Modern Alternative:** If you're maintaining SOAP services, consider a gradual migration to gRPC for internal services or REST for public APIs. Most new systems avoid SOAP due to complexity and verbosity.
{{< /callout >}}

---

## Part 2: Real-Time Communication

These patterns enable server-to-client push and low-latency bidirectional communication.

### Polling

**What it is:** Client repeatedly asks "anything new?"

**Type:** Pattern (uses HTTP)

{{< mermaid >}}
sequenceDiagram
    participant Client
    participant Server

    loop Every 5 seconds
        Client->>Server: GET /api/status
        Server-->>Client: {status: "processing"}
        Note over Client: Wait 5 seconds

        Client->>Server: GET /api/status
        Server-->>Client: {status: "processing"}
        Note over Client: Wait 5 seconds

        Client->>Server: GET /api/status
        Server-->>Client: {status: "complete"}
    end
{{< /mermaid >}}

**Example:**

```javascript
// Simple polling - check every 5 seconds
function pollStatus(jobId) {
  setInterval(async () => {
    const response = await fetch(`/api/jobs/${jobId}/status`);
    const data = await response.json();

    if (data.status === 'complete') {
      console.log('Job finished!');
      clearInterval(pollInterval);
    }
  }, 5000);
}
```

**Pros:**
- ✅ Simple to implement
- ✅ Works everywhere (just HTTP)
- ✅ No special server support needed

**Cons:**
- ❌ Wastes bandwidth (constant requests)
- ❌ High latency (up to poll interval)
- ❌ Server load (many unnecessary requests)

**When to use:**

- ✅ Simple updates that aren't time-critical
- ✅ Fallback when other methods unavailable
- ❌ Real-time needs (use WebSocket/SSE)
- ❌ High-frequency updates (too wasteful)

---

### Long Polling

**What it is:** Server holds request open until data is available.

**Type:** Pattern (uses HTTP)

{{< mermaid >}}
sequenceDiagram
    participant Client
    participant Server

    Client->>Server: GET /api/updates (connection opens)
    Note over Server: Wait for event...<br/>No response yet<br/>(connection held open)
    Note over Server: Event happens!
    Server-->>Client: {data: "new update"}

    Note over Client: Process update<br/>Immediately reconnect
    Client->>Server: GET /api/updates (connection opens)
    Note over Server: Wait for next event...
{{< /mermaid >}}

**Example:**

```javascript
async function longPoll() {
  while (true) {
    try {
      // Server holds this request open until data available
      const response = await fetch('/api/updates', {
        timeout: 30000  // 30 second timeout
      });

      const data = await response.json();
      handleUpdate(data);

      // Immediately reconnect
    } catch (error) {
      // On timeout or error, reconnect after delay
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }
}
```

**Long Polling vs Regular Polling:**

| Aspect | Regular Polling | Long Polling |
|--------|----------------|--------------|
| **Requests** | Every N seconds | Only when data available |
| **Latency** | Up to N seconds | Near-instant |
| **Bandwidth** | High (many empty responses) | Lower (only meaningful data) |
| **Server load** | Many short requests | Fewer long-held connections |

**When to use:**

- ✅ Near real-time updates needed
- ✅ WebSocket not supported
- ✅ Firewall/proxy restrictions
- ❌ True real-time (use WebSocket)
- ❌ Many concurrent clients (server holds many connections)

---

### Server-Sent Events (SSE)

**What it is:** Server pushes updates to client over HTTP.

**Type:** Protocol (uses HTTP with `text/event-stream`)

{{< mermaid >}}
sequenceDiagram
    participant Client
    participant Server

    Client->>Server: GET /api/stream<br/>Accept: text/event-stream
    Note over Server: Connection established
    Server-->>Client: HTTP 200<br/>Content-Type: text/event-stream

    Note over Server: Connection stays open

    Server->>Client: data: {temperature: 72}
    Note over Client: Update UI

    Server->>Client: data: {temperature: 73}
    Note over Client: Update UI

    Server->>Client: data: {temperature: 74}
    Note over Client: Update UI

    Note over Server,Client: Server can push anytime!
{{< /mermaid >}}

**Client Code:**

```javascript
// Create EventSource connection
const eventSource = new EventSource('/api/stream');

// Listen for messages
eventSource.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Received:', data);
  updateDashboard(data);
};

// Handle connection events
eventSource.onopen = () => {
  console.log('Connection established');
};

eventSource.onerror = (error) => {
  console.error('Connection error:', error);
};

// Close when done
// eventSource.close();
```

**Server Code (Python/FastAPI):**

```python
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
import asyncio
import json

app = FastAPI()

async def event_generator():
    """Generate events to send to client"""
    while True:
        # Get data (from sensor, database, queue, etc.)
        data = {"temperature": get_temperature(), "timestamp": time.time()}

        # SSE format: "data: {json}\n\n"
        yield f"data: {json.dumps(data)}\n\n"

        await asyncio.sleep(1)  # Send update every second

@app.get("/api/stream")
async def stream():
    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream"
    )
```

**SSE vs WebSocket:**

| Feature | Server-Sent Events | WebSocket |
|---------|-------------------|-----------|
| **Direction** | Server → Client only | Bidirectional |
| **Protocol** | HTTP (text/event-stream) | WebSocket protocol |
| **Complexity** | Simple | More complex |
| **Reconnection** | Automatic | Manual |
| **Use case** | Live feeds, notifications | Chat, gaming, collaboration |

**When to use:**

- ✅ Live dashboards (stock prices, metrics)
- ✅ Progress updates (file uploads, long tasks)
- ✅ Notifications
- ✅ News/activity feeds
- ❌ Need client-to-server messages (use WebSocket)
- ❌ Binary data (use WebSocket)

---

### WebSocket

**What it is:** Persistent bidirectional connection between client and server.

**Type:** Protocol (RFC 6455)

{{< mermaid >}}
sequenceDiagram
    participant Client
    participant Server

    Note over Client,Server: 1. Initial HTTP Handshake
    Client->>Server: GET /chat HTTP/1.1<br/>Upgrade: websocket<br/>Connection: Upgrade
    Server-->>Client: HTTP/1.1 101 Switching Protocols<br/>Upgrade: websocket

    Note over Client,Server: 2. WebSocket Connection Established

    rect rgb(128, 170, 221, 0.1)
        Note over Client,Server: Bidirectional Communication
        Client->>Server: {"type": "message", "text": "Hello"}
        Server->>Client: {"type": "message", "text": "Hi there!"}
        Server->>Client: {"type": "notification", "text": "User joined"}
        Client->>Server: {"type": "message", "text": "Welcome"}
    end

    Note over Client,Server: 3. Connection Close
    Client->>Server: Close frame
    Server-->>Client: Close frame
{{< /mermaid >}}

**Client Code:**

```javascript
// Create WebSocket connection
const socket = new WebSocket('wss://example.com/chat');

// Connection opened
socket.addEventListener('open', (event) => {
  console.log('Connected to server');
  socket.send(JSON.stringify({type: 'join', room: 'general'}));
});

// Listen for messages from server
socket.addEventListener('message', (event) => {
  const data = JSON.parse(event.data);

  if (data.type === 'chat') {
    displayMessage(data.user, data.message);
  } else if (data.type === 'notification') {
    showNotification(data.message);
  }
});

// Send message to server
function sendMessage(text) {
  socket.send(JSON.stringify({
    type: 'chat',
    message: text
  }));
}

// Handle connection close
socket.addEventListener('close', (event) => {
  console.log('Disconnected from server');
  // Implement reconnection logic
});

// Handle errors
socket.addEventListener('error', (error) => {
  console.error('WebSocket error:', error);
});
```

**Server Code (Python/FastAPI):**

```python
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from typing import List

app = FastAPI()

# Store active connections
active_connections: List[WebSocket] = []

@app.websocket("/chat")
async def websocket_endpoint(websocket: WebSocket):
    # Accept connection
    await websocket.accept()
    active_connections.append(websocket)

    try:
        while True:
            # Receive message from client
            data = await websocket.receive_json()

            if data['type'] == 'chat':
                # Broadcast to all connected clients
                message = {
                    'type': 'chat',
                    'user': data['user'],
                    'message': data['message']
                }

                for connection in active_connections:
                    await connection.send_json(message)

    except WebSocketDisconnect:
        # Remove from active connections
        active_connections.remove(websocket)

        # Notify others
        for connection in active_connections:
            await connection.send_json({
                'type': 'notification',
                'message': 'User disconnected'
            })
```

**When to use:**

- ✅ Chat applications
- ✅ Live collaboration (Google Docs style)
- ✅ Multiplayer games
- ✅ Live dashboards with user interaction
- ✅ Real-time trading platforms
- ❌ Simple one-way updates (use SSE)
- ❌ Occasional API calls (use REST)

---

### WebRTC

**What it is:** Peer-to-peer real-time communication for audio, video, and data.

**Type:** Protocol suite

{{< mermaid >}}
flowchart TB
    subgraph browser1["Browser 1"]
        app1["Web App"]
        rtc1["WebRTC API"]
    end

    subgraph signaling["Signaling Server<br/>(WebSocket/HTTP)"]
        signal["Exchange connection info<br/>SDP offers/answers<br/>ICE candidates"]
    end

    subgraph browser2["Browser 2"]
        app2["Web App"]
        rtc2["WebRTC API"]
    end

    subgraph p2p["Peer-to-Peer Connection"]
        media["Audio/Video Streams"]
        data["Data Channels"]
    end

    app1 <-->|Signaling| signal
    signal <-->|Signaling| app2

    rtc1 <-.->|Direct P2P| p2p
    p2p <-.->|Direct P2P| rtc2

    style signaling fill:#80AADD,stroke:#4a5568,color:#f8f8ff
    style p2p fill:#33D17A,stroke:#4a5568,color:#f8f8ff
{{< /mermaid >}}

**Key Characteristics:**

1. **Peer-to-peer**: Direct browser-to-browser connection (no server in the middle)
2. **Media streams**: Audio and video
3. **Data channels**: Arbitrary data transfer
4. **NAT traversal**: Works across firewalls/routers (STUN/TURN servers)

**Use Cases:**

- Video conferencing (Zoom, Google Meet)
- Screen sharing
- Peer-to-peer file transfer
- Multiplayer gaming (low latency)
- IoT device communication

**When to use:**

- ✅ Video/audio calling
- ✅ Need lowest possible latency
- ✅ Want to minimize server bandwidth
- ❌ Need server-side processing of media
- ❌ Simple messaging (use WebSocket)

{{< callout type="info" >}}
**WebRTC Complexity:** WebRTC is powerful but complex. You still need a signaling server (often WebSocket) to establish the peer-to-peer connection initially. Consider using libraries like **PeerJS** or services like **Twilio** to simplify implementation.
{{< /callout >}}

---

## Part 3: Event-Driven Patterns

These patterns enable asynchronous, decoupled communication based on events.

### Webhooks

**What it is:** HTTP callback where a server notifies your app when events happen.

**Type:** Pattern (uses HTTP POST)

{{< mermaid >}}
sequenceDiagram
    participant Your App
    participant External Service
    participant Your Webhook Endpoint

    Note over Your App,External Service: 1. Registration
    Your App->>External Service: POST /api/webhooks<br/>{url: "https://yourapp.com/webhook"}
    External Service-->>Your App: 200 OK<br/>{webhook_id: "abc123"}

    Note over External Service: User makes payment...

    Note over External Service,Your Webhook Endpoint: 2. Event Notification
    External Service->>Your Webhook Endpoint: POST /webhook<br/>{event: "payment.success",<br/>amount: 99.99}
    Note over Your Webhook Endpoint: Process payment<br/>Update database<br/>Send email
    Your Webhook Endpoint-->>External Service: 200 OK

    Note over External Service: Another event...
    External Service->>Your Webhook Endpoint: POST /webhook<br/>{event: "refund.processed"}
    Your Webhook Endpoint-->>External Service: 200 OK
{{< /mermaid >}}

**Example: GitHub Webhook**

```javascript
// Express.js endpoint to receive GitHub webhooks
app.post('/webhook/github', (req, res) => {
  const event = req.headers['x-github-event'];
  const payload = req.body;

  // Verify signature (security best practice)
  const signature = req.headers['x-hub-signature-256'];
  if (!verifySignature(signature, req.body)) {
    return res.status(401).send('Invalid signature');
  }

  // Handle different event types
  if (event === 'push') {
    console.log(`Push to ${payload.repository.name}`);
    console.log(`Commits: ${payload.commits.length}`);

    // Trigger CI/CD pipeline
    triggerBuild(payload.repository.name);

  } else if (event === 'pull_request') {
    console.log(`PR ${payload.action}: ${payload.pull_request.title}`);

    // Run tests, post status check
    runTests(payload.pull_request);
  }

  // Always return 200 OK to acknowledge receipt
  res.status(200).send('Webhook received');
});
```

**Common Webhook Providers:**

{{< mermaid >}}
flowchart LR
    subgraph providers["Webhook Providers"]
        stripe["Stripe<br/>(Payments)"]
        github["GitHub<br/>(Code events)"]
        twilio["Twilio<br/>(SMS/calls)"]
        sendgrid["SendGrid<br/>(Email events)"]
        shopify["Shopify<br/>(E-commerce)"]
    end

    subgraph your["Your Application"]
        endpoint["/webhook endpoint"]
        logic["Event Handler<br/>Business Logic"]
    end

    stripe -->|payment.succeeded| endpoint
    github -->|push, pull_request| endpoint
    twilio -->|message.received| endpoint
    sendgrid -->|delivered, opened| endpoint
    shopify -->|order.created| endpoint

    endpoint --> logic

    style providers fill:#80AADD,stroke:#4a5568,color:#f8f8ff
    style your fill:#33D17A,stroke:#4a5568,color:#f8f8ff
{{< /mermaid >}}

**Security Best Practices:**

```javascript
const crypto = require('crypto');

// Verify webhook signature (example: GitHub)
function verifySignature(signature, body) {
  const secret = process.env.GITHUB_WEBHOOK_SECRET;
  const hmac = crypto.createHmac('sha256', secret);
  const digest = 'sha256=' + hmac.update(body).digest('hex');
  return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(digest));
}

// Implement idempotency (handle duplicate webhooks)
const processedWebhooks = new Set();

app.post('/webhook', (req, res) => {
  const webhookId = req.headers['x-webhook-id'];

  // Check if already processed
  if (processedWebhooks.has(webhookId)) {
    return res.status(200).send('Already processed');
  }

  // Process webhook
  handleWebhook(req.body);

  // Mark as processed
  processedWebhooks.add(webhookId);

  res.status(200).send('OK');
});
```

**When to use:**

- ✅ Payment notifications (Stripe, PayPal)
- ✅ CI/CD triggers (GitHub, GitLab)
- ✅ Form submissions (Typeform, Google Forms)
- ✅ Email events (SendGrid, Mailgun)
- ✅ Any "notify me when X happens" scenario
- ❌ Need immediate response (webhooks are async)
- ❌ High-frequency events (consider message queues)

{{< callout type="warning" >}}
**Webhook Reliability:** Webhooks can fail (network issues, your server down). Always implement retry logic on the sender side and idempotency on the receiver side. Store webhook deliveries in a database and process them asynchronously.
{{< /callout >}}

---

### Message Queues

**What it is:** Asynchronous message passing to decouple services.

**Type:** Pattern + various implementations (RabbitMQ, Kafka, AWS SQS, Redis)

{{< mermaid >}}
flowchart TB
    subgraph producers["Producers"]
        web["Web App"]
        api["API Service"]
        cron["Scheduled Job"]
    end

    subgraph queue["Message Queue"]
        q1["orders queue"]
        q2["emails queue"]
        q3["analytics queue"]
    end

    subgraph consumers["Consumers"]
        order["Order Processor"]
        email["Email Sender"]
        analytics["Analytics Worker"]
    end

    web -->|New order| q1
    api -->|User registered| q2
    cron -->|Daily report| q3

    q1 -->|Pull messages| order
    q1 -->|Pull messages| order
    q2 -->|Pull messages| email
    q3 -->|Pull messages| analytics

    style producers fill:#80AADD,stroke:#4a5568,color:#f8f8ff
    style queue fill:#FFB300,stroke:#4a5568,color:#f8f8ff
    style consumers fill:#33D17A,stroke:#4a5568,color:#f8f8ff
{{< /mermaid >}}

**Core Patterns:**

**1. Point-to-Point Queue**

{{< mermaid >}}
sequenceDiagram
    participant Producer
    participant Queue
    participant Consumer1
    participant Consumer2

    Producer->>Queue: Send message 1
    Producer->>Queue: Send message 2
    Producer->>Queue: Send message 3

    Queue->>Consumer1: Deliver message 1
    Note over Consumer1: Process message 1

    Queue->>Consumer2: Deliver message 2
    Note over Consumer2: Process message 2

    Queue->>Consumer1: Deliver message 3
    Note over Consumer1: Process message 3

    Note over Queue: Each message delivered<br/>to ONE consumer
{{< /mermaid >}}

**2. Pub/Sub (Publish/Subscribe)**

{{< mermaid >}}
sequenceDiagram
    participant Publisher
    participant Topic
    participant Sub1 as Subscriber 1
    participant Sub2 as Subscriber 2
    participant Sub3 as Subscriber 3

    Publisher->>Topic: Publish "order.created"

    Topic->>Sub1: Copy of message
    Topic->>Sub2: Copy of message
    Topic->>Sub3: Copy of message

    Note over Sub1: Email notification
    Note over Sub2: Update inventory
    Note over Sub3: Log analytics

    Note over Topic: Each subscriber gets<br/>a COPY of message
{{< /mermaid >}}

**Example: RabbitMQ (Python)**

```python
import pika
import json

# Producer: Send message to queue
connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
channel = connection.channel()

# Declare queue (creates if doesn't exist)
channel.queue_declare(queue='orders', durable=True)

# Send message
message = {
    'order_id': 12345,
    'customer_id': 789,
    'total': 99.99
}

channel.basic_publish(
    exchange='',
    routing_key='orders',
    body=json.dumps(message),
    properties=pika.BasicProperties(
        delivery_mode=2,  # Make message persistent
    )
)

print(f"Sent order {message['order_id']}")
connection.close()

# Consumer: Process messages from queue
def process_order(ch, method, properties, body):
    order = json.loads(body)
    print(f"Processing order {order['order_id']}")

    # Do work (update database, send email, etc.)
    process_payment(order)
    fulfill_order(order)

    # Acknowledge message (remove from queue)
    ch.basic_ack(delivery_tag=method.delivery_tag)

# Set up consumer
connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
channel = connection.channel()
channel.queue_declare(queue='orders', durable=True)

# Process one message at a time (fair dispatch)
channel.basic_qos(prefetch_count=1)

# Start consuming
channel.basic_consume(queue='orders', on_message_callback=process_order)
print('Waiting for messages...')
channel.start_consuming()
```

**Example: AWS SQS (Python/boto3)**

```python
import boto3
import json

sqs = boto3.client('sqs', region_name='us-east-1')
queue_url = 'https://sqs.us-east-1.amazonaws.com/123456789/my-queue'

# Send message
response = sqs.send_message(
    QueueUrl=queue_url,
    MessageBody=json.dumps({
        'event': 'user_registered',
        'user_id': 12345,
        'email': 'user@example.com'
    })
)

# Receive and process messages
while True:
    response = sqs.receive_message(
        QueueUrl=queue_url,
        MaxNumberOfMessages=10,
        WaitTimeSeconds=20  # Long polling
    )

    messages = response.get('Messages', [])

    for message in messages:
        body = json.loads(message['Body'])
        print(f"Processing: {body['event']}")

        # Process message
        handle_event(body)

        # Delete from queue (acknowledge)
        sqs.delete_message(
            QueueUrl=queue_url,
            ReceiptHandle=message['ReceiptHandle']
        )
```

**Benefits of Message Queues:**

| Benefit | Description |
|---------|-------------|
| **Decoupling** | Services don't need to know about each other |
| **Load leveling** | Queue absorbs traffic spikes |
| **Reliability** | Messages persist if consumer is down |
| **Scalability** | Add more consumers to process faster |
| **Async processing** | Don't block web requests with slow tasks |

**When to use:**

- ✅ Background jobs (email, image processing)
- ✅ Microservices communication
- ✅ Event-driven architectures
- ✅ Handle traffic spikes
- ✅ Retry failed operations
- ❌ Need immediate response (use synchronous APIs)
- ❌ Simple request-response (use REST)

---

### MQTT (Message Queuing Telemetry Transport)

**What it is:** Lightweight pub/sub protocol for IoT and constrained devices.

**Type:** Protocol (binary, over TCP)

{{< mermaid >}}
flowchart TB
    subgraph devices["IoT Devices"]
        temp["Temperature Sensor"]
        motion["Motion Sensor"]
        camera["Camera"]
        light["Smart Light"]
    end

    subgraph broker["MQTT Broker"]
        topics["Topics:<br/>home/bedroom/temp<br/>home/living/motion<br/>home/camera/alert"]
    end

    subgraph subscribers["Subscribers"]
        app["Mobile App"]
        dashboard["Dashboard"]
        automation["Automation Engine"]
    end

    temp -->|publish| topics
    motion -->|publish| topics
    camera -->|publish| topics

    topics -->|subscribe| app
    topics -->|subscribe| dashboard
    topics -->|subscribe| automation

    automation -->|publish| light

    style devices fill:#80AADD,stroke:#4a5568,color:#f8f8ff
    style broker fill:#FFB300,stroke:#4a5568,color:#f8f8ff
    style subscribers fill:#33D17A,stroke:#4a5568,color:#f8f8ff
{{< /mermaid >}}

**Characteristics:**

- Extremely lightweight (header ~2 bytes vs HTTP ~100+ bytes)
- Pub/sub model with topics
- Quality of Service (QoS) levels (0, 1, 2)
- Retained messages (new subscribers get last value)
- Low power consumption
- Designed for unreliable networks

**Example (Python/paho-mqtt):**

```python
import paho.mqtt.client as mqtt

# Publisher
client = mqtt.Client()
client.connect("mqtt.example.com", 1883)

# Publish temperature reading
client.publish("home/bedroom/temperature", "72.5")

# Subscriber
def on_message(client, userdata, message):
    print(f"Topic: {message.topic}")
    print(f"Value: {message.payload.decode()}")

client = mqtt.Client()
client.on_message = on_message
client.connect("mqtt.example.com", 1883)

# Subscribe to topic (supports wildcards)
client.subscribe("home/+/temperature")  # All rooms
client.subscribe("home/#")  # All topics under home/

client.loop_forever()
```

**MQTT vs HTTP REST:**

| Aspect | MQTT | HTTP REST |
|--------|------|-----------|
| **Overhead** | ~2 bytes | ~100+ bytes |
| **Pattern** | Pub/Sub | Request-Response |
| **Power** | Very low | Higher |
| **Use case** | IoT sensors | Web APIs |
| **Network** | Works on unreliable networks | Needs stable connection |

**When to use:**

- ✅ IoT devices (sensors, smart home)
- ✅ Battery-powered devices
- ✅ Unreliable/low bandwidth networks
- ✅ Real-time telemetry
- ❌ Web APIs (use REST/WebSocket)
- ❌ Large payloads (use HTTP)

---

## Part 4: Decision Framework

How do you choose the right communication pattern? Use these decision trees and comparisons.

### Communication Pattern Decision Tree

{{< mermaid >}}
flowchart TD
    start["Choose Communication Pattern"]

    start --> sync{Synchronous<br/>or Async?}

    sync -->|Synchronous| crud{Standard<br/>CRUD API?}
    sync -->|Async/Event-driven| event{Who initiates?}

    crud -->|Yes| rest["REST"]
    crud -->|No, complex queries| graphql["GraphQL"]
    crud -->|No, function calls| perf{Performance<br/>critical?}

    perf -->|Yes| grpc["gRPC"]
    perf -->|No| rpc["JSON-RPC"]

    event -->|Server notifies client| webhook["Webhook"]
    event -->|Services communicate| mq["Message Queue"]
    event -->|IoT devices| mqtt["MQTT"]

    start --> realtime{Real-time<br/>needed?}

    realtime -->|Yes| direction{Communication<br/>direction?}

    direction -->|Server → Client only| sse["Server-Sent Events"]
    direction -->|Bidirectional| ws["WebSocket"]
    direction -->|Peer-to-peer media| webrtc["WebRTC"]

    realtime -->|No, occasional| polling["Polling/REST"]

    style rest fill:#80AADD,stroke:#4a5568,color:#f8f8ff
    style graphql fill:#80AADD,stroke:#4a5568,color:#f8f8ff
    style grpc fill:#33D17A,stroke:#4a5568,color:#f8f8ff
    style ws fill:#33D17A,stroke:#4a5568,color:#f8f8ff
    style webhook fill:#FFB300,stroke:#4a5568,color:#f8f8ff
    style mq fill:#FFB300,stroke:#4a5568,color:#f8f8ff
{{< /mermaid >}}

### Performance Comparison

{{< mermaid >}}
graph LR
    subgraph latency["Latency (Lower is better)"]
        l1["WebSocket<br/>~1ms"]
        l2["gRPC<br/>~5ms"]
        l3["WebRTC<br/>~10ms"]
        l4["REST<br/>~50ms"]
        l5["Long Polling<br/>~100ms"]
        l6["SSE<br/>~150ms"]
        l7["Polling<br/>~5000ms"]
        l8["Webhook<br/>Variable"]
    end

    subgraph throughput["Throughput (Higher is better)"]
        t1["gRPC<br/>100k msg/s"]
        t2["WebSocket<br/>50k msg/s"]
        t3["MQTT<br/>30k msg/s"]
        t4["REST<br/>10k msg/s"]
        t5["GraphQL<br/>8k msg/s"]
        t6["SOAP<br/>1k msg/s"]
    end

    style l1 fill:#33D17A,stroke:#4a5568,color:#f8f8ff
    style l2 fill:#33D17A,stroke:#4a5568,color:#f8f8ff
    style l7 fill:#F26E74,stroke:#4a5568,color:#f8f8ff
    style l8 fill:#F26E74,stroke:#4a5568,color:#f8f8ff

    style t1 fill:#33D17A,stroke:#4a5568,color:#f8f8ff
    style t2 fill:#33D17A,stroke:#4a5568,color:#f8f8ff
    style t6 fill:#F26E74,stroke:#4a5568,color:#f8f8ff
{{< /mermaid >}}

### Complexity vs Capability

{{< mermaid >}}
quadrantChart
    title Complexity vs Capability
    x-axis "Low Complexity" --> "High Complexity"
    y-axis "Basic Features" --> "Advanced Features"

    REST: [0.2, 0.5]
    Webhook: [0.25, 0.4]
    Polling: [0.15, 0.2]
    SSE: [0.35, 0.6]
    WebSocket: [0.55, 0.75]
    GraphQL: [0.6, 0.7]
    gRPC: [0.75, 0.9]
    Message Queues: [0.7, 0.85]
    WebRTC: [0.9, 0.95]
    MQTT: [0.4, 0.55]
{{< /mermaid >}}

### Use Case Mapping

| Use Case | Recommended Pattern | Why? |
|----------|-------------------|------|
| **Public API for mobile/web** | REST | Standard, cacheable, simple |
| **Complex data requirements** | GraphQL | Flexible queries, avoid over-fetching |
| **Microservices internal communication** | gRPC | High performance, type safety |
| **Real-time chat** | WebSocket | Bidirectional, low latency |
| **Live dashboard (one-way)** | Server-Sent Events | Simple server push |
| **Payment notifications** | Webhook | Event-driven, reliable delivery |
| **Background job processing** | Message Queue | Async, decoupled, scalable |
| **IoT sensor data** | MQTT | Lightweight, low power |
| **Video conferencing** | WebRTC | Peer-to-peer, low latency |
| **Stock ticker** | Server-Sent Events | Continuous updates, one-way |
| **Multiplayer game** | WebSocket or WebRTC | Low latency, bidirectional |

---

## Part 5: Hybrid Architectures

Real-world systems rarely use just one pattern. Here's how to combine them effectively.

### E-Commerce System Example

{{< mermaid >}}
flowchart TB
    subgraph clients["Clients"]
        web["Web Browser"]
        mobile["Mobile App"]
        admin["Admin Dashboard"]
    end

    subgraph api["API Gateway"]
        rest["REST API<br/>/api/products<br/>/api/orders"]
        ws["WebSocket<br/>/ws/cart<br/>/ws/notifications"]
    end

    subgraph services["Microservices"]
        order["Order Service"]
        inventory["Inventory Service"]
        payment["Payment Service"]
        notification["Notification Service"]
    end

    subgraph async["Async Layer"]
        queue["Message Queue"]
        events["Event Bus"]
    end

    subgraph external["External Services"]
        stripe["Stripe<br/>(Payments)"]
        shippo["Shippo<br/>(Shipping)"]
    end

    web -->|GET /products| rest
    mobile -->|POST /orders| rest
    admin -->|WebSocket connection| ws

    rest <-->|gRPC| order
    rest <-->|gRPC| inventory

    order -->|publish event| queue
    queue -->|consume| payment
    queue -->|consume| notification

    payment <-->|HTTP API| stripe
    stripe -.->|webhook| payment

    order <-->|HTTP API| shippo
    shippo -.->|webhook| notification

    notification -->|push| ws
    ws -->|real-time updates| admin

    style clients fill:#80AADD,stroke:#4a5568,color:#f8f8ff
    style api fill:#33D17A,stroke:#4a5568,color:#f8f8ff
    style services fill:#FFB300,stroke:#4a5568,color:#f8f8ff
    style async fill:#F26E74,stroke:#4a5568,color:#252627
    style external fill:#2c5282,stroke:#4a5568,color:#f8f8ff
{{< /mermaid >}}

**Breaking down this architecture:**

1. **REST API** - Public-facing endpoints for standard operations
   - `GET /products` - Browse catalog
   - `POST /orders` - Place order
   - `GET /orders/{id}` - Check order status

2. **WebSocket** - Real-time updates for admin dashboard
   - Live order notifications
   - Inventory alerts
   - Customer activity feed

3. **gRPC** - Internal microservice communication
   - Order service ↔ Inventory service (high performance)
   - Order service ↔ Payment service (type safety)

4. **Message Queue** - Async processing
   - Order created → Send confirmation email
   - Order created → Update inventory
   - Order created → Trigger analytics

5. **Webhooks** - External service integration
   - Stripe → Payment confirmation
   - Shippo → Shipping updates
   - SendGrid → Email delivery status

### Social Media Platform Example

{{< mermaid >}}
flowchart TB
    subgraph frontend["Frontend Applications"]
        webapp["Web App"]
        mobileapp["Mobile App"]
    end

    subgraph gateway["API Layer"]
        graphql["GraphQL API<br/>Flexible queries"]
        wsserver["WebSocket Server<br/>Real-time updates"]
        rest["REST API<br/>Simple endpoints"]
    end

    subgraph backend["Backend Services"]
        user["User Service"]
        post["Post Service"]
        feed["Feed Service"]
        messaging["Messaging Service"]
    end

    subgraph storage["Data Layer"]
        postgres[("PostgreSQL<br/>User data")]
        redis[("Redis<br/>Cache/Sessions")]
        s3[("S3<br/>Media storage")]
    end

    subgraph realtime["Real-Time Layer"]
        pubsub["Pub/Sub"]
        wsconnections["WebSocket<br/>Connection Pool"]
    end

    webapp -->|Complex queries| graphql
    mobileapp -->|Simple endpoints| rest
    webapp <-->|Chat, notifications| wsserver
    mobileapp <-->|Chat, notifications| wsserver

    graphql --> user
    graphql --> post
    graphql --> feed

    rest --> user
    rest --> post

    wsserver <--> messaging
    messaging --> pubsub
    pubsub --> wsconnections
    wsconnections --> webapp
    wsconnections --> mobileapp

    user --> postgres
    post --> postgres
    feed --> redis
    post --> s3

    style frontend fill:#80AADD,stroke:#4a5568,color:#f8f8ff
    style gateway fill:#33D17A,stroke:#4a5568,color:#f8f8ff
    style backend fill:#FFB300,stroke:#4a5568,color:#f8f8ff
    style storage fill:#2c5282,stroke:#4a5568,color:#f8f8ff
    style realtime fill:#F26E74,stroke:#4a5568,color:#252627
{{< /mermaid >}}

**Why this combination?**

- **GraphQL** - Web app needs flexible queries (user profile + posts + comments in one request)
- **REST** - Mobile app needs simple, cacheable endpoints
- **WebSocket** - Real-time chat and notifications
- **Pub/Sub** - Distribute messages to all connected users

### Monitoring & Observability System

{{< mermaid >}}
flowchart LR
    subgraph sources["Data Sources"]
        app1["Application Logs"]
        app2["Metrics"]
        app3["Traces"]
    end

    subgraph ingestion["Ingestion Layer"]
        mqtt["MQTT<br/>(IoT devices)"]
        grpc["gRPC<br/>(High throughput)"]
        http["HTTP<br/>(Legacy systems)"]
    end

    subgraph processing["Processing"]
        kafka["Kafka<br/>Message Stream"]
        processor["Stream Processor"]
    end

    subgraph storage["Storage"]
        timeseries[("Time-series DB")]
        elasticsearch[("Elasticsearch")]
    end

    subgraph ui["User Interface"]
        dashboard["Dashboard"]
        alerts["Alert Manager"]
    end

    app1 --> grpc
    app2 --> grpc
    app3 --> http
    mqtt --> kafka
    grpc --> kafka
    http --> kafka

    kafka --> processor
    processor --> timeseries
    processor --> elasticsearch

    timeseries --> dashboard
    elasticsearch --> dashboard

    processor -->|SSE| dashboard
    processor -->|Webhook| alerts

    style sources fill:#80AADD,stroke:#4a5568,color:#f8f8ff
    style ingestion fill:#33D17A,stroke:#4a5568,color:#f8f8ff
    style processing fill:#FFB300,stroke:#4a5568,color:#f8f8ff
    style storage fill:#2c5282,stroke:#4a5568,color:#f8f8ff
    style ui fill:#F26E74,stroke:#4a5568,color:#252627
{{< /mermaid >}}

**Pattern choices:**

- **gRPC** - High-throughput metrics ingestion (10k+ msg/s)
- **MQTT** - Lightweight IoT device telemetry
- **Kafka** - Message stream for processing
- **Server-Sent Events** - Live dashboard updates
- **Webhooks** - Alert notifications (PagerDuty, Slack)

{{< callout type="success" >}}
**Best Practice:** Start simple with REST, add real-time patterns (WebSocket/SSE) where needed, introduce message queues for async processing, and use gRPC for internal high-performance services. Don't over-engineer—adopt patterns as requirements emerge.
{{< /callout >}}

---

## Conclusion

Modern applications require multiple communication patterns working together. Here's your decision framework:

### Quick Reference

**Need to fetch/update data?**
→ **REST** (simple) or **GraphQL** (complex queries)

**Need to call remote functions?**
→ **RPC** (simple) or **gRPC** (high performance)

**Need real-time bidirectional communication?**
→ **WebSocket**

**Need server-to-client push only?**
→ **Server-Sent Events**

**Need to be notified of external events?**
→ **Webhook**

**Need async background processing?**
→ **Message Queue** (RabbitMQ, Kafka, SQS)

**Building IoT system?**
→ **MQTT**

**Need video/audio calling?**
→ **WebRTC**

### Key Takeaways

1. **Not all patterns are protocols** - REST is a style, WebSocket is a protocol, webhook is a pattern, gRPC is a framework

2. **Patterns are complementary** - Use REST for your API, webhooks for external events, WebSocket for real-time, gRPC for microservices

3. **Choose based on requirements** - Consider latency, throughput, complexity, and existing infrastructure

4. **Start simple** - REST covers most needs. Add complexity only when required.

5. **Security matters** - Verify webhook signatures, use WSS:// for WebSocket, implement authentication for all patterns

### Further Reading

- **REST**: [Roy Fielding's Dissertation](https://www.ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm)
- **WebSocket**: [RFC 6455](https://tools.ietf.org/html/rfc6455)
- **gRPC**: [gRPC Documentation](https://grpc.io/docs/)
- **GraphQL**: [GraphQL Specification](https://spec.graphql.org/)
- **MQTT**: [MQTT.org](https://mqtt.org/)

{{< callout type="info" >}}
**Want to dive deeper?** Check out our related articles on [serialization formats](/blog/posts/serialization-explained/), [building production APIs](/blog/posts/), and [microservices architecture patterns](/blog/posts/).
{{< /callout >}}

---

*Have questions or suggestions? Found an error? [Open an issue on GitHub](https://github.com/blackwell-systems/blog/issues) or connect on [Twitter/X](https://twitter.com/blackwellsystems).*
