---
title: "You Don't Know JSON: Part 8 - Lessons from the JSON Revolution"
date: 2025-12-16
draft: false
series: ["you-dont-know-json"]
seriesOrder: 8
tags: ["json", "xml", "architecture", "software-evolution", "design-philosophy", "modularity", "jsx", "react", "vue", "angular", "graphql", "history", "patterns", "zeitgeist", "monolithic", "microservices", "ecosystem", "fragmentation", "trade-offs"]
categories: ["fundamentals", "architecture", "philosophy"]
description: "The meta-lessons from JSON's triumph: how architectural zeitgeist shapes technology, why good patterns survive regardless of packaging, and the hidden costs of modularity through ecosystem fragmentation."
summary: "JSON recreated XML's entire ecosystem modularly. JSX brought back XML's syntax. What does this teach us about technology evolution? Explore the architectural zeitgeist, pattern survival, and the modularity paradox: choice vs. discoverability."
---

We've completed our journey through the JSON ecosystem. From [origins]({{< relref "you-dont-know-json-part-1-origins.md" >}}) through [validation]({{< relref "you-dont-know-json-part-2-json-schema.md" >}}), [binary formats]({{< relref "you-dont-know-json-part-3-binary-databases.md" >}}) for [databases]({{< relref "you-dont-know-json-part-3-binary-databases.md" >}}) and [APIs]({{< relref "you-dont-know-json-part-4-binary-apis.md" >}}), [protocols]({{< relref "you-dont-know-json-part-5-json-rpc.md" >}}), [streaming]({{< relref "you-dont-know-json-part-6-json-lines.md" >}}), and [security]({{< relref "you-dont-know-json-part-7-security.md" >}}) - each part demonstrated JSON's modular architecture.

But there's a deeper story here. **Why did JSON succeed where XML failed?** Not because JSON was "better" in absolute terms, but because it reflected the architectural thinking of its era.

This final part steps back to examine the meta-patterns: what JSON teaches us about technology evolution, why good ideas survive architectural shifts, and the hidden trade-offs of modularity.

{blurb, class: information}
**Meta-Perspective:** This isn't about JSON vs XML anymore. It's about how software architecture patterns evolve across decades, how technologies embody their era's zeitgeist, and what that means for the systems we build today.
{/blurb}

---

## The Full Circle: JSON Recreated XML's Ecosystem

Here's the remarkable pattern we've documented across this series:

| Problem | XML (1998) | JSON (2001+) | Architecture |
|---------|-----------|--------------|--------------|
| **Validation** | XSD (built-in) | JSON Schema (separate) | Monolithic → Modular |
| **Binary** | N/A | JSONB, MessagePack (separate) | N/A → Modular |
| **Protocol** | SOAP (built-in) | JSON-RPC (separate) | Monolithic → Modular |
| **Security** | XML Signature (built-in) | JWT, JWS (separate) | Monolithic → Modular |
| **Query** | XPath (built-in) | jq, JSONPath (separate) | Monolithic → Modular |

**JSON didn't avoid XML's problems. It organized the solutions differently.**

### Same Problems, Different Organization

**Every gap we've explored in this series:**
- Part 2: No validation → JSON Schema
- Part 3-4: Text format tax → Binary formats
- Part 5: No protocol structure → JSON-RPC
- Part 6: Can't stream → JSON Lines
- Part 7: No security → JWT/JWS/JWE

**XML solved these too:**
- Validation: XSD (built into parsers)
- Protocol: SOAP (integrated with XML)
- Security: XML Signature (part of spec)
- Query: XPath (standard tooling)

**The difference isn't the solutions. It's the packaging.**

### Why the Architecture Differs: Software Evolution

The key insight: **Technologies don't just compete on features. They reflect the architectural thinking of their era.**

**XML Era (1990s):**
- Monolithic was the norm (CORBA, J2EE, Microsoft COM)
- "Complete specification" was a feature
- One vendor, one integrated solution
- Tight coupling was acceptable
- Enterprise architecture meant comprehensive upfront design
- SOAP, XSD, XSLT came bundled because that's how we built systems

**JSON Era (2000s-present):**
- Microservices philosophy emerging
- Loose coupling as best practice
- Dependency injection patterns standard
- Open source ecosystem mindset
- Unix philosophy: small composable tools
- Agile: evolve incrementally, not big design upfront
- JSON Schema, JWT, MessagePack exist independently because that's how we build now

