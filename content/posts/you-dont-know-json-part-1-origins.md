---
title: "You Don't Know JSON: Part 1 - Origins, Evolution, and the Cracks in the Foundation"
date: 2025-12-15
draft: false
series: ["you-dont-know-json"]
seriesOrder: 1
tags: ["json", "data-formats", "xml", "yaml", "serialization", "web-development", "api-design", "javascript", "rest-api", "data-interchange", "json-schema", "standards", "rfc", "history", "web-standards", "parsing", "validation", "configuration", "distributed-systems", "microservices"]
categories: ["fundamentals", "programming"]
description: "The complete history of JSON from Douglas Crockford's discovery to today's dominance. Learn why JSON replaced XML, where it fails, and why the JSON ecosystem evolved beyond basic key-value pairs."
summary: "Everyone thinks they know JSON. But do you know why it was created, what problems it solved, and more importantly - what problems it created? Part 1 explores JSON's origins, its triumph over XML, and the fundamental weaknesses that spawned an entire ecosystem of extensions."
---

Every developer knows JSON. You've written `{"key": "value"}` thousands of times. You've debugged missing commas, fought with trailing characters, and cursed the lack of comments in configuration files.

But how did we get here? Why does the world's most popular data format have such obvious limitations? And why, despite being "simple," has JSON spawned an entire ecosystem of variants, extensions, and workarounds?

This series explores the JSON you don't know - the one beyond basic syntax. We'll examine binary formats, streaming protocols, validation schemas, RPC layers, and security considerations. But first, we need to understand why JSON exists and where it falls short.

---

## The Pre-JSON Dark Ages: XML Everywhere

### The Problem Space (Late 1990s)

The web was growing explosively. Websites evolved from static HTML to dynamic applications. Services needed to communicate across networks, applications needed configuration files, and developers needed a way to move structured data between systems.

**The requirements were clear:**
- Human-readable (developers must debug it)
- Machine-parseable (computers must process it)
- Language-agnostic (works in any programming language)
- Supports nested structures (real data has hierarchy)
- Self-describing (data carries its own schema)

### XML: The Heavyweight Champion

XML (eXtensible Markup Language) emerged as the answer. By the early 2000s, it dominated:

**XML everywhere:**
- Configuration files (web.xml, applicationContext.xml)
- SOAP web services (the enterprise standard)
- Data exchange (RSS, Atom feeds)
- Document formats (DOCX, SVG)
- Build systems (Maven pom.xml, Ant build.xml)

**A simple person record in XML:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<person>
  <name>Alice Johnson</name>
  <email>alice@example.com</email>
  <age>30</age>
  <active>true</active>
  <hobbies>
    <hobby>reading</hobby>
    <hobby>cycling</hobby>
  </hobbies>
