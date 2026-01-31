# Blog Tech Stack

This document describes the infrastructure and tooling that powers the Blackwell Systems blog.

---

## Static Site Generation

**Hugo** - Static site generator
- Version: v0.152.2+ (via Docker)
- Base image: `hugomods/hugo:exts`
- Theme: Nightfall
- Configuration: `hugo.toml`

**Why Hugo:**
- Fast build times
- No runtime dependencies
- Markdown-based content
- Powerful templating system

**Theme: Nightfall**
- Repository: https://github.com/LordMathis/hugo-theme-nightfall
- Customizations:
  - Dark theme with muted color palette
  - Custom mermaid diagram support with click-to-expand lightbox
  - Custom callout blocks (info, warning, success, danger)
  - Table styling for dark theme
  - Navigation hover effects
  - Custom footer (removed Hugo/theme attribution)

---

## Hosting

**GitHub Pages**
- Repository: https://github.com/blackwell-systems/blog
- Branch: `main`
- Deploy: Automatic via GitHub Actions on push
- Workflow: `.github/workflows/deploy.yml`
- Public URL: https://blackwell-systems.github.io/blog/

**Why GitHub Pages:**
- Free hosting for static sites
- Automatic HTTPS
- GitHub Actions integration
- Git-based deployment (commit = deploy)

---

## Domain & DNS

**Domain Registrar:** Cloudflare

**Canonical site:** https://blog.blackwell-systems.com

### Edge-Controlled Static Architecture

This site uses Cloudflare as the edge router and GitHub Pages as the static origin.

```text
              ┌────────────────────────┐
              │      Cloudflare Edge   │
User ───────▶ │  TLS • Identity • Rules│
              └──────────┬─────────────┘
                         │
                         ▼
              ┌────────────────────────┐
              │    GitHub Pages (CDN)  │
              │     Static Origin      │
              └────────────────────────┘
```

**Architecture goals:**
- One canonical public site (`blog.blackwell-systems.com`)
- Preserve legacy links (`blackwell-systems.com/...`)
- Support marketing www alias (`www.blackwell-systems.com`)
- Avoid multi-level TLS failures (`www.blog...`)
- Never expose origin IP
- All traffic terminated at edge and redirected safely

### DNS Layer (Cloudflare)

| Host | Record | Target | Proxy |
|------|--------|--------|-------|
| `blackwell-systems.com` | A | `192.0.2.1` (dummy) | Proxied |
| `www.blackwell-systems.com` | CNAME | `blackwell-systems.com` | Proxied |
| `blog.blackwell-systems.com` | CNAME | `blackwell-systems.github.io` | DNS only |

**Why this works:**

- **`blackwell-systems.com`** - Never fetched from origin, Cloudflare always intercepts
- **`www.blackwell-systems.com`** - Cloudflare-only alias that terminates TLS and redirects
- **`blog.blackwell-systems.com`** - Served directly by GitHub Pages (GitHub issues/manages TLS cert)

This avoids double-TLS and multi-subdomain certificate traps.

### Redirect Rules (Cloudflare Edge)

Cloudflare handles all routing **before** any origin request is made.

**Rule 1 - www → canonical blog (301):**
```
IF Hostname equals www.blackwell-systems.com
THEN 301 redirect to
  concat("https://blog.blackwell-systems.com", http.request.uri)
```
Preserves path and query strings.

**Rule 2 - /oss legacy path (301):**
```
IF Hostname equals blackwell-systems.com
AND (URI Path equals /oss OR starts with /oss/)
THEN 301 redirect to
  concat("https://blog.blackwell-systems.com", http.request.uri.path)
```

**Rule 3 - /consulting legacy path (301):**
```
IF Hostname equals blackwell-systems.com
AND (URI Path equals /consulting OR starts with /consulting/)
THEN 301 redirect to
  concat("https://blog.blackwell-systems.com", http.request.uri.path)
```

**Rule 4 - Product canonicalization (301):**
```
IF Hostname equals blackwell-systems.com
AND (
  URI Path equals /gcp-emulator-pro
  OR URI Path equals /gcp-emulator-pro/
  OR URI Path starts with /gcp-emulator-pro/
)
THEN 301 redirect to
  https://blog.blackwell-systems.com/products/gcp-emulator-pro/
```

**Why this exists:**
- Preserves external links shared before the `/products/` hierarchy existed
- Consolidates SEO authority onto a single canonical page
- Prevents content identity fragmentation
- Allows product URLs to change without breaking public references

**Rule 5 - Apex catch-all (301):**
```
IF Hostname equals blackwell-systems.com
THEN 301 redirect to
  https://blog.blackwell-systems.com/
```

This ensures no request ever reaches the fake IP origin.

### Request Flow

```
User → blackwell-systems.com
        ↓
    Cloudflare Edge
        ↓
   Redirect Rules
        ↓
blog.blackwell-systems.com
        ↓
   GitHub Pages
```

**Example flows:**