{blurb, class: tip}
**The Revelation:** XML was architecturally correct for 1990s software practices. JSON is architecturally correct for 2000s+ software practices. Neither is "better" in absolute terms - they're optimized for different development paradigms.
{/blurb}

### The Timeline Shows the Shift

**Architectural Zeitgeist Evolution Timeline:**

| Era | Years | Dominant Patterns | Key Technologies | Philosophy |
|-----|-------|-------------------|------------------|-----------|
| Monolithic Era | 1990s | Integrated solutions | CORBA, J2EE, COM+, XML with XSD, SOAP, XSLT | Everything bundled together |
| Transition Period | 2000s | Service-Oriented Architecture | JSON emerges (2001), REST popularized (2006) | Loose coupling concepts |
| Modular Era | 2010s | Microservices mainstream | Docker, Kubernetes, JSON ecosystem, npm, cargo | Composable tools |
| Cloud-Native Era | 2020s | Serverless, edge computing | JSON remains dominant, GraphQL, gRPC | Modular remains default |

**The pattern:** Each era's dominant data format reflects that era's architectural preferences.

---

## The Modularity Paradox: Discovery vs. Choice

But modularity has a hidden cost we haven't discussed: **fragmentation and discoverability**.

### The XML Experience

**XML forced awareness:**
```xml
<!-- You couldn't escape knowing this stuff existed -->
<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema">
  <!-- XSD validation forced on you -->
</xs:schema>

<definitions xmlns:soap="http://schemas.xmlsoap.org/wsdl/soap/">
  <!-- SOAP protocol forced on you -->
</definitions>
```

**Every XML developer knew:**
- Validation exists (XSD)
- Protocols exist (SOAP, WSDL)
- Signing exists (XML Signature)
- Transformation exists (XSLT)
- Querying exists (XPath)

**You might have hated it, but you couldn't be ignorant of it.**

### The JSON Experience

**JSON enables ignorance:**
```json
{
  "id": 123,
  "username": "alice"
}
```

**Simple. Clean. Works.**

**But now developers can:**
- Use JSON for years without discovering JSON Schema
- Build APIs without knowing JSON-RPC exists
- Process logs without hearing about JSON Lines
- Stream gigabytes unaware of newline-delimited format
- Pay bandwidth costs not knowing MessagePack exists
- Roll homegrown JWT parsing with security holes

{blurb, class: warning}
**The Fragmentation Problem:** Modularity enables informed choice but also enables uninformed ignorance. XML's bundling forced awareness. JSON's separation enables developers to never discover solutions to problems they'll eventually hit.
{/blurb}

### Real-World Fragmentation

**How many production systems have:**

**No validation** (never heard of JSON Schema)
```javascript
// "JSON is schemaless, we don't need validation"
// (Until prod breaks with unexpected data)
app.post('/api/users', (req, res) => {
  db.insert(req.body);  // Hope for the best
});
```

**Homegrown JWT parsing** (security vulnerabilities)
```javascript
// "JWT is just base64, I'll parse it myself"
const [header, payload, signature] = token.split('.');
const data = JSON.parse(atob(payload));  // No signature check!
```

**Memory crashes streaming** (never heard of JSON Lines)
```javascript
// "I'll load the whole 10GB log file"
const logs = JSON.parse(fs.readFileSync('logs.json'));  // OOM
```

**Bandwidth complaints** (never heard of binary formats)
```javascript
// "Our mobile app is slow"
// (Sending 5MB JSON when MessagePack would be 3MB)
res.json(data);  // 40% larger than necessary
```

**The irony:** These are solved problems. The solutions exist. They're just not forced on you anymore.

### The Trade-off Table

| Aspect | XML (Monolithic) | JSON (Modular) |
|--------|------------------|----------------|
| **Discovery** | Forced awareness | Optional discovery |
| **Learning curve** | Steep (learn everything) | Gradual (learn as needed) |
| **Ecosystem knowledge** | Everyone knows same tools | Fragmented knowledge |
| **Problem awareness** | Can't ignore solved problems | Easy to reinvent wheels |
| **Getting started** | Hard (too much upfront) | Easy (minimal core) |
| **Scaling complexity** | Same complexity always | Add complexity when needed |
| **Best practices** | Standardized (bundled) | Fragmented (choose your own) |

