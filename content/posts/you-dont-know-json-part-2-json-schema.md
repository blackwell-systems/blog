---
title: "You Don't Know JSON: Part 2 - JSON Schema and the Art of Validation"
date: 2025-12-15
draft: false
series: ["you-dont-know-json"]
seriesOrder: 2
tags: ["json", "json-schema", "validation", "api-design", "openapi", "swagger", "type-safety", "schema-validation", "ajv", "jsonschema", "data-validation", "typescript", "go", "python", "rest-api", "microservices", "contract-testing", "api-contracts", "schema-generation", "runtime-validation"]
categories: ["fundamentals", "programming"]
description: "Master JSON Schema: the validation layer that transforms JSON from untyped text into strongly-validated contracts. Learn schemas, composition patterns, code generation, and OpenAPI integration with real-world examples."
summary: "JSON lacks types and validation - any structure parses successfully. JSON Schema solves this by adding a validation layer without changing JSON itself. Learn how to define schemas, validate at runtime, generate code, and build type-safe APIs."
---

In [Part 1]({{< relref "you-dont-know-json-part-1-origins.md" >}}), we explored JSON's triumph over XML and its fundamental weakness: **no built-in validation**. JSON parsers accept any syntactically valid structure, but they can't tell you if the data makes sense for your application.

```json
{"age": "thirty"}
```

```json
{"age": 30}
```

```json
{"age": null}
```

All three parse successfully. But which is correct? Your application crashes at runtime when it expects a number.

{{< callout type="info" >}}
**What XML Had:** XSD (XML Schema Definition) - 2001

**XML's approach:** Built-in validation system with complex type hierarchies, inheritance, constraints, and namespaces integrated into the core specification.

```xml
<!-- XSD schema -->
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <xs:element name="user">
    <xs:complexType>
      <xs:sequence>
        <xs:element name="age" type="xs:integer"/>
        <xs:element name="email" type="xs:string"/>
      </xs:sequence>
    </xs:complexType>
  </xs:element>
</xs:schema>
```

**Benefit:** Comprehensive type system with inheritance and built-in validation  
**Cost:** Extreme complexity, tight coupling to XML parsers, difficult to learn

**JSON's approach:** External validation layer (JSON Schema) - separate standard

**Architecture shift:** Built-in validation → External validation, Complex type system → Simple constraint-based, Monolithic → Modular
{{< /callout >}}

JSON Schema solves this. It's a vocabulary for defining the structure, types, and constraints of JSON documents. Think of it as TypeScript for JSON - adding type safety and validation without changing the underlying format.

This article covers:
- How JSON Schema works (concepts and syntax)
- Validation in Go, JavaScript, and Python
- Advanced patterns (composition, references, recursion)
- Code generation from schemas
- OpenAPI integration
- Real-world best practices

---

## Running Example: Validating Our User API