| Request | Result |
|---------|--------|
| `https://blackwell-systems.com` | → `https://blog.blackwell-systems.com/` |
| `https://blackwell-systems.com/oss` | → `https://blog.blackwell-systems.com/oss` |
| `https://blackwell-systems.com/gcp-emulator-pro` | → `https://blog.blackwell-systems.com/products/gcp-emulator-pro/` |
| `https://www.blackwell-systems.com/oss?x=1` | → `https://blog.blackwell-systems.com/oss?x=1` |
| `https://blog.blackwell-systems.com` | Served by GitHub |

### Why This Architecture Works

**Avoids TLS traps:**
- No `www.blog...` multi-level subdomain
- Cloudflare only terminates TLS for one-level hosts

**Edge-first:**
- Redirects happen at Cloudflare, not origin
- No unnecessary origin requests

**Zero origin exposure:**
- Apex IP is fake (`192.0.2.1`)
- Cloudflare must redirect, or nothing loads

**Host portability:**
- Can move from GitHub Pages to Netlify, S3, etc.
- Only the blog CNAME changes

**Performance:**
- Edge decision: 10-50ms (nearest edge node)
- Traditional origin redirect: 200-500ms
- No origin latency, no origin failures

### Architecture Deep Dive

This stack implements **Modern Static Architecture**: a high-performance edge redirect engine sitting on top of a zero-maintenance origin.

By combining Cloudflare's edge routing with GitHub Pages as the static host, this architecture solves two classic problems simultaneously:

