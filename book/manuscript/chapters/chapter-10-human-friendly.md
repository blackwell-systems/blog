---
title: "Chapter 10: Human-Friendly JSON Variants"
status: TO BE WRITTEN
target_words: 7000
---

# Chapter 10: Human-Friendly JSON Variants

**Status:** To be written (Q2 2026)  
**Target length:** ~7,000 words  
**Key insight:** Configuration is a distinct use case with different needs

## Planned Content

### Sections to Write

1. **The Configuration Problem**
   - Why JSON fails for config files
   - No comments
   - Trailing comma errors
   - Quoted keys annoyance
   - Real-world pain points

2. **JSON5: Minimal Extensions**
   - ECMAScript 5 inspired
   - Comments (// and /* */)
   - Trailing commas
   - Unquoted keys
   - Single quotes
   - When to use

3. **HJSON: Maximum Readability**
   - Designed for humans
   - Minimal syntax
   - Multiline strings
   - No quotes needed (most cases)
   - When to use

4. **YAML: Widespread Adoption**
   - Indentation-based
   - No braces needed
   - Complex features (anchors, references)
   - Why it dominates DevOps
   - Common pitfalls (Norway problem, indentation)
   - When to use

5. **TOML: Clarity for Configs**
   - INI-inspired
   - Clear sections
   - Type system
   - Rust ecosystem adoption
   - When to use

6. **Migration Strategies**
   - Converting between formats
   - Tooling support
   - Team adoption
   - When to stay with JSON

### Comparison Matrix

Full comparison table across 10+ dimensions:
- Readability
- Comments support
- Syntax flexibility
- Error messages
- Tooling support
- Language support
- Adoption level
- Learning curve
- Best use cases

### Code Examples (all languages)

Same configuration in:
- JSON
- JSON5
- HJSON
- YAML
- TOML

Show real-world configs:
- Package.json vs package.json5
- Docker Compose (YAML)
- Cargo.toml (Rust)
- Config files

### Decision Framework

Flowchart for choosing format based on:
- Team familiarity
- Tooling requirements
- Complexity needs
- Human editing frequency

### Cross-References

- References Chapter 1 (JSON limitations)
- Connects to Chapter 2 (modular solutions)
- Relates to Chapter 11 (API design - when to use which format)

---

**Note:** This chapter is currently a small section in Part 1 of the blog. Needs full expansion with comprehensive examples, comparisons, and practical guidance.

**Source material:** `content/posts/you-dont-know-json-part-1-origins.md` lines 850-950 (human-friendly section)