In [Part 1]({{< relref "you-dont-know-json-part-1-origins.md" >}}#running-example-building-a-user-api), we introduced a User API for a social platform. We have basic JSON, but no validation:

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

**The problems:**
- Clients could send `"email": "not-an-email"`
- Nothing prevents `"followers": -1000`
- Users could set `"verified": true` themselves
- No validation on username length or format

**What we need:**
- Email format validation
- Numeric ranges (followers ≥ 0)
- Required fields (username, email)
- String constraints (username 3-20 chars)
- Read-only fields (id, verified, created)

JSON Schema will solve all of these.

---

## The Core Problem: Trust Nothing

Every system boundary is a vulnerability. Never trust input from external sources - users, other services, configuration files, or databases. Validate at the boundary before data enters your system.

---

## JSON Schema Fundamentals

### What is JSON Schema?

JSON Schema is itself a JSON document that describes other JSON documents.

**Let's validate our User API from Part 1:**

**User data:**
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

**User schema:**
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://api.example.com/schemas/user.json",
  "title": "User",
  "description": "Social platform user profile",
  "type": "object",
  "properties": {
    "id": {
      "type": "string",
      "pattern": "^user-[a-z0-9]+$",
      "readOnly": true
    },
    "username": {
      "type": "string",
      "minLength": 3,
      "maxLength": 20,
      "pattern": "^[a-z0-9_]+$"
    },
    "email": {
      "type": "string",
      "format": "email"
    },
    "created": {
      "type": "string",
      "format": "date-time",
      "readOnly": true
    },
    "bio": {
      "type": "string",
      "maxLength": 500
    },
    "followers": {
      "type": "integer",
      "minimum": 0
    },
    "verified": {
      "type": "boolean",
      "readOnly": true
    }
  },
  "required": ["username", "email"],
  "additionalProperties": false
}
```

**This schema enforces:**
- Required fields (username, email)
- Username format (3-20 chars, lowercase alphanumeric + underscore)
- Valid email format
- Non-negative followers count
- Read-only fields (id, created, verified) - clients can't set these
- No additional fields allowed

**Key concepts:**
- `$schema` - Declares which JSON Schema version you're using
- `type` - The data type this schema validates
- `properties` - Object field definitions
- `required` - Fields that must be present
- `additionalProperties` - Whether extra fields are allowed

### Schema Evolution: Draft Versions

JSON Schema has evolved through multiple draft versions:

| Draft | Year | Key Features |
|-------|------|--------------|
| Draft 4 | 2013 | First widely adopted version |
| Draft 6 | 2017 | `const`, `contains`, property dependencies |
| Draft 7 | 2018 | `if/then/else`, `readOnly`, `writeOnly` |
| Draft 2019-09 | 2019 | `$recursiveRef`, `unevaluatedProperties` |
| Draft 2020-12 | 2020 | `prefixItems`, `$dynamicRef` (current) |

**Always specify `$schema`:** Different validators support different drafts. Explicit declaration prevents compatibility issues.

{{< mermaid >}}
timeline
    title JSON Schema Evolution
    2013 : Draft 4 - First major adoption
         : Basic validation keywords
    2017 : Draft 6 - Property dependencies
         : const keyword
    2018 : Draft 7 - Conditional schemas
         : readOnly/writeOnly
    2019 : Draft 2019-09 - Recursive refs
         : Vocabulary system
    2020 : Draft 2020-12 - Dynamic refs
         : Tuple validation
    2024+ : Widespread tooling support
         : OpenAPI 3.1 alignment
{{< /mermaid >}}

---

## Core Validation Types

### String Validation

```json
{
  "type": "string",
  "minLength": 3,
  "maxLength": 100,
  "pattern": "^[A-Za-z0-9_-]+$",
  "format": "email"
}
```

**Constraints:**
- `minLength` / `maxLength` - Character count limits
- `pattern` - Regular expression (ECMAScript regex flavor)
- `format` - Built-in formats (see below)

**Built-in formats:**
```json
"format": "date-time"   // "2023-01-15T10:30:00Z"
"format": "date"        // "2023-01-15"
"format": "time"        // "10:30:00"
"format": "email"       // "user@example.com"
"format": "hostname"    // "example.com"
"format": "ipv4"        // "192.168.1.1"
"format": "ipv6"        // "2001:0db8::1"
"format": "uri"         // "https://example.com/path"
"format": "uuid"        // "550e8400-e29b-41d4-a716-446655440000"
"format": "regex"       // Valid regular expression
```

**Example: Username validation**
```json
{
  "type": "string",
  "minLength": 3,
  "maxLength": 20,
  "pattern": "^[a-z0-9_]+$",
  "description": "Lowercase alphanumeric with underscores"
}
```

### Number Validation

```json
{
  "type": "integer",
  "minimum": 0,
  "maximum": 150,
  "multipleOf": 5
}
```

```json
{
  "type": "number",
  "exclusiveMinimum": 0,
  "exclusiveMaximum": 100
}
```

**Number vs Integer:**
- `integer` - Whole numbers only
- `number` - Any numeric value (integers and floats)

**Constraints:**
- `minimum` / `maximum` - Inclusive bounds
- `exclusiveMinimum` / `exclusiveMaximum` - Exclusive bounds
- `multipleOf` - Must be divisible by value

### Boolean and Null

```json
{"type": "boolean"}
```

```json
{"type": "null"}
```

**Multiple types allowed:**
```json
{
  "type": ["string", "null"]
}
```

This accepts strings or `null`, useful for optional fields.

### Array Validation

**Simple arrays (all items same type):**
```json
{
  "type": "array",
  "items": {"type": "string"},
  "minItems": 1,
  "maxItems": 10,
  "uniqueItems": true
}
```

**Tuple validation (fixed positions):**
```json
{
  "type": "array",
  "prefixItems": [
    {"type": "string"},
    {"type": "number"},
    {"type": "boolean"}
  ],
  "items": false
}
```

This validates `["name", 42, true]` but rejects arrays with different types or length.

**Example: Tag list**
```json
{
  "type": "array",
  "items": {
    "type": "string",
    "minLength": 1,
    "maxLength": 50
  },
  "minItems": 1,
  "maxItems": 20,
  "uniqueItems": true
}
```

### Object Validation

```json
{
  "type": "object",
  "properties": {
    "name": {"type": "string"},
    "email": {"type": "string", "format": "email"},
    "age": {"type": "integer", "minimum": 0}
  },
  "required": ["name", "email"],
  "additionalProperties": false
}
```

**Key concepts:**
- `properties` - Expected fields
- `required` - Mandatory fields (array of property names)
- `additionalProperties` - Controls unexpected fields

**`additionalProperties` strategies:**

```json
"additionalProperties": false
```
Rejects any field not in `properties`. Strict validation.

```json
"additionalProperties": true
```
Allows any extra fields. Flexible validation.

```json
"additionalProperties": {"type": "string"}
```
Allows extra fields but validates their type.

**Pattern properties (dynamic field names):**
```json
{
  "type": "object",
  "patternProperties": {
    "^[a-z]+_id$": {"type": "integer"}
  }
}
```

Validates `{"user_id": 123, "order_id": 456}` where field names match the pattern.

{{< mermaid >}}
flowchart TB
    subgraph validation["Validation Process"]
        start[Receive JSON]
        parse[Parse JSON]
        validate[Apply Schema]
        
        start --> parse
        parse --> validate
        
        validate --> valid{Valid?}
        valid -->|Yes| accept[Accept Data]
        valid -->|No| reject[Reject with Errors]
    end
    
    subgraph schema["Schema Components"]
        types[Type Checking]
        constraints[Constraints]
        required[Required Fields]
        formats[Format Validation]
        
        validate --> types
        validate --> constraints
        validate --> required
        validate --> formats
    end
    
    style validation fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style schema fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

---

## Schema Composition: Building Complex Schemas

### allOf: Intersection (AND)

Combines multiple schemas - data must satisfy all:

```json
{
  "allOf": [
    {
      "type": "object",
      "properties": {
        "name": {"type": "string"}
      },
      "required": ["name"]
    },
    {
      "type": "object",
      "properties": {
        "email": {"type": "string", "format": "email"}
      },
      "required": ["email"]
    }
  ]
}
```

Data must have both `name` and `email`. Useful for combining base schemas with extensions.

**Use case: Adding audit fields**
```json
{
  "allOf": [
    {"$ref": "#/$defs/BaseEntity"},
    {
      "properties": {
        "created_at": {"type": "string", "format": "date-time"},
        "updated_at": {"type": "string", "format": "date-time"}
      },
      "required": ["created_at", "updated_at"]
    }
  ]
}
```

### anyOf: Union (OR)

Data must satisfy at least one schema:

```json
{
  "anyOf": [
    {"type": "string"},
    {"type": "number"},
    {"type": "null"}
  ]
}
```

Accepts strings, numbers, or null. Useful for flexible types.

**Use case: Multiple contact methods**
```json
{
  "type": "object",
  "anyOf": [
    {"required": ["email"]},
    {"required": ["phone"]},
    {"required": ["address"]}
  ],
  "properties": {
    "email": {"type": "string", "format": "email"},
    "phone": {"type": "string"},
    "address": {"type": "string"}
  }
}
```

User must provide at least one contact method.

### oneOf: Exclusive OR (XOR)

Data must satisfy exactly one schema:

```json
{
  "oneOf": [
    {
      "type": "object",
      "properties": {
        "credit_card": {"type": "string"}
      },
      "required": ["credit_card"]
    },
    {
      "type": "object",
      "properties": {
        "paypal_email": {"type": "string", "format": "email"}
      },
      "required": ["paypal_email"]
    }
  ]
}
```

User must choose exactly one payment method, not both.

### not: Negation

Data must NOT match schema:

```json
{
  "not": {
    "type": "null"
  }
}
```

Rejects `null` values. Useful for excluding specific patterns.

**Combining composition:**
```json
{
  "allOf": [
    {"$ref": "#/$defs/User"},
    {
      "not": {
        "properties": {
          "role": {"const": "admin"}
        }
      }
    }
  ]
}
```

Accepts users who are not admins.

{{< mermaid >}}
flowchart LR
    subgraph composition["Schema Composition"]
        allof[allOf<br/>Intersection]
        anyof[anyOf<br/>Union]
        oneof[oneOf<br/>Exclusive]
        notof[not<br/>Negation]
    end
    
    subgraph examples["Use Cases"]
        e1[Combine schemas]
        e2[Flexible types]
        e3[Exclusive choice]
        e4[Exclude patterns]
    end
    
    allof --> e1
    anyof --> e2
    oneof --> e3
    notof --> e4
    
    style composition fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style examples fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

---

## Schema Reuse and References

### Local Definitions with $defs

Define reusable schemas within the document:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "user": {"$ref": "#/$defs/User"},
    "manager": {"$ref": "#/$defs/User"}
  },
  "$defs": {
    "User": {
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "email": {"type": "string", "format": "email"}
      },
      "required": ["name", "email"]
    }
  }
}
```

