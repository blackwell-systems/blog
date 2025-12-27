---
title: "Your README is a Landing Page, Not Your Documentation"
date: 2025-12-25
draft: false
tags: ["documentation", "readme", "open-source", "developer-tools", "technical-writing", "markdown", "github", "documentation-patterns", "software-engineering", "best-practices", "api-documentation", "crates-io", "npm", "pypi", "repository-management", "code-hygiene", "documentation-sprawl", "content-strategy", "engineering-culture", "oss-maintenance"]
categories: ["developer-tools", "best-practices"]
description: "Stop treating READMEs like documentation dumps. Learn why README sprawl kills engagement and how to maintain disciplined, focused landing pages that actually convert readers into users."
summary: "More features always lead to more sprawl. The longer it goes on, the harder it is to bring back under control. Here's how to treat your README like a landing page - with hooks, not walls of text."
---

Every feature you add to your project makes your README longer. Every API you document inline pushes the Quick Start section further down. Every example you add "for clarity" moves the installation instructions off the first screen.

Before you know it, your README is 800 lines. New users bounce. Contributors get lost. Your carefully crafted introduction sits at the top of a wall of text that nobody reads past line 50.

This isn't a documentation problem. **It's a marketing problem.**

## Table of Contents

- [The Uncomfortable Truth](#the-uncomfortable-truth) - READMEs are marketing
- [The Sprawl Pattern](#the-sprawl-pattern) - How it happens
- [Why Sprawl Happens](#why-sprawl-happens) - Engineering mindset traps
- [The Landing Page Mindset](#the-landing-page-mindset) - Think like a product page
- [The README Formula](#the-readme-formula) - Hero, pain point, features, installation
- [The Extraction Pattern](#the-extraction-pattern) - Surgical reduction in 4 steps
- [Real Example: error-envelope](#real-example-error-envelope) - ~500→235 lines (53% reduction)
- [The "But What About..." Questions](#the-but-what-about-questions) - Objections answered
- [The Discipline Framework](#the-discipline-framework) - Line budgets and maintenance rules
- [The Templates](#the-templates) - Copy-paste starting points
- [The Hard Part: Saying No](#the-hard-part-saying-no) - Defending your line budget
- [The Documentation Hierarchy](#the-documentation-hierarchy) - Where different content belongs
- [The Anti-Patterns](#the-anti-patterns) - Common README killers
- [The Psychology of Scrolling](#the-psychology-of-scrolling) - User behavior patterns
- [Start Today](#start-today) - Actionable next steps

## The Uncomfortable Truth

{{< callout type="warning" >}}
**Engineers don't want to hear this, but it's true:** Your README is more about marketing than documentation.
{{< /callout >}}

Not marketing in the sleazy sense. Marketing in the:

- "I have 30 seconds to convince someone this solves their problem" sense
- "Every line needs to earn its place" sense
- "If they're still reading at line 200, you've already lost" sense

Your README isn't where people learn your API. It's where they decide whether to learn your API at all.

{{< callout type="warning" >}}
**Reality Check:** Users make a decision about your project in the first 10 seconds. If they're scrolling past 300 lines of API documentation to find the Quick Start, they're not coming back.
{{< /callout >}}

## The Sprawl Pattern

The pattern is predictable:

1. **Start clean** - Minimal README with one example
2. **Add "just one more thing"** - Someone asks about error handling, so you add a section
3. **Duplicate for clarity** - Show the same concept in three languages "to be helpful"
4. **Inline everything** - Full API reference because "it's convenient"
5. **Hit 800+ lines** - README is now a documentation dump

{{< callout type="warning" >}}
**The Sprawl Problem:** Long READMEs create a discoverability problem. When documentation exceeds 500+ lines, key information (Quick Start, Installation) gets pushed down. Users who arrive looking for a quick evaluation often scroll briefly, then leave to check alternatives. The completeness that feels helpful to maintainers can become a barrier to first-time users.
{{< /callout >}}

## Why Sprawl Happens

The engineering mindset works against us here.

### "Let me just add one more example"

You're proud of your error handling. You want to show it off. So you add an example. Then someone asks about retries, so you add that too. Then distributed tracing. Then rate limiting.

Before you know it, you have 15 examples in your README. Each one made sense in isolation. Together, they're overwhelming.

### "I'll document it while I remember"

You just added a new feature. Your brain is full of context. The easiest thing is to document it right there in the README where everyone will see it.

Except "everyone will see it" becomes "nobody will find it" when your README is 700 lines long.

### "But comprehensive is better"

No. **Comprehensive is overwhelming.**

Users don't need comprehensive in your README. They need:
- Does this solve my problem?
- Can I install it?
- Can I make it work in 5 minutes?
- Where do I go to learn more?

That's it. Everything else is resistance.

## The Landing Page Mindset

{{< callout type="success" >}}
Think about every landing page you've seen for a SaaS product. The landing page is short, focused, with one job: convince you to click "Get Started." Everything else lives somewhere else.
{{< /callout >}}

**Your README is a front door.** You don't stack everything in the front yard blocking the entrance. You present a nice landscape, help visitors find the door, and structure your content into dedicated spaces that can be easily discovered and understood.

A good README tells people:
- What this is
- **Why they should care**
- Exactly how to use it in the fewest steps possible

**Your README should be less about "what" and more about "why," with the "whats" connecting directly to the "whys."**

Then link out to detailed documentation (installation guides, tutorials, API reference, example gallery, migration guides).

## The README Formula

People look for libraries because they're trying to solve a problem. **Your README needs to validate their pain point before showing your solution.** If they can't figure out whether this solves their problem in the first 30 seconds, they bounce.

Here's the structure that works:

### 1. Hero Section (Lines 1-10)

One sentence. What does this do? Who is it for?

**This is your value proposition:** the benefit someone gets from using your project, stated clearly enough that they understand it in 5 seconds.

```markdown
# project-name

A tiny Rust crate for consistent HTTP error responses across services.
```

Not:
```markdown
# project-name

A comprehensive, feature-rich, battle-tested solution for managing,
handling, and responding to error conditions in distributed systems
with support for multiple frameworks including Axum, Actix, Rocket,
and custom integrations, providing type-safe error codes, structured
JSON responses, distributed tracing integration, retry logic, and...
```

**One sentence. Value proposition. Done.**

### 2. Social Proof (Lines 11-15)

Badges. Keep them in one line if possible.

```markdown
[![Crates.io](https://img.shields.io/crates/v/error-envelope.svg)](https://crates.io/crates/error-envelope)
[![Docs.rs](https://docs.rs/error-envelope/badge.svg)](https://docs.rs/error-envelope)
[![CI](https://github.com/user/project/actions/workflows/ci.yml/badge.svg)](https://github.com/user/project/actions)
```

### 3. Quick Example (Lines 16-30)

**One** working example. 5-10 lines. Shows the primary use case.

```rust
use error_envelope::Error;

async fn get_user(id: String) -> Result<Json<User>, Error> {
    let user = db::find_user(&id).await?;
    Ok(Json(user))
}
```

Not three examples. Not "here's basic, here's intermediate, here's advanced." **One example.**

{{< callout type="success" >}}
**Best Practice:** Your quick example should be copy-pasteable and runnable. If it requires 10 lines of setup code, it's not quick anymore.
{{< /callout >}}

**Hero vs Quick Start confusion:**

Many READMEs duplicate content between a hero example (top) and a Quick Start section (later). This is the easiest place to create redundancy.

**Differentiate them:**
- **Hero example** - Shows "batteries included" functionality. Demonstrates the full power with integrations, multiple features, complete output. This is your sales pitch.
- **Quick Start section** (if you have one) - Shows minimal, initial use case. Ease-in to the product. Just enough to get something working.

If your hero already shows the complete picture, your Quick Start should be tiny (3-5 lines) and show the simplest possible usage. Or skip Quick Start entirely and link to examples/.

**Example (error-envelope):**
- Hero: Shows anyhow integration + validation + structured output (full power)
- Quick Start: `Error::not_found("...").with_trace_id("...")` (minimal builder pattern)

Don't repeat the hero example in Quick Start. If they're the same, you're wasting space.

### 3.5. The Problem Statement (Optional but Powerful)

Before listing features, consider articulating the pain point:

```markdown
## Why

Without a standard, every endpoint returns errors differently:
- `{"error": "bad request"}`
- `{"message": "invalid email"}`  
- `{"code": "E123", "details": {...}}`

This forces clients to handle each endpoint specially. error-envelope provides one predictable error shape.
```

**This validates the reader's experience.** If they've felt this pain, they immediately know: "This is for me."

Don't skip this. The reader needs to see their problem reflected back before they trust your solution.

### 4. Features (Lines 31-50)

Bullet list. Each feature is one line with a link to detailed docs.

```markdown
## Features

- **Consistent error format** - One predictable JSON structure ([docs](docs/FORMAT.md))
- **Typed error codes** - 18 standard codes as enum ([complete list](ERROR_CODES.md))
- **Framework integration** - Axum, Actix, Rocket ([examples](examples/))
- **Traceability** - Built-in trace IDs ([guide](docs/TRACING.md))
```

Notice the pattern: **Hook + link.** Not full explanations inline.

### 5. Installation (Lines 51-60)

Simple. Cargo.toml, npm install, pip install. One command.

```markdown
## Installation

\`\`\`toml
[dependencies]
error-envelope = "0.2"
\`\`\`
```

Optional features if relevant, but keep it short.

### 6. Table of Contents (Optional, Lines 61-70)

Only if your README is still over 200 lines (it shouldn't be). Keep it to 4-5 top-level links.

```markdown
## Documentation

- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Reference](API.md) - Complete API documentation
- [Error Codes](ERROR_CODES.md) - All error codes with descriptions
```

### 7. What's Next Section (Lines 71-80)

Links to real documentation.

```markdown
## Learn More

- [API Documentation](https://docs.rs/error-envelope) - Complete API reference
- [Examples](examples/) - Real-world usage patterns
- [Architecture Guide](ARCHITECTURE.md) - Design decisions and internals
```

**Total: 80-150 lines.**

Everything else lives in separate files.

## The Extraction Pattern

You've already got an 800-line README. How do you fix it?

### Step 1: Create Dedicated Files

Don't rewrite. Extract.

```bash
# Create dedicated documentation files
touch API.md              # Full API reference
touch ERROR_CODES.md      # Complete error code table
touch EXAMPLES.md         # Gallery of examples
touch ARCHITECTURE.md     # Design decisions
touch MIGRATION.md        # Version upgrade guides
```

### Step 2: Move Content (Don't Delete)

Copy sections from README to dedicated files. **Preserve everything.** This isn't about losing content - it's about organizing it.

```markdown
# In API.md (was lines 100-250 of README.md)

## Complete API Reference

### Error Constructors

Full documentation of all 18 constructors...
```

### Step 3: Replace with Hooks

Where you had 150 lines of API documentation, replace with 20 lines of hooks:

```markdown
## API Reference

Common constructors for typical scenarios:

\`\`\`rust
Error::internal("Database connection failed");      // 500
Error::not_found("User not found");                 // 404
Error::unauthorized("Missing token");               // 401
\`\`\`

**Full API documentation:** [API.md](API.md) - Complete constructor reference, builder patterns, advanced usage
```

### Step 4: Measure the Result

```bash
wc -l README.md
# Before: 600 lines
# After: 200 lines (67% reduction)
```

Target: **200-400 lines.** If you're still over 400, extract more.

## Real Example: error-envelope

I recently did this with [error-envelope](https://github.com/blackwell-systems/error-envelope), a Rust crate for HTTP error responses.

**Before:**
- README.md: ~500 lines
- Full API reference inline (18 constructors, full signatures)
- Complete error codes table (18 rows with descriptions)
- 13 mermaid diagrams explaining architecture
- Multiple framework integration examples
- Architecture explanations mixed throughout

**Problem:** New users had to scroll past 200+ lines of API documentation, diagrams, and architecture discussion to find the Quick Start.

**After (surgical extraction):**
- README.md: 235 lines (53% reduction)
- API.md: 364 lines (complete API reference)
- ERROR_CODES.md: 167 lines (full error code documentation)
- ARCHITECTURE.md: 272 lines (design decisions with 4 essential mermaid diagrams)

**README changes:**
- API section reduced from 90 lines to 30 lines (8 common constructors + link to API.md)
- Error codes reduced from 18-row table to 5-row table (most common codes + link)
- Mermaid diagrams reduced from 13 to 4 (moved 9 to ARCHITECTURE.md)
- Table of contents trimmed from 11 sections to 6 key links

**Result:** The README now serves as a landing page. If you want the full API, you click a link. If you want to see all error codes, you click a link. But if you just want to understand what this crate does and whether it solves your problem, **you get your answer in the first 50 lines.**

## The "But What About..." Questions

### "But users expect comprehensive READMEs"

No. Users expect to find information quickly. A 600-line README makes that harder, not easier.

GitHub's search is mediocre. Users scroll, not search. Long READMEs increase time-to-answer, not decrease it.

### "But I want everything in one place"

Everything **is** in one place: your repository. Just not in one file.

Think about it: would you put your entire codebase in one file because "it's convenient"? No. You organize into modules.

Documentation works the same way.

### "But what if people don't click the links"

If they don't click links in a 200-line README, they definitely won't scroll through a 600-line README.

Links are lower friction than scrolling. Separate files are easier to navigate than one massive file. This is why documentation sites exist.

### "But more detail shows thoroughness"

To other engineers, maybe. To users evaluating your project, it shows lack of focus.

"This README is so long they must be serious" is not a thought anyone has ever had. "This README is so long I'll come back later" is a thought everyone has had.

{{< callout type="info" >}}
**Key Insight:** Thoroughness belongs in your documentation. Conciseness belongs in your README. These are not conflicting goals - they're different audiences at different stages of the journey.
{{< /callout >}}

## The Discipline Framework

Here's how to maintain README discipline over time:

### Rule 1: Line Budget

Set a target based on project scope:

- **Single-purpose library:** 200-400 lines max
- **Framework or tool:** 400-600 lines max
- **Monorepo/workspace (multiple crates):** 500-800 lines max
- **Large platform:** 800-1000 lines max (but consider splitting to docs/)

The key: **set a number and stick to it.** Every time you add a section, something else must get extracted or trimmed.

**Examples:**
- `serde` (single crate, focused): ~200 lines
- `tokio` (runtime with multiple components): ~500 lines
- `rust-lang/rust` (massive monorepo): ~800 lines, but heavily links out

If you're a single library and hitting 600 lines, you have sprawl. If you're a workspace with 8 crates and at 600 lines, you're probably fine.

### Rule 2: One Example Rule

Each concept gets **one** example in the README. More examples go in `examples/` or `EXAMPLES.md`.

You don't need:
- Basic example
- Intermediate example
- Advanced example
- Edge case example

You need: **The most common example.** That's it.

### Rule 3: No Inline API Docs

Full API documentation belongs in:
- docs.rs for Rust crates
- API.md or docs/ directory for GitHub
- Your documentation site

README gets: 5-8 most common functions + link to full docs.

{{< mermaid >}}
flowchart TB
    subgraph decision["Adding New Content to README?"]
        new["New content to document"]
        question1{"Is it core to<br/>understanding<br/>what this does?"}
        question2{"Can it be shown<br/>in 10 lines<br/>or less?"}
        question3{"Is it more important<br/>than existing<br/>content?"}
    end

    subgraph actions["Actions"]
        add_readme["Add to README"]
        add_docs["Add to API.md/docs/"]
        extract["Extract existing<br/>content first"]
        link["Add link in README"]
    end

    new --> question1
    question1 -->|No| add_docs
    question1 -->|Yes| question2
    question2 -->|No| add_docs
    question2 -->|Yes| question3
    question3 -->|No| extract
    question3 -->|Yes| add_readme
    
    add_docs --> link
    extract --> add_readme

    style decision fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style actions fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}

### Rule 4: Resist "Just One More"

Every new feature doesn't need a README section. Most features need:
- A line in the Features section (with link to docs)
- An entry in CHANGELOG.md
- Documentation in API.md or docs/

Not:
- A new README section
- Another example inline
- A detailed explanation of internals

## The Templates

Use these as starting points.

### Minimal README Template (Library/Tool)

```markdown
# project-name

One-sentence description of what this does and who it's for.

[![Crates.io](https://img.shields.io/crates/v/project.svg)](https://crates.io/crates/project)
[![Docs](https://docs.rs/project/badge.svg)](https://docs.rs/project)

## Quick Start

\`\`\`rust
use project::Thing;

fn main() {
    let x = Thing::new();
    x.do_thing(); // One working example
}
\`\`\`

## Features

- **Feature 1** - Brief description ([docs](API.md#feature1))
- **Feature 2** - Brief description ([docs](API.md#feature2))
- **Feature 3** - Brief description ([docs](API.md#feature3))

## Installation

\`\`\`toml
[dependencies]
project = "1.0"
\`\`\`

## Documentation

- [API Reference](API.md) - Complete API documentation
- [Examples](examples/) - Real-world usage patterns
- [Architecture](ARCHITECTURE.md) - Design decisions

## License

MIT
```

**Total: ~40 lines.**

### Comprehensive README Template (Framework/Platform)

```markdown
# project-name

One-sentence value proposition.

[![Crates.io](https://img.shields.io/crates/v/project.svg)](https://crates.io/crates/project)
[![Docs](https://docs.rs/project/badge.svg)](https://docs.rs/project)

## Overview

2-3 sentence expansion on what this does, why it exists, and who uses it.

\`\`\`rust
// One minimal working example (5-10 lines)
\`\`\`

## Why Use This

- + Benefit 1
- + Benefit 2
- + Benefit 3
- - Not suitable for X
- - Not suitable for Y

## Features

- **Feature 1** - One-line description ([docs](docs/FEATURE1.md))
- **Feature 2** - One-line description ([docs](docs/FEATURE2.md))
- **Feature 3** - One-line description ([docs](docs/FEATURE3.md))

## Installation

\`\`\`bash
cargo add project
\`\`\`

## Quick Start

\`\`\`rust
// Slightly longer example showing typical usage (10-20 lines)
\`\`\`

## Common Patterns

### Pattern 1
\`\`\`rust
// Minimal example
\`\`\`

### Pattern 2
\`\`\`rust
// Minimal example
\`\`\`

More patterns in [EXAMPLES.md](EXAMPLES.md).

## Documentation

- [API Reference](https://docs.rs/project) - Complete API documentation
- [User Guide](docs/GUIDE.md) - Detailed usage guide
- [Examples](examples/) - Real-world examples
- [Architecture](ARCHITECTURE.md) - Design and internals
- [Migration Guide](MIGRATION.md) - Upgrading between versions

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
```

**Total: ~80-120 lines.**

## The Documentation Hierarchy

Here's where different content belongs:

| Content Type | Location | Why |
|--------------|----------|-----|
| Value proposition | README | First thing users see |
| One working example | README | Proves it works quickly |
| Installation | README | Reduces friction to try |
| Feature bullets | README | Helps users decide if relevant |
| Complete API reference | API.md or docs.rs | Searchable, comprehensive |
| All error codes | ERROR_CODES.md | Reference material |
| Multiple examples | examples/ or EXAMPLES.md | Shows flexibility without cluttering |
| Design decisions | ARCHITECTURE.md | For contributors and curious users |
| Migration guides | MIGRATION.md | Version-specific, doesn't age well in README |
| Tutorials | docs/ directory | Step-by-step, too long for README |
| Community content | GitHub Wiki | User-contributed, not core |

## The Anti-Patterns

Watch out for these README killers:

### 1. The Kitchen Sink

```markdown
## API Reference

### Error Constructors

[Lists all 30 constructors with full signatures]

### Builder Methods

[Lists all 15 builder methods with full signatures]

### Extension Traits

[Lists all traits with impl blocks]

[... 200 lines of API documentation ...]
```

**Fix:** Extract to API.md. Show 5-8 common constructors in README with link to full docs.

### 2. The Example Gallery

```markdown
## Examples

### Basic Example
[30 lines]

### Intermediate Example
[40 lines]

### Advanced Example
[50 lines]

### With Axum
[40 lines]

### With Actix
[40 lines]

### With Custom Middleware
[50 lines]

[... 250 lines of examples ...]
```

**Fix:** Keep ONE basic example in README. Move everything else to `examples/` directory or EXAMPLES.md.

### 3. The Historian

```markdown
## Background

This project started in 2018 when I was working at Company X. We needed
a solution for Y but existing tools like Z didn't support our use case.
I tried approaches A, B, and C but they all had problems...

[300 lines of history and evolution]
```

**Fix:** History belongs in a blog post or HISTORY.md. README gets 2-3 sentences max on "why this exists."

### 4. The Completionist

```markdown
## Installation

### From crates.io
### From GitHub
### From source
### For Alpine Linux  
### For ARM processors
### For Windows with MSVC
### For Windows with GNU
### For macOS with Homebrew
### For macOS without Homebrew
### Via Docker
### Via Nix
### Via Conda

[150 lines of installation permutations]
```

**Fix:** README shows the primary installation method (cargo add, npm install). Everything else goes in INSTALLATION.md or docs/INSTALL.md.

### 5. The Inline Troubleshooter

```markdown
## Common Issues

### Error: X doesn't work

If you see error X, try:
1. Check Y
2. Verify Z
3. Install A
4. Update B

[50 lines]

### Error: W fails

[50 lines]

### Performance is slow

[50 lines]

[... 300 lines of troubleshooting ...]
```

**Fix:** Troubleshooting belongs in docs/TROUBLESHOOTING.md or GitHub Discussions. Link to it from README.

## The Psychology of Scrolling

Users don't read READMEs linearly - they scan. In the first 10 seconds, they decide if this solves their problem. In the next 20 seconds, they look for proof it works (Quick Start). Then they check how hard it is to set up (Installation). After that, they either try it or bounce to another tab.

Every line between the title and Quick Start is friction. Your README competes with 10 other open tabs. Make it easy to choose yours.

## The Hard Part: Saying No

The hardest part of README discipline isn't the refactoring. It's saying no to well-meaning additions.

**Contributor:** "I added a new feature, here's a PR with 50 lines of README docs."

**You:** "Thanks! Let's add a bullet in the Features section with a link to docs/FEATURE_X.md instead."

**Contributor:** "But people need to know how it works!"

**You:** "They do - in the docs. The README is for deciding whether to use it, not learning how to use it."

This feels harsh. It feels like you're hiding information. You're not. You're **organizing** information so users can find it.

{{< callout type="info" >}}
Every line you add to the README makes all other lines harder to find. This isn't theoretical - it's information design. Density works against discoverability.
{{< /callout >}}

## Start Today

The longer you wait, the harder extraction becomes. Start with one section:

1. `wc -l README.md` - Check current length
2. Pick the longest section (API reference, error codes, examples)
3. Extract to dedicated file (API.md, ERROR_CODES.md, EXAMPLES.md)
4. Replace with 3-5 line summary + link
5. Commit: "Extract [section] from README to reduce sprawl"

Set a line budget for your project scope. Defend it. Every new feature doesn't need a README section - most need a bullet + link.

**More hooks, less sprawl.**