</person>
```

**Size:** 247 bytes

### XML's Strengths

XML wasn't chosen arbitrarily. It had real advantages:

**+ Schema validation** (XSD, DTD, RelaxNG)  
**+ Namespaces** (avoid naming conflicts)  
**+ XPath** (query language)  
**+ XSLT** (transformation)  
**+ Comments** (documentation support)  
**+ Attributes and elements** (flexible modeling)  
**+ Mature tooling** (parsers in every language)

### XML's Fatal Flaws

But XML's complexity became its downfall:

**- Extreme verbosity** (closing tags double the size)  
**- Parsing complexity** (DOM vs SAX, namespace handling)  
**- Schema complexity** (XSD is harder than the data itself)  
**- Mixed content confusion** (text + elements in same node)  
**- Attribute vs element debates** (no clear guidance)  
**- Namespace hell** (xmlns everywhere)  
**- SOAP overhead** (10KB of envelope for 100 bytes of data)

**The real killer:** Developer experience. Writing XML by hand was tedious. Reading XML logs was painful. Debugging SOAP requests required specialized tools.

{{< mermaid >}}
flowchart TB
    subgraph xml["XML Complexity"]
        parse[XML Parser]
        ns[Namespace Handler]
        schema[Schema Validator]
        xpath[XPath Processor]
        
        parse --> ns
        ns --> schema
        schema --> xpath
    end
    
    subgraph json["JSON Simplicity"]
        jsparse[JSON.parse]
    end
    
    data[Raw Data] --> xml
    data --> json
    
    xml --> result1[Parse Result]
    json --> result2[Parse Result]
    
    style xml fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style json fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

---

## JSON's Accidental Discovery

### Douglas Crockford's Realization (2001)

JSON wasn't invented - it was discovered. Douglas Crockford realized that JavaScript's object literal notation was already a perfect data format:

```javascript
// JavaScript code that's also data
var person = {
    name: "Alice Johnson",
    email: "alice@example.com",
    age: 30,
    active: true,
    hobbies: ["reading", "cycling"]
};
```

**Key insight:** This notation was:
- Already in JavaScript engines (browsers everywhere)
- Minimal syntax (no closing tags)
- Easy to parse (recursive descent parser is ~500 lines)
- Human-readable
- Machine-friendly

### The Same Data in JSON

```json
{
  "name": "Alice Johnson",
  "email": "alice@example.com",
  "age": 30,
  "active": true,
  "hobbies": ["reading", "cycling"]
}
```

**Size:** 129 bytes (52% smaller than XML)

### The Simplicity Revolution

JSON's radical simplification:

**Six data types:**
1. `object` - `{ "key": "value" }`
2. `array` - `[1, 2, 3]`
3. `string` - `"text"`
4. `number` - `123` or `123.45`
5. `boolean` - `true` or `false`
6. `null` - `null`

That's it. No attributes. No namespaces. No CDATA sections. No processing instructions.

### Browser Native Support

The killer feature:

```javascript
// Parse JSON (browsers built-in)
var data = JSON.parse(jsonString);

// Generate JSON
var json = JSON.stringify(data);
```

No XML parser library needed. No SAX vs DOM decision. Just two functions.

{{< mermaid >}}
timeline
    title Evolution of Data Formats
    1998 : XML 1.0 Specification
         : SOAP begins development
    2001 : JSON discovered by Crockford
         : First JSON parsers appear
    2005 : JSON used in AJAX applications
         : Web 2.0 movement
    2006 : RFC 4627 - JSON specification
         : JSON becomes formal standard
    2013 : RFC 7159 - Updated JSON spec
         : ECMA-404 standard
    2017 : RFC 8259 - Current JSON standard
         : JSON dominates REST APIs
    2020+ : JSON Schema, JSONB, JSONL
         : JSON ecosystem mature
{{< /mermaid >}}

---

## Why JSON Won

### 1. The AJAX Revolution (2005)

Google Maps launched and changed everything. AJAX (Asynchronous JavaScript and XML) applications became the future of the web.

**Irony:** Despite the name, JSON quickly replaced XML in AJAX because:
- Faster to parse in JavaScript
- Smaller payloads (bandwidth mattered on 2005 connections)
- Native browser support
- Easier for front-end developers

### 2. REST vs SOAP

REST APIs adopted JSON as the default format:

**SOAP request (XML):**
```xml
<?xml version="1.0"?>
<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
  <soap:Header>
  </soap:Header>
  <soap:Body>
    <m:GetUser xmlns:m="http://example.com/users">
      <m:UserId>123</m:UserId>
    </m:GetUser>
  </soap:Body>
</soap:Envelope>
```

**REST request (JSON):**
```http
GET /users/123
Accept: application/json
```

**REST response:**
```json
{
  "id": 123,
  "name": "Alice Johnson",
  "email": "alice@example.com"
}
```

The difference was stark. REST + JSON became the de facto standard for web APIs.

### 3. NoSQL Movement (2009+)

MongoDB, CouchDB, and other NoSQL databases chose JSON-like formats:

```javascript
// MongoDB document (BSON internally)
{
  "_id": ObjectId("507f1f77bcf86cd799439011"),
  "name": "Alice Johnson",
  "email": "alice@example.com",
  "created": ISODate("2023-01-15T10:30:00Z")
}
```

**Why JSON for databases:**
- Schema flexibility (add fields without migrations)
- Direct JavaScript integration
- Document model matches JSON structure
- Query results are already in API format

### 4. Configuration Files

JSON displaced XML in configuration:

**package.json (Node.js):**
```json
{
  "name": "my-app",
  "version": "1.0.0",
  "dependencies": {
    "express": "^4.18.0"
  }
}
```

**tsconfig.json (TypeScript):**
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "commonjs",
    "strict": true
  }
}
```

