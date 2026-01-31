---
title: "Edge-Native Publishing Architecture with Cloudflare and GitHub Pages"
date: 2026-01-31
draft: false
tags: ["cloudflare", "github-pages", "edge-computing", "cdn", "dns", "tls", "architecture", "static-site", "hugo", "devops", "infrastructure", "networking", "web-architecture", "ssl", "seo", "301-redirects", "serverless"]
categories: ["architecture", "infrastructure"]
description: "A reference architecture for building edge-native publishing systems using Cloudflare as an edge router and GitHub Pages as the static origin. Includes DNS configuration, redirect rules, and implementation guide."
summary: "A production-grade architecture pattern for static publishing that uses Cloudflare's edge network for routing and GitHub Pages for content delivery. Complete with DNS setup, redirect rules, and step-by-step implementation guide."
---

This is a reference architecture for **edge-native static publishing**: routing decisions happen at the edge (Cloudflare), content is served from a zero-maintenance origin (GitHub Pages), and the entire system costs ~$24/year ($12 domain + $12 email).

**Note:** This article uses generic `example.com` placeholders. The actual implementation uses `blackwell-systems.com` (apex/www) and `blog.blackwell-systems.com` (canonical site).

---

## Core Concepts

Before diving into the architecture, it's important to understand the fundamental technologies this pattern uses.

### Static Sites

A **static site** is pre-rendered HTML served directly to users—no server-side code execution, no database queries, no runtime processing.

**Traditional (dynamic) flow:**
```
User request → Server executes code → Queries database → Renders HTML → Sends response
```

**Static site flow:**
```
User request → Server sends pre-built HTML file
```

**How static sites are built:**

Static site generators (Hugo, Jekyll, Next.js, Gatsby) take source files (Markdown, templates, data) and **build** HTML at deployment time, not request time.

```bash
# Build process (happens once during deployment)
hugo build
  → Reads content/posts/*.md
  → Applies templates
  → Generates public/index.html, public/posts/article.html, etc.

# Runtime (every user request)
  → Serve public/article.html (no processing, just file delivery)
```

**Benefits:**
- **Fast:** No database queries, no code execution
- **Secure:** No server-side code to exploit
- **Cheap:** Can be served from CDNs, no compute costs
- **Scalable:** Pre-rendered files can be cached globally

**Tradeoff:** Content changes require rebuilding and redeploying. Not suitable for user-specific dynamic content (e.g., dashboards, real-time data).

### GitHub Pages

**GitHub Pages** is a free static hosting service that:

