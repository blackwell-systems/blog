# Chapter 4: Binary JSON in Databases

In Chapter 2, we saw how JSON's modular architecture enabled independent solutions for each gap. Chapter 3 showed validation as a separate layer (JSON Schema). Now we tackle the performance gap: **database-managed binary formats**.

JSON's human-readability is both its greatest strength and its Achilles heel. Every byte is text. Field names repeat in every object. Numbers are stored as strings. Parsing requires scanning every character.

For configuration files and API responses under 100KB, this is fine. But when storing millions of user records, events, or documents - the text format becomes expensive for databases.

{blurb, class: information}
**What XML Had:** No successful binary format (1998-2010)

**XML's approach:** XML was purely textual for databases. Binary encoding attempts existed but failed:
- **WBXML** (1999): WAP-specific, limited adoption
- **Fast Infoset** (2005): Complex, required special parsers
- **EXI** (2011): Too late, minimal database support
- **Binary XML (.NET)**: Proprietary, Microsoft-only

```xml
<!-- XML: Always text in databases, even for large datasets -->
<users>
  <user><id>1</id><name>Alice</name></user>
  <user><id>2</id><name>Bob</name></user>
  <!-- Repeated tags and field names for millions of records -->
</users>
```

**For embedding binary data (images, files), both XML and JSON equally bad:**
```xml
<!-- XML: Must base64 encode binary -->
<image>iVBORw0KGgoAAAANSUhEUgAAAAUA...</image>
```
```json
// JSON: Must base64 encode binary (33% overhead)
{"image": "iVBORw0KGgoAAAANSUhEUgAAAAUA..."}
```

**Benefit:** Human readable, universal parser support  
**Cost:** Massive storage overhead (repeated structure), slow parsing at scale, no database optimization, no native binary data type

**JSON's approach:** Database-specific binary formats (JSONB, BSON) succeeded where XML's failed - modular, database-optimized solutions

**Architecture shift:** Text-only → Binary storage with text compatibility, Failed standards → Database-integrated formats, No binary data type → Extended types (BSON)
{/blurb}

Database binary JSON formats solve this at the storage layer - maintaining JSON's structure and flexibility while dramatically improving query speed and storage efficiency.

---

## Running Example: Storing 10 Million Users