**Neither is strictly better.** Monolithic: forced education. Modular: gradual discovery with risk of ignorance.

---

## The JSX Vindication: Good Patterns Survive

The most profound proof of our thesis comes from an unexpected place: **frontend frameworks brought back XML's syntax**.

### XML for UIs Was Actually Good

**XML in the 1990s:**
```xml
<User id="123" name="Alice">
  <Posts>
    <Post title="Hello World" />
    <Post title="Second Post" />
  </Posts>
</User>
```

**This was genuinely excellent for UI structure:**
- Self-describing hierarchical markup
- Attributes for data
- Nesting shows relationships
- Closing tags provide clarity
- Human-readable structure

**The problem wasn't the syntax. It was what came with it:**
- XSD schemas (hundreds of lines for simple structures)
- XSLT transformations (complex Turing-complete language)
- Namespace collision handling (`xmlns` everywhere)
- DTD validation (yet another schema system)
- Monolithic parsers (everything built-in, 50MB libraries)

**Developers rejected the bundle.** We threw out the baby with the bathwater.

### The 2000s: JSON Objects for Everything

**React early days (2013 JSX introduction):**
```javascript
// Before JSX: Plain JavaScript objects
React.createElement(
  'div',
  {className: 'user'},
  React.createElement('h1', null, 'Alice'),
  React.createElement('p', null, 'Profile')
)
```

**This worked but was verbose.** The hierarchy wasn't visually obvious. Nested structures became unreadable.

### JSX: XML Syntax Returns (2013)

**React with JSX:**
```jsx
<User id={123} name="Alice">
  <Posts>
    <Post title="Hello World" />
    <Post title="Second Post" />
  </Posts>
</User>
```

**Wait. This looks exactly like XML.**

**But with modular architecture:**
- Type checking: PropTypes or TypeScript (separate, choose your own)
- Transformation: Babel (lightweight transpiler, not XSLT)
- Imports: ES6 modules (not XML namespaces)
- Validation: Choose your library (not XSD bundled)
- Rendering: Plain JavaScript (not monolithic DOM manipulation)

**We "stole" XML's best feature (hierarchical markup) and left the monolithic baggage behind.**

### The Pattern Across Frameworks

**Vue.js:**
```vue
<template>
  <User :id="123" name="Alice">
    <Posts>
      <Post title="Hello World" />
    </Posts>
  </User>
</template>
```

**Angular:**
```html
<app-user [id]="123" name="Alice">
  <app-posts>
    <app-post title="Hello World"></app-post>
  </app-posts>
</app-user>
```

**Svelte:**
```svelte
<User id={123} name="Alice">
  <Posts>
    <Post title="Hello World" />
  </Posts>
</User>
```

**All major frameworks brought back XML-style markup.** But none brought back XSD, XSLT, namespaces, or monolithic parsing.

{blurb, class: tip}
**The Realization:** We didn't reject XML's syntax. We rejected XML's monolithic architecture. Once we could decouple the markup language from the validation/protocol stack, XML-style tags made sense again for UIs.

**Good patterns survive architectural shifts.** Self-describing markup was always good for hierarchical UIs. It just needed to wait for the modular era to separate syntax from ecosystem burden.
{/blurb}

### The Evolution Table

| Era | UI Representation | Validation | Transformation | Architecture |
|-----|------------------|------------|----------------|--------------|
| **1990s** | XML tags | XSD (built-in) | XSLT (built-in) | Monolithic |
| **2000s** | JSON objects | Runtime checks | Template engines | Data-centric |
| **2010s+** | JSX tags | TypeScript (separate) | Babel (separate) | Modular |

**We came full circle on syntax while maintaining modular architecture.**

---

## What JSON Teaches Us About Technology Evolution

### Lesson 1: Technologies Reflect Their Era's Zeitgeist

**Successful technologies align with contemporary architectural thinking.**

**Examples beyond JSON:**

**Docker (2013):** Succeeded because it aligned with microservices era
- Pre-Docker: VMs (monolithic, heavyweight)
- Docker era: Containers (modular, lightweight, composable)
- Zeitgeist: Single-purpose services, immutable infrastructure

