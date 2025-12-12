# Blackwell Systems Blog

[![Blackwell Systems™](https://raw.githubusercontent.com/blackwell-systems/blackwell-docs-theme/main/badge-trademark.svg)](https://github.com/blackwell-systems)
[![Proprietary](https://raw.githubusercontent.com/blackwell-systems/blackwell-docs-theme/main/badge-proprietary.svg)](https://github.com/blackwell-systems/blog)
[![Deploy Status](https://github.com/blackwell-systems/blog/workflows/Deploy%20Hugo%20site%20to%20Pages/badge.svg)](https://github.com/blackwell-systems/blog/actions)

[![Hugo](https://img.shields.io/badge/Hugo-0.139.4-ff4088?logo=hugo&logoColor=white)](https://gohugo.io)
[![Theme](https://img.shields.io/badge/Theme-Nightfall-purple)](https://github.com/LordMathis/hugo-theme-nightfall)
[![Sponsor](https://img.shields.io/badge/Sponsor-Buy%20Me%20a%20Coffee-yellow?logo=buy-me-a-coffee&logoColor=white)](https://buymeacoffee.com/blackwellsystems)

> **Technical writing on developer tools, AI workflows, and dotfiles.** Deep dives into Claude Code integration, secret management, and building better development environments.

[Read the Blog](https://blackwell-systems.github.io/blog/) | [GitHub](https://github.com/blackwell-systems/blog)

---

## About

This is the official technical blog for **Blackwell Systems™**, covering:

- **Developer Tools** – CLI utilities, shell configuration, productivity workflows
- **AI-Assisted Development** – Claude Code integration, context management, AI workflows
- **Dotfiles & Configuration** – Cross-platform setup, secret management, machine templates
- **Open Source Projects** – Deep dives into dotclaude, blackdot, and other tools

**Published at:** https://blackwell-systems.github.io/blog/

---

## Local Development

### Prerequisites

- [Hugo Extended](https://gohugo.io/installation/) v0.139.4 or higher
- Git with submodules support

### Setup

```bash
# Clone repository with theme submodule
git clone --recursive git@github.com:blackwell-systems/blog.git
cd blog

# Or if already cloned, fetch submodules
git submodule update --init --recursive
```

### Run Development Server

```bash
hugo server -D

# With live reload and draft posts
hugo server --bind 0.0.0.0 --baseURL http://localhost:1313 -D
```

Visit: http://localhost:1313/blog/

### Build for Production

```bash
hugo --minify

# Output in public/ directory
```

---

## Project Structure

```
blog/
├── content/
│   ├── posts/           # Blog posts (Markdown)
│   └── about/           # About page
├── layouts/             # Custom Hugo layouts
│   └── shortcodes/      # Reusable content blocks
├── static/              # Static assets (images, CSS, JS)
├── themes/
│   └── nightfall/       # Hugo Nightfall theme (submodule)
├── hugo.toml            # Hugo configuration
└── README.md            # This file
```

---

## Writing Posts

### Create New Post

```bash
hugo new content/posts/my-new-post.md
```

### Front Matter Template

```yaml
---
title: "Your Post Title"
date: 2025-12-02
draft: false
tags: ["tag1", "tag2", "tag3"]
categories: ["tutorials"]
description: "SEO description (150-160 chars)"
summary: "Preview text shown in post listings"
---

Your content here...
```

### Writing a Post Series

To group related posts into a series (like "Part 1", "Part 2", etc.):

```yaml
---
title: "Building Go Libraries: Part 1 - Project Structure"
date: 2025-12-15
draft: false
series: ["go-library-development"]
seriesOrder: 1
tags: ["go", "golang", "libraries"]
---
```

**How it works:**
- All posts with the same `series` value are grouped together
- `seriesOrder` controls the display order (1, 2, 3, etc.)
- A navigation box appears at the top/bottom of each post showing all parts
- Automatic series page created at `/series/go-library-development/`

**Example series structure:**

```yaml
# Part 1
series: ["go-library-development"]
seriesOrder: 1

# Part 2
series: ["go-library-development"]
seriesOrder: 2

# Part 3
series: ["go-library-development"]
seriesOrder: 3
```

**Series naming:**
- Use kebab-case: `go-library-development`, `production-practices`
- Keep names short and descriptive
- Series names are auto-humanized in display ("go-library-development" → "Go Library Development")

---

## Custom Components

### Mermaid Diagrams

Interactive diagrams with click-to-expand lightbox.

**Usage:**

```markdown
{{< mermaid >}}
flowchart TB
    A[Start] --> B[Process]
    B --> C[End]
{{< /mermaid >}}
```

**Features:**
- Rendered with dark theme matching site aesthetic
- Larger size with subtle background container
- Hover effect indicates clickability
- Click any diagram to expand to full screen lightbox
- Close lightbox via X button, background click, or Escape key
- Responsive scaling up to 95% of viewport

**Theme colors:**
- Primary: #80AADD (blue)
- Background: #252627
- Custom palette matching nightfall theme

---

### Callout Blocks

Callout blocks highlight important information with colored accents. Four variants are available:

**Usage:**

```markdown
{{< callout type="info" >}}
**Title:** Your message here.
{{< /callout >}}

{{< callout type="warning" >}}
**Warning:** Something to be careful about.
{{< /callout >}}

{{< callout type="success" >}}
**Success:** Positive outcome or best practice.
{{< /callout >}}

{{< callout type="danger" >}}
**Critical:** Important security or breaking change.
{{< /callout >}}
```

**Variants:**

| Class | Color | Use Case |
|-------|-------|----------|
| `.callout.info` | Blue (#80AADD) | General information, tips, concepts |
| `.callout.warning` | Orange (#FFB300) | Warnings, gotchas, deprecated features |
| `.callout.success` | Green (#33D17A) | Best practices, success patterns, wins |
| `.callout.danger` | Red (#F26E74) | Critical warnings, security issues, breaking changes |

**Styling:**
- Subtle 10% opacity background (monochrome-friendly)
- 4px colored left border accent
- 1.5rem padding for comfortable reading
- Auto-margin for proper spacing

**Example in markdown:**

```markdown
{{< callout type="info" >}}
**Key Concept:** Runtime objects are ephemeral. <u>This is why we need serialization.</u>
{{< /callout >}}
```

---

## Theme

This blog uses the **[Nightfall](https://github.com/LordMathis/hugo-theme-nightfall)** theme by LordMathis, included as a Git submodule.

### Color Palette

<!-- Palette swatches -->
![Accent](https://img.shields.io/badge/-f41c80?style=flat)
![Slate](https://img.shields.io/badge/-6b7280?style=flat)
![UI](https://img.shields.io/badge/-292a2d?style=flat)
![UI](https://img.shields.io/badge/-292c34?style=flat)
![UI](https://img.shields.io/badge/-282f3c?style=flat)
![UI](https://img.shields.io/badge/-263143?style=flat)

### Update Theme

```bash
cd themes/nightfall
git pull origin main
cd ../..
git add themes/nightfall
git commit -m "chore: Update nightfall theme"
```

---

## Deployment

The blog is automatically deployed to **GitHub Pages** via GitHub Actions on every push to `main`.

**Workflow:** `.github/workflows/deploy.yml`

**Live URL:** https://blackwell-systems.github.io/blog/

---

## Related Projects

- **[dotclaude](https://github.com/blackwell-systems/dotclaude)** – Profile management for Claude Code
- **[dotfiles](https://github.com/blackwell-systems/dotfiles)** – AI-ready dotfiles with multi-vault secrets
- **[blackwell-docs-theme](https://github.com/blackwell-systems/blackwell-docs-theme)** – Docsify theme for documentation sites

---

## License

**© 2025 Blackwell Systems™. All Rights Reserved.**

This blog and its content are proprietary and confidential. No part of this repository may be reproduced, distributed, or transmitted in any form without prior written permission from Blackwell Systems.

**Blackwell Systems™** is a trademark of Blackwell Systems. See [BRAND.md](BRAND.md) for usage guidelines.

**Public but Proprietary:** This repository is publicly visible for transparency and reference, but is not open source and does not accept outside contributions.

---

**Questions?** Contact via [GitHub Issues](https://github.com/blackwell-systems/blog/issues) or visit the [main organization page](https://github.com/blackwell-systems).
