# Appendix A: JSON Specification Summary

This appendix provides a comprehensive quick reference for JSON syntax, JSON Schema essentials, and binary format comparisons. Use it as a handy guide during development and system design.

## JSON Syntax Quick Reference

### Data Types

JSON supports exactly six data types. Understanding their precise definitions prevents common errors:

**String**
```json
"hello world"
"unicode: \u0048\u0065\u006C\u006C\u006F"
"escaped: \"quotes\" and \\backslashes\\"
""
```
- Must use double quotes (not single)
- Common escape sequences: `\"`, `\\`, `\/`, `\b`, `\f`, `\n`, `\r`, `\t`
- Unicode escape: `\uXXXX` (4 hexadecimal digits)

**Number**
```json
42
-17
3.14159
-2.5e10
1.23E-4
0
```
- No leading zeros (except for `0` itself)
- Decimal point requires digits on both sides
- Scientific notation: `e` or `E`, optional `+` or `-`
- No `NaN`, `Infinity`, or `undefined`

**Boolean**
```json
true
false
```
- Lowercase only
- No other truthy/falsy values

**null**
```json
null
```
- Represents intentional absence of value
- Not the same as `undefined`, `0`, or `""`

**Object**
```json
{
  "name": "Alice",
  "age": 30,
  "active": true
}
```
- Unordered collection of key-value pairs
- Keys must be strings
- Values can be any JSON type
- Trailing commas not allowed

**Array**
```json
[1, 2, 3]
["a", "b", "c"]
[{"id": 1}, {"id": 2}]
[]
```
- Ordered list of values
- Values can be any JSON type, mixed types allowed
- Trailing commas not allowed

### Syntax Rules

**Whitespace**
- Allowed: space (U+0020), tab (U+0009), line feed (U+000A), carriage return (U+000D)
- Can appear before/after any token
- Has no significance (unlike Python or YAML)

**Comments**
- **Not supported in standard JSON**
- Some parsers allow them as extension
- Use separate documentation for schema comments

**Nesting**
- Objects and arrays can contain other objects and arrays
- No depth limit in specification (implementations may have limits)
- Circular references not supported

### Common Gotchas

**Trailing Commas**
```json
// Invalid - trailing comma
{
  "name": "Alice",
  "age": 30,
}

// Valid - no trailing comma
{
  "name": "Alice", 
  "age": 30
}
```

**Undefined Values**
```json
// Invalid - undefined not supported
{"value": undefined}

// Use null instead
{"value": null}

// Or omit the key entirely
{}
```

**Single vs Double Quotes**
```json
// Invalid - single quotes
{'name': 'Alice'}

// Valid - double quotes
{"name": "Alice"}
```

**Numbers Leading Zeros**
```json
// Invalid - leading zero
{"count": 007}

// Valid - no leading zero
{"count": 7}

// Exception - zero itself
{"count": 0}
```

## JSON Schema Essentials

JSON Schema provides vocabulary for validating JSON documents. Here are the most commonly used keywords:

### Core Keywords

**type** - Specifies the expected data type
```json
{
  "type": "string"
}

{
  "type": ["string", "null"]
}
```

**required** - Lists required properties for objects
```json
{
  "type": "object",
  "required": ["email", "name"]
}
```

**properties** - Defines schema for object properties
```json
{
  "type": "object",
  "properties": {
    "email": {"type": "string"},
    "age": {"type": "integer"}
  }
}
```

**items** - Defines schema for array elements
```json
{
  "type": "array",
  "items": {"type": "string"}
}
```

### Validation Keywords

**String Validation**
```json
{
  "type": "string",
  "minLength": 1,
  "maxLength": 100,
  "pattern": "^[a-zA-Z0-9]+$",
  "format": "email"
}
```

**Number Validation**
```json
{
  "type": "number",
  "minimum": 0,
  "maximum": 100,
  "exclusiveMinimum": 0,
  "multipleOf": 0.01
}
```

**Array Validation**
```json
{
  "type": "array",
  "minItems": 1,
  "maxItems": 10,
  "uniqueItems": true
}
```

**Object Validation**
```json
{
  "type": "object",
  "minProperties": 1,
  "maxProperties": 10,
  "additionalProperties": false
}
```