**npm (2010):** Succeeded because it aligned with modular JavaScript
- Pre-npm: jQuery plugins (monolithic libraries)
- npm era: Small focused packages (left-pad, anyone?)
- Zeitgeist: Unix philosophy applied to JavaScript

**GraphQL (2015):** Emerged from API evolution
- REST era: Server dictates response shape
- GraphQL era: Client specifies data needs
- Zeitgeist: Frontend empowerment, mobile-first, bandwidth optimization

**The pattern:** Technologies don't exist in vacuum. They succeed when they match how developers are learning to build systems.

### Lesson 2: Same Problems, Evolving Solutions

**The problems don't change:**
- Data needs validation
- Systems need protocols
- Security requires authentication
- Performance needs optimization
- Large data needs streaming

**The organization changes:**
- 1990s: Bundle everything
- 2010s: Separate everything
- Future: ???

**JSON's lesson:** Focus on *organizing* solutions, not inventing new ones. XML already solved validation (XSD). JSON Schema solved it differently (separate, evolvable). Same problem, new organization.

### Lesson 3: Modularity Enables Evolution

**Why JSON's ecosystem keeps growing:**

Each solution evolves independently:
- JSON Schema updates don't break parsers
- JWT improvements don't require new JSON spec
- MessagePack optimizations don't affect JSON Lines
- New formats (CBOR, BSON) emerge without coordination

**Contrast with XML:**
- XSD change requires parser updates
- SOAP change requires WSDL updates
- Everything coupled, everything moves slowly

**The trade-off:** Faster evolution, harder discovery.

### Lesson 4: Good Ideas Transcend Architecture

**JSX proves it:** Self-describing hierarchical markup was always good for UIs. It survived the XML → JSON → JSX journey. The syntax persisted through two major architectural shifts.

**Other examples of surviving patterns:**

**Request/Response** (survived multiple protocols)
- SOAP (monolithic XML)
- REST (modular HTTP)
- GraphQL (query-based)
- gRPC (binary)

**Hierarchical Structure** (survived format changes)
- XML (verbose markup)
- JSON (compact notation)
- YAML (human-friendly)
- TOML (configuration-focused)

**Key-Value Pairs** (universal pattern)
- XML attributes
- JSON objects
- HTTP headers
- Environment variables

**The lesson:** If a pattern solves a real problem elegantly, it survives regardless of packaging.

---

## The Modularity Tax: What We Gave Up

Let's be honest about modularity's costs.

### Discoverability Crisis

**XML developers in 1998:**
```
"I need validation."
→ Look at XML spec
→ Find XSD
→ Use XSD
```

**JSON developers in 2024:**
```
"I need validation."
→ Google "JSON validation"
→ Find: JSON Schema, Joi, Yup, Zod, AJV, TypeBox, Superstruct
→ Read comparison articles
→ Check GitHub stars
→ Debate with team
→ Choose one
→ Hope it's the right choice
```

**More choice ≠ less complexity.** Sometimes it's more.

### Fragmented Best Practices

**XML era:** Everyone used XSD the same way (spec defined it)

**JSON era:** Every team has different validation approaches:
- Some use JSON Schema
- Some use TypeScript interfaces
- Some use runtime validation libraries
- Some use nothing (YOLO)
- Some build their own (NIH syndrome)

**The cost:** No universal patterns. Every codebase different.

### Ecosystem Ignorance

**Real conversation overheard:**

> Dev 1: "Our logs are 50GB, JSON parsing crashes."  
> Dev 2: "Can't you stream it?"  
> Dev 1: "How? JSON doesn't support streaming."  
> Dev 2: "Use JSON Lines."  
> Dev 1: "What's JSON Lines?"

**This conversation would never happen in XML era.** Everyone knew streaming existed (SAX parsers, StAX). It was bundled, you couldn't miss it.

**JSON's modularity:** Powerful for those who know the ecosystem. Dangerous for those who don't.

### The Reinvention Problem

**How many teams have built:**
- Custom JSON validation (never heard of JSON Schema)
- Homegrown JWT parsing (with security bugs)
- Memory-hungry log parsers (never heard of streaming)
- Inefficient binary serialization (never heard of MessagePack)

**These are solved problems.** The solutions exist, documented, tested. But modularity means they're optional, and optional means many never discover them.


![Diagram 1](images/diagrams/chapter-09-lessons-diagram-1.png){width=85%}