**Benefits:**
- DRY principle (Don't Repeat Yourself)
- Single source of truth for shared types
- Easier maintenance

### External References

Reference schemas in other files:

```json
{
  "$ref": "https://example.com/schemas/user.json"
}
```

```json
{
  "$ref": "./user.json"
}
```

```json
{
  "$ref": "./user.json#/$defs/Address"
}
```

**Use case: Shared schema library**
```
schemas/
  common/
    address.json
    contact.json
  user.json
  order.json
```

```json
{
  "$ref": "./common/address.json"
}
```

### Recursive Schemas

Self-referencing schemas for tree structures:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$defs": {
    "Node": {
      "type": "object",
      "properties": {
        "value": {"type": "string"},
        "children": {
          "type": "array",
          "items": {"$ref": "#/$defs/Node"}
        }
      }
    }
  },
  "$ref": "#/$defs/Node"
}
```

Validates nested tree structures:
```json
{
  "value": "root",
  "children": [
    {
      "value": "child1",
      "children": []
    },
    {
      "value": "child2",
      "children": [
        {"value": "grandchild", "children": []}
      ]
    }
  ]
}
```

---

## Validation in Practice: Code Examples

### JavaScript with AJV

AJV (Another JSON Validator) is the fastest JSON Schema validator for JavaScript:

```bash
npm install ajv ajv-formats
```

**Basic validation:**
```javascript
const Ajv = require('ajv');
const addFormats = require('ajv-formats');

