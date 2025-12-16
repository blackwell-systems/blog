---
title: "You Don't Know JSON: Part 3 - Binary JSON in Databases"
date: 2025-12-15
draft: false
series: ["you-dont-know-json"]
seriesOrder: 3
tags: ["json", "jsonb", "bson", "binary-serialization", "performance", "optimization", "postgresql", "mongodb", "data-formats", "database-optimization", "parsing", "encoding"]
categories: ["fundamentals", "programming", "performance"]
description: "Master binary JSON in databases: PostgreSQL's JSONB and MongoDB's BSON. Learn how databases optimize JSON storage with binary formats for faster queries and efficient indexing."
summary: "Database-managed binary JSON formats solve storage and query performance problems. JSONB enables fast PostgreSQL queries with indexing, while BSON adds extended types for MongoDB. Learn when databases beat text JSON."
---

In [Part 1]({{< relref "you-dont-know-json-part-1-origins.md" >}}), we explored JSON's triumph through simplicity. In [Part 2]({{< relref "you-dont-know-json-part-2-json-schema.md" >}}), we added validation with JSON Schema. Now we tackle JSON's performance tax when storing millions of documents: **database-managed binary formats**.

JSON's human-readability is both its greatest strength and its Achilles heel. Every byte is text. Field names repeat in every object. Numbers are stored as strings. Parsing requires scanning every character.

For configuration files and API responses under 100KB, this is fine. But when storing millions of user records, events, or documents - the text format becomes expensive for databases.

{{< callout type="info" >}}
**What XML Had:** No binary format (1998-2010)

**XML's approach:** XML was purely textual. Binary solutions like WBXML (Wireless Binary XML) were proprietary, complex, and poorly supported. Microsoft's .NET Binary XML and ITU-T's Fast Infoset existed but never achieved widespread adoption.

```xml
<!-- XML: Always text, even for large datasets -->
<users>
  <user><id>1</id><name>Alice</name></user>
  <user><id>2</id><name>Bob</name></user>
  <!-- Repeated structure and field names for millions of records -->
</users>
```

**Benefit:** Human readable, universal parser support  
**Cost:** Massive storage overhead, slow parsing at scale, no database optimization

**JSON's approach:** Database-specific binary formats (JSONB, BSON) - modular solutions

**Architecture shift:** Text-only → Binary storage with text compatibility, Verbose repetition → Decomposed efficiency, Parser-only → Database-integrated
{{< /callout >}}

Database binary JSON formats solve this at the storage layer - maintaining JSON's structure and flexibility while dramatically improving query speed and storage efficiency.

---

## Running Example: Storing 10 Million Users