Developers preferred JSON over XML for configuration because it was easier to read and edit.

### 5. Language Support Explosion

By 2010, every major language had JSON support:

**Go:**
```go
import "encoding/json"

type Person struct {
    Name  string   `json:"name"`
    Email string   `json:"email"`
    Age   int      `json:"age"`
}

json.Marshal(person)   // encode
json.Unmarshal(data, &person)  // decode
```

**Python:**
```python
import json

person = {"name": "Alice", "email": "alice@example.com"}
json.dumps(person)  # encode
json.loads(data)    # decode
```

**Java:**
```java
import com.fasterxml.jackson.databind.ObjectMapper;

ObjectMapper mapper = new ObjectMapper();
String json = mapper.writeValueAsString(person);  // encode
Person person = mapper.readValue(json, Person.class);  // decode
```

{{< callout type="info" >}}
**The Ecosystem Effect:** Once every language had JSON support, it became the obvious choice for data interchange. Network effects made JSON the default - not because it was technically superior, but because it was universally supported.
{{< /callout >}}

{{< mermaid >}}
flowchart LR
    subgraph formats["Data Format Comparison"]
        xml[XML<br/>247 bytes]
        json[JSON<br/>129 bytes]
        yaml[YAML<br/>98 bytes]
    end
    
    subgraph metrics["Key Metrics"]
        size[Size]
        parse[Parse Speed]
        write[Write Speed]
        human[Readability]
    end
    
    formats --> metrics
    
    json -.Best Balance.-> metrics
    
    style xml fill:#4C3A3C,stroke:#6b7280,color:#f0f0f0
    style json fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style yaml fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style metrics fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

---

## JSON's Fundamental Weaknesses

Now we reach the core problem. JSON won because it was simple. But that simplicity came with trade-offs that become painful at scale.

### 1. No Schema or Validation

**The problem:**

```json
{
  "name": "Alice",
  "age": "30"
}
```

Is `age` a string or a number? Both are valid JSON. The parser accepts both. Your application crashes when it expects a number.

**Real-world consequences:**
- API breaking changes go undetected
- Invalid data passes validation
- Runtime errors instead of compile-time checks
- Documentation is separate from data format
- Client-server contract is implicit, not explicit

### 2. No Date/Time Type

JSON has no standard way to represent dates:

```json
{
  "created": "2023-01-15"
}
```

```json
{
  "created": "2023-01-15T10:30:00Z"
}
```

```json
{
  "created": 1673780400
}
```

All are valid JSON. Which format do you use? ISO 8601 string? Unix timestamp? Custom format?

**Every project reinvents this.** Libraries make assumptions. APIs document their chosen format. Parsing errors happen when formats don't match.

### 3. Number Precision Issues

JavaScript uses IEEE 754 double-precision floats for all numbers:

```javascript
// JavaScript
console.log(9007199254740992 + 1);  // 9007199254740992
// Lost precision!
```

**Problems:**
- Large integers lose precision (database IDs, timestamps)
- No distinction between integer and float
- Different languages handle this differently
- Financial calculations require special handling

**Common workaround:**
```json
{
  "id": "9007199254740993",
  "balance": "1234.56"
}
```

Represent numbers as strings to preserve precision. But now you need custom parsing logic.

### 4. No Comments

You cannot add comments to JSON:

```json
{
  "port": 8080,
  "debug": true
}
```

Why is debug enabled? What does this configuration do? You can't document it in the file itself.

