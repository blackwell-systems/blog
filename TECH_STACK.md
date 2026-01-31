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

### Network Architecture: Cloudflare → GitHub Pages Edge Redirect

This site uses Cloudflare as the edge router and GitHub Pages as the static origin.

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

**Rule 4 - Apex catch-all (301):**
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

This tech stack is a textbook example of "Modern Static Architecture"—essentially a high-performance redirect engine sitting on top of a zero-maintenance origin.

**The Apex CNAME Problem + SSL Depth Problem:**

Solved simultaneously by using Cloudflare's logic to intercept traffic before it ever looks for a real server.

#### The "Dummy IP" as Infrastructure Trigger

The use of `192.0.2.1` is a pro-level move. In Cloudflare, a "Proxied" record isn't just a DNS entry—it's a toggle that tells Cloudflare's global network to "listen" for traffic on that hostname.

Without that dummy record, Redirect Rules would never trigger because the browser would get a "Domain not found" error before it even sent the HTTP request to Cloudflare.

This creates a serverless routing layer where the "origin" (GitHub) only handles the final destination, and Cloudflare handles the identity and legacy path management.

#### Legacy Path Preservation

Rules 2 and 3 (`/oss` and `/consulting`) are critical for SEO preservation. By using `concat` with `http.request.uri.path`, a user clicking a 5-year-old link to `blackwell-systems.com/oss/project-alpha` lands exactly on `blog.blackwell-systems.com/oss/project-alpha`.

**The SEO Win:** Because these are 301 (Permanent) redirects, Google eventually updates its index to the new blog URLs, effectively merging the "authority" of the old domain into the new one.

#### DNS-Only for Blog Subdomain

`blog.blackwell-systems.com` is set to DNS Only (Grey Cloud). This is a smart choice for GitHub Pages specifically:

**The SSL Conflict:** GitHub Pages generates its own Let's Encrypt certificates. If you "Orange Cloud" (proxy) that record, GitHub's automated SSL bot sometimes fails to verify the domain because it sees Cloudflare's IP instead of its own.

**The Performance Tradeoff:** You lose Cloudflare's "Edge Caching" for the blog content, but GitHub Pages is already served via its own global CDN (Fastly), so the speed difference is negligible.

#### Email Deliverability

The email setup is airtight.

**MX + SPF + DKIM** is the "Golden Ratio" for deliverability.

Many people forget the DKIM (CNAME) record, which is why their emails end up in spam. By including it, every email is digitally signed, proving to Gmail/Outlook that the message hasn't been tampered with.

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
