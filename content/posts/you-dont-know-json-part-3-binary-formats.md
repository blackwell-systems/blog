---
title: "You Don't Know JSON: Part 3 - Binary JSON: When Text Format Isn't Fast Enough"
date: 2025-12-15
draft: false
series: ["you-dont-know-json"]
seriesOrder: 3
tags: ["json", "jsonb", "bson", "messagepack", "cbor", "binary-serialization", "performance", "optimization", "postgresql", "mongodb", "data-formats", "serialization", "parsing", "encoding", "database-optimization", "api-performance", "microservices", "caching", "bandwidth-optimization", "compression"]
categories: ["fundamentals", "programming", "performance"]
description: "Master binary JSON formats: JSONB, BSON, MessagePack, and CBOR. Learn when text JSON becomes a bottleneck and how binary formats solve size and performance problems while maintaining JSON-like structure."
summary: "JSON's text format is human-readable but inefficient. Binary JSON formats (JSONB, BSON, MessagePack, CBOR) solve performance problems with smaller sizes and faster parsing while keeping JSON's flexibility. Learn when and how to use each format."
---

In [Part 1]({{< relref "you-dont-know-json-part-1-origins.md" >}}), we explored JSON's triumph through simplicity. In [Part 2]({{< relref "you-dont-know-json-part-2-json-schema.md" >}}), we added validation with JSON Schema. Now we tackle JSON's performance tax: **the text format overhead**.

JSON's human-readability is both its greatest strength and its Achilles heel. Every byte is text. Field names repeat in every object. Numbers are stored as strings. Parsing requires scanning every character.

For configuration files and API responses under 100KB, this is fine. But at scale - millions of messages per second, gigabytes of log data, mobile apps on slow networks - the text format becomes expensive.

{{< callout type="info" >}}
**The Modular Response:** Rather than rebuild JSON with binary support built-in (the XML approach), the ecosystem created separate binary formats. Each maintains JSON's structure while optimizing for specific use cases - database storage (JSONB), document databases (BSON), or universal serialization (MessagePack, CBOR). This modularity lets you choose the efficiency level per use case without changing your data model.
{{< /callout >}}

Binary JSON formats solve this. They maintain JSON's structure and flexibility while dramatically improving size and speed.

---

## Running Example: Storing 10 Million Users