1. Serves files from a GitHub repository
2. Provides a CDN (Fastly) for global delivery
3. Automatically builds Jekyll sites (or accepts pre-built HTML)
4. Issues free HTTPS certificates (Let's Encrypt) for custom domains
5. Supports custom domains via CNAME configuration

**How it works:**

```
Your repo (main branch or gh-pages branch)
  → GitHub's build pipeline (if using Jekyll)
  → Static files served via Fastly CDN
  → Available at username.github.io/repo or your custom domain
```

**Why GitHub Pages for this architecture:**
- Zero cost (free for public repositories)
- Zero maintenance (no servers to manage)
- Global CDN included (Fastly)
- Automatic HTTPS
- Git-based deployment (push to deploy)

### The Edge

The **edge** refers to servers geographically distributed close to users, as opposed to a centralized origin server.

**Traditional architecture:**
```
User in Tokyo → Origin server in Virginia (200ms roundtrip)
User in London → Origin server in Virginia (100ms roundtrip)
User in Sydney → Origin server in Virginia (250ms roundtrip)
```

**Edge architecture:**
```
User in Tokyo → Tokyo edge node (10ms)
User in London → London edge node (15ms)
User in Sydney → Sydney edge node (20ms)
```

**What edge nodes do:**

1. **Terminate TLS** - Handle HTTPS without origin involvement
2. **Cache content** - Serve cached responses without origin requests
3. **Execute logic** - Run routing rules, redirects, transformations
4. **Route requests** - Forward to origin only when necessary

**Cloudflare's edge network:**
- 330+ data centers globally
- Automatic routing to nearest node
- Shared infrastructure (free tier available)

### Edge-Native vs Traditional

**Traditional static hosting:**
```
User → Origin CDN → Origin server → Static files
```
All logic (routing, redirects) happens at the origin.

**Edge-native architecture:**
```
User → Edge (routing logic) → Origin (only canonical content)
```
Routing decisions happen at the edge. Origin only serves one canonical hostname.

**Why this matters:**

**Edge-native enables:**
- **Faster redirects** (10-50ms vs 200-500ms)
- **Origin protection** (no direct origin access)
- **Zero origin for redirects** (dummy IP, edge handles everything)
- **Global policy enforcement** (rules execute at every edge node)

**Traditional requires:**
- Running a server for redirects
- Origin handles all routing logic
- Origin exposed to public internet
- Centralized latency (distance to origin matters)

---

## Architecture Overview

```text
              ┌──────────────────────────┐
              │      Cloudflare Edge     │
User ────────►│  TLS • Identity • Rules  │
              └────────────┬─────────────┘
                           │ (redirect)
                           ▼
              ┌──────────────────────────┐
              │   GitHub Pages (Fastly)  │
              │      Static Origin       │
              └──────────────────────────┘
```

Cloudflare intercepts traffic at the edge and makes routing decisions before any origin request. The origin (GitHub Pages) only serves the canonical hostname.

### The Three Planes

| Plane | Owner | Responsibility |
|-------|-------|----------------|
| **Edge Plane** | Cloudflare | TLS termination, identity (apex/www), redirects, legacy paths |
| **Content Plane** | GitHub Pages | Static HTML delivery, CDN (Fastly), origin TLS |
| **Authoring Plane** | Hugo/Jekyll/etc + Git | Content creation, templating, version control |

Each plane operates independently. You can swap GitHub Pages for Netlify without changing edge routing. You can change Hugo to Jekyll without touching DNS.

---

## DNS Configuration

### Records

| Host | Type | Target | Proxy |
|------|------|--------|-------|
| `example.com` | A | `192.0.2.1` | Proxied |
| `www.example.com` | CNAME | `example.com` | Proxied |
| `blog.example.com` | CNAME | `username.github.io` | DNS only |

### Why This Structure

**Apex domain (`example.com`):**
- Points to `192.0.2.1` (RFC 5737 documentation IP, non-routable)
- Proxied through Cloudflare (orange cloud)
- Never contacts origin—Cloudflare handles all requests via Redirect Rules

**www subdomain (`www.example.com`):**
- CNAME to apex
- Proxied through Cloudflare
- Terminates TLS at edge, redirects to canonical blog hostname

**Blog subdomain (`blog.example.com`):**
- CNAME to GitHub Pages
- **DNS only** (gray cloud, not proxied)
- GitHub Pages handles TLS (Let's Encrypt via ACME)
- Served directly via Fastly CDN

### The Dummy IP Strategy

`192.0.2.1` is from TEST-NET-1, reserved for documentation. It's guaranteed non-routable.

In Cloudflare, a **proxied** record signals the edge to terminate TLS and evaluate Redirect Rules. Without the dummy IP + proxy mode, DNS queries would fail before Cloudflare could intercept.

This creates a **serverless routing layer**: all routing logic lives at the edge, no origin server required for redirects.

---

## Redirect Rules

All routing logic is declarative—implemented as Cloudflare Redirect Rules. Rules execute at every edge node globally before any origin request.

### Rule 1: www → Canonical Blog

```
IF Hostname equals www.example.com
THEN 301 redirect to
  concat("https://blog.example.com", http.request.uri)
```

**Preserves:** Full URI (path + query string)

**Example:**
```
https://www.example.com/about?ref=home
  → https://blog.example.com/about?ref=home
```

### Rule 2: Section Namespace Preservation

```
IF Hostname equals example.com
AND (URI Path equals /oss OR starts with /oss/)
THEN 301 redirect to
  concat("https://blog.example.com", http.request.uri.path)
```

**Repeat for each legacy section** (`/consulting`, `/docs`, `/api`, etc.)

**Purpose:** Preserves SEO for old section URLs. Search engines transfer authority from `example.com/oss` to `blog.example.com/oss`.

**Note:** This rule uses `http.request.uri.path` (path only), which **drops query strings**. If you need to preserve query parameters (UTM tags, tracking params), use `http.request.uri` instead. The actual implementation drops query strings for section redirects—they're used for SEO preservation of deep links, not marketing campaigns.

### Rule 3: Product Canonicalization

```
IF Hostname equals example.com
AND (
  URI Path equals /product-name
  OR URI Path equals /product-name/
  OR URI Path starts with /product-name/
)
THEN 301 redirect to
  https://blog.example.com/products/product-name/
```

**Use case:** Historical product URLs shared before `/products/` hierarchy existed. Consolidates SEO authority onto one canonical URL.

### Rule 4: Apex Catch-All

```
IF Hostname equals example.com
THEN 301 redirect to
  https://blog.example.com/
```

**Critical:** This rule must be **last**. It handles all traffic that doesn't match earlier rules, ensuring no request reaches the dummy IP.

### Rule Processing Order

Rules execute in order until a match:

1. www redirect (Rule 1)
2. Specific path rules (Rules 2-3: /oss, /consulting, /product-name)
3. Apex catch-all (Rule 4 - must be last)

The catch-all never runs if a more specific rule matches first.

---

## Implementation Guide

### Phase 1: Prepare Content

1. Deploy static site to GitHub Pages (Hugo, Jekyll, Next.js, etc.)
2. Verify it works at `username.github.io/repo`
3. Do **not** configure custom domain yet

### Phase 2: Configure Cloudflare DNS

1. Add domain to Cloudflare
2. Update nameservers at your registrar to Cloudflare's
3. Wait 24-48 hours for propagation
4. Verify: `dig NS example.com` should return Cloudflare nameservers

### Phase 3: Set Up Blog Subdomain

1. Add CNAME record: `blog.example.com` → `username.github.io`
2. Set to **DNS only** (gray cloud, not proxied)
3. In GitHub Pages settings, add custom domain: `blog.example.com`
4. Wait 5-10 minutes for GitHub to issue Let's Encrypt certificate
5. Verify HTTPS: `curl -I https://blog.example.com`

### Phase 4: Configure Apex Domain

1. Add A record: `example.com` → `192.0.2.1`
2. Set to **Proxied** (orange cloud)
3. Add CNAME: `www.example.com` → `example.com`
4. Set to **Proxied** (orange cloud)

At this point, both apex and www will fail (522 errors) because no redirect rules exist yet.

### Phase 5: Add Redirect Rules

In Cloudflare dashboard → Rules → Redirect Rules:

1. Add www redirect rule
2. Add section-specific rules (if applicable)
3. Add product rules (if applicable)
4. Add apex catch-all rule (must be last)

Test each rule individually before enabling the next.

### Phase 6: Verify

Test all URL patterns:

```bash
# Should redirect to blog
curl -I https://example.com
curl -I https://www.example.com

# Should redirect preserving paths
curl -I https://example.com/oss
curl -I https://www.example.com/about?ref=test

# Should serve directly from GitHub Pages
curl -I https://blog.example.com
```

All redirects should be **301 Permanent**.

---

## Design Decisions Explained

### Why Proxy the Apex but Not the Blog?

**Apex + www are proxied** because they exist solely for redirects. Cloudflare must intercept traffic to evaluate Redirect Rules.

**Blog is DNS-only** because:
- GitHub Pages needs direct DNS resolution to issue Let's Encrypt certificates (ACME validation)
- GitHub Pages already serves via Fastly CDN—adding Cloudflare proxy provides no performance benefit
- Avoids double-CDN complexity

### Why 301 Permanent Redirects?

**301** signals to search engines:
- Transfer ranking authority from old URL to new URL
- Update index to replace old URLs with new ones
- Merge historical SEO signals

**302 Temporary** would preserve old URLs in search index indefinitely.

### Why Path-Preserving Redirects?

Redirecting `example.com/oss/project` to `blog.example.com/oss/project` (not just `blog.example.com`) preserves:
- Deep links from external sites
- Bookmarks and saved URLs
- SEO for specific pages (not just domain authority)

This is critical for maintaining traffic after domain migration.

### Why Separate Edge and Content Planes?

**Decoupling enables:**
- **Origin portability:** Migrate from GitHub Pages to Netlify by changing one CNAME
- **Independent scaling:** Edge routing scales independently of content delivery
- **Failure isolation:** Cloudflare outage affects redirects, not content delivery (and vice versa)
- **Technology flexibility:** Change static site generator without touching DNS

---

## Performance Characteristics

### Redirect Latency

**Traditional origin-based redirect:**
```
Client → Origin (200-500ms) → 301 Response → Redirect
```

**Edge-based redirect:**
```
Client → Cloudflare Edge (10-50ms) → 301 Response → Redirect
```

**20x faster** because redirects happen at the nearest edge node (330+ globally), not a centralized origin server.

### Content Delivery

**blog.example.com** is served via:
- GitHub Pages → Fastly CDN (global)
- Typical latency: 20-100ms depending on edge proximity

**Why not proxy blog through Cloudflare?**

You'd get:
- Cloudflare edge → Fastly CDN → GitHub Pages origin

Adding Cloudflare between user and Fastly provides minimal benefit and breaks GitHub's certificate automation.

---

## When to Use This Pattern

**Good fit:**
- Static sites (pre-rendered HTML)
- Documentation platforms
- Blogs and marketing sites
- Open source project sites
- Low-traffic applications (<10M requests/month on free tier)

**Not a fit:**
- Dynamic server-side applications (use Workers or origin servers)
- Real-time applications (WebSocket support limited)
- High-security applications requiring origin IP protection beyond Cloudflare

---

## Cost Analysis

| Component | Cost |
|-----------|------|
| Domain registration | $12/year |
| Email (Zoho Mail) | $12/year ($1/month) |
| Cloudflare Free | $0/month |
| GitHub Pages | $0/month (public repos) |
| **Total** | **$24/year** |

**What you get:**
- Global CDN (Cloudflare + Fastly)
- Automatic HTTPS (Let's Encrypt)
- DDoS protection (Cloudflare)
- Professional email (@yourdomain.com)
- Zero server maintenance
- Unlimited bandwidth (within GitHub Pages limits)

Compare to:
- VPS hosting: $60-600/year
- Managed static hosting: $240-2400/year
- Email hosting alone: $60-120/year (Google Workspace, Microsoft 365)

---

## Common Issues and Solutions

### Issue: 522 Error on Apex Domain

**Cause:** No redirect rules configured, or rules disabled

**Fix:** Verify Redirect Rules are active and apex domain is proxied (orange cloud)

### Issue: GitHub Pages Certificate Failed

**Cause:** Blog subdomain is proxied through Cloudflare

**Fix:** Set blog subdomain to **DNS only** (gray cloud). Wait 5-10 minutes for GitHub to retry certificate issuance.

### Issue: Query Strings Dropped on Redirect

**Cause:** Using `http.request.uri.path` instead of `http.request.uri`

**Fix:** Use full URI for www redirect:
```
concat("https://blog.example.com", http.request.uri)
```

### Issue: Search Engines Still Showing Old URLs

**Cause:** Recently migrated, search engines haven't updated index yet

**Fix:** Wait 4-8 weeks. Submit new sitemap to Google Search Console. Verify 301 redirects are working (not 302).

---

## Extensions and Variations

### Multiple Products

Add a rule per product:

```
IF Hostname equals example.com
AND URI Path starts with /product-a/
THEN 301 redirect to
  https://blog.example.com/products/product-a/
```

### Subdomain for Documentation

Same pattern:
- `docs.example.com` → CNAME to docs hosting (DNS only)
- Redirect rules remain unchanged

### Staging Environment

Add staging subdomain:
- `staging.blog.example.com` → CNAME to staging GitHub Pages (DNS only)
- No redirect rules needed (staging is separate from production)

---

## Migration from Traditional Hosting

### If You're Currently on VPS/Shared Hosting

1. Build static version of site (use static site generator)
2. Follow implementation guide above
3. Keep old hosting active during DNS propagation (48 hours)
4. Monitor traffic for 1 week
5. Shut down old hosting after confirming migration success

### If You're Currently Using Apex Domain as Primary

1. Deploy to `blog.example.com` first (Phase 3)
2. Test thoroughly before adding redirects
3. Add redirect rules (Phase 5)
4. Monitor 404 rates for broken links
5. Update external links where possible (social media, backlinks you control)

---

## Architectural Invariants

These principles define the pattern:

1. **All identity lives at the edge** - Origin never makes routing decisions
2. **Origins serve content, not routes** - Prevents origin compromise from affecting routing
3. **Legacy paths are first-class** - Old URLs work indefinitely via redirects
4. **TLS is single-owner** - Each subdomain level has one TLS authority (no coordination)
5. **Static content only** - No server-side execution, minimal attack surface

Violating these principles breaks the architecture's guarantees.

---

## Comparison to Alternatives

### vs ALIAS/ANAME Records

**ALIAS/ANAME pros:**
- Simpler DNS setup (no dummy IP)

**ALIAS/ANAME cons:**
- Proprietary (not universal DNS standard)
- Locks you into specific DNS provider
- No redirect logic (can't preserve legacy paths)

**This pattern wins on:** Portability, flexibility, SEO preservation

### vs Cloudflare Workers

**Workers pros:**
- More flexibility (custom JavaScript logic)
- Can transform content, not just redirect

**Workers cons:**
- More complex (code instead of declarative rules)
- Higher cost at scale (CPU time billing)
- Requires deployment pipeline

**This pattern wins on:** Simplicity, cost, declarative config

### vs Origin-Based Redirects

**Origin redirects pros:**
- Traditional, well-understood pattern

**Origin redirects cons:**
- Requires running a server (cost + maintenance)
- Origin latency (200-500ms vs 10-50ms)
- Origin failures affect redirects

**This pattern wins on:** Performance, cost, reliability

---

## Further Reading

**Cloudflare:**
- [Redirect Rules Documentation](https://developers.cloudflare.com/rules/url-forwarding/)
- [Proxied DNS Records](https://developers.cloudflare.com/dns/manage-dns-records/reference/proxied-dns-records/)
- [SSL/TLS Mode Selection](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/)

**GitHub Pages:**
- [Custom Domain Configuration](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site)
- [HTTPS for Custom Domains](https://docs.github.com/en/pages/getting-started-with-github-pages/securing-your-github-pages-site-with-https)

**DNS Standards:**
- [RFC 5737 - IPv4 Documentation Addresses](https://datatracker.ietf.org/doc/html/rfc5737)
- [RFC 2606 - Reserved Top Level Domains](https://datatracker.ietf.org/doc/html/rfc2606)

**SEO:**
- [Google 301 Redirect Guidance](https://developers.google.com/search/docs/crawling-indexing/301-redirects)
- [Site Migration with URL Changes](https://developers.google.com/search/docs/crawling-indexing/site-move-with-url-changes)

---

## Summary

This architecture provides:

- **Edge-first routing** (10-50ms global latency)
- **Zero-maintenance origin** (GitHub Pages, static files)
- **SEO preservation** (301 redirects with path preservation)
- **TLS isolation** (no coordination between providers)
- **Origin portability** (swap hosting without DNS changes)
- **$24/year cost** (domain + email, everything else free)

The pattern is production-ready, scales to millions of requests, and requires no server maintenance. It's the same architectural approach used by modern documentation platforms and open-source project sites.