**Workarounds:**
```json
{
  "_comment": "Enable debug mode in development",
  "debug": true
}
```

Use fake fields for comments. But parsers still process these as data.

### 5. No Binary Data Support

JSON is text-based. Binary data must be encoded:

```json
{
  "image": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
}
```

**Problems:**
- Base64 encoding increases size by ~33%
- Additional encoding/decoding overhead
- Not efficient for large binary files

### 6. Verbose for Large Datasets

Repeated field names add significant overhead:

```json
[
  {"id": 1, "name": "Alice", "email": "alice@example.com"},
  {"id": 2, "name": "Bob", "email": "bob@example.com"},
  {"id": 3, "name": "Carol", "email": "carol@example.com"}
]
```

Field names ("id", "name", "email") repeat for every record. In a 100,000 row dataset, this is wasteful.

**CSV alternative (for comparison):**
```csv
id,name,email
1,Alice,alice@example.com
2,Bob,bob@example.com
3,Carol,carol@example.com
```

More compact, but loses type information and nested structure support.

### 7. No Circular References

JSON cannot represent circular references:

```javascript
// JavaScript object
let person = {name: "Alice"};
let company = {name: "Acme Corp", ceo: person};
person.employer = company;  // Circular reference

JSON.stringify(person);  
// TypeError: Converting circular structure to JSON
```

You must manually break cycles or use a [serialization library]({{< relref "serialization-explained.md" >}}) that detects and handles them.

{{< callout type="warning" >}}
**Critical Insight:** JSON's weaknesses aren't bugs - they're consequences of extreme simplification. Every missing feature (schemas, comments, binary support) was left out intentionally to keep the format minimal.
{{< /callout >}}

---

## The Format Comparison Landscape

Let's compare JSON to its alternatives across key dimensions:

| Feature                  | JSON       | XML        | YAML       | TOML       | Protocol Buffers |
|--------------------------|------------|------------|------------|------------|------------------|
| **Human-readable**       | Yes        | Yes        | Yes        | Yes        | No               |
| **Schema validation**    | No*        | Yes        | No         | No         | Yes              |
| **Comments**             | No         | Yes        | Yes        | Yes        | No               |
| **Binary support**       | No         | No         | No         | No         | Yes              |
| **Date types**           | No         | No         | No         | Yes        | Yes              |
| **Size efficiency**      | Medium     | Large      | Medium     | Medium     | Small            |
| **Parse speed**          | Fast       | Slow       | Medium     | Medium     | Very Fast        |
| **Language support**     | Universal  | Universal  | Wide       | Growing    | Wide             |
| **Nested structures**    | Yes        | Yes        | Yes        | Limited    | Yes              |
| **Trailing commas**      | No         | N/A        | Yes        | Yes        | N/A              |
| **Type safety**          | No         | Yes        | No         | Partial    | Yes              |

*JSON Schema provides validation but isn't part of JSON itself.