- **The Apex CNAME problem** (root domains can't CNAME cleanly)
- **The SSL depth problem** (multi-level subdomains break wildcard TLS)

Cloudflare intercepts traffic *before DNS resolution ever reaches a real server*.

#### The Dummy IP as Infrastructure Trigger

Using `192.0.2.1` as the A record for the apex domain is deliberate.

In Cloudflare, a **proxied** DNS record isn't just name resolution—it's a signal to Cloudflare's global network to **terminate TLS and process the request**.

Without a proxied record, redirect rules would never run. The browser would fail DNS lookup before Cloudflare ever saw the request.

By pointing the apex at a non-routable IP and enabling proxy mode, this creates a **serverless routing layer**:

```
User → Cloudflare Edge → Redirect Rules → Real Origin (GitHub)
```

Cloudflare handles identity, legacy paths, and TLS. GitHub only serves the final content.

#### Legacy Path Preservation

Path-specific rules for `/oss` and `/consulting` do real SEO work.

Using `concat("https://blog.blackwell-systems.com", http.request.uri.path)` means a user hitting:

```
https://blackwell-systems.com/oss/project-alpha
```

lands on:

```
https://blog.blackwell-systems.com/oss/project-alpha
```

**The SEO benefit:** Because these are **301 permanent redirects**, search engines transfer authority from the old domain, update their index to the new canonical URLs, and merge historical ranking signals into the new site. This preserves years of link equity.

#### DNS-Only for Blog Subdomain

`blog.blackwell-systems.com` is intentionally **not proxied** through Cloudflare.

**TLS Conflict:** GitHub Pages issues its own Let's Encrypt certificates. If you proxy the domain, GitHub's ACME validation can fail because it sees Cloudflare's IP instead of its own.

**Performance Tradeoff:** You lose Cloudflare edge caching, but GitHub Pages is already served via **Fastly** (a global CDN). The latency difference is negligible.

Result: Cloudflare handles routing, GitHub handles hosting + TLS, no certificate deadlocks.

#### Email Deliverability

The email stack is correctly hardened:

| Record | Purpose |
|--------|---------|
| **MX** | Tells the world where mail is delivered |
| **SPF** | Authorizes which servers can send mail |
| **DKIM** | Cryptographically signs each message |

Together, these form the golden ratio of deliverability. Many setups fail because they skip DKIM—this setup doesn't, which means mail is verifiable, tamper-proof, and far less likely to land in spam.

#### The Big Picture

This architecture provides:

- Cloudflare as **edge router + policy engine**
- GitHub Pages as **static origin**
- One canonical hostname
- Legacy compatibility
- No origin exposure
- No TLS traps
- No server maintenance

This is the same architectural pattern used by modern documentation platforms, open-source portals, and SaaS marketing stacks.

### Email (Zoho Mail)

**MX Records (Mail Exchange):**
- Priority 10: `mx.zoho.com` (primary)
- Priority 20: `mx2.zoho.com` (backup)
- Priority 50: `mx3.zoho.com` (backup)

These direct incoming email to Zoho's mail servers.

**SPF Record (Sender Policy Framework):**
- Type: TXT
- Value: `v=spf1 include:zohomail.com ~all`
- Purpose: Authorizes Zoho to send email on behalf of blackwell-systems.com
- Prevents email spoofing

**DKIM Record (Domain Keys Identified Mail):**
- Type: CNAME
- Name: `zmail._domainkey`
- Purpose: Digital signature for outgoing email
- Zoho signs emails with private key, recipients verify with public key in DNS
- Proves email authenticity and prevents tampering

**Zoho Verification:**
- Type: CNAME
- Name: `zb74673982`
- Purpose: Proves domain ownership to Zoho during setup

**Email deliverability trifecta:**
- MX (where to deliver)
- SPF (who can send)
- DKIM (signature verification)

This ensures emails from support@blackwell-systems.com don't end up in spam.

---

## Local Development

**Docker-based Hugo server:**

```bash
# Start server
make serve-bg

# Access
http://localhost:1313/blog/

# Stop server
make stop
```

**Dockerfile:**
```dockerfile
FROM hugomods/hugo:exts
WORKDIR /src
EXPOSE 1313
CMD ["server", "--bind", "0.0.0.0", "--baseURL", "http://localhost:1313", "-D"]
```

**Why Docker:**
- Nightfall theme requires Hugo v0.146.0+
- Docker ensures consistent version across environments
- No local Hugo installation needed
- Automatic live reload on file changes

**Makefile commands:**
- `make build` - Build Docker image
- `make serve` - Start server (foreground)
- `make serve-bg` - Start server (background)
- `make stop` - Stop server
- `make clean` - Remove Docker image

---

## Content Management

**Structure:**
```
content/
├── posts/           # Blog articles
├── products/        # Product pages
│   ├── _index.md    # Products overview
│   └── gcp-emulator-pro.md
├── about.md         # About page
├── consulting.md    # Consulting page
└── oss.md           # Open source software page
```

**Custom components:**

**Mermaid diagrams:**
```markdown
{{< mermaid >}}
flowchart TB
    A --> B
{{< /mermaid >}}
```
- Dark theme with muted colors
- Click-to-expand lightbox
- All diagram types supported

**Callout blocks:**
```markdown
{{< callout type="info" >}}
Content here
{{< /callout >}}
```
- Types: info, warning, success, danger
- Styled for dark theme

---

## Deployment Pipeline

**GitHub Actions workflow:**

1. **Trigger:** Push to `main` branch
2. **Build:** Hugo builds static site from markdown
3. **Deploy:** Push to `gh-pages` branch
4. **Serve:** GitHub Pages serves from `gh-pages`
5. **CDN:** Cloudflare caches and serves via blog.blackwell-systems.com

**Zero manual steps** - commit to main = live in minutes

---

## Customizations

**CSS:** `/static/css/custom.css`
- Dark, muted color palette
- Navigation hover effects (animated underlines)
- Table styling (borders, padding, hover)
- Mermaid diagram styling
- Callout block styling

**Mermaid configuration:** `/layouts/_partials/custom-head.html`
- Dark theme variables
- Click-to-expand JavaScript
- Lightbox modal styling

**Footer:** `hugo.toml`
- Custom: "© 2026 Blackwell Systems"
- Removed: Hugo and Nightfall theme attribution

**Navigation:** `hugo.toml`
- Order: Posts → Products → Open Source Software → Consulting → About
- Spacing: 0.75rem between items
- Hover: Animated underline effect

---

## Why This Stack?

**Static site advantages:**
- No server to maintain
- No runtime security vulnerabilities
- Fast (pre-rendered HTML)
- Version controlled (content in git)
- Free hosting (GitHub Pages)

**Hugo advantages:**
- Fast builds (milliseconds for incremental)
- Markdown-based (easy to write)
- No JavaScript runtime required
- Powerful templating
- Great theme ecosystem

**Cloudflare advantages:**
- DDOS protection
- Free SSL/HTTPS
- Global CDN
- DNS management
- Email configuration
- Redirect Rules (edge routing without origin)

**GitHub Pages advantages:**
- Free for public repos
- Automatic HTTPS
- GitHub Actions integration
- Git-based workflow

---

## Stack Summary

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Static Site Generator** | Hugo v0.152.2+ | Build markdown to HTML |
| **Theme** | Nightfall (customized) | Dark theme, styling |
| **Hosting** | GitHub Pages | Static site hosting |
| **Domain** | Cloudflare | DNS, CDN, DDOS protection |
| **Email** | Zoho Mail | Professional email |
| **Deployment** | GitHub Actions | Automated CI/CD |
| **Local Dev** | Docker + Hugo | Consistent dev environment |
| **Content** | Markdown | Posts, pages, products |
| **Diagrams** | Mermaid.js | Architecture diagrams |
| **Version Control** | Git + GitHub | Source control |

---

## Total Cost

**One-time:**
- Domain registration: $10/year (Cloudflare)

**Recurring:**
- Email (Zoho Mail): $1/month

**Zero cost:**
- Hosting (GitHub Pages): Free
- CDN/HTTPS (Cloudflare): Free
- DNS (Cloudflare): Free
- CI/CD (GitHub Actions): Free
- SSL certificates: Free

**Total: $22/year ($10 domain + $12 email)**

No hosting costs, no variable costs, no bandwidth charges.

---

**Last Updated:** 2026-01-29