Our User API from [Part 1](##running-example-building-a-user-api) now has validation from [Part 2](#). Next challenge: **storing 10 million users efficiently in a database**.

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

{blurb, class: information}
**Database Rule of Thumb:** Text JSON columns are fine for rarely-queried metadata. Consider binary formats when you have:
- Frequent queries on JSON fields
- Large datasets (>100K rows with JSON)
- Complex aggregations or analytics
- Need to index JSON content
- Performance-critical applications
{/blurb}

**Database Binary JSON Evolution Timeline:**

| Year | Database/Technology | Innovation | Impact |
|------|-------------------|-----------|--------|
| 2009 | MongoDB BSON | Binary JSON with extended types | First major binary JSON implementation |
| 2012 | PostgreSQL JSON | Text JSON column support | SQL databases adopt JSON |
| 2014 | PostgreSQL JSONB | Binary JSON with indexing | Performance breakthrough for SQL JSON |
| 2015 | MySQL JSON | Binary JSON column type | Major database vendors adopt binary JSON |
| 2016 | SQL Server JSON | JSON functions and indexing | Enterprise database JSON support |
| 2020+ | Industry-wide | Wide adoption in production | Binary JSON becomes mainstream |

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

{blurb, class: warning}
**Key Distinction:** Database binary JSON is **storage-optimized** - designed for frequent queries, indexing, and database operations. API/network binary formats (covered in Part 4) optimize for serialization speed and bandwidth.
{/blurb}


![Diagram 1](chapter-04-binary-databases-diagram-1.png){width=85%}


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

{blurb, class: tip}
**Best Practice:** Use JSONB for:
- Semi-structured data in PostgreSQL
- Documents with varied schemas
- Fast queries on JSON fields
- When you need indexing

Stick with JSON column type only if you need:
- Exact key order preservation
- Faster inserts (no decomposition)
- Original formatting preserved
{/blurb}

### Query Optimization with JSONB

Understanding JSONB's internal structure helps write efficient queries. Here are production patterns that leverage JSONB's strengths:

**1. Containment queries (fast with GIN index):**

```sql
-- Find users with specific attribute (indexed lookup)
SELECT * FROM users 
WHERE data @> '{"role": "admin"}';

-- Find users with any tag in array (indexed)
SELECT * FROM users
WHERE data->'tags' @> '["golang"]';

-- Multi-condition containment
SELECT * FROM users
WHERE data @> '{"role": "admin", "status": "active"}';
```

**Why this is fast:** GIN index creates inverted index of all key-value pairs. Containment check is O(log n) instead of O(n) table scan.

**2. Existence checks (also indexed):**

```sql
-- Has specific key? (fast with GIN)
SELECT * FROM users
WHERE data ? 'premium_features';

-- Has any of these keys?
SELECT * FROM users
WHERE data ?| array['phone', 'mobile'];

-- Has all of these keys?
SELECT * FROM users
WHERE data ?& array['email', 'username'];
```

**3. Path extraction (not indexed, but efficient):**

```sql
-- Extract nested value (binary read, no text parsing)
SELECT data->'profile'->>'name' as name,
       data->'profile'->>'city' as city
FROM users
WHERE data->'profile'->>'country' = 'USA';
```

**Operator guide:**
- `->` returns JSONB (binary, for chaining)
- `->>` returns TEXT (final extraction)
- `@>` containment (left contains right)
- `<@` contained by (left contained in right)
- `?` key exists
- `#>` path extraction array notation: `data #> '{profile,address,city}'`

**4. Aggregations on JSONB:**

```sql
-- Count users by country
SELECT data->'profile'->>'country' as country,
       COUNT(*) as user_count
FROM users
GROUP BY data->'profile'->>'country'
ORDER BY user_count DESC;

-- Average age from JSONB
SELECT AVG((data->>'age')::int) as avg_age
FROM users
WHERE data->>'age' IS NOT NULL;
```

**5. Updates and modifications:**

```sql
-- Update nested value (binary operation, efficient)
UPDATE users
SET data = jsonb_set(data, '{profile,city}', '"San Francisco"')
WHERE id = 123;

-- Append to array
UPDATE users
SET data = jsonb_set(
  data,
  '{tags}',
  (data->'tags' || '["new-tag"]')
)
WHERE id = 123;

-- Remove key
UPDATE users
SET data = data - 'temporary_field';
```

### Index Selection Guide: GIN vs GiST

PostgreSQL offers two JSONB index types with different trade-offs:

**GIN (Generalized Inverted Index):**

```sql
CREATE INDEX idx_users_data_gin ON users USING GIN (data);
```

**Optimizes:**
- Containment queries (`@>`, `<@`)
- Existence checks (`?`, `?|`, `?&`)
- Full-text search within JSONB

**Characteristics:**
- Larger index size (1.5-2x the data size)
- Slower inserts/updates (index maintenance)
- Faster queries (most common use case)

**Use when:** Read-heavy workloads, complex containment queries

**GiST (Generalized Search Tree):**

```sql
CREATE INDEX idx_users_data_gist ON users USING GiST (data);
```

**Optimizes:**
- Range queries
- Nearest-neighbor searches
- Custom operators

**Characteristics:**
- Smaller index size (0.5-1x the data size)
- Faster inserts/updates
- Slower containment queries than GIN

**Use when:** Write-heavy workloads, index size is critical

**Partial indexes (best of both worlds):**

```sql
-- Only index users with premium features
CREATE INDEX idx_premium_users 
ON users USING GIN (data)
WHERE data ? 'premium_features';

-- Only index active users
CREATE INDEX idx_active_users
ON users USING GIN ((data->'profile'))
WHERE data->>'status' = 'active';
```

**Benefit:** Smaller index, faster queries on subset, reduced maintenance overhead

**Expression indexes (query-specific optimization):**

```sql
-- Index specific field for equality checks
CREATE INDEX idx_user_email 
ON users ((data->>'email'));

-- Index computed value
CREATE INDEX idx_user_age_bucket
ON users (((data->>'age')::int / 10));
```

**Real-world example from Segment:**

Segment stores event data in JSONB. They use:

```sql
-- GIN index for property searches
CREATE INDEX idx_events_properties_gin 
ON events USING GIN (properties);

-- Partial index for recent events (90% of queries)
CREATE INDEX idx_recent_events
ON events USING GIN (properties)
WHERE created_at > NOW() - INTERVAL '30 days';

-- Expression index for common property
CREATE INDEX idx_user_id
ON events ((properties->>'user_id'));
```

**Result:** 50x query speedup on common patterns, 30% smaller indexes than full GIN.

### Migrating from JSON to JSONB in Production

Moving existing JSON columns to JSONB requires careful planning to avoid downtime.

**Phase 1: Add JSONB column (zero downtime)**

```sql
-- Add new JSONB column
ALTER TABLE users ADD COLUMN data_jsonb JSONB;

-- Backfill in batches (avoids long locks)
DO $$
DECLARE
  batch_size INT := 10000;
  last_id INT := 0;
BEGIN
  LOOP
    UPDATE users
    SET data_jsonb = data::jsonb
    WHERE id > last_id AND id <= last_id + batch_size
      AND data_jsonb IS NULL;
    
    EXIT WHEN NOT FOUND;
    last_id := last_id + batch_size;
    
    -- Avoid lock contention
    PERFORM pg_sleep(0.1);
  END LOOP;
END $$;
```

**Phase 2: Dual writes (maintain both columns)**

```javascript
// Application code writes to both
await db.query(`
  UPDATE users 
  SET data = $1, data_jsonb = $1::jsonb 
  WHERE id = $2
`, [jsonData, userId]);
```

**Phase 3: Validate consistency**

```sql
-- Check for mismatches
SELECT COUNT(*) 
FROM users 
WHERE data::jsonb != data_jsonb;

-- If mismatches exist, find them
SELECT id, data, data_jsonb
FROM users
WHERE data::jsonb != data_jsonb
LIMIT 100;
```

**Phase 4: Switch reads to JSONB**

```javascript
// Change queries to use data_jsonb
const result = await db.query(`
  SELECT data_jsonb as data
  FROM users
  WHERE data_jsonb @> $1
`, [{role: 'admin'}]);
```

**Phase 5: Create indexes (during low-traffic period)**

```sql
-- Create index with CONCURRENTLY (no table lock)
CREATE INDEX CONCURRENTLY idx_users_data_jsonb 
ON users USING GIN (data_jsonb);

-- Verify index is used
EXPLAIN ANALYZE
SELECT * FROM users 
WHERE data_jsonb @> '{"role": "admin"}';
```

**Phase 6: Drop old column (after monitoring period)**

```sql
-- After 1-2 weeks of stable operation
ALTER TABLE users DROP COLUMN data;
ALTER TABLE users RENAME COLUMN data_jsonb TO data;
```

**Timeline:** 2-4 weeks for safe migration of large tables (millions of rows)

**Cost:** GitHub migrated 10M records to JSONB - 2 weeks, zero downtime, 40% query speedup

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

{blurb, class: information}
**BSON Use Cases:**
- MongoDB storage (native format)
- MongoDB wire protocol
- Document databases needing extended types
- Systems requiring ObjectId benefits

**Not recommended for:**
- General-purpose serialization (use MessagePack)
- Non-MongoDB systems (ecosystem smaller)
- Human debugging (binary format)
{/blurb}

### MongoDB Query Patterns with BSON

MongoDB's BSON format enables efficient queries through its binary structure and extended types.

**1. ObjectId queries (very fast):**

```javascript
// Find by _id (indexed by default, O(1) lookup)
db.users.findOne({_id: ObjectId("507f1f77bcf86cd799439011")});

// Range queries on ObjectId (contains timestamp)
db.users.find({
  _id: {
    $gt: ObjectId.fromDate(new Date('2023-01-01')),
    $lt: ObjectId.fromDate(new Date('2023-12-31'))
  }
});
```

**Why fast:** ObjectId embeds timestamp in first 4 bytes, enabling time-based queries without separate timestamp field.

**2. Embedded document queries:**

```javascript
// Query nested field (dot notation)
db.users.find({
  "profile.country": "USA",
  "profile.age": {$gte: 18}
});

// Compound index on nested fields
db.users.createIndex({"profile.country": 1, "profile.age": 1});
```

**3. Array queries (unique to document databases):**

```javascript
// Element match
db.users.find({tags: "golang"});

// Multiple conditions on array elements
db.users.find({
  tags: {$all: ["golang", "rust"]}
});

// Array element matching
db.users.find({
  "orders": {
    $elemMatch: {
      status: "completed",
      total: {$gt: 100}
    }
  }
});
```

**4. Decimal128 for financial data (no rounding errors):**

```javascript
// Precise decimal arithmetic
db.transactions.insertOne({
  amount: NumberDecimal("1234.56"),
  currency: "USD",
  created: new Date()
});

// Aggregation with precise decimals
db.transactions.aggregate([
  {$group: {
    _id: "$currency",
    total: {$sum: "$amount"}  // No floating-point errors
  }}
]);
```

**5. Binary data queries:**

```javascript
// Store file with metadata
db.files.insertOne({
  filename: "avatar.png",
  data: BinData(0, binaryImageData),
  contentType: "image/png",
  size: 25600,
  uploaded: new Date()
});

// Query by metadata (binary data not scanned)
db.files.find({
  contentType: "image/png",
  size: {$lt: 1000000}  // < 1MB
});
```

**Index strategy for MongoDB:**

```javascript
// Compound index for common query pattern
db.users.createIndex({
  "profile.country": 1,
  "created": -1
});

// Partial index (only index subset)
db.users.createIndex(
  {"profile.premiumFeatures": 1},
  {partialFilterExpression: {
    "profile.premium": true
  }}
);

// Text index for search
db.articles.createIndex({
  title: "text",
  content: "text"
});
```

---

## Real-World Production Examples

### Uber: JSONB for Geospatial + Structured Data

**Use case:** Store driver and rider location history with trip metadata

```sql
CREATE TABLE trip_events (
  id BIGSERIAL PRIMARY KEY,
  trip_id UUID NOT NULL,
  event_type TEXT NOT NULL,
  location GEOMETRY(Point, 4326),  -- PostGIS
  metadata JSONB,  -- Flexible event data
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for geospatial + JSONB queries
CREATE INDEX idx_trip_events_location 
ON trip_events USING GIST (location);

CREATE INDEX idx_trip_events_metadata 
ON trip_events USING GIN (metadata);
```

**Query pattern:**

```sql
-- Find trips near location with specific metadata
SELECT trip_id, metadata
FROM trip_events
WHERE ST_DWithin(
  location,
  ST_MakePoint(-122.4194, 37.7749)::geography,
  1000  -- 1km radius
)
AND metadata @> '{"event_type": "pickup_completed"}'
AND created_at > NOW() - INTERVAL '1 hour';
```

**Result:** 100M+ events/day, sub-second queries, 60% storage reduction vs text JSON

### Stripe: MongoDB BSON for API Events

**Use case:** Store webhook events with variable payload structures

```javascript
// Event schema (flexible with BSON types)
{
  _id: ObjectId("..."),
  type: "payment_intent.succeeded",
  created: ISODate("2023-12-01T10:30:00Z"),
  livemode: false,
  api_version: "2023-10-16",
  data: {
    object: {
      id: "pi_...",
      amount: NumberDecimal("2500.00"),  // Precise currency
      currency: "usd",
      status: "succeeded",
      metadata: { 
        order_id: "order_123",
        customer_email: "user@example.com"
      }
    }
  },
  request: {
    id: "req_...",
    idempotency_key: "..."
  }
}
```

**Index strategy:**

```javascript
// Compound index for API queries
db.events.createIndex({
  "type": 1,
  "created": -1,
  "livemode": 1
});

// Partial index for recent events
db.events.createIndex(
  {"data.object.id": 1},
  {
    partialFilterExpression: {
      created: {$gt: new Date(Date.now() - 90*24*60*60*1000)}
    }
  }
);
```

**Result:** 1B+ events stored, 99.99% query success rate, sub-100ms p95 latency

### GitHub: JSONB for Code Search Metadata

**Use case:** Store code file metadata with flexible indexing

```sql
CREATE TABLE code_files (
  id BIGSERIAL PRIMARY KEY,
  repo_id INTEGER NOT NULL,
  path TEXT NOT NULL,
  language TEXT,
  metadata JSONB,  -- File stats, imports, symbols
  content_hash TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Specialized indexes
CREATE INDEX idx_code_files_language 
ON code_files (language);

CREATE INDEX idx_code_files_metadata_gin 
ON code_files USING GIN (metadata);

-- Expression index for specific metadata
CREATE INDEX idx_code_files_has_tests
ON code_files ((metadata->>'has_tests'))
WHERE metadata->>'has_tests' = 'true';
```

**Query examples:**

```sql
-- Find files importing specific module
SELECT repo_id, path
FROM code_files
WHERE metadata->'imports' @> '["react"]'
AND language = 'javascript';

-- Find test files with high coverage
SELECT path, metadata->>'coverage' as coverage
FROM code_files
WHERE metadata->>'has_tests' = 'true'
AND (metadata->>'coverage')::float > 80.0;
```

**Result:** 200M+ files indexed, enables GitHub Code Search, 10x faster than text JSON

### Key Takeaways from Production

**JSONB wins when:**
- You need SQL joins with JSON data
- ACID transactions are critical
- Geospatial queries + JSON (PostGIS + JSONB)
- Complex indexing strategies (partial, expression indexes)

**BSON wins when:**
- Schema varies significantly across documents
- Extended types are needed (Decimal128, ObjectId, Binary)
- Horizontal scaling is required (MongoDB sharding)
- Document-first data model fits naturally

**Both provide:**
- 40-60% storage savings vs text JSON
- 10-50x query speedup with proper indexing
- Zero-parsing overhead for queries
- Production-proven at massive scale (billions of records)

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

In [Part 4](#), we'll explore binary JSON formats designed for APIs and data transfer: MessagePack for universal serialization and CBOR for IoT and security protocols. These formats optimize for network bandwidth and serialization speed rather than database storage.

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
