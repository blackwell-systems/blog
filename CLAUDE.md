# Blog Project - Claude Code Instructions

This is the **Blackwell Systems™ Blog** - a Hugo-powered technical blog covering developer tools, AI workflows, dotfiles, and system architecture.

**Live site:** https://blackwell-systems.github.io/blog/

---

## Blog Features & Components

### Custom Components

This blog has two custom Hugo shortcodes that should be used frequently:

#### 1. Mermaid Diagrams (Dark Theme)

**Always use mermaid diagrams** for architectural explanations, flows, comparisons, and system designs. The blog has fully configured dark-theme mermaid support with click-to-expand lightbox functionality.

```markdown
{{< mermaid >}}
flowchart LR
    A[Client] --> B[Server]
    B --> C[Database]
{{< /mermaid >}}
```

**Mermaid configuration:**
- Automatically renders in dark mode
- Click any diagram to expand to full-screen lightbox
- Close with X button, background click, or Escape key
- All diagram types supported: flowchart, sequence, timeline, graph, etc.

**Important:** See "Color Preferences" section below for exact color values to use.

#### 2. Callout Blocks

Use callout blocks to highlight important information:

```markdown
{{< callout type="info" >}}
**Key Insight:** Important concept explanation here.
{{< /callout >}}

{{< callout type="warning" >}}
**Warning:** Something to be careful about.
{{< /callout >}}

{{< callout type="success" >}}
**Best Practice:** Recommended approach.
{{< /callout >}}

{{< callout type="danger" >}}
**Critical:** Security warning or breaking change.
{{< /callout >}}
```

---

## Writing Style Preferences

### General Guidelines

1. **No emoji** - Use text symbols instead:
   - Use `+` instead of ✅
   - Use `-` instead of ❌
   - Never use 🎉, 🚀, or other emoji

2. **Comprehensive, educational content**
   - Write detailed, thorough articles (5,000+ words is fine)
   - Include code examples in multiple languages
   - Provide comparison tables
   - Add decision frameworks
   - Include real-world use cases

3. **SEO optimization**
   - Use 20+ relevant tags
   - Write descriptive meta descriptions (150-160 chars)
   - Include clear summaries
   - Use proper heading hierarchy

4. **Structure articles with:**
   - Clear introduction
   - Table of contents (via headings)
   - Multiple sections with subheadings
   - Code examples
   - Mermaid diagrams throughout
   - Comparison tables
   - Decision frameworks
   - Conclusion with key takeaways

### Article Front Matter Template

```yaml
---
title: "Clear, Descriptive Title with Keywords"
date: 2025-12-11
draft: false
tags: ["tag1", "tag2", "tag3", "tag4", "tag5", "tag6", "tag7", "tag8"]
categories: ["programming", "architecture"]
description: "SEO-optimized description 150-160 characters with main keywords"
summary: "Preview text for post listings, highlighting key value proposition"
---
```

---

## Color Preferences

**Critical:** The blog uses a **dark, muted, professional color palette**. Never use bright, saturated colors.

### Approved Color Palette

**For mermaid diagrams and inline styles:**

```
Dark Fills (for boxes/containers):
- Dark Slate Blue:  #3A4A5C
- Dark Forest:      #3A4C43
- Dark Brown:       #4C4538
- Dark Burgundy:    #4C3A3C

Borders & Lines:
- Neutral Gray:     #6b7280
- Border Gray:      #4a5568

Text (must be bright for contrast):
- Primary Text:     #f0f0f0 (bright white)
- Background:       #252627 (very dark)

Muted Accent Colors (use sparingly):
- Muted Blue:       #5B8AAF
- Muted Green:      #2A9F66
- Muted Orange:     #CC8F00
- Muted Red:        #C24F54
```

### Mermaid Diagram Color Rules

When creating mermaid diagrams, **always** use this pattern:

```markdown
{{< mermaid >}}
flowchart TB
    subgraph section1["Section Name"]
        node1[Node 1]
        node2[Node 2]
    end

    style section1 fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}
```

**Color assignment for multiple subgraphs:**
- Use `#3A4A5C` (dark slate) for primary/client-side sections
- Use `#3A4C43` (dark forest) for processing/middleware sections
- Use `#4C4538` (dark brown) for data/storage sections
- Use `#4C3A3C` (dark burgundy) for external/third-party sections

**Always specify:**
- `fill:#3A4A5C` (or other dark color)
- `stroke:#6b7280` (neutral gray border)
- `color:#f0f0f0` (bright white text)

### Callout Block Colors

Already configured in CSS - just use the shortcode:
- `type="info"` - Gray
- `type="warning"` - Muted brown
- `type="success"` - Muted green
- `type="danger"` - Muted red

---

## Local Testing with Docker