{{< mermaid >}}
flowchart TB
    subgraph decision["Choose Your Format"]
        start{What's the use case?}
        
        config{Human-edited<br/>configuration?}
        api{API/Network<br/>transfer?}
        perf{Performance<br/>critical?}
        legacy{Legacy system<br/>integration?}
        
        start --> config
        start --> api
        start --> perf
        start --> legacy
        
        config -->|Need comments| yaml[YAML]
        config -->|Simple config| toml[TOML]
        config -->|Complex schema| xml[XML]
        
        api -->|Web APIs| json[JSON]
        api -->|Microservices| proto[Protocol Buffers]
        
        perf -->|Extreme perf| proto2[Protocol Buffers]
        perf -->|Binary + schema| msgpack[MessagePack/CBOR]
        
        legacy -->|Enterprise| xml2[XML/SOAP]
        legacy -->|Tabular data| csv[CSV]
    end
    
    style decision fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style json fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style proto fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style proto2 fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

---

## When NOT to Use JSON

Despite JSON's dominance, there are clear cases where alternatives are better:

### 1. High-Performance Systems → Protocol Buffers, FlatBuffers

When you're handling millions of requests per second, [Protocol Buffers](/posts/understanding-protobuf-part-1/) offer compelling advantages:

```protobuf
message Person {
  string name = 1;
  string email = 2;
  int32 age = 3;
}
```

**Benefits:**
- 3-10x smaller than JSON
- 5-20x faster to parse
- Schema enforced at compile time
- Backward/forward compatibility built-in

**Trade-off:** Not human-readable, requires schema compilation.

Read more: [Understanding Protocol Buffers: Part 1](/posts/understanding-protobuf-part-1/)

### 2. Human-Edited Configuration → YAML, TOML, JSON5

When developers edit config files frequently:

**TOML:**
```toml
[database]
host = "localhost"
port = 5432

# Connection pool settings
[database.pool]
max_connections = 100
min_connections = 10
```

**YAML:**
```yaml
database:
  host: localhost
  port: 5432
  pool:
    max_connections: 100
    min_connections: 10  # Minimum pool size
```

**Benefits:** Comments, less syntax noise, more readable.

**Trade-off:** YAML has subtle parsing gotchas (indentation, special values like `no`/`yes`).

### 3. Large Tabular Datasets → CSV, Parquet, Arrow

For analytics and data pipelines:

```csv
id,name,email,created
1,Alice,alice@example.com,2023-01-15
2,Bob,bob@example.com,2023-01-16
```

**Benefits:** Much more compact, streaming-friendly, tooling optimized for analysis.

**Trade-off:** No nested structures, limited type information.

### 4. Document Storage → BSON, MessagePack

When JSON-like flexibility meets binary efficiency:

```javascript
// MongoDB (BSON)
{
  _id: ObjectId("507f1f77bcf86cd799439011"),
  name: "Alice",
  created: ISODate("2023-01-15T10:30:00Z"),
  avatar: BinData(0, "base64data...")
}
```

**Benefits:** Native date types, binary data support, efficient storage.

**Trade-off:** Binary format, language-specific implementations.

---

## The Evolution: JSON's Ecosystem Response

JSON's limitations didn't kill it. Instead, an entire ecosystem evolved to address the weaknesses while preserving the core simplicity:

### 1. Validation Layer: JSON Schema

**Problem:** No built-in validation  
**Solution:** External schema language

```json
{
  "type": "object",
  "properties": {
    "name": {"type": "string", "minLength": 1},
    "email": {"type": "string", "format": "email"},
    "age": {"type": "integer", "minimum": 0}
  },
  "required": ["name", "email"]
}
```

{{< callout type="success" >}}
**Transformation:** This single innovation transformed JSON from "hope the data is correct" to "validate at runtime with strict schemas." JSON Schema adds the type safety layer that JSON itself deliberately omitted.
{{< /callout >}}

**Next article:** [Part 2]({{< relref "you-dont-know-json-part-2-json-schema.md" >}}) dives deep into JSON Schema - how it works, why it matters, and how it solves JSON's validation problem.

### 2. Binary Variants: JSONB, BSON, MessagePack

**Problem:** Text format is inefficient  
**Solution:** Binary encoding with JSON-like structure

These formats maintain JSON's structure while using efficient binary [serialization]({{< relref "serialization-explained.md" >}}):

- **PostgreSQL JSONB:** Decomposed binary format, indexable, faster queries
- **MongoDB BSON:** Binary JSON with extended types
- **MessagePack:** Universal binary serialization

### 3. Streaming Format: JSON Lines (JSONL)

**Problem:** JSON arrays don't stream  
**Solution:** Newline-delimited JSON objects

```jsonl
{"id": 1, "name": "Alice"}
{"id": 2, "name": "Bob"}
{"id": 3, "name": "Carol"}
```

Each line is independent, enabling streaming, log files, and Unix pipeline processing.

### 4. Protocol Layer: JSON-RPC

**Problem:** No standard RPC convention  
**Solution:** Structured request/response format

```json
{
  "jsonrpc": "2.0",
  "method": "getUser",
  "params": {"id": 123},
  "id": 1
}
```

Used by Ethereum, LSP (Language Server Protocol), and many other systems.

### 5. Human-Friendly Variants: JSON5, HJSON

**Problem:** No comments, strict syntax  
**Solution:** Relaxed JSON with comments and trailing commas

```json5
{
  // Configuration for production
  name: 'my-app',
  port: 8080,
  features: {
    debug: false,  // Trailing comma OK
  },
}
```

### 6. Security Layer: JWS, JWE

**Problem:** No built-in security  
**Solution:** JSON Web Signatures and Encryption standards

{{< mermaid >}}
flowchart TB
    subgraph core["JSON Core (2001)"]
        json[JSON Specification<br/>RFC 8259]
    end
    
    subgraph extensions["JSON Ecosystem (2005-2025)"]
        schema[JSON Schema<br/>Validation]
        jsonb[JSONB/BSON<br/>Binary Storage]
        jsonl[JSON Lines<br/>Streaming]
        rpc[JSON-RPC<br/>Protocols]
        json5[JSON5/HJSON<br/>Human-Friendly]
        jwt[JWT/JWS/JWE<br/>Security]
    end
    
    json --> schema
    json --> jsonb
    json --> jsonl
    json --> rpc
    json --> json5
    json --> jwt
    
    style core fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style extensions fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

---

## Conclusion: JSON's Success Through Simplicity

JSON won not because it was perfect, but because it was simple enough to understand, implement, and adopt universally. Its weaknesses are real, but they're addressable through layered solutions.

**What made JSON win:**
- Minimal syntax (6 data types, simple rules)
- Browser native support (JSON.parse/stringify)
- Perfect timing (AJAX era, REST movement)
- Universal language support (parsers in everything)
- Good enough for most use cases

**What JSON lacks:**
- Schema validation (solved by JSON Schema)
- Binary efficiency (solved by JSONB, BSON, MessagePack)
- Streaming support (solved by JSON Lines)
- Protocol conventions (solved by JSON-RPC)
- Human-friendly syntax (solved by JSON5, HJSON)

The JSON ecosystem evolved to patch these gaps while preserving the core simplicity that made JSON successful.

{{< callout type="info" >}}
**Series Roadmap:** This series explores the JSON ecosystem:
- **Part 1** (this article): Origins and fundamental weaknesses
- **Part 2**: JSON Schema - validation, types, and contracts
- **Part 3**: Binary JSON formats - JSONB, BSON, MessagePack
- **Part 4**: Streaming JSON - JSON Lines and large datasets
- **Part 5**: JSON-RPC and protocol layers
- **Part 6**: Security - JWT, canonicalization, and attacks
{{< /callout >}}

In Part 2, we'll solve JSON's most critical weakness: the lack of validation. JSON Schema transforms JSON from "untyped text" into "strongly validated contracts" without sacrificing simplicity. We'll explore how to define schemas, validate data at runtime, generate code from schemas, and integrate validation into your entire stack.

**The core problem JSON Schema solves:** How do you maintain the simplicity of JSON while gaining the safety of typed, validated data?

**Next:** [You Don't Know JSON: Part 2 - JSON Schema and the Art of Validation]({{< relref "you-dont-know-json-part-2-json-schema.md" >}})

---

## Further Reading

**Specifications:**
- [RFC 8259 - JSON Standard](https://www.rfc-editor.org/rfc/rfc8259.html)
- [ECMA-404 - JSON Data Interchange Format](https://www.ecma-international.org/publications-and-standards/standards/ecma-404/)

**Historical:**
- [Douglas Crockford - The JSON Saga](https://www.youtube.com/watch?v=-C-JoyNuQJs)
- [JSON.org - Introducing JSON](https://www.json.org/)

**Comparisons:**
- [XML vs JSON Performance Benchmarks](https://www.xml.com/pub/a/2006/01/04/xml-vs-json.html)
- [Protocol Buffers vs JSON](https://blog.gopheracademy.com/advent-2016/go-and-package-focused-design/)
