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

**DNS Configuration:**

### Website Traffic

**Root domain (blackwell-systems.com):**
- Type: A Record
- Value: `192.0.2.1` (dummy origin)
- Proxy: Enabled (orange cloud)
- Purpose: Edge-only redirect topology (never hits origin)
- Redirects: Cloudflare Redirect Rules route all traffic to blog subdomain

**Blog subdomain (blog.blackwell-systems.com):**
- Type: CNAME
- Value: `blackwell-systems.github.io`
- Proxy: Enabled (orange cloud)
- Target: GitHub Pages

**Proxy status (orange cloud):**
- Traffic routes through Cloudflare edge
- Provides: DDOS protection, SSL/HTTPS, CDN caching, Redirect Rules
- Masks origin server IP

**Cloudflare Redirect Rules:**

Rule 1 - OSS namespace passthrough (301):
```
When: (http.host eq "blackwell-systems.com" and
       (http.request.uri.path eq "/oss" or
        starts_with(http.request.uri.path, "/oss/")))
Then: concat("https://blog.blackwell-systems.com", http.request.uri.path)
```
- Preserves `/oss` and `/oss/*` paths
- Query strings preserved

Rule 2 - Catch-all fallback (301):
```
When: (http.host eq "blackwell-systems.com")
Then: https://blog.blackwell-systems.com/
```
- Redirects all other traffic to blog root
- Prevents origin 522 errors (redirect-only domain)

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