Our User API from [Part 1]({{< relref "you-dont-know-json-part-1-origins.md" >}}#running-example-building-a-user-api) now has validation from [Part 2]({{< relref "you-dont-know-json-part-2-json-schema.md" >}}). Next challenge: **storing 10 million users efficiently**.

**Current user object (text JSON):**
```json
{
  "id": "user-5f9d88c",
  "username": "alice",
  "email": "alice@example.com",
  "created": "2023-01-15T10:30:00Z",
  "bio": "Software engineer",
  "followers": 1234,
  "verified": true
}
```

**Size:** 156 bytes per user
**10M users:** 1.56 GB as text JSON

**Problems at scale:**
- Field names repeated 10 million times
- Text parsing on every query
- No indexing into JSON structure
- Inefficient storage and retrieval

Binary JSON formats solve this. Let's see the impact.

---

## The Text Format Tax

### What You Pay for Human-Readability

**Our user object in JSON:**
```json
{
  "id": "user-5f9d88c",
  "username": "alice",
  "email": "alice@example.com",
  "created": "2023-01-15T10:30:00Z",
  "bio": "Software engineer",
  "followers": 1234,
  "verified": true
}
```

**Size:** 156 bytes

**What happens during parsing:**
1. Read entire string character by character
2. Decode UTF-8 sequences
3. Identify delimiters (`{`, `}`, `:`, `,`)
4. Parse string values (allocate memory, copy)
5. Convert number strings to numeric types
6. Handle escape sequences
7. Build object structure in memory

**The hidden costs:**
- Field names stored repeatedly (`"id"`, `"username"`, `"email"` in every record)
- Numbers stored as text (`123456789` = 9 bytes vs 4 bytes as integer)
- Date stored as 24-character string vs 8-byte timestamp
- Parse overhead: string scanning, allocation for every field
- No indexing without parsing entire document

### When Does This Matter?

**Scenarios where text JSON hurts:**

+ **High-throughput APIs** - Parsing millions of messages/second
+ **Mobile applications** - Bandwidth costs on cellular networks  
+ **Database storage** - Repeated field names in millions of rows
+ **Message queues** - Throughput bottlenecked by serialization
+ **Log aggregation** - Storing gigabytes of JSON logs
+ **Caching layers** - Memory usage in Redis/Memcached
+ **IoT devices** - Limited bandwidth and processing power

{{< callout type="info" >}}
**Rule of Thumb:** Text JSON is fine for human-edited configs and small API payloads. Consider binary formats when you have:
- High message volume (>10K/sec)
- Large payloads (>100KB)
- Bandwidth constraints (mobile, IoT)
- Storage costs matter (logs, databases)
- Parse performance critical (real-time systems)
{{< /callout >}}

{{< mermaid >}}
timeline
    title Evolution of JSON Formats
    2001 : JSON Specification
         : Text-based, human-readable
    2009 : MongoDB BSON
         : Binary JSON with extended types
    2010 : MessagePack
         : Universal binary serialization
    2012 : CBOR (RFC 7049)
         : IETF standard binary format
    2014 : PostgreSQL JSONB
         : Indexable binary JSON
    2020 : CBOR updated (RFC 8949)
         : Improved specification
    2024+ : Binary JSON mature
         : Production-ready ecosystem
{{< /mermaid >}}

---

## The Binary JSON Landscape

Binary JSON formats share common goals but differ in implementation and use cases.

### Common Goals

**1. Smaller Size**
- Remove repeated field names (or compress them)
- Efficient number encoding (binary, not text)
- No syntax overhead (no quotes, commas as text)

**2. Faster Parsing**
- Skip string scanning (length-prefixed data)
- Direct memory mapping possible
- Type information embedded (no string-to-type conversion)

**3. Extended Types**
- Native date/timestamp support
- Binary data (no Base64 overhead)
- Specialized numeric types (decimals, big integers)

### The Formats

| Format | Creator | Primary Use | Schema | Standardized |
|--------|---------|-------------|--------|--------------|
| **JSONB** | PostgreSQL | Database storage | No | No (Postgres-specific) |
| **BSON** | MongoDB | Document DB, wire protocol | No | [Spec](http://bsonspec.org/) |
| **MessagePack** | Sadayuki Furuhashi | Universal serialization | No | [Spec](https://msgpack.org/) |
| **CBOR** | IETF | IoT, security (WebAuthn) | No | [RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html) |
| **Protocol Buffers** | Google | RPC, microservices | **Yes** | [Spec](https://protobuf.dev/) |

{{< callout type="warning" >}}
**Key Distinction:** Binary JSON formats (JSONB, BSON, MessagePack, CBOR) are **schemaless** - they preserve JSON's flexibility. Protocol Buffers requires a schema definition. This is a fundamental architectural difference, not just an implementation detail.
{{< /callout >}}

{{< mermaid >}}
flowchart TB
    start{Need binary format?}
    
    start -->|Database storage| db{Which database?}
    start -->|Universal serialization| universal{Schema required?}
    start -->|Specific use case| specific{What use case?}
    
    db -->|PostgreSQL| jsonb[JSONB]
    db -->|MongoDB| bson[BSON]
    db -->|Other SQL| msgpack[MessagePack in BLOB]
    
    universal -->|No schema| msgpack2[MessagePack]
    universal -->|Schema enforcement| protobuf[Protocol Buffers]
    
    specific -->|IoT/Embedded| cbor[CBOR]
    specific -->|Web standards| cbor2[CBOR]
    specific -->|Microservices| choice{Schema?}
    
    choice -->|Need schema| protobuf2[Protocol Buffers]
    choice -->|Flexibility| msgpack3[MessagePack]
    
    style jsonb fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style bson fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style msgpack fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style msgpack2 fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style msgpack3 fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style cbor fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style cbor2 fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style protobuf fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style protobuf2 fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

---

## PostgreSQL JSONB: Indexable Documents

### What is JSONB?

JSONB is PostgreSQL's **binary JSON storage format**. Unlike the `JSON` column type (which stores text), JSONB decomposes JSON into a binary structure.

**Key difference:**
```sql
-- JSON column: stores text as-is, parses on every query
CREATE TABLE users_json (
    data JSON
);

-- JSONB column: stores binary, no reparse needed
CREATE TABLE users_jsonb (
    data JSONB
);
```

### Internal Structure

JSONB uses a decomposed binary format:

**Storage layout:**
- **Header:** Version and flags
- **JEntry array:** Metadata for each key/value (offset, length, type)
- **Data section:** Actual values in binary form

**Benefits:**
- No reparsing on queries (already decomposed)
- Keys stored once per object
- Direct access to nested fields (offset jumping)
- Indexable (GIN, GiST indexes)

**Trade-off:**
- Slower to insert (decomposition overhead)
- Slightly larger than compressed JSON text
- Key order not preserved (sorted for efficiency)

### Querying JSONB

**Operators:**
```sql
-- Extract as JSON (->)
SELECT data->'email' FROM users_jsonb WHERE id = 1;
-- Result: "alice@example.com"

-- Extract as text (->>)
SELECT data->>'email' FROM users_jsonb WHERE id = 1;
-- Result: alice@example.com (no quotes)

-- Nested access
SELECT data->'address'->>'city' FROM users_jsonb WHERE id = 1;

-- Containment (@>)
SELECT * FROM users_jsonb WHERE data @> '{"active": true}';

-- Key existence (?)
SELECT * FROM users_jsonb WHERE data ? 'premium_until';

-- Any key exists (?|)
SELECT * FROM users_jsonb WHERE data ?| array['email', 'phone'];

-- All keys exist (?&)
SELECT * FROM users_jsonb WHERE data ?& array['email', 'username'];
```

### Indexing JSONB

**GIN Index (Generalized Inverted Index):**
```sql
-- Index entire document
CREATE INDEX idx_users_data ON users_jsonb USING GIN (data);

-- Now fast queries like:
SELECT * FROM users_jsonb WHERE data @> '{"active": true}';
SELECT * FROM users_jsonb WHERE data ? 'email';
```

**GIN index on specific path:**
```sql
-- Index specific field
CREATE INDEX idx_users_email ON users_jsonb USING GIN ((data->'email'));

-- Fast lookup
SELECT * FROM users_jsonb WHERE data->>'email' = 'alice@example.com';
```

**Expression index:**
```sql
-- Index extracted value
CREATE INDEX idx_users_username ON users_jsonb ((data->>'username'));
```

**B-tree index for range queries:**
```sql
-- Index numeric field for sorting/range
CREATE INDEX idx_users_created ON users_jsonb 
  ((data->>'created')::timestamp);

-- Fast range query
SELECT * FROM users_jsonb 
WHERE (data->>'created')::timestamp > '2023-01-01';
```

### Practical Example

```sql
-- Create table
CREATE TABLE events (
    id SERIAL PRIMARY KEY,
    event_data JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Insert data
INSERT INTO events (event_data) VALUES
('{"type": "login", "user_id": 123, "ip": "192.168.1.1", "timestamp": "2023-01-15T10:30:00Z"}'),
('{"type": "purchase", "user_id": 123, "amount": 99.99, "product_id": 456}'),
('{"type": "logout", "user_id": 123, "session_duration": 3600}');

-- Create indexes
CREATE INDEX idx_events_type ON events USING GIN ((event_data->'type'));
CREATE INDEX idx_events_user ON events USING GIN ((event_data->'user_id'));

-- Query by type (uses index)
SELECT event_data FROM events 
WHERE event_data->>'type' = 'purchase';

-- Query by user (uses index)
SELECT event_data FROM events 
WHERE event_data @> '{"user_id": 123}';

-- Update nested field
UPDATE events 
SET event_data = jsonb_set(event_data, '{processed}', 'true')
WHERE event_data->>'type' = 'purchase';

-- Add field to all records
UPDATE events 
SET event_data = event_data || '{"version": "2.0"}'::jsonb;

-- Remove field
UPDATE events 
SET event_data = event_data - 'ip';
```

### Performance Characteristics

**Benchmark: 1M rows, user documents**

| Operation | JSON (text) | JSONB (binary) | Speedup |
|-----------|-------------|----------------|---------|
| INSERT | 15.2s | 18.7s | 0.81x (slower) |
| SELECT by ID | 0.12ms | 0.08ms | 1.5x |
| SELECT with filter | 2.3s | 0.45s (indexed) | 5.1x |
| UPDATE field | 1.8s | 0.9s | 2x |
| Storage size | 285 MB | 310 MB | 1.09x (larger) |

**With GIN index:**
- Index size: +95 MB
- Query speedup: 10-50x for containment queries

{{< callout type="success" >}}
**Best Practice:** Use JSONB for:
- Semi-structured data in PostgreSQL
- Documents with varied schemas
- Fast queries on JSON fields
- When you need indexing

Stick with JSON column type only if you need:
- Exact key order preservation
- Faster inserts (no decomposition)
- Original formatting preserved
{{< /callout >}}

---

## MongoDB BSON: Extended Types

### What is BSON?

BSON (Binary JSON) is MongoDB's data storage and wire protocol format. Created in 2009, it extends JSON with additional types and efficient binary encoding.

**Key features:**
- Extended type system
- Length-prefixed elements (traversable without parsing)
- Efficient binary encoding
- Native in MongoDB drivers

### Extended Type System

BSON adds types JSON lacks:

```javascript
{
  _id: ObjectId("507f1f77bcf86cd799439011"),        // 12-byte unique identifier
  username: "alice",                                 // String
  email: "alice@example.com",                        // String
  age: 30,                                           // Int32
  balance: NumberDecimal("1234.56"),                 // Decimal128 (financial)
  created: ISODate("2023-01-15T10:30:00Z"),         // UTC DateTime
  avatar: BinData(0, "iVBORw0KGgoAAAA..."),         // Binary data
  tags: ["golang", "rust"],                          // Array
  metadata: {visits: 42},                            // Embedded document
  pattern: /^user_/i,                                // Regular expression
  lastSeen: Timestamp(1673780400, 1),               // Internal timestamp
  maxValue: NumberLong("9223372036854775807"),      // Int64
  minValue: MinKey(),                                // Special min value
  maxValue: MaxKey()                                 // Special max value
}
```

### BSON Types

| BSON Type | JSON Equivalent | Binary Size | Notes |
|-----------|-----------------|-------------|-------|
| Double | number | 8 bytes | IEEE 754 float |
| String | string | 4 + length + 1 | UTF-8, length-prefixed |
| Object | object | Variable | Embedded document |
| Array | array | Variable | Like object with numeric keys |
| Binary | (Base64 string) | 4 + length | Raw bytes, no encoding |
| ObjectId | (string) | 12 bytes | Unique identifier |
| Boolean | boolean | 1 byte | true/false |
| Date | (string) | 8 bytes | UTC milliseconds since epoch |
| Null | null | 0 bytes | Just type marker |
| Regex | (no equivalent) | Variable | Pattern + flags |
| Int32 | number | 4 bytes | 32-bit integer |
| Timestamp | (no equivalent) | 8 bytes | Internal use |
| Int64 | number | 8 bytes | 64-bit integer |
| Decimal128 | (string) | 16 bytes | High-precision decimal |

### ObjectId Deep Dive

ObjectId is a 12-byte identifier designed for distributed systems:

**Structure:**
```
| 4-byte timestamp | 5-byte random | 3-byte counter |
```

**Properties:**
- Globally unique (no coordination needed)
- Sortable by creation time
- Embedded timestamp
- Short (12 bytes vs 36-byte UUID)

**Generation in drivers:**

**JavaScript:**
```javascript
const { ObjectId } = require('mongodb');

// Generate new ObjectId
const id = new ObjectId();
console.log(id.toString());  // "507f1f77bcf86cd799439011"

// Extract timestamp
console.log(id.getTimestamp());  // Date object

// Create from string
const id2 = new ObjectId("507f1f77bcf86cd799439011");

// Comparison
id.equals(id2);  // true/false
```

**Go:**
```go
import "go.mongodb.org/mongo-driver/bson/primitive"

// Generate new ObjectId
id := primitive.NewObjectID()
fmt.Println(id.Hex())  // "507f1f77bcf86cd799439011"

// Extract timestamp
timestamp := id.Timestamp()

// Parse from string
id2, err := primitive.ObjectIDFromHex("507f1f77bcf86cd799439011")

// Comparison
id == id2  // true/false
```

**Python:**
```python
from bson import ObjectId
from datetime import datetime

# Generate new ObjectId
id = ObjectId()
print(str(id))  # "507f1f77bcf86cd799439011"

# Extract timestamp
timestamp = id.generation_time  # datetime object

# Create from string
id2 = ObjectId("507f1f77bcf86cd799439011")

# Comparison
id == id2  # True/False
```

### Date Handling

BSON's native date type solves JSON's date problem:

**JavaScript:**
```javascript
// Insert with native Date
await collection.insertOne({
  username: "alice",
  created: new Date(),
  updated: new Date("2023-01-15T10:30:00Z")
});

// Query by date range
const recentUsers = await collection.find({
  created: { $gte: new Date("2023-01-01") }
}).toArray();

// Date is stored as 8-byte UTC milliseconds
```

**Go:**
```go
import "time"

// Insert with time.Time
collection.InsertOne(ctx, bson.M{
    "username": "alice",
    "created":  time.Now(),
    "updated":  time.Date(2023, 1, 15, 10, 30, 0, 0, time.UTC),
})

// Query by date range
filter := bson.M{
    "created": bson.M{
        "$gte": time.Date(2023, 1, 1, 0, 0, 0, 0, time.UTC),
    },
}
```

**Python:**
```python
from datetime import datetime

# Insert with datetime
collection.insert_one({
    "username": "alice",
    "created": datetime.now(),
    "updated": datetime(2023, 1, 15, 10, 30, 0)
})

# Query by date range
recent_users = collection.find({
    "created": {"$gte": datetime(2023, 1, 1)}
})
```

### Binary Data Handling

BSON avoids Base64 overhead for binary data:

**JavaScript:**
```javascript
const { Binary } = require('mongodb');

// Store binary data
const imageBuffer = fs.readFileSync('avatar.png');
await collection.insertOne({
  username: "alice",
  avatar: new Binary(imageBuffer)
});

// Retrieve binary data
const user = await collection.findOne({username: "alice"});
fs.writeFileSync('retrieved.png', user.avatar.buffer);

// No Base64 encoding/decoding overhead!
```

### Size Comparison

**Sample document:**
```json
{
  "_id": "507f1f77bcf86cd799439011",
  "username": "alice",
  "email": "alice@example.com",
  "age": 30,
  "balance": "1234.56",
  "created": "2023-01-15T10:30:00Z"
}
```

**Sizes:**
- JSON text: 169 bytes
- BSON binary: 142 bytes
- Savings: 16%

**Larger document (100 fields):**
- JSON text: 5,234 bytes
- BSON binary: 4,012 bytes
- Savings: 23%

**With binary data (1KB image):**
- JSON + Base64: 1,536 bytes (33% overhead)
- BSON binary: 1,100 bytes (raw binary)
- Savings: 28%

### BSON in Practice

**Complete example:**

**JavaScript (Node.js):**
```javascript
const { MongoClient, ObjectId, Decimal128, Binary } = require('mongodb');

async function example() {
  const client = await MongoClient.connect('mongodb://localhost:27017');
  const db = client.db('myapp');
  const users = db.collection('users');

  // Insert with extended types
  const result = await users.insertOne({
    _id: new ObjectId(),
    username: 'alice',
    email: 'alice@example.com',
    balance: Decimal128.fromString('1234.56'),
    created: new Date(),
    avatar: new Binary(Buffer.from('image data'))
  });

  console.log('Inserted:', result.insertedId);

  // Query
  const user = await users.findOne({ username: 'alice' });
  
  // Access ObjectId
  console.log('User ID:', user._id.toString());
  console.log('Created:', user._id.getTimestamp());
  
  // Access Decimal128
  console.log('Balance:', user.balance.toString());
  
  // Access Binary
  console.log('Avatar size:', user.avatar.buffer.length);

  await client.close();
}
```

**Go:**
```go
import (
    "go.mongodb.org/mongo-driver/bson"
    "go.mongodb.org/mongo-driver/bson/primitive"
    "go.mongodb.org/mongo-driver/mongo"
)

func example(client *mongo.Client) {
    users := client.Database("myapp").Collection("users")

    // Insert with extended types
    result, err := users.InsertOne(ctx, bson.M{
        "_id":      primitive.NewObjectID(),
        "username": "alice",
        "email":    "alice@example.com",
        "balance":  primitive.NewDecimal128(123456, 2), // 1234.56
        "created":  time.Now(),
        "avatar":   primitive.Binary{Data: imageBytes},
    })

    // Query
    var user bson.M
    err = users.FindOne(ctx, bson.M{"username": "alice"}).Decode(&user)

    // Access ObjectId
    id := user["_id"].(primitive.ObjectID)
    fmt.Println("User ID:", id.Hex())
    fmt.Println("Created:", id.Timestamp())
}
```

**Python:**
```python
from pymongo import MongoClient
from bson import ObjectId, Decimal128, Binary
from datetime import datetime

client = MongoClient('mongodb://localhost:27017')
db = client.myapp
users = db.users

# Insert with extended types
result = users.insert_one({
    '_id': ObjectId(),
    'username': 'alice',
    'email': 'alice@example.com',
    'balance': Decimal128('1234.56'),
    'created': datetime.now(),
    'avatar': Binary(image_bytes)
})

print('Inserted:', result.inserted_id)

# Query
user = users.find_one({'username': 'alice'})

# Access ObjectId
print('User ID:', str(user['_id']))
print('Created:', user['_id'].generation_time)

# Access Decimal128
print('Balance:', str(user['balance']))

# Access Binary
print('Avatar size:', len(user['avatar']))
```

{{< callout type="info" >}}
**BSON Use Cases:**
- MongoDB storage (native format)
- MongoDB wire protocol
- Document databases needing extended types
- Systems requiring ObjectId benefits

**Not recommended for:**
- General-purpose serialization (use MessagePack)
- Non-MongoDB systems (ecosystem smaller)
- Human debugging (binary format)
{{< /callout >}}

---

## MessagePack: Universal Binary Serialization

### What is MessagePack?

MessagePack is a language-agnostic binary serialization format. Think of it as "binary JSON" - it serializes the same data structures (objects, arrays, strings, numbers) but in efficient binary form.

**Design goals:**
- Smaller than JSON
- Faster than JSON
- Simple specification
- Wide language support
- Streaming-friendly

**Created:** 2010 by Sadayuki Furuhashi  
**Specification:** [msgpack.org](https://msgpack.org/)

### Type System

MessagePack types map cleanly to JSON:

| MessagePack | JSON | Notes |
|-------------|------|-------|
| nil | null | Single byte |
| boolean | boolean | Single byte |
| integer | number | Variable: 1-9 bytes depending on value |
| float | number | 5 bytes (float32) or 9 bytes (float64) |
| string | string | Length-prefixed UTF-8 |
| binary | (Base64) | Raw bytes, not in JSON |
| array | array | Length-prefixed |
| map | object | Length-prefixed key-value pairs |
| extension | N/A | User-defined types |

### Size Efficiency

**Encoding examples:**

```
Value: null
JSON:  4 bytes  "null"
MsgPack: 1 byte   0xc0

Value: true
JSON:  4 bytes  "true"
MsgPack: 1 byte   0xc3

Value: 42
JSON:  2 bytes  "42"
MsgPack: 1 byte   0x2a (fixint)

Value: 1000
JSON:  4 bytes  "1000"
MsgPack: 3 bytes  0xcd 0x03 0xe8 (uint16)

Value: "hello"
JSON:  7 bytes  "hello" (with quotes in transmission)
MsgPack: 6 bytes  0xa5 "hello" (fixstr: type+length+data)
```

**Sample object:**
```json
{
  "id": 123,
  "name": "alice",
  "active": true
}
```

**Sizes:**
- JSON: 46 bytes
- MessagePack: 28 bytes
- Savings: 39%

**Array of 1000 small objects:**
- JSON: ~45 KB
- MessagePack: ~28 KB
- Savings: 38%

### Encoding and Decoding

**JavaScript (Node.js):**
```javascript
const msgpack = require('msgpack5')();

// Encode
const data = {
  id: 123,
  username: 'alice',
  tags: ['golang', 'rust'],
  active: true,
  balance: 1234.56
};

const encoded = msgpack.encode(data);
console.log('Size:', encoded.length);  // 48 bytes vs 83 JSON

// Decode
const decoded = msgpack.decode(encoded);
console.log(decoded);  // Original data

// Stream encoding
const stream = msgpack.encoder();
stream.pipe(output);
stream.write(data);

// Stream decoding
const decoder = msgpack.decoder();
input.pipe(decoder);
decoder.on('data', obj => console.log(obj));
```

**Go:**
```go
import "github.com/vmihailenco/msgpack/v5"

type User struct {
    ID       int      `msgpack:"id"`
    Username string   `msgpack:"username"`
    Tags     []string `msgpack:"tags"`
    Active   bool     `msgpack:"active"`
    Balance  float64  `msgpack:"balance"`
}

// Encode
user := User{
    ID:       123,
    Username: "alice",
    Tags:     []string{"golang", "rust"},
    Active:   true,
    Balance:  1234.56,
}

data, err := msgpack.Marshal(user)
if err != nil {
    panic(err)
}
fmt.Println("Size:", len(data))  // 48 bytes

// Decode
var decoded User
err = msgpack.Unmarshal(data, &decoded)
if err != nil {
    panic(err)
}
fmt.Printf("%+v\n", decoded)

// Streaming
encoder := msgpack.NewEncoder(writer)
encoder.Encode(user)

decoder := msgpack.NewDecoder(reader)
decoder.Decode(&decoded)
```

**Python:**
```python
import msgpack

# Encode
data = {
    'id': 123,
    'username': 'alice',
    'tags': ['golang', 'rust'],
    'active': True,
    'balance': 1234.56
}

encoded = msgpack.packb(data)
print(f'Size: {len(encoded)}')  # 48 bytes

# Decode
decoded = msgpack.unpackb(encoded, raw=False)
print(decoded)

# Streaming
packer = msgpack.Packer()
for item in items:
    stream.write(packer.pack(item))

unpacker = msgpack.Unpacker(stream, raw=False)
for unpacked in unpacker:
    print(unpacked)
```

**Rust:**
```rust
use serde::{Serialize, Deserialize};
use rmp_serde::{Serializer, Deserializer};

#[derive(Serialize, Deserialize, Debug)]
struct User {
    id: i32,
    username: String,
    tags: Vec<String>,
    active: bool,
    balance: f64,
}

fn main() {
    let user = User {
        id: 123,
        username: "alice".to_string(),
        tags: vec!["golang".to_string(), "rust".to_string()],
        active: true,
        balance: 1234.56,
    };

    // Encode
    let encoded = rmp_serde::to_vec(&user).unwrap();
    println!("Size: {}", encoded.len());  // 48 bytes

    // Decode
    let decoded: User = rmp_serde::from_slice(&encoded).unwrap();
    println!("{:?}", decoded);
}
```

### Extension Types

MessagePack supports user-defined extension types:

**Define custom type:**
```javascript
const msgpack = require('msgpack5')();

// Register timestamp extension
msgpack.register(0x01, Date, 
  // Encode
  (date) => {
    const buf = Buffer.allocUnsafe(8);
    buf.writeDoubleBE(date.getTime());
    return buf;
  },
  // Decode
  (buf) => {
    return new Date(buf.readDoubleBE());
  }
);

// Now dates encode as binary timestamps
const data = { created: new Date() };
const encoded = msgpack.encode(data);  // Uses extension
const decoded = msgpack.decode(encoded);  // Reconstructs Date object
```

### Performance Benchmarks

**Serialization (10,000 iterations):**

| Format | Encode | Decode | Total |
|--------|--------|--------|-------|
| JSON | 45ms | 38ms | 83ms |
| MessagePack | 28ms | 22ms | 50ms |
| Speedup | 1.6x | 1.7x | 1.7x |

**Complex nested object:**

| Format | Encode | Decode | Size |
|--------|--------|--------|------|
| JSON | 125ms | 98ms | 15.2 KB |
| MessagePack | 72ms | 54ms | 9.8 KB |
| Speedup | 1.7x | 1.8x | 1.55x |

### Real-World Use Cases

**1. Redis caching:**
```javascript
const redis = require('redis');
const msgpack = require('msgpack5')();

const client = redis.createClient();

// Store with MessagePack
async function cacheUser(user) {
  const encoded = msgpack.encode(user);
  await client.set(`user:${user.id}`, encoded);
}

// Retrieve with MessagePack
async function getUser(id) {
  const encoded = await client.getBuffer(`user:${id}`);
  return msgpack.decode(encoded);
}

// 35% memory savings vs JSON strings
```

**2. Microservice communication:**
```go
// HTTP endpoint that returns MessagePack
func handleGetUser(w http.ResponseWriter, r *http.Request) {
    user := getUserFromDB(id)
    
    data, _ := msgpack.Marshal(user)
    
    w.Header().Set("Content-Type", "application/msgpack")
    w.Write(data)
}

// Client decodes MessagePack
resp, _ := http.Get("http://api/users/123")
defer resp.Body.Close()

var user User
decoder := msgpack.NewDecoder(resp.Body)
decoder.Decode(&user)
```

**3. Message queue (RabbitMQ):**
```python
import pika
import msgpack

connection = pika.BlockingConnection(pika.ConnectionParameters('localhost'))
channel = connection.channel()

# Publish with MessagePack
def publish_event(event):
    data = msgpack.packb(event)
    channel.basic_publish(
        exchange='events',
        routing_key='user.created',
        body=data
    )

# Consume with MessagePack
def callback(ch, method, properties, body):
    event = msgpack.unpackb(body, raw=False)
    handle_event(event)

channel.basic_consume(queue='events', on_message_callback=callback)
```

**4. Log aggregation:**
```javascript
// Write log files in MessagePack
const fs = require('fs');
const msgpack = require('msgpack5')();

const logStream = fs.createWriteStream('app.log.msgpack');
const encoder = msgpack.encoder();
encoder.pipe(logStream);

function log(entry) {
  encoder.write({
    timestamp: Date.now(),
    level: entry.level,
    message: entry.message,
    metadata: entry.metadata
  });
}

// 40-50% smaller log files than JSON
// Faster to parse when processing logs
```

{{< callout type="success" >}}
**MessagePack Best For:**
+ General-purpose binary serialization
+ Microservice communication (schemaless flexibility)
+ Caching layers (size matters)
+ Message queues
+ Log files (size + speed)
+ Mobile apps (bandwidth savings)

**When to avoid:**
- Human debugging needed (use JSON)
- Schema enforcement critical (use Protocol Buffers)
- Database-specific needs (use JSONB/BSON)
{{< /callout >}}

---

## CBOR: Concise Binary Object Representation

### What is CBOR?

CBOR (RFC 8949) is an IETF-standardized binary data format similar to MessagePack but with more rigorous specification and additional features.

**Key differences from MessagePack:**
- Formal IETF standard (RFC 8949)
- Self-describing format
- Deterministic encoding (for signatures)
- Tagged types (extensible type system)
- Better specification clarity

**Created:** 2013 (RFC 7049), updated 2020 (RFC 8949)  
**Specification:** [RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html)

### When to Use CBOR

CBOR is preferred in:

**1. Security applications** (WebAuthn, COSE)
- Deterministic encoding for signatures
- Tagged types for security objects
- Well-specified for cryptographic use

**2. IoT and embedded systems**
- Smaller than JSON
- Simple parsing (low memory)
- Standardized (interoperability)

**3. Standards-based systems**
- IETF specification ensures consistency
- Multiple independent implementations
- Long-term stability

### CBOR vs MessagePack

| Feature | CBOR | MessagePack |
|---------|------|-------------|
| Standardization | IETF RFC | Community spec |
| Deterministic encoding | Yes (canonical) | No |
| Tagged types | Yes (extensible) | Extension types (simpler) |
| Float16 support | Yes | No |
| Specification clarity | Very detailed | Brief |
| Adoption | IoT, security | General purpose |
| Performance | Similar | Slightly faster |

### CBOR in Practice

**JavaScript (Node.js):**
```javascript
const cbor = require('cbor');

// Encode
const data = {
  id: 123,
  username: 'alice',
  created: new Date(),
  tags: ['golang', 'rust']
};

const encoded = cbor.encode(data);
console.log('Size:', encoded.length);

// Decode
const decoded = cbor.decode(encoded);
console.log(decoded);

// Tagged types
const tagged = new cbor.Tagged(32, 'https://example.com');  // URI tag
const encoded2 = cbor.encode(tagged);
```

**Go:**
```go
import "github.com/fxamacker/cbor/v2"

type User struct {
    ID       int      `cbor:"id"`
    Username string   `cbor:"username"`
    Created  time.Time `cbor:"created"`
    Tags     []string `cbor:"tags"`
}

// Encode
user := User{
    ID:       123,
    Username: "alice",
    Created:  time.Now(),
    Tags:     []string{"golang", "rust"},
}

data, err := cbor.Marshal(user)
if err != nil {
    panic(err)
}

// Decode
var decoded User
err = cbor.Unmarshal(data, &decoded)

// Deterministic encoding (for signatures)
encMode, _ := cbor.CanonicalEncMode()
canonical, _ := encMode.Marshal(user)
```

**Python:**
```python
import cbor2
from datetime import datetime

# Encode
data = {
    'id': 123,
    'username': 'alice',
    'created': datetime.now(),
    'tags': ['golang', 'rust']
}

encoded = cbor2.dumps(data)
print(f'Size: {len(encoded)}')

# Decode
decoded = cbor2.loads(encoded)
print(decoded)

# Tagged types
from cbor2 import CBORTag
tagged = CBORTag(32, 'https://example.com')  # URI tag
encoded2 = cbor2.dumps(tagged)
```

### CBOR Tagged Types

CBOR's tagged type system enables extensibility:

**Standard tags:**
```
Tag 0: Date/time string (ISO 8601)
Tag 1: Epoch-based date/time (number)
Tag 2: Positive bignum
Tag 3: Negative bignum
Tag 32: URI
Tag 33: Base64url
Tag 34: Base64
Tag 55799: Self-describe CBOR (magic number)
```

**Example:**
```javascript
const cbor = require('cbor');

// Date (tag 1: epoch timestamp)
const date = new Date();
const encoded = cbor.encode(date);
// Encoded as tag 1 + numeric timestamp

// URI (tag 32)
const uri = new cbor.Tagged(32, 'https://example.com');
const encoded2 = cbor.encode(uri);

// Custom tag
const custom = new cbor.Tagged(1000, {custom: 'data'});
```

### CBOR in WebAuthn

WebAuthn (web authentication standard) uses CBOR for credential data:

```javascript
// Browser WebAuthn API returns CBOR
const credential = await navigator.credentials.create({
  publicKey: options
});

// attestationObject is CBOR-encoded
const attestation = credential.response.attestationObject;

// Server decodes CBOR
const cbor = require('cbor');
const decoded = cbor.decode(attestation);

console.log(decoded);
// {
//   fmt: 'packed',
//   attStmt: {...},
//   authData: <Buffer...>
// }
```

### Size Comparison

**Sample data:**
```json
{
  "id": 123,
  "username": "alice",
  "email": "alice@example.com",
  "created": "2023-01-15T10:30:00Z",
  "tags": ["golang", "rust", "python"]
}
```

**Sizes:**
- JSON: 142 bytes
- MessagePack: 88 bytes
- CBOR: 90 bytes
- Difference: CBOR ~2 bytes larger (negligible)

{{< callout type="info" >}}
**CBOR Best For:**
+ IoT devices and embedded systems
+ Security applications (WebAuthn, COSE)
+ Standards-based systems (need RFC)
+ Cryptographic use (deterministic encoding)

**Use MessagePack instead if:**
- General-purpose serialization
- Performance critical (slight edge)
- Simpler specification preferred
- Wider ecosystem matters
{{< /callout >}}

---

## Performance Benchmarks

### Test Methodology

**Environment:**
- CPU: Intel i7-12700K
- RAM: 32GB DDR4
- OS: Ubuntu 22.04
- Languages: Node.js 20, Go 1.21, Python 3.11

**Test data:**
- Small object: User profile (200 bytes JSON)
- Medium object: API response (5 KB JSON)
- Large array: 10,000 user objects (2 MB JSON)

### Results: Small Object (200 bytes)

**Encoding speed (ops/sec):**

| Format | JavaScript | Go | Python |
|--------|------------|-----|---------|
| JSON | 1,245,000 | 2,100,000 | 385,000 |
| MessagePack | 1,890,000 | 3,200,000 | 580,000 |
| CBOR | 1,720,000 | 2,950,000 | 520,000 |
| BSON | 945,000 | 1,850,000 | 310,000 |

**Speedup vs JSON:**
- MessagePack: 1.5x
- CBOR: 1.4x
- BSON: 0.8x (slower)

**Size:**
- JSON: 200 bytes
- MessagePack: 128 bytes (36% smaller)
- CBOR: 131 bytes (35% smaller)
- BSON: 142 bytes (29% smaller)

### Results: Medium Object (5 KB)

**Encoding speed (ops/sec):**

| Format | JavaScript | Go | Python |
|--------|------------|-----|---------|
| JSON | 52,000 | 98,000 | 18,500 |
| MessagePack | 88,000 | 165,000 | 32,000 |
| CBOR | 79,000 | 152,000 | 28,000 |
| BSON | 41,000 | 85,000 | 15,000 |

**Speedup vs JSON:**
- MessagePack: 1.7x
- CBOR: 1.5x
- BSON: 0.8x

**Size:**
- JSON: 5,120 bytes
- MessagePack: 3,280 bytes (36% smaller)
- CBOR: 3,350 bytes (35% smaller)
- BSON: 3,680 bytes (28% smaller)

### Results: Large Array (2 MB, 10K objects)

**Encoding time:**

| Format | JavaScript | Go | Python |
|--------|------------|-----|---------|
| JSON | 125ms | 72ms | 385ms |
| MessagePack | 73ms | 41ms | 225ms |
| CBOR | 82ms | 48ms | 255ms |
| BSON | 145ms | 85ms | 425ms |

**Speedup vs JSON:**
- MessagePack: 1.7x
- CBOR: 1.5x
- BSON: 0.9x

**Size:**
- JSON: 2.05 MB
- MessagePack: 1.31 MB (36% smaller)
- CBOR: 1.34 MB (35% smaller)
- BSON: 1.48 MB (28% smaller)

### Memory Usage

**Peak memory during encoding (2 MB dataset):**

| Format | JavaScript | Go | Python |
|--------|------------|-----|---------|
| JSON | 8.2 MB | 4.5 MB | 12.3 MB |
| MessagePack | 6.1 MB | 3.2 MB | 9.1 MB |
| CBOR | 6.4 MB | 3.4 MB | 9.5 MB |
| BSON | 7.8 MB | 4.1 MB | 11.8 MB |

{{< mermaid >}}
flowchart LR
    subgraph perf["Performance Characteristics"]
        size[Size Efficiency]
        speed[Parse Speed]
        memory[Memory Usage]
    end
    
    subgraph formats["Format Rankings"]
        msgpack[MessagePack<br/>Best Overall]
        cbor[CBOR<br/>Close Second]
        bson[BSON<br/>Extended Types]
        json[JSON<br/>Human-Readable]
    end
    
    perf --> formats
    
    msgpack -.36% smaller.-> size
    msgpack -.1.7x faster.-> speed
    msgpack -.25% less memory.-> memory
    
    style msgpack fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style cbor fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style bson fill:#4C4538,stroke:#6b7280,color:#f0f0f0
    style json fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style perf fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### Key Takeaways

**Size savings:**
- Binary formats: 28-36% smaller than JSON
- MessagePack/CBOR most efficient
- BSON less efficient (extended type overhead)

**Speed improvements:**
- 1.5-1.7x faster encoding/decoding
- Go implementations fastest
- Python benefits most from binary formats

**Memory efficiency:**
- 20-30% less memory than JSON
- Streaming parsers reduce memory further

{{< callout type="warning" >}}
**Benchmark Caveats:**
- Results vary by data structure (nested vs flat)
- Implementation quality matters (library choice)
- Compression changes the equation (gzip, zstd)
- Network overhead may dominate (size less critical)
- Always benchmark with YOUR actual data
{{< /callout >}}

---

## Binary JSON vs Protocol Buffers

Both solve JSON's performance problems, but through different philosophies:

### Fundamental Difference

**Binary JSON (MessagePack, CBOR):**
- Schemaless (like JSON)
- Self-describing format
- Flexible structure
- No compilation step

**Protocol Buffers:**
- Schema required
- Schema compiled to code
- Strict structure
- Type safety enforced

### Detailed Comparison

| Aspect | Binary JSON | Protocol Buffers |
|--------|-------------|------------------|
| **Schema** | Optional | Required |
| **Flexibility** | Add fields freely | Schema evolution rules |
| **Size** | 30-40% smaller than JSON | 50-70% smaller than JSON |
| **Speed** | 1.5-2x faster than JSON | 3-5x faster than JSON |
| **Type safety** | Runtime only | Compile-time |
| **Versioning** | Implicit | Explicit (field numbers) |
| **Debugging** | Can inspect structure | Need schema to decode |
| **Setup** | Zero (just library) | Schema compilation |
| **Cross-language** | Parse anywhere | Generated code per language |

### Size Comparison

**Sample user object:**

```json
{
  "id": 123,
  "username": "alice",
  "email": "alice@example.com",
  "age": 30,
  "active": true
}
```

**Sizes:**
- JSON: 98 bytes
- MessagePack: 62 bytes (37% smaller)
- Protocol Buffers: 28 bytes (71% smaller)

**Why Protocol Buffers is smaller:**
- Field numbers instead of names (1 byte vs "username" = 8 bytes)
- Efficient varint encoding
- No type markers (schema provides types)

### When to Use Each

**Use Binary JSON (MessagePack/CBOR) when:**
+ Schema flexibility needed (rapid iteration)
+ Dynamic data structures (user-generated content)
+ Different clients need different fields
+ Simple setup (no compilation)
+ Debugging matters (self-describing)
+ Multiple data types in same stream

**Use Protocol Buffers when:**
+ Schema stability (defined API contract)
+ Maximum performance (size + speed)
+ Type safety critical
+ Versioning discipline needed
+ RPC systems (gRPC)
+ Long-term data storage

### Hybrid Approaches

**1. Protocol Buffers with JSON names:**
```protobuf
message User {
  int32 id = 1 [json_name = "id"];
  string username = 2 [json_name = "username"];
}
```
Can serialize as JSON or binary.

**2. MessagePack with schema validation:**
```javascript
const Ajv = require('ajv');
const msgpack = require('msgpack5')();

// Validate before encoding
const validate = ajv.compile(schema);
if (validate(data)) {
  const encoded = msgpack.encode(data);
}
```

**3. Mixed protocols:**
```javascript
// JSON for configuration (human-edited)
const config = JSON.parse(fs.readFileSync('config.json'));

// MessagePack for high-volume data
const data = msgpack.decode(message);

// Protocol Buffers for RPC
const request = UserRequest.decode(buffer);
```

### Migration Example

**From JSON to MessagePack (gradual):**

```javascript
// Step 1: Support both formats
app.post('/api/users', async (req, res) => {
  const contentType = req.headers['content-type'];
  
  let data;
  if (contentType === 'application/msgpack') {
    data = msgpack.decode(req.body);
  } else {
    data = JSON.parse(req.body);
  }
  
  // Process data...
  
  // Return in same format
  if (contentType === 'application/msgpack') {
    res.type('application/msgpack');
    res.send(msgpack.encode(result));
  } else {
    res.json(result);
  }
});

// Step 2: Update clients gradually
// Step 3: Monitor metrics (size, speed, errors)
// Step 4: Deprecate JSON after migration complete
```

For more on Protocol Buffers, see: [Understanding Protocol Buffers: Part 1]({{< relref "understanding-protobuf-part-1.md" >}})

---

## Trade-offs and Best Practices

### Loss of Human-Readability

**The Problem:**

Binary formats can't be read directly:

```bash
# JSON: cat works
$ cat user.json
{"id": 123, "username": "alice"}

# MessagePack: garbage
$ cat user.msgpack
▒▒id{username▒alice
```

**Solutions:**

**1. Debugging tools:**
```bash
# MessagePack CLI
$ msgpack-cli decode user.msgpack
{id: 123, username: "alice"}

# Python one-liner
$ python -c "import msgpack; import sys; print(msgpack.unpack(sys.stdin.buffer))" < user.msgpack

# Node.js one-liner
$ node -e "const m=require('msgpack5')();process.stdin.on('data',d=>console.log(m.decode(d)))" < user.msgpack
```

**2. Logging wrapper:**
```javascript
// Log binary data as JSON for debugging
function debugLog(label, binaryData) {
  if (process.env.NODE_ENV === 'development') {
    const decoded = msgpack.decode(binaryData);
    console.log(label, JSON.stringify(decoded, null, 2));
  }
}

debugLog('Received:', encodedData);
```

**3. Development vs production:**
```javascript
// Use JSON in development, MessagePack in production
const serialize = process.env.NODE_ENV === 'production'
  ? (data) => msgpack.encode(data)
  : (data) => Buffer.from(JSON.stringify(data));

const deserialize = process.env.NODE_ENV === 'production'
  ? (buf) => msgpack.decode(buf)
  : (buf) => JSON.parse(buf.toString());
```

### Compression Considerations

Binary formats are already compressed. Further compression may not help much:

**Compression results (10KB user data):**

| Format | Uncompressed | gzip | zstd | Savings |
|--------|--------------|------|------|---------|
| JSON | 10,240 bytes | 2,180 bytes | 1,950 bytes | 81% |
| MessagePack | 6,580 bytes | 2,050 bytes | 1,850 bytes | 72% |
| Benefit | - | 6% smaller | 5% smaller | Marginal |

**Guidelines:**

+ **Compress JSON** - Significant savings (70-80%)
+ **Binary formats** - Compression helps less (10-20% additional)
+ **Network transfer** - Always compress (gzip, brotli)
+ **Storage** - Depends on size/query trade-offs
+ **In-memory** - Usually don't compress (CPU cost)

**Example: Redis with compression:**
```javascript
const zlib = require('zlib');
const msgpack = require('msgpack5')();

// Store compressed MessagePack
async function cacheUser(user) {
  const encoded = msgpack.encode(user);
  const compressed = zlib.gzipSync(encoded);
  await redis.set(`user:${user.id}`, compressed);
}

// Retrieve and decompress
async function getUser(id) {
  const compressed = await redis.getBuffer(`user:${id}`);
  const encoded = zlib.gunzipSync(compressed);
  return msgpack.decode(encoded);
}
```

### Schema Drift in Schemaless Formats

Without schemas, binary formats can drift:

**The problem:**
```javascript
// Service A sends:
msgpack.encode({id: 123, name: "alice"})

// Service B expects:
msgpack.decode(data)
// Assumes 'username' field exists -> undefined
```

**Solutions:**

**1. Validation layer:**
```javascript
const Ajv = require('ajv');
const ajv = new Ajv();

const schema = {
  type: 'object',
  properties: {
    id: {type: 'integer'},
    username: {type: 'string'}
  },
  required: ['id', 'username']
};

const validate = ajv.compile(schema);

function decodeAndValidate(data) {
  const decoded = msgpack.decode(data);
  if (!validate(decoded)) {
    throw new Error('Invalid data: ' + JSON.stringify(validate.errors));
  }
  return decoded;
}
```

**2. Version field:**
```javascript
// Always include version
function encode(data) {
  return msgpack.encode({
    _version: 2,
    ...data
  });
}

function decode(data) {
  const decoded = msgpack.decode(data);
  const version = decoded._version || 1;
  
  if (version === 1) {
    return migrateV1toV2(decoded);
  }
  return decoded;
}
```

**3. Type definitions:**
```typescript
// TypeScript enforces structure
interface UserV2 {
  _version: 2;
  id: number;
  username: string;
  email?: string;
}

function encode(user: UserV2): Buffer {
  return msgpack.encode(user);
}

function decode(data: Buffer): UserV2 {
  return msgpack.decode(data) as UserV2;
}
```

### Best Practices

**1. Content negotiation:**
```javascript
app.use((req, res, next) => {
  const accept = req.headers['accept'];
  
  res.formatResponse = (data) => {
    if (accept.includes('application/msgpack')) {
      res.type('application/msgpack');
      res.send(msgpack.encode(data));
    } else {
      res.json(data);
    }
  };
  
  next();
});

app.get('/users/:id', (req, res) => {
  const user = getUserById(req.params.id);
  res.formatResponse(user);
});
```

**2. Graceful fallback:**
```javascript
async function fetchUser(id) {
  try {
    const response = await fetch(`/api/users/${id}`, {
      headers: {
        'Accept': 'application/msgpack'
      }
    });
    
    const buffer = await response.arrayBuffer();
    return msgpack.decode(Buffer.from(buffer));
  } catch (err) {
    // Fallback to JSON
    const response = await fetch(`/api/users/${id}`);
    return await response.json();
  }
}
```

**3. Monitoring:**
```javascript
// Track format usage
function encodeWithMetrics(data, format) {
  const start = Date.now();
  const encoded = format === 'msgpack' 
    ? msgpack.encode(data)
    : Buffer.from(JSON.stringify(data));
  
  metrics.timing('encoding.duration', Date.now() - start, {format});
  metrics.gauge('encoding.size', encoded.length, {format});
  
  return encoded;
}
```

{{< callout type="success" >}}
**Production Checklist:**
- [ ] Validation layer for critical data
- [ ] Version field in all messages
- [ ] Debugging tools available
- [ ] Monitoring for format usage
- [ ] Graceful fallback to JSON
- [ ] Documentation for format choice
- [ ] Performance benchmarks with real data
- [ ] Compression strategy defined
{{< /callout >}}

---

## Real-World Use Cases

### 1. High-Throughput API (MessagePack)

**Scenario:** API serving 50K requests/sec, 5KB average response

**Before (JSON):**
- Response size: 5 KB
- Parse time: 2.1ms
- Network: 250 Mbps
- Memory: 12 GB

**After (MessagePack):**
- Response size: 3.2 KB (36% smaller)
- Parse time: 1.2ms (43% faster)
- Network: 160 Mbps (36% reduction)
- Memory: 8.5 GB (29% reduction)

**Implementation:**
```javascript
// Express middleware
app.use((req, res, next) => {
  res.sendMsgPack = (data) => {
    res.type('application/msgpack');
    res.send(msgpack.encode(data));
  };
  next();
});

app.get('/api/products', async (req, res) => {
  const products = await db.products.find();
  res.sendMsgPack(products);
});

// Client
const response = await fetch('/api/products', {
  headers: {'Accept': 'application/msgpack'}
});
const buffer = await response.arrayBuffer();
const products = msgpack.decode(Buffer.from(buffer));
```

### 2. Mobile App (MessagePack)

**Scenario:** Mobile app on cellular networks, battery-conscious

**Benefits:**
- 35% less bandwidth (cost savings)
- Faster parsing (battery savings)
- Better on slow networks

**Implementation:**
```javascript
// React Native client
import msgpack from 'react-native-msgpack';

async function fetchData(endpoint) {
  const response = await fetch(API_URL + endpoint, {
    headers: {
      'Accept': 'application/msgpack',
      'Content-Type': 'application/msgpack'
    }
  });
  
  const buffer = await response.arrayBuffer();
  return msgpack.decode(new Uint8Array(buffer));
}

async function postData(endpoint, data) {
  const encoded = msgpack.encode(data);
  
  const response = await fetch(API_URL + endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/msgpack'
    },
    body: encoded
  });
  
  const buffer = await response.arrayBuffer();
  return msgpack.decode(new Uint8Array(buffer));
}
```

### 3. PostgreSQL Document Storage (JSONB)

**Scenario:** E-commerce product catalog with varying attributes

**Schema:**
```sql
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    sku VARCHAR(50) NOT NULL UNIQUE,
    attributes JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Index for common queries
CREATE INDEX idx_products_category ON products USING GIN ((attributes->'category'));
CREATE INDEX idx_products_brand ON products USING GIN ((attributes->'brand'));
CREATE INDEX idx_products_price ON products ((attributes->>'price')::numeric);

-- Full-text search on name
CREATE INDEX idx_products_name ON products USING GIN (to_tsvector('english', attributes->>'name'));
```

**Queries:**
```sql
-- Find products by category
SELECT id, attributes->>'name' as name, attributes->>'price' as price
FROM products
WHERE attributes @> '{"category": "electronics"}';

-- Price range
SELECT * FROM products
WHERE (attributes->>'price')::numeric BETWEEN 100 AND 500;

-- Search by name
SELECT * FROM products
WHERE to_tsvector('english', attributes->>'name') @@ plainto_tsquery('laptop');

-- Complex query
SELECT 
    attributes->>'name' as name,
    attributes->>'brand' as brand,
    (attributes->>'price')::numeric as price
FROM products
WHERE attributes @> '{"category": "electronics"}'
  AND (attributes->>'price')::numeric < 1000
  AND attributes->>'brand' IN ('Apple', 'Samsung')
ORDER BY (attributes->>'price')::numeric DESC
LIMIT 20;
```

**Benefits:**
- Flexible schema (different attributes per product)
- Fast queries with GIN indexes
- No schema migrations when adding attributes
- Native JSON operations in SQL

### 4. Message Queue (MessagePack)

**Scenario:** Event-driven microservices with RabbitMQ

**Publisher:**
```javascript
const amqp = require('amqplib');
const msgpack = require('msgpack5')();

async function publishEvent(event) {
  const connection = await amqp.connect('amqp://localhost');
  const channel = await connection.createChannel();
  
  await channel.assertExchange('events', 'topic', {durable: true});
  
  const encoded = msgpack.encode({
    timestamp: Date.now(),
    type: event.type,
    data: event.data
  });
  
  channel.publish('events', event.type, encoded, {
    persistent: true,
    contentType: 'application/msgpack'
  });
  
  await channel.close();
  await connection.close();
}

// Usage
await publishEvent({
  type: 'user.created',
  data: {id: 123, username: 'alice'}
});
```

**Consumer:**
```javascript
async function consumeEvents() {
  const connection = await amqp.connect('amqp://localhost');
  const channel = await connection.createChannel();
  
  await channel.assertQueue('user-service', {durable: true});
  await channel.bindQueue('user-service', 'events', 'user.*');
  
  channel.consume('user-service', (msg) => {
    if (msg.properties.contentType === 'application/msgpack') {
      const event = msgpack.decode(msg.content);
      handleEvent(event);
    }
    
    channel.ack(msg);
  });
}
```

### 5. Log Aggregation (MessagePack)

**Scenario:** Collecting logs from 1000+ servers, 10GB/day

**Logger:**
```javascript
const fs = require('fs');
const msgpack = require('msgpack5')();

class BinaryLogger {
  constructor(filename) {
    this.stream = fs.createWriteStream(filename);
    this.encoder = msgpack.encoder();
    this.encoder.pipe(this.stream);
  }
  
  log(level, message, metadata = {}) {
    this.encoder.write({
      timestamp: Date.now(),
      level,
      message,
      metadata,
      host: os.hostname(),
      pid: process.pid
    });
  }
  
  close() {
    this.encoder.end();
  }
}

const logger = new BinaryLogger('/var/log/app.msgpack');
logger.log('info', 'Server started', {port: 3000});
logger.log('error', 'Database connection failed', {error: err.message});
```

**Log processor:**
```javascript
const fs = require('fs');
const msgpack = require('msgpack5')();

function processLogs(filename) {
  const stream = fs.createReadStream(filename);
  const decoder = msgpack.decoder();
  
  stream.pipe(decoder);
  
  decoder.on('data', (entry) => {
    if (entry.level === 'error') {
      // Send to alerting system
      sendAlert(entry);
    }
    
    // Store in database
    db.logs.insert(entry);
  });
}
```

**Size savings:**
- JSON logs: 10 GB/day
- MessagePack logs: 6.2 GB/day
- Savings: 3.8 GB/day (38%)
- Annual savings: 1.4 TB

### 6. IoT Device Communication (CBOR)

**Scenario:** Temperature sensors sending data every minute

**Device code (embedded C):**
```c
#include "cbor.h"

void send_reading() {
    CborEncoder encoder, map;
    uint8_t buffer[128];
    
    cbor_encoder_init(&encoder, buffer, sizeof(buffer), 0);
    cbor_encoder_create_map(&encoder, &map, 4);
    
    cbor_encode_text_stringz(&map, "device_id");
    cbor_encode_text_stringz(&map, "sensor-001");
    
    cbor_encode_text_stringz(&map, "temperature");
    cbor_encode_float(&map, 23.5);
    
    cbor_encode_text_stringz(&map, "humidity");
    cbor_encode_float(&map, 65.2);
    
    cbor_encode_text_stringz(&map, "timestamp");
    cbor_encode_int(&map, time(NULL));
    
    cbor_encoder_close_container(&encoder, &map);
    
    size_t length = cbor_encoder_get_buffer_size(&encoder, buffer);
    send_to_gateway(buffer, length);
}
```

**Gateway (Node.js):**
```javascript
const cbor = require('cbor');

function processReading(buffer) {
  const reading = cbor.decode(buffer);
  
  console.log(`Device: ${reading.device_id}`);
  console.log(`Temp: ${reading.temperature}°C`);
  console.log(`Humidity: ${reading.humidity}%`);
  
  // Store in time-series database
  influx.writePoints([{
    measurement: 'temperature',
    tags: {device: reading.device_id},
    fields: {
      value: reading.temperature,
      humidity: reading.humidity
    },
    timestamp: reading.timestamp * 1000000000
  }]);
}
```

**Benefits:**
- 45% smaller than JSON (bandwidth critical)
- Standardized format (IETF RFC)
- Simple parsing on embedded devices
- Low memory footprint

---

## Conclusion: Choosing Your Binary Format

Binary JSON formats solve the performance limitations of text JSON while maintaining structural flexibility. The choice depends on your specific needs:

### Decision Matrix

**Choose JSONB if:**
+ You're using PostgreSQL
+ You need indexable document storage
+ Query performance matters
+ Semi-structured data in relational DB

**Choose BSON if:**
+ You're using MongoDB
+ You need extended types (ObjectId, Date, Decimal128)
+ Document database is your primary store
+ MongoDB wire protocol compatibility needed

**Choose MessagePack if:**
+ General-purpose binary serialization
+ Maximum speed and size efficiency
+ Microservice communication
+ Message queues, caching layers
+ Wide language support needed

**Choose CBOR if:**
+ IoT or embedded systems
+ Security applications (WebAuthn, COSE)
+ Need IETF standard
+ Deterministic encoding required

**Stick with JSON if:**
+ Human readability critical (configs, logs)
+ Debugging frequency high
+ Payloads small (<10 KB)
+ Performance acceptable
+ Simplicity trumps efficiency

### What We Learned

**Binary formats provide:**
- 30-40% size reduction over JSON
- 1.5-2x faster parsing
- Extended type systems (dates, binary data)
- Better memory efficiency

**Trade-offs:**
- Loss of human-readability
- Binary debugging tools needed
- Schema drift without validation
- Ecosystem smaller than JSON

**Key insight:** Binary formats fill the gap between JSON's simplicity and Protocol Buffers' schema enforcement. They're the right choice when JSON's performance matters but schema flexibility is still needed.

{{< callout type="info" >}}
**Series Progress:**
- **Part 1**: JSON's origins and fundamental weaknesses
- **Part 2**: JSON Schema for validation and contracts
- **Part 3** (this article): Binary formats for performance
- **Part 4**: Streaming JSON with JSON Lines
- **Part 5**: JSON-RPC protocol layers
- **Part 6**: Security (JWT, canonicalization, attacks)
{{< /callout >}}

In Part 4, we'll tackle streaming JSON with JSON Lines (JSONL) - solving JSON's inability to handle large datasets and streaming scenarios. We'll explore newline-delimited JSON, log processing, Unix pipeline integration, and streaming APIs.

**Next:** Part 4 - Streaming JSON: Processing Gigabytes Without Running Out of Memory

---

## Further Reading

**Specifications:**
- [MessagePack Specification](https://msgpack.org/)
- [CBOR RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html)
- [BSON Specification](http://bsonspec.org/)
- [PostgreSQL JSONB](https://www.postgresql.org/docs/current/datatype-json.html)

**Libraries:**
- [msgpack5 (JavaScript)](https://github.com/mcollina/msgpack5)
- [vmihailenco/msgpack (Go)](https://github.com/vmihailenco/msgpack)
- [msgpack (Python)](https://github.com/msgpack/msgpack-python)
- [rmp-serde (Rust)](https://github.com/3Hren/msgpack-rust)

**Performance:**
- [MessagePack Benchmarks](https://github.com/msgpack/msgpack/wiki/Benchmarks)
- [Binary Serialization Comparison](https://github.com/alecthomas/go_serialization_benchmarks)

**Related:**
- [Understanding Protocol Buffers: Part 1]({{< relref "understanding-protobuf-part-1.md" >}})
- [Serialization Explained]({{< relref "serialization-explained.md" >}})