const ajv = new Ajv({allErrors: true});
addFormats(ajv);

const schema = {
  type: 'object',
  properties: {
    username: {
      type: 'string',
      minLength: 3,
      maxLength: 20,
      pattern: '^[a-z0-9_]+$'
    },
    email: {
      type: 'string',
      format: 'email'
    },
    age: {
      type: 'integer',
      minimum: 0,
      maximum: 150
    }
  },
  required: ['username', 'email'],
  additionalProperties: false
};

const validate = ajv.compile(schema);

const data = {
  username: 'alice',
  email: 'alice@example.com',
  age: 30
};

if (validate(data)) {
  console.log('Valid!');
} else {
  console.log('Validation errors:', validate.errors);
}
```

**Error output:**
```javascript
[
  {
    instancePath: '/email',
    schemaPath: '#/properties/email/format',
    keyword: 'format',
    params: { format: 'email' },
    message: 'must match format "email"'
  }
]
```

**TypeScript integration:**
```typescript
import Ajv, {JSONSchemaType} from 'ajv';

interface User {
  username: string;
  email: string;
  age?: number;
}

const schema: JSONSchemaType<User> = {
  type: 'object',
  properties: {
    username: {type: 'string', minLength: 3},
    email: {type: 'string', format: 'email'},
    age: {type: 'integer', nullable: true}
  },
  required: ['username', 'email'],
  additionalProperties: false
};

const ajv = new Ajv();
const validate = ajv.compile(schema);

const data: unknown = JSON.parse(input);

if (validate(data)) {
  // TypeScript knows data is User here
  console.log(data.username);
}
```

### Go with gojsonschema

```bash
go get github.com/xeipuuv/gojsonschema
```

```go
package main

import (
    "fmt"
    "github.com/xeipuuv/gojsonschema"
)