**Enumeration**
```json
{
  "type": "string",
  "enum": ["red", "green", "blue"]
}
```

### Composition Keywords

**allOf** - Must match all schemas
```json
{
  "allOf": [
    {"type": "string"},
    {"minLength": 5}
  ]
}
```

**anyOf** - Must match at least one schema
```json
{
  "anyOf": [
    {"type": "string"},
    {"type": "number"}
  ]
}
```

**oneOf** - Must match exactly one schema
```json
{
  "oneOf": [
    {"type": "string"},
    {"type": "number"}
  ]
}
```

**not** - Must not match schema
```json
{
  "not": {"type": "null"}
}
```

### Advanced Features

**Conditionals** - Apply schemas based on conditions
```json
{
  "type": "object",
  "if": {
    "properties": {"type": {"const": "user"}}
  },
  "then": {
    "required": ["email"]
  },
  "else": {
    "required": ["apiKey"]
  }
}
```

**References** - Reuse schema definitions
```json
{
  "definitions": {
    "user": {
      "type": "object",
      "properties": {
        "name": {"type": "string"}
      }
    }
  },
  "type": "array",
  "items": {"$ref": "#/definitions/user"}
}
```

**Custom Formats** - Extend built-in formats
```json
{
  "type": "string",
  "format": "custom-id"
}
```

## Binary Format Comparison

When JSON's performance characteristics don't meet your needs, several binary alternatives provide different trade-offs:

| Format | Size Reduction | Speed Improvement | Schema Required | Primary Use Case |
|--------|---------------|-------------------|-----------------|------------------|
| **JSON** | Baseline | Baseline | Optional | APIs, Configuration, Human-readable data |
| **MessagePack** | ~20% smaller | ~2x faster | No | API optimization, Caching, Redis storage |
| **CBOR** | ~25% smaller | ~2x faster | No | IoT devices, Embedded systems, Constrained environments |
| **Protocol Buffers** | ~40% smaller | ~10x faster | Required | gRPC services, Internal APIs, High-performance systems |
| **Apache Avro** | ~35% smaller | ~5x faster | Required | Big data pipelines, Kafka, Schema evolution |
| **FlatBuffers** | ~30% smaller | ~100x faster | Required | Game development, Real-time systems, Zero-copy access |
| **Apache Parquet** | ~60% smaller | Variable | Required | Analytics, Data warehousing, Columnar storage |

### When to Choose Each Format

**Stick with JSON when:**
- Human readability matters
- Debugging is frequent
- Schema flexibility is important
- Performance is adequate
- Ecosystem integration is critical

**Choose MessagePack when:**
- You need moderate performance gains
- Schema flexibility must be preserved
- Migration from JSON should be easy
- Redis or similar systems are involved

**Choose CBOR when:**
- Working with constrained devices
- Standards compliance matters (IETF RFC 7049)
- Need better number representation than JSON
- IoT or embedded contexts

**Choose Protocol Buffers when:**
- Maximum performance is critical
- Strong typing is beneficial
- Code generation is acceptable
- gRPC adoption is planned

**Choose Apache Avro when:**
- Schema evolution is critical
- Working with Kafka or Hadoop ecosystems
- Need dynamic typing with schemas
- Big data processing is the primary use case

**Choose FlatBuffers when:**
- Zero-copy access is required
- Memory usage must be minimized
- Real-time performance is critical
- Game development or similar constraints

**Choose Parquet when:**
- Analytics workloads dominate
- Columnar access patterns exist
- Data compression is critical
- Integration with analytics tools matters

### Migration Strategies

**Gradual Migration:**
1. Introduce binary format for internal services
2. Keep JSON for external APIs
3. Use gateways to translate between formats
4. Migrate service-by-service based on performance needs

**Dual Format Support:**
1. Design APIs to support multiple content types
2. Use Content-Type headers for negotiation
3. Generate schemas for both formats from single source
4. Test both paths thoroughly

**Schema-First Approach:**
1. Define schemas in neutral format (JSON Schema, OpenAPI)
2. Generate code for all target formats
3. Version schemas independently from implementations
4. Use schema registries for runtime validation

This specification summary provides the foundational knowledge needed to work effectively with JSON and make informed decisions about when to adopt alternatives. Keep it handy during development for quick reference on syntax rules, validation patterns, and format trade-offs.