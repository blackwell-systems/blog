# Feedback and Errata

## Found an Issue?

Despite careful editing, technical books inevitably contain errors. If you find:

- **Technical errors** - Incorrect code examples or explanations
- **Typos or formatting issues** - Spelling, grammar, or layout problems
- **Broken links** - URLs that don't work
- **Unclear explanations** - Sections that need clarification

**Please report them:**

**GitHub Issues:** https://github.com/blackwell-systems/you-dont-know-json/issues

Or email: dayna@blackwell-systems.com

I review all feedback and update the book regularly. Leanpub readers receive all updates automatically at no additional cost.

---

## Companion Repository

All code examples, schemas, and configuration files from this book are available in the companion repository:

**https://github.com/blackwell-systems/you-dont-know-json**

The repository includes:

**Validation Examples**
- Complete JSON Schema examples with Ajv, custom errors, and Express integration
- Go validation with struct tags
- Python validation with Pydantic

**JWT Authentication**
- Token creation and validation in JavaScript, Go, and Python
- Security patterns preventing common attacks
- Refresh token rotation examples

**JSON Lines Processing**
- Streaming parsers with error recovery
- Log processing pipelines
- Performance benchmarks

**Schema Evolution**
- Backward and forward compatibility examples
- Migration strategies with real data

**Testing Templates**
- Contract tests for JSON APIs
- Security test suites
- Performance benchmarks

**OpenAPI Specifications**
- Complete API examples from the book
- Schema definitions
- Documentation generation

**Docker Compose**
- Run all examples locally
- Includes databases, message queues, and supporting services

**How to Use the Repository**

1. Clone the repository:
   ```bash
   git clone https://github.com/blackwell-systems/you-dont-know-json.git
   ```

2. Navigate to language-specific directories:
   ```
   /javascript - Node.js examples
   /go - Go examples
   /python - Python examples
   /rust - Rust examples
   ```

3. Each example includes:
   - README with setup instructions
   - Dependencies and version requirements
   - Tests you can run to verify
   - Comments explaining key concepts

4. Adapt patterns to your use cases:
   - Copy validation schemas
   - Use JWT patterns
   - Adapt streaming examples
   - Reference testing strategies

**Contributing**

Found a better way to implement something? Have additional examples? Pull requests welcome!

---

## Stay Connected

**Book updates:** Follow on Leanpub for automatic updates

**Technical questions:** GitHub Discussions in the companion repo

**Speaking/Consulting:** speaking@blackwell-systems.com or consulting@blackwell-systems.com

**LinkedIn:** linkedin.com/in/dayna-blackwell

**Next book in series:** "You Don't Know REST APIs" (coming Q1 2026)

---

Thank you for reading. Your feedback helps make this book better for everyone.

-- Dayna Blackwell