func main() {
    schemaJSON := `{
        "type": "object",
        "properties": {
            "username": {
                "type": "string",
                "minLength": 3,
                "maxLength": 20
            },
            "email": {
                "type": "string",
                "format": "email"
            },
            "age": {
                "type": "integer",
                "minimum": 0
            }
        },
        "required": ["username", "email"],
        "additionalProperties": false
    }`

    dataJSON := `{
        "username": "alice",
        "email": "alice@example.com",
        "age": 30
    }`

    schemaLoader := gojsonschema.NewStringLoader(schemaJSON)
    documentLoader := gojsonschema.NewStringLoader(dataJSON)

    result, err := gojsonschema.Validate(schemaLoader, documentLoader)
    if err != nil {
        panic(err)
    }

    if result.Valid() {
        fmt.Println("Document is valid")
    } else {
        fmt.Println("Document is invalid:")
        for _, err := range result.Errors() {
            fmt.Printf("- %s: %s\n", err.Field(), err.Description())
        }
    }
}
```

**Struct-based schema generation:**
```go
type User struct {
    Username string `json:"username" jsonschema:"required,minLength=3,maxLength=20"`
    Email    string `json:"email" jsonschema:"required,format=email"`
    Age      int    `json:"age,omitempty" jsonschema:"minimum=0"`
}

schema := jsonschema.Reflect(&User{})
```

### Python with jsonschema

```bash
pip install jsonschema
```

```python
from jsonschema import validate, ValidationError, Draft7Validator
import jsonschema

schema = {
    "type": "object",
    "properties": {
        "username": {
            "type": "string",
            "minLength": 3,
            "maxLength": 20,
            "pattern": "^[a-z0-9_]+$"
        },
        "email": {
            "type": "string",
            "format": "email"
        },
        "age": {
            "type": "integer",
            "minimum": 0,
            "maximum": 150
        }
    },
    "required": ["username", "email"],
    "additionalProperties": False
}

data = {
    "username": "alice",
    "email": "alice@example.com",
    "age": 30
}

try:
    validate(instance=data, schema=schema)
    print("Valid!")
except ValidationError as e:
    print(f"Validation error: {e.message}")
    print(f"Failed at path: {e.json_path}")
```

**Detailed error handling:**
```python
validator = Draft7Validator(schema)
errors = sorted(validator.iter_errors(data), key=lambda e: e.path)

for error in errors:
    path = '.'.join(str(p) for p in error.path)
    print(f"Error at {path}: {error.message}")
```

**Pydantic integration (Pythonic validation):**
```python
from pydantic import BaseModel, EmailStr, Field

class User(BaseModel):
    username: str = Field(..., min_length=3, max_length=20, regex="^[a-z0-9_]+$")
    email: EmailStr
    age: int = Field(..., ge=0, le=150)

    class Config:
        extra = 'forbid'  # No additional fields

# Validation happens automatically
user = User(username="alice", email="alice@example.com", age=30)

# Export JSON Schema
print(User.schema_json(indent=2))
```

{{< callout type="info" >}}
**Performance Tip:** Compile schemas once and reuse the validator. Schema compilation is expensive, but validation is fast. In AJV and most libraries, compile at application startup, not per-request.
{{< /callout >}}

---

## Code Generation from Schemas

### TypeScript from JSON Schema

**quicktype** generates TypeScript types:

```bash
npm install -g quicktype
```

```bash
quicktype -s schema user-schema.json -o user.ts
```

**Output:**
```typescript
export interface User {
    username: string;
    email:    string;
    age?:     number;
}
```

**json-schema-to-typescript:**
```bash
npm install -D json-schema-to-typescript
```

```javascript
import {compile} from 'json-schema-to-typescript';

const schema = {...};
const ts = await compile(schema, 'User');
console.log(ts);
```

### Go from JSON Schema

**go-jsonschema:**
```bash
go install github.com/atombender/go-jsonschema/cmd/gojsonschema@latest
```

```bash
gojsonschema -p models user-schema.json
```

**Output:**
```go
package models

type User struct {
    Username string `json:"username"`
    Email    string `json:"email"`
    Age      *int   `json:"age,omitempty"`
}
```

### Python from JSON Schema

**datamodel-code-generator:**
```bash
pip install datamodel-code-generator
```

```bash
datamodel-codegen --input user-schema.json --output user.py
```

**Output:**
```python
from pydantic import BaseModel, EmailStr, Field

class User(BaseModel):
    username: str = Field(..., min_length=3, max_length=20)
    email: EmailStr
    age: int = Field(None, ge=0, le=150)
```

{{< mermaid >}}
flowchart LR
    subgraph sources["Schema Sources"]
        manual[Hand-written<br/>Schema]
        generated[Generated from<br/>Code]
        openapi[OpenAPI<br/>Spec]
    end
    
    subgraph targets["Generated Artifacts"]
        types[Type Definitions<br/>TS, Go, Python]
        validators[Validators]
        docs[Documentation]
    end
    
    manual --> targets
    generated --> targets
    openapi --> targets
    
    style sources fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style targets fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

---

## OpenAPI Integration

OpenAPI 3.1 uses JSON Schema for request/response validation:

```yaml
openapi: 3.1.0
info:
  title: User API
  version: 1.0.0

paths:
  /users:
    post:
      summary: Create user
      requestBody:
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/User'
      responses:
        '201':
          description: Created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'

components:
  schemas:
    User:
      type: object
      properties:
        username:
          type: string
          minLength: 3
          maxLength: 20
        email:
          type: string
          format: email
        age:
          type: integer
          minimum: 0
      required:
        - username
        - email
      additionalProperties: false
```

**Benefits:**
- Single source of truth (schema + docs + validation)
- Code generation for clients and servers
- Contract testing
- Interactive documentation (Swagger UI)

**Generate validators from OpenAPI:**
```bash
openapi-generator-cli generate \
  -i openapi.yaml \
  -g typescript-axios \
  -o ./generated
```

---

## Schema Evolution and Versioning

### Safe Changes (Non-Breaking)

**+ Add optional field:**
```json
{
  "properties": {
    "name": {"type": "string"},
    "email": {"type": "string"},
    "phone": {"type": "string"}
  },
  "required": ["name", "email"]
}
```

Old data still validates. New field is optional.

**+ Relax constraints:**
```json
{
  "minLength": 3
}
```
Change to:
```json
{
  "minLength": 1
}
```

More permissive. Old data still validates.

**+ Remove required field:**
```json
"required": ["name", "email", "age"]
```
Change to:
```json
"required": ["name", "email"]
```

### Breaking Changes (Dangerous)

**- Make field required:**
```json
"required": ["name"]
```
Change to:
```json
"required": ["name", "email"]
```

Old data without `email` fails validation.

**- Restrict type:**
```json
{"type": ["string", "null"]}
```
Change to:
```json
{"type": "string"}
```

Old data with `null` fails.

**- Tighten constraints:**
```json
{"minLength": 3}
```
Change to:
```json
{"minLength": 10}
```

Old data with shorter strings fails.

### Versioning Strategies

**1. Schema $id versioning:**
```json
{
  "$id": "https://example.com/schemas/user/v2.json",
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  ...
}
```

**2. API versioning:**
```
/v1/users  → user-schema-v1.json
/v2/users  → user-schema-v2.json
```

**3. Feature flags in schema:**
```json
{
  "allOf": [
    {"$ref": "#/$defs/BaseUser"},
    {
      "if": {
        "properties": {
          "version": {"const": 2}
        }
      },
      "then": {
        "properties": {
          "new_field": {"type": "string"}
        },
        "required": ["new_field"]
      }
    }
  ]
}
```

{{< callout type="warning" >}}
**Migration Strategy:** When introducing breaking schema changes, support both old and new versions during a transition period. Use API versioning or content negotiation to route requests to appropriate validators.
{{< /callout >}}

---

## Best Practices

### 1. Always Specify $schema

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema"
}
```

Different validators support different drafts. Explicit declaration prevents confusion.

### 2. Use Descriptive Field Names and Descriptions

```json
{
  "properties": {
    "email": {
      "type": "string",
      "format": "email",
      "description": "User's primary email address for notifications"
    }
  }
}
```

Schemas are documentation. Make them readable.

### 3. Leverage $defs for Reusable Types

```json
{
  "$defs": {
    "Email": {
      "type": "string",
      "format": "email"
    },
    "Username": {
      "type": "string",
      "minLength": 3,
      "pattern": "^[a-z0-9_]+$"
    }
  }
}
```

DRY principle. Define once, reference everywhere.

### 4. Include Examples

```json
{
  "type": "string",
  "format": "email",
  "examples": [
    "user@example.com",
    "admin@company.org"
  ]
}
```

Examples help developers understand expected format.

### 5. Set additionalProperties Explicitly

```json
{
  "additionalProperties": false
}
```

**Or:**
```json
{
  "additionalProperties": true
}
```

Never leave it implicit. Be clear about whether extra fields are allowed.

### 6. Validate at System Boundaries

```javascript
// API endpoint
app.post('/api/users', (req, res) => {
  if (!validate(req.body)) {
    return res.status(400).json({
      error: 'Validation failed',
      details: validate.errors
    });
  }
  
  // Business logic here
});
```

As discussed earlier - validate at boundaries, reject early.

### 7. Compile Schemas Once

```javascript
// At startup (once)
const validateUser = ajv.compile(userSchema);

// Per request (many times)
app.post('/users', (req, res) => {
  if (!validateUser(req.body)) {
    return res.status(400).json(validateUser.errors);
  }
});
```

Schema compilation is expensive. Do it once at application startup.

### 8. Test Your Schemas

```javascript
describe('User Schema', () => {
  it('accepts valid user', () => {
    const data = {username: 'alice', email: 'alice@example.com'};
    expect(validate(data)).toBe(true);
  });

  it('rejects missing required field', () => {
    const data = {username: 'alice'};
    expect(validate(data)).toBe(false);
    expect(validate.errors[0].message).toContain('required');
  });

  it('rejects invalid email format', () => {
    const data = {username: 'alice', email: 'not-an-email'};
    expect(validate(data)).toBe(false);
  });
});
```

Schemas are code. Test them like code.

---

## Common Pitfalls

### 1. Over-Constraining Schemas

**Too strict:**
```json
{
  "type": "string",
  "pattern": "^[A-Z][a-z]+$"
}
```

Rejects valid names like "O'Brien", "van Gogh", "José".

**Better:**
```json
{
  "type": "string",
  "minLength": 1,
  "maxLength": 100
}
```

Let application logic handle complex name validation.

### 2. Regex Performance Issues

**Dangerous (exponential backtracking):**
```json
{
  "pattern": "^(a+)+b$"
}
```

Can cause ReDoS (Regular Expression Denial of Service).

**Safe:**
```json
{
  "pattern": "^a+b$"
}
```

Avoid nested quantifiers.

### 3. Not Handling additionalProperties

**Forgetting to set it:**
```json
{
  "properties": {
    "name": {"type": "string"}
  }
}
```

Accepts ANY extra fields by default. Be explicit.

### 4. Format Validation Inconsistencies

Format keywords are optional in JSON Schema spec. Not all validators implement all formats.

**Solution:** Use regex patterns for critical validation:
```json
{
  "type": "string",
  "pattern": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
}
```

### 5. Misunderstanding Draft Differences

Draft 4 uses `definitions`. Draft 2020-12 uses `$defs`.

```json
// Draft 4
{"definitions": {...}}

// Draft 2020-12
{"$defs": {...}}
```

Always specify `$schema` to avoid confusion.

---

## Alternatives to JSON Schema

### Zod (TypeScript-First)

```typescript
import {z} from 'zod';

const userSchema = z.object({
  username: z.string().min(3).max(20).regex(/^[a-z0-9_]+$/),
  email: z.string().email(),
  age: z.number().int().nonnegative().optional()
});

type User = z.infer<typeof userSchema>;

const result = userSchema.safeParse(data);
if (result.success) {
  console.log(result.data);
} else {
  console.log(result.error.errors);
}
```

**Benefits:**
- TypeScript-native (types inferred from schema)
- Better DX (developer experience)
- Composable validators

**Trade-off:** JavaScript ecosystem only.

### Joi (JavaScript Validation)

```javascript
const Joi = require('joi');

const schema = Joi.object({
  username: Joi.string().min(3).max(20).pattern(/^[a-z0-9_]+$/),
  email: Joi.string().email(),
  age: Joi.number().integer().min(0).optional()
});

const {error, value} = schema.validate(data);
```

**Benefits:** Mature, expressive API, good error messages.

**Trade-off:** JavaScript only, no JSON Schema compatibility.

### Pydantic (Python)