---

## What Comes After JSON?

**The question isn't "will JSON be replaced?"** but "when will architectural thinking shift again?"

### JSON Remains Dominant Because...

**Current zeitgeist still favors modularity:**
- Microservices still dominant
- Cloud-native architecture standard
- Composable tools expected
- Loose coupling best practice

**JSON aligns perfectly with this.** It won't be displaced until architectural thinking shifts.

### What Could Trigger a Shift?

**Speculative future scenarios:**

**Edge Computing Era (2030s?):**
- Extreme latency sensitivity
- Bandwidth constraints
- Need for efficiency
- Possible shift: Binary-first formats become default (Protocol Buffers, Cap'n Proto)
- But probably still "modular" architecture

**AI-Native Systems (2030s?):**
- LLMs generate code
- Semantic understanding over syntax
- Self-describing systems
- Possible shift: Schema-embedded formats (everything has types)
- Could swing back toward "built-in validation"

**Quantum/Post-Quantum Era (2040s?):**
- New cryptographic requirements
- Fundamental security rethink
- Possible shift: Security-first data formats
- JSON with mandatory signing/encryption?

### The Meta-Pattern

**Notice:** Each hypothetical shift reflects changes in *how we build systems*, not just data format preferences.

**The lesson:** Don't ask "will JSON be replaced?" Ask "when will the architectural zeitgeist shift, and what will that mean for data formats?"

**JSON won't be displaced by a "better JSON."** It will be displaced when developers adopt a new architectural paradigm that JSON doesn't align with.

---

## Applying These Lessons

### For Technology Choices

**Don't ask:** "Is technology X better than Y?"  
**Ask:** "Does technology X align with how we build systems today?"

**Examples:**

**"Should we use GraphQL or REST?"**
- Wrong framing: Which is better?
- Right framing: Do we need client-specified data shapes? (GraphQL) Or are server-defined responses fine? (REST)

**"Should we use microservices?"**
- Wrong framing: Are microservices better than monoliths?
- Right framing: Does our team/scale/deployment match microservices patterns?

**"Should we use TypeScript?"**
- Wrong framing: Is TypeScript objectively better?
- Right framing: Do we value compile-time safety over JavaScript's flexibility?

### For System Design

**Recognize architectural assumptions:**

**If you're building in 2024:**
- Loose coupling is expected (don't fight it)
- Modular components are standard (embrace it)
- Composability is valued (design for it)

**If zeitgeist shifts:**
- Recognize when assumptions change
- Adapt to new patterns
- Don't cling to "the old way"

**XML failed not because it was bad, but because it didn't adapt to new patterns.**

### For Ecosystem Contribution

**If building tools for developers:**

**Discoverability matters:**
- Modularity is great, but help people find solutions
- Documentation needs to address "you don't know this exists"
- Comparison guides (not just "use our tool")

**Integration matters:**
- Show how pieces fit together
- Provide complete examples
- Address ecosystem fragmentation

**This series is an example:** Many developers use JSON daily but never heard of JSON Schema, JSON Lines, or MessagePack. Education bridges the modularity gap.

---

## The Series in Retrospect

### What We Learned

**Part 1:** JSON's triumph through simplicity - but incompleteness enabled modularity

**Part 2:** Validation gap filled by JSON Schema - separate, evolvable, optional

**Part 3-4:** Performance gap filled by binary formats - choose per use case (JSONB, BSON, MessagePack, CBOR)

**Part 5:** Protocol gap filled by JSON-RPC - structured APIs without REST constraints

**Part 6:** Streaming gap filled by JSON Lines - simplest possible convention (newlines)

**Part 7:** Security gap filled by JWT/JWS/JWE - composable cryptographic protection

**Part 8:** Meta-lessons - technologies reflect their era's architectural zeitgeist

### The Architectural Framework

**Every part followed the same pattern:**

1. **Identify incompleteness** (JSON's gap)
2. **Show ecosystem response** (modular solution)
3. **Demonstrate benefits** (independent evolution)
4. **Acknowledge trade-offs** (discoverability cost)

**This pattern applies beyond JSON:**
- Unix philosophy (small composable tools)
- npm ecosystem (focused packages)
- Docker containers (single-purpose services)
- Cloud-native architecture (modular deployments)

### The Core Thesis

**Incompleteness isn't weakness when you design for modularity.**

**JSON succeeded by:**
- Staying minimal (six types, simple syntax)
- Enabling extensions (ecosystem fills gaps)
- Avoiding built-in features (let others innovate)
- Reflecting contemporary architecture (modular era)

**Each gap became an opportunity:**
- Validation → JSON Schema
- Performance → Binary formats
- Protocol → JSON-RPC
- Streaming → JSON Lines
- Security → JWT/JWS/JWE

**Each solution evolved independently, without breaking JSON parsers.**

---

## Conclusion: Patterns Survive, Architectures Evolve

We opened this series with JSON's triumph over XML. We close with a deeper understanding: **it wasn't about formats, it was about architecture.**

**XML embodied 1990s thinking:** Monolithic, integrated, complete specifications, tight coupling.

**JSON embodied 2000s+ thinking:** Modular, composable, minimal core, loose coupling.

**JSX vindicated XML's syntax:** Good patterns survive regardless of packaging. Self-describing markup returned once we could decouple syntax from architecture.

**The modularity paradox:** JSON's separated ecosystem enables choice but risks ignorance. XML's bundled approach forced awareness at the cost of flexibility.

{blurb, class: information}
**The Ultimate Lesson:** Technology success depends on architectural alignment. JSON won not because it was "better" but because it matched how developers were learning to build systems. The next shift will come not from a better data format, but from a new architectural paradigm.

When choosing technologies, ask: "Does this align with contemporary architectural patterns?" Not: "Is this objectively superior?"

When zeitgeist shifts, successful technologies shift with it. Unsuccessful ones cling to old patterns.
{/blurb}

### The Series Complete

**You now know JSON** - not just the syntax, but:
- Why it succeeded (architectural alignment)
- How ecosystem filled gaps (modular solutions)
- When to use what (decision frameworks)
- What it teaches us (pattern survival)

**More importantly:** You understand how technologies reflect their era's architectural thinking. This lens applies far beyond JSON.

**Next time you evaluate a technology, ask:**
- What architectural paradigm does this reflect?
- Does it align with contemporary patterns?
- Am I being swayed by zeitgeist or fundamental benefits?
- What will seem obvious in retrospect?

**JSON's story is really the story of how we build systems, how patterns evolve, and how good ideas survive regardless of packaging.**

{blurb, class: tip}
**Thank you for reading this series.** Whether you came for JSON specifics or stayed for architectural insights, you've journeyed from simple data format to technology philosophy.

**The JSON ecosystem will keep evolving** - new formats, new patterns, new solutions to old problems. But the core lesson remains: incompleteness enables modularity, modularity enables evolution, and evolution reflects the ever-changing zeitgeist of software architecture.

**Build systems that align with contemporary patterns. Recognize when patterns shift. Adapt accordingly.**

That's what JSON did. That's why it won.
{/blurb}

---

## Further Reflection

**Recommended reading:**
- [The Cathedral and the Bazaar](http://www.catb.org/~esr/writings/cathedral-bazaar/) - Eric Raymond
- [Unix Philosophy](https://en.wikipedia.org/wiki/Unix_philosophy) - Composability principles
- [Microservices Patterns](https://microservices.io/patterns/) - Modern architecture
- [The Pragmatic Programmer](https://pragprog.com/titles/tpp20/) - Timeless principles

**Related series articles:**
- [Part 1: Origins]({{< relref "you-dont-know-json-part-1-origins.md" >}}) - Where it all began
- [Part 2: JSON Schema]({{< relref "you-dont-know-json-part-2-json-schema.md" >}}) - Validation layer
- [Part 3: Binary Databases]({{< relref "you-dont-know-json-part-3-binary-databases.md" >}}) - JSONB, BSON
- [Part 4: Binary APIs]({{< relref "you-dont-know-json-part-4-binary-apis.md" >}}) - MessagePack, CBOR
- [Part 5: JSON-RPC]({{< relref "you-dont-know-json-part-5-json-rpc.md" >}}) - Protocol layer
- [Part 6: JSON Lines]({{< relref "you-dont-know-json-part-6-json-lines.md" >}}) - Streaming
- [Part 7: Security]({{< relref "you-dont-know-json-part-7-security.md" >}}) - JWT, JWS, JWE