Our User API from [Part 1]({{< relref "you-dont-know-json-part-1-origins.md" >}}#running-example-building-a-user-api) now has validation from [Part 2]({{< relref "you-dont-know-json-part-2-json-schema.md" >}}). Next challenge: **storing 10 million users efficiently in a database**.

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

**Problems at scale in databases:**
- Field names repeated 10 million times in storage
- Text parsing required on every query
- No indexing into JSON structure without parsing
- Inefficient storage and retrieval for database operations

Database binary JSON formats solve this at the storage layer. Let's see the impact.

---

## The Text Format Tax in Databases

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

**What happens during database queries:**
1. Read entire string character by character from disk
2. Decode UTF-8 sequences
3. Identify delimiters (`{`, `}`, `:`, `,`)
4. Parse string values (allocate memory, copy)
5. Convert number strings to numeric types
6. Handle escape sequences
7. Build object structure in memory for every query

**The database-specific costs:**
- Field names stored repeatedly (`"id"`, `"username"`, `"email"` in every record)
- Numbers stored as text (`123456789` = 9 bytes vs 4 bytes as integer)
- Date stored as 24-character string vs 8-byte timestamp
- Parse overhead: string scanning, allocation for every query
- No indexing without parsing entire document
- JOIN operations require reparsing for every row

### When Does This Matter in Databases?

**Scenarios where text JSON hurts databases:**

+ **Large table queries** - Parsing JSON columns in millions of rows
+ **Complex WHERE clauses** - Filtering on JSON fields requires parsing
+ **Aggregation operations** - GROUP BY, SUM on JSON fields
+ **JOIN operations** - Joining on JSON fields
+ **Index maintenance** - Extracting values for indexing
+ **Backup/restore operations** - Processing entire datasets
+ **Analytics queries** - OLAP workloads on JSON data

{{< callout type="info" >}}
**Database Rule of Thumb:** Text JSON columns are fine for rarely-queried metadata. Consider binary formats when you have:
- Frequent queries on JSON fields
- Large datasets (>100K rows with JSON)
- Complex aggregations or analytics
- Need to index JSON content
- Performance-critical applications
{{< /callout >}}

{{< mermaid >}}
timeline
    title Database Binary JSON Evolution
    2009 : MongoDB BSON
         : Binary JSON with extended types
    2012 : PostgreSQL JSON
         : Text JSON column support
    2014 : PostgreSQL JSONB
         : Binary JSON with indexing
    2015 : MySQL JSON
         : Binary JSON column type
    2016 : SQL Server JSON
         : JSON functions and indexing
    2020+ : Wide Adoption
         : Binary JSON in production
{{< /mermaid >}}

---

## The Database Binary JSON Landscape

Database binary JSON formats share common goals but differ in implementation and focus.

### Common Database Goals

**1. Smaller Storage**
- Remove repeated field names (or compress them)
- Efficient number encoding (binary, not text)
- No syntax overhead stored on disk

**2. Faster Queries**
- Skip string parsing on queries (pre-decomposed data)
- Direct field access via offsets
- Type information embedded (no string-to-type conversion)

**3. Indexable Structure**
- Extract fields without full document parsing
- Support complex index types (GIN, GiST)
- Enable fast WHERE clauses on JSON content

### The Database Formats

| Format | Database | Primary Use | Indexable | Schema Required |
|--------|----------|-------------|-----------|-----------------|
| **JSONB** | PostgreSQL | Relational + document hybrid | Yes (GIN/GiST) | No |
| **BSON** | MongoDB | Document database storage | Yes (compound) | No |
| **JSON** | MySQL 5.7+ | Binary JSON columns | Yes (virtual columns) | No |
| **JSON** | SQL Server | JSON functions/indexing | Yes (computed columns) | No |

{{< callout type="warning" >}}
**Key Distinction:** Database binary JSON is **storage-optimized** - designed for frequent queries, indexing, and database operations. API/network binary formats (covered in Part 4) optimize for serialization speed and bandwidth.
{{< /callout >}}

{{< mermaid >}}
flowchart TB
    start{Need JSON in database?}
    
    start -->|Relational DB| sql{Which SQL DB?}
    start -->|Document DB| document{Which document DB?}
    start -->|Search| search[Elasticsearch JSON]
    
    sql -->|PostgreSQL| jsonb[JSONB]
    sql -->|MySQL 5.7+| mysql_json[MySQL JSON]
    sql -->|SQL Server| sqlserver_json[SQL Server JSON]
    sql -->|Others| text_json[TEXT column + JSON functions]
    
    document -->|MongoDB| bson[BSON]
    document -->|CouchDB| couchdb[CouchDB JSON]
    document -->|RavenDB| ravendb[RavenDB JSON]
    
    style jsonb fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style bson fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style mysql_json fill:#4A3C3A,stroke:#6b7280,color:#f0f0f0
    style sqlserver_json fill:#4A3C3A,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

---

## PostgreSQL JSONB: Indexable Documents

### What is JSONB?

JSONB is PostgreSQL's **binary JSON storage format**. Unlike the `JSON` column type (which stores text), JSONB decomposes JSON into a binary structure optimized for database operations.

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

BSON (Binary JSON) is MongoDB's data storage and wire protocol format. Created in 2009, it extends JSON with additional types and efficient binary encoding optimized for database operations.

**Key features:**
- Extended type system beyond JSON
- Length-prefixed elements (traversable without parsing)
- Efficient binary encoding
- Native in MongoDB drivers

### Extended Type System

BSON adds types JSON lacks, crucial for database operations:

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

| BSON Type | JSON Equivalent | Binary Size | Database Benefits |
|-----------|-----------------|-------------|-------------------|
| Double | number | 8 bytes | IEEE 754 float, indexable |
| String | string | 4 + length + 1 | UTF-8, length-prefixed |
| Object | object | Variable | Embedded documents |
| Array | array | Variable | Indexed arrays |
| Binary | (Base64 string) | 4 + length | No encoding overhead |
| ObjectId | (string) | 12 bytes | Unique, sortable, indexed |
| Boolean | boolean | 1 byte | Efficient storage |
| Date | (string) | 8 bytes | Native date queries |
| Null | null | 0 bytes | Efficient null handling |
| Regex | (no equivalent) | Variable | Pattern matching |
| Int32 | number | 4 bytes | Precise integers |
| Timestamp | (no equivalent) | 8 bytes | Replication ordering |
| Int64 | number | 8 bytes | Large integers |
| Decimal128 | (string) | 16 bytes | Financial precision |

### ObjectId Deep Dive

ObjectId is a 12-byte identifier designed for distributed database systems:

**Structure:**
```
| 4-byte timestamp | 5-byte random | 3-byte counter |
```

**Database properties:**
- Globally unique (no coordination needed)
- Sortable by creation time (natural ordering)
- Embedded timestamp (no separate created_at needed)
- Efficient indexing (12 bytes vs 36-byte UUID)

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

BSON's native date type solves JSON's date problem in databases:

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

BSON avoids Base64 overhead for binary data in databases:

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

## Choosing Database Binary JSON

Database binary JSON formats excel at different use cases:

### PostgreSQL JSONB When...

**Choose JSONB if you need:**
- Relational database with document flexibility
- Complex indexing requirements (GIN/GiST)
- ACID transactions with JSON data
- SQL queries with JSON operations
- Hybrid relational-document model

**Example scenarios:**
- User profiles with varying fields
- Event logging with structured metadata
- Configuration data that needs querying
- Semi-structured analytics data

### MongoDB BSON When...

**Choose BSON/MongoDB if you need:**
- Pure document database approach
- Extended type system (ObjectId, Decimal128, dates)
- Horizontal scaling (sharding)
- Flexible schema evolution
- Binary data without encoding overhead

**Example scenarios:**
- Content management systems
- Catalogs with varying product attributes
- Time-series data with metadata
- File storage with metadata

---

## Database Performance Impact

**10M user benchmark:**

| Database | Format | Storage | Query Speed | Index Size |
|----------|---------|---------|-------------|------------|
| PostgreSQL | JSON | 1.56 GB | 2.3s (filter) | N/A |
| PostgreSQL | JSONB | 1.67 GB | 0.45s (indexed) | +310 MB |
| MongoDB | JSON | 1.56 GB | 1.8s (scan) | N/A |
| MongoDB | BSON | 1.31 GB | 0.12s (indexed) | +280 MB |

**Key insights:**
- Binary formats trade insert speed for query speed
- Indexing provides 5-20x query speedup
- Storage overhead: 5-15% for binary format + indexes
- Extended types (BSON) can reduce storage vs text

---

## What's Next: Beyond Database Storage

Database binary JSON solves storage and query performance within individual databases. But what about data transfer between services, mobile applications, and distributed systems?

In [Part 4]({{< relref "you-dont-know-json-part-4-binary-apis.md" >}}), we'll explore binary JSON formats designed for APIs and data transfer: MessagePack for universal serialization and CBOR for IoT and security protocols. These formats optimize for network bandwidth and serialization speed rather than database storage.

**Coming up:**
- MessagePack: The universal binary JSON
- CBOR: IETF standard for constrained environments  
- Performance comparison: when binary beats JSON
- Real-world bandwidth cost analysis

The goal remains the same - keeping JSON's flexibility while eliminating the text format tax - but the trade-offs shift from storage efficiency to network efficiency.

---

## References

**Specifications:**
- [PostgreSQL JSONB Documentation](https://www.postgresql.org/docs/current/datatype-json.html)
- [MongoDB BSON Specification](http://bsonspec.org/)

**Performance:**
- [PostgreSQL JSONB Performance](https://www.postgresql.org/docs/current/datatype-json.html#JSON-INDEXING)
- [MongoDB Performance Best Practices](https://docs.mongodb.com/manual/administration/analyzing-mongodb-performance/)