```python
from pydantic import BaseModel, EmailStr, Field

class User(BaseModel):
    username: str = Field(..., min_length=3, max_length=20)
    email: EmailStr
    age: int = Field(None, ge=0)

user = User(**data)  # Automatic validation
```

**Benefits:** Pythonic, integrated with FastAPI, excellent performance.

**Trade-off:** Python only.

### When to Use JSON Schema

**Use JSON Schema when:**
- + Cross-language validation needed
- + OpenAPI integration required
- + Standard-based validation important
- + Schema portability matters
- + Documentation generation from schema

**Use language-specific alternatives when:**
- + Single-language project
- + Better DX is priority
- + Type inference important
- + Framework integration available (FastAPI + Pydantic)

---

## Real-World Use Cases

### 1. API Request Validation

```javascript
app.post('/api/users', async (req, res) => {
  if (!validateUser(req.body)) {
    return res.status(400).json({
      error: 'Invalid request',
      details: validateUser.errors
    });
  }

  const user = await db.users.create(req.body);
  res.status(201).json(user);
});
```

### 2. Configuration File Validation

```json
{
  "$schema": "https://example.com/config-schema.json",
  "database": {
    "host": "localhost",
    "port": 5432
  }
}
```

IDE provides autocomplete and validation while editing.

### 3. Contract Testing

```javascript
describe('User API Contract', () => {
  it('returns user matching schema', async () => {
    const response = await fetch('/api/users/1');
    const data = await response.json();
    
    expect(validateUser(data)).toBe(true);
  });
});
```

### 4. Database Schema Enforcement

PostgreSQL with JSON Schema:

```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  data JSONB,
  CONSTRAINT valid_user CHECK (
    jsonb_matches_schema('{"type": "object", ...}', data)
  )
);
```

### 5. Message Queue Validation

```javascript
// Producer validates before sending
if (!validateEvent(event)) {
  throw new Error('Invalid event');
}
await queue.publish('events', event);

// Consumer validates on receipt
queue.subscribe('events', (msg) => {
  if (!validateEvent(msg)) {
    logger.error('Invalid message', msg);
    return;
  }
  
  processEvent(msg);
});
```

---

## Conclusion: JSON + Schema = Type Safety

JSON Schema transforms JSON from "any structure passes" to "only valid structures accepted." It bridges the gap between dynamic typing and type safety without changing JSON itself.

**What you learned:**
- JSON Schema provides validation layer for JSON
- Schemas define types, constraints, and structure
- Composition patterns (allOf, anyOf, oneOf) enable complex validation
- References ($ref, $defs) enable schema reuse
- Code generation creates types from schemas
- OpenAPI uses JSON Schema for API contracts
- Schema evolution requires careful planning

**The transformation:** JSON Schema adds the contract layer JSON was missing. It enables:
- Type safety without changing JSON format
- API contracts that are both docs and validation
- Code generation from a single source of truth
- Runtime validation with compile-time-like guarantees

{{< callout type="success" >}}
**Best Practice Summary:**
- Specify `$schema` version explicitly
- Validate at system boundaries (API endpoints, file readers)
- Compile schemas once at startup
- Use `$defs` for reusable components
- Set `additionalProperties` explicitly
- Test your schemas like code
- Version schemas when making breaking changes
{{< /callout >}}

In Part 3, we'll explore binary JSON formats (JSONB, BSON, MessagePack) - solving JSON's size and performance limitations while maintaining JSON-like structure.

**Next:** Part 3 - Binary JSON: When Text Format Isn't Fast Enough

---

## Further Reading

**Specifications:**
- [JSON Schema Specification](https://json-schema.org/specification.html)
- [Understanding JSON Schema (Official Guide)](https://json-schema.org/understanding-json-schema/)
- [OpenAPI 3.1 and JSON Schema](https://spec.openapis.org/oas/v3.1.0)

**Tools:**
- [AJV - JavaScript Validator](https://ajv.js.org/)
- [JSON Schema Validator (online)](https://www.jsonschemavalidator.net/)
- [quicktype - Code Generation](https://quicktype.io/)

**Libraries:**
- [Zod (TypeScript)](https://zod.dev/)
- [Pydantic (Python)](https://docs.pydantic.dev/)
- [gojsonschema (Go)](https://github.com/xeipuuv/gojsonschema)
