---
title: "Chapter 11: API Design with JSON"
status: TO BE WRITTEN
target_words: 8000
---

# Chapter 11: API Design with JSON

**Status:** To be written (Q2 2026)  
**Target length:** ~8,000 words  

## Planned Content

### Sections to Write

1. **REST API Best Practices**
   - Resource naming conventions
   - HTTP method usage (GET, POST, PUT, DELETE, PATCH)
   - Status code selection
   - URL structure and versioning
   - HATEOAS and hypermedia
   - Richardson Maturity Model

2. **Pagination Patterns**
   - Offset-based pagination
   - Cursor-based pagination
   - Keyset pagination
   - Performance implications
   - Response format standards

3. **Error Response Formats**
   - Standard error structure
   - HTTP status codes
   - Error code systems
   - Field-level validation errors
   - Consistent formatting across endpoints

4. **API Versioning Strategies**
   - URL versioning (/v1/, /v2/)
   - Header versioning (Accept: application/vnd.api+json; version=2)
   - Query parameter versioning (?version=2)
   - Semantic versioning for APIs
   - Deprecation strategies
   - Migration paths

5. **Rate Limiting**
   - Implementation approaches
   - Response headers (X-RateLimit-*)
   - Error responses (429 Too Many Requests)
   - Client-side handling
   - Distributed rate limiting

6. **Content Negotiation**
   - Accept headers
   - JSON vs MessagePack vs XML
   - Compression (gzip, brotli)
   - Language selection
   - API versioning via content types

7. **Security Considerations**
   - HTTPS enforcement
   - CORS configuration
   - Input validation
   - SQL injection prevention
   - XSS prevention in JSON responses
   - Rate limiting for security

### Code Examples

Multi-language API implementations:
- **Node.js/Express:** Complete REST API with all patterns
- **Go:** High-performance API server
- **Python/FastAPI:** Modern async API
- **Rust/Actix:** Type-safe API

Show:
- Pagination implementations
- Error handling middleware
- Rate limiting middleware
- Versioning strategies
- Security hardening

### Real-World Examples

Study production APIs:
- GitHub API (REST maturity level 3)
- Stripe API (excellent error handling)
- Twitter API (pagination done right)
- AWS APIs (versioning strategy)

### Decision Frameworks

When to use:
- REST vs JSON-RPC (reference Chapter 6)
- GraphQL vs REST
- Binary formats vs JSON (reference Chapter 5)

### Cross-References

- References Chapter 6 (JSON-RPC vs REST)
- References Chapter 8 (JWT for auth)
- References Chapter 5 (Binary formats for performance)
- References Chapter 3 (JSON Schema for validation)

---

**Note:** This chapter provides comprehensive practical guidance for building production JSON APIs. Focuses on patterns that have proven effective across thousands of real-world APIs.