**Important:** Always test locally before committing blog posts.

### Quick Start

The blog uses a Dockerfile and Makefile for easy local testing:

```bash
# Start Hugo server
make serve

# Start in background
make serve-bg

# View logs (if running in background)
docker logs blog-hugo

# Stop server
make stop
```

**Access:** http://localhost:1313/blog/

### Available Make Commands

- `make build` - Build the Docker image
- `make serve` - Start Hugo server (foreground, interactive)
- `make serve-bg` - Start Hugo server (background, detached)
- `make stop` - Stop the Hugo server
- `make clean` - Remove the Docker image

### Manual Docker Commands

If you prefer not to use Make:

```bash
# Build image
docker build -t blog-hugo .

# Run server (foreground)
docker run --rm -v $(pwd):/src -p 1313:1313 blog-hugo

# Run server (background)
docker run -d --rm -v $(pwd):/src -p 1313:1313 --name blog-hugo blog-hugo

# View logs
docker logs blog-hugo

# Stop server
docker stop blog-hugo
```

### Hugo Container Details

- **Base Image:** `hugomods/hugo:exts`
- **Hugo Version:** v0.152.2+
- **Port:** 1313
- **Volume:** Current directory mounted to `/src`
- **Live Reload:** Enabled (changes auto-rebuild)

### Why Docker?

The Nightfall theme requires Hugo v0.146.0+, but local installations may be outdated. Docker ensures we always use the correct version without version conflicts.

**Dockerfile:**

```dockerfile
FROM hugomods/hugo:exts
WORKDIR /src
EXPOSE 1313
CMD ["server", "--bind", "0.0.0.0", "--baseURL", "http://localhost:1313", "-D"]
```

### Testing Workflow

1. Start Hugo server: `make serve-bg`
2. Make changes to markdown files
3. Hugo automatically rebuilds (check logs: `docker logs blog-hugo`)
4. Refresh browser to see changes
5. Verify mermaid diagrams render correctly
6. Check colors match preferences
7. Test click-to-expand on mermaid diagrams
8. Verify callout blocks display correctly
9. Stop server: `make stop`

---

## Creating New Blog Posts

### Quick Start

```bash
# Create new post
hugo new content/posts/my-new-post.md

# Edit the file
# Add mermaid diagrams
# Use callout blocks
# Test with docker-compose up
# Commit when ready
```

### Article Types & Structure

**Technical deep-dives:**
- Introduction with problem statement
- Background/evolution section (with timeline diagram)
- Multiple sections covering different aspects
- Code examples in multiple languages
- Architecture diagrams (mermaid)
- Comparison tables
- Decision frameworks
- Hybrid/real-world examples
- Conclusion with key takeaways

**Tutorial articles:**
- Clear prerequisites section
- Step-by-step instructions
- Code examples with explanations
- Common pitfalls section
- Best practices
- Further reading

**Comparison articles:**
- Quick comparison table at top
- Individual sections for each option
- Side-by-side code examples
- Decision tree diagram (mermaid)
- Use case mapping

---

## Mermaid Diagram Best Practices

### Types to Use

- **Flowcharts** - For processes, decisions, architectures
- **Sequence diagrams** - For API interactions, message flows
- **Timeline** - For historical evolution, project phases
- **Architecture diagrams** - For system components

### Diagram Guidelines

1. **Keep diagrams readable:**
   - Don't overload with too many nodes
   - Use subgraphs to group related items
   - Label connections clearly

2. **Use consistent styling:**
   - Always apply dark fills (`#3A4A5C`, etc.)
   - Always use bright text (`#f0f0f0`)
   - Always use neutral borders (`#6b7280`)

3. **Add context:**
   - Use descriptive node labels
   - Add notes/annotations where helpful
   - Include legends for complex diagrams

4. **Test interactivity:**
   - Click to verify lightbox works
   - Check that diagrams scale properly
   - Verify text is readable at all sizes

### Example Diagram Templates

**Flowchart:**
```markdown
{{< mermaid >}}
flowchart TB
    subgraph client["Client Layer"]
        web[Web App]
        mobile[Mobile App]
    end

    subgraph api["API Layer"]
        rest[REST API]
        graphql[GraphQL]
    end

    subgraph data["Data Layer"]
        db[(Database)]
        cache[(Cache)]
    end

    web --> rest
    mobile --> graphql
    rest --> db
    graphql --> db
    rest --> cache

    style client fill:#3A4A5C,stroke:#6b7280,color:#f0f0f0
    style api fill:#3A4C43,stroke:#6b7280,color:#f0f0f0
    style data fill:#4C4538,stroke:#6b7280,color:#f0f0f0
{{< /mermaid >}}
```

**Sequence Diagram:**
```markdown
{{< mermaid >}}
sequenceDiagram
    participant Client
    participant Server
    participant Database

    Client->>Server: Request data
    Server->>Database: Query
    Database-->>Server: Results
    Server-->>Client: Response
{{< /mermaid >}}
```

**Timeline:**
```markdown
{{< mermaid >}}
timeline
    title Evolution of Technology
    1990s : HTTP/1.0
          : CGI Scripts
    2000s : REST APIs
          : AJAX
    2010s : WebSocket
          : GraphQL
    2020+ : gRPC
          : HTTP/3
{{< /mermaid >}}
```

---

## Common Tasks

### Updating Mermaid Theme

Mermaid configuration is in `/layouts/_partials/custom-head.html`. The theme variables are already optimized - don't change them unless the user specifically requests it.

### Updating Callout Styles

Callout CSS is in `/static/css/custom.css`. Colors are already set to match the muted palette.

### Adding New Shortcodes

Create new shortcode files in `/layouts/shortcodes/`. Follow the pattern of existing shortcodes (mermaid.html, callout.html).

---

## Git Commit Style

**Important:** Follow these commit message conventions:

1. **No AI mentions** - Never mention Claude, AI, or automated generation
2. **No emoji** - Professional commits only (no 🎉, ✨, etc.)
3. **Be concise** - 50-72 character subject line
4. **Be descriptive** - Explain what changed and why
5. **Use imperative mood** - "Add feature" not "Added feature"

**Good examples:**
```
Add API communication patterns guide with diagrams

Update mermaid theme to dark mode with muted colors

Create callout shortcode for highlighting key information

Configure Docker environment for local Hugo testing
```

**Bad examples:**
```
✨ Add new blog post (emoji)
Updated stuff with Claude's help (mentions AI)
Changes (not descriptive)
Added things (past tense)
```

---

## Deployment

The blog auto-deploys to GitHub Pages via GitHub Actions on every push to `main`.

**Workflow:** `.github/workflows/deploy.yml`

**No manual deployment needed** - just commit and push.

---

## Related Preferences

Based on previous conversations, the blog owner prefers:

1. **Professional, subdued aesthetics** - Never use bright colors
2. **No emoji in blog posts** - Use text symbols (`+`, `-`)
3. **Comprehensive content** - Long-form, detailed articles are encouraged
4. **Educational approach** - Explain the "why" not just the "how"
5. **Multiple examples** - Show code in various languages
6. **Visual aids** - Use mermaid diagrams extensively
7. **Decision frameworks** - Help readers choose between options
8. **Real-world examples** - Show how patterns combine in actual systems

### LinkedIn Post Preferences

**Emoji usage for LinkedIn posts (different from blog):**
- 🔹 for bullet point lists
- 📚 for links to blog posts
- 📦 for links to GitHub repos or crates.io packages

LinkedIn posts should be:
- Direct and straightforward (no hype or false claims)
- Reference all related parts in a series
- Include engagement question at the end
- Use appropriate hashtags (not excessive)

---

## Key Reminders

- Always test locally with `make serve-bg`
- Use mermaid diagrams extensively (with dark theme)
- Apply correct color palette (dark fills, bright text)
- No emoji - use text symbols (+ and -)
- Add 20+ relevant tags for SEO
- Include code examples in multiple languages
- Use callout blocks for important info
- Write comprehensive, educational content
- Test click-to-expand on mermaid diagrams
- Verify colors match preferences before committing
- Stop Hugo server with `make stop` when done

---

## Example Article Structure

```markdown
---
title: "Understanding API Communication Patterns"
date: 2025-12-11
draft: false
tags: ["api", "rest", "graphql", "websocket", "grpc", "architecture"]
categories: ["programming"]
description: "Comprehensive guide to API patterns with examples and diagrams"
summary: "Learn when to use REST, GraphQL, WebSocket, gRPC with decision frameworks"
---

Introduction paragraph setting context...

{{< callout type="info" >}}
**Key Insight:** Main concept explanation here.
{{< /callout >}}

## Section 1: Evolution

{{< mermaid >}}
timeline
    title Historical Context
    1990s : Technology A
    2000s : Technology B
{{< /mermaid >}}

## Section 2: Patterns

### Pattern 1: REST

Explanation...

**Example:**
```javascript
// Code example
```

**When to use:**
- + Good for X
- + Good for Y
- - Not good for Z

{{< mermaid >}}
sequenceDiagram
    participant A
    participant B
    A->>B: Request
{{< /mermaid >}}

[Continue with more sections...]

## Conclusion

Key takeaways:
1. Point 1
2. Point 2
3. Point 3
```

---

**This file documents blog-specific conventions. For general coding standards, see the global CLAUDE.md in ~/.claude/**
