---
title: "Building a Low-Cost Production-Grade Edge-Native Publishing Architecture with Cloudflare and GitHub Pages"
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
              │   Cloudflare Edge (330+) │
User ────────►│  Routing • TLS • Rules   │
              └────────────┬─────────────┘
                           │ (301 redirect)
                           ▼
              ┌──────────────────────────┐
              │   Fastly Edge (Global)   │
              │  Content CDN via GitHub  │
              └──────────────────────────┘
```

**Two global CDN networks working in perfect coordination:**

**Cloudflare's edge (330+ nodes)** handles routing decisions in 10-50ms globally, triggered by a dummy IP (192.0.2.1) that creates a routing fabric with zero origin. Redirect rules execute at every edge node—no centralized server required.

**Fastly's edge (via GitHub Pages)** caches and delivers pre-rendered HTML from geographically distributed points of presence. Pure content acceleration with no routing logic.

The two networks never interfere with each other. Cloudflare evaluates redirect rules and sends tiny 301 responses (<1KB). Fastly serves actual HTML files from cache. You get edge routing performance + edge content performance with zero provider coordination.

### How This Architecture Works

This architecture **separates identity from content delivery**.

**Identity** means which public-facing hostnames exist and what they do (redirect vs serve content). This is managed at the edge. Cloudflare handles `example.com` and `www.example.com` as proxied hostnames. These domains never contact an origin—Cloudflare intercepts all traffic and redirects immediately. Users see these domains in their browser, but they're routing constructs, not content hosts. They exist purely to provide familiar URLs (apex and www) that redirect to the canonical location. The edge layer owns the public interface—which hostnames are valid and where they route.

**Content delivery** means serving the actual HTML files. This is managed at the origin. GitHub Pages handles only `blog.example.com` as a DNS-only hostname. This is the single canonical hostname that actually serves HTML. There's no redirect logic at this layer—just static file delivery via Fastly's global CDN. The origin doesn't know about apex or www domains and doesn't need to. It has one job: serve pre-built HTML for the canonical hostname.

**Request flow for apex domain:**
```
1. User types: example.com
2. DNS returns: Cloudflare IP (because apex is proxied)
3. Browser connects: Nearest Cloudflare edge node
4. Cloudflare terminates TLS: Issues its own certificate
5. Cloudflare evaluates redirect rules: Matches catch-all rule
6. Cloudflare responds: 301 → https://blog.example.com/
7. Browser follows redirect: Connects to blog.example.com
8. DNS returns: GitHub Pages IP (because blog is DNS-only)
9. GitHub Pages serves: Pre-built HTML file
```

**Request flow for canonical domain:**
```
1. User types: blog.example.com
2. DNS returns: GitHub Pages IP (DNS-only, no Cloudflare)
3. Browser connects: Fastly edge node (GitHub's CDN)
4. Fastly terminates TLS: GitHub's Let's Encrypt certificate
5. Fastly serves: Cached HTML file from GitHub origin
```

**Why this separation matters:**

The origin never makes routing decisions. GitHub Pages doesn't know about `example.com` or `www.example.com`—it only serves `blog.example.com`. This means routing policy (which domains redirect where) is enforced at the edge, not the origin. If the origin is compromised, an attacker cannot redirect users to malicious sites because the origin has no routing authority.

The edge never serves content. Cloudflare doesn't cache or serve HTML for redirected hostnames. It evaluates rules and sends 301 responses (tiny, typically <1KB). Content delivery happens at Fastly's edge network, not Cloudflare.

**The dual-edge advantage:**

Each network does what it's optimized for:

**Cloudflare specializes in:**
- Global routing intelligence (330+ edge nodes)
- Sub-50ms redirect decisions
- TLS termination for routing layer
- Zero origin requests (dummy IP triggers edge logic)

**Fastly specializes in:**
- Content delivery and caching
- Static asset acceleration
- Geographic distribution of HTML files
- Origin pull from GitHub's infrastructure

The result: Routing decisions happen at Cloudflare's edge (10-50ms globally), content delivery happens at Fastly's edge (20-100ms from nearest POP), and the two networks collaborate without coordination. The origin (GitHub Pages) is completely stateless—just pre-built HTML files in a Git repository.

### The Three Planes

| Plane | Owner | Responsibility |
|-------|-------|----------------|
| **Edge Plane** | Cloudflare | TLS termination, identity (apex/www), redirects, path preservation |
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

The apex domain (`example.com`) points to `192.0.2.1`, a documentation IP from RFC 5737's TEST-NET-1 range that's guaranteed non-routable on the public internet. This IP will never respond to requests. The record is set to proxied (orange cloud) in Cloudflare, which signals Cloudflare's edge network to intercept all traffic and evaluate Redirect Rules before attempting any origin connection. The origin is never contacted—every request to the apex domain is handled entirely at the edge.

The www subdomain (`www.example.com`) is a CNAME pointing to the apex. It's also proxied through Cloudflare. When a user visits the www hostname, Cloudflare terminates TLS using its own certificate and immediately evaluates redirect rules. There's no origin server for www—it's purely an edge routing construct that provides the familiar www prefix while redirecting to the canonical blog hostname.

The blog subdomain (`blog.example.com`) is a CNAME pointing to GitHub Pages (`username.github.io`). This record is set to DNS-only (gray cloud, not proxied). DNS queries return GitHub's actual IP addresses, not Cloudflare's. This allows GitHub Pages to issue Let's Encrypt certificates via ACME validation without interference from Cloudflare's proxy layer. The blog subdomain is served directly through Fastly (GitHub's CDN) and is the only hostname that actually delivers content—no redirects, just static HTML files.

### The Dummy IP Strategy

The use of `192.0.2.1` is the architectural linchpin that makes serverless edge routing possible.

**Why a non-routable IP works:**

In Cloudflare, a proxied DNS record is an **infrastructure trigger**, not just name resolution. When you set a record to proxied (orange cloud), you're signaling Cloudflare's global network to:

1. Intercept all traffic at the edge
2. Terminate TLS locally (issue Cloudflare certificates)
3. Evaluate redirect rules before any origin request
4. Only contact the origin if rules don't match

The IP address itself becomes irrelevant—Cloudflare intercepts traffic before any connection attempt. `192.0.2.1` is from RFC 5737's TEST-NET-1 range, guaranteed non-routable on the public internet. It will never respond to requests because it's designed never to exist as a real host.

**What this enables:**

By combining a dummy IP with proxy mode, you create a **routing fabric with zero origin infrastructure**. There's no server at `192.0.2.1`—it's a trigger address that tells Cloudflare's 330+ edge nodes to handle requests locally. Redirect rules execute globally without any centralized origin server. The apex and www domains exist as pure routing constructs.

This is why the architecture costs $24/year instead of $600/year—you're not running servers for redirects. The edge network itself becomes the routing layer, triggered by a DNS record pointing to an address that intentionally goes nowhere.

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

### Rule 2: Path Preservation

```
IF Hostname equals example.com
AND (URI Path equals /oss OR starts with /oss/)
THEN 301 redirect to
  concat("https://blog.example.com", http.request.uri.path)
```

**Repeat for each section** (`/consulting`, `/docs`, `/api`, etc.)

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

### Why Redirect Rules (Not Workers)

**Redirect Rules are declarative:**
- Configuration, not code
- No deployment pipeline required
- Faster to audit (view all rules in dashboard)
- Changes propagate globally in seconds

**Cloudflare Workers are imperative:**
- Custom JavaScript execution
- Requires version control + deployment
- More powerful (can transform content, not just redirect)
- Higher cost at scale (CPU time billing)

**Use Redirect Rules when:** Simple path-based redirects, canonicalization, path preservation.

**Use Workers when:** Complex logic (geolocation routing, A/B testing, header manipulation), content transformation at edge.

For this architecture, Redirect Rules provide the right balance: declarative, auditable, and zero deployment overhead.

### Rule Evaluation Semantics

**First match wins:** Rules execute in order until one matches. Subsequent rules are skipped.

**Critical implication:** Put specific rules before general rules. The catch-all must always be last.

**Example of shadowing (wrong):**
```
Rule 1: IF hostname = example.com THEN redirect to blog.example.com/
Rule 2: IF hostname = example.com AND path = /oss THEN redirect to blog.example.com/oss
```
Rule 2 never runs—Rule 1 matches first and redirects to homepage.

**Correct order:**
```
Rule 1: IF hostname = example.com AND path = /oss THEN redirect to blog.example.com/oss
Rule 2: IF hostname = example.com THEN redirect to blog.example.com/
```
Specific path rules first, catch-all last.

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

The apex and www hostnames are proxied because they exist solely for redirects. Cloudflare must intercept traffic to evaluate Redirect Rules. Without proxy mode, these hostnames would try to contact the dummy IP (`192.0.2.1`) and fail with connection timeouts.

The blog subdomain is DNS-only for three reasons. First, GitHub Pages needs direct DNS resolution to issue Let's Encrypt certificates. The ACME validation process requires GitHub to prove control of the domain, which fails if DNS returns Cloudflare's IPs instead of GitHub's. Second, GitHub Pages already serves through Fastly's global CDN—there's no need to proxy through Cloudflare because content is already edge-cached. Third, keeping the blog DNS-only avoids certificate coordination issues. Each layer manages its own TLS independently: Cloudflare for apex/www, GitHub for the blog subdomain.

**The architecture uses two CDN networks, but not for redundancy:**

The redirected hostnames (`example.com`, `www.example.com`) use Cloudflare's edge network exclusively for routing—Cloudflare sends 301 responses (typically <1KB) without serving content. The canonical hostname (`blog.example.com`) bypasses Cloudflare entirely (DNS-only) and uses Fastly's edge network exclusively for content delivery—Fastly caches and serves pre-rendered HTML globally.

Each network handles what it's optimized for: Cloudflare for sub-50ms routing decisions at 330+ global nodes, Fastly for content caching and delivery.

### Why 301 Permanent Redirects?

**301** signals to search engines:
- Transfer ranking authority from old URL to new URL
- Update index to replace old URLs with new ones
- Merge historical SEO signals

**302 Temporary** would preserve old URLs in search index indefinitely.

### Redirect Chain Budget

**Target:** 1 hop maximum for apex/www redirects.

**Acceptable:** 2 hops maximum for path preservation.

**Why this matters:**

Redirect chains (A → B → C) waste crawl budget and dilute ranking signals. Search engines may stop following after 3-5 hops.

**How to avoid:**

Ensure each redirect rule points **directly** to the final canonical URL. Don't redirect to another URL that redirects again.

**Example of a chain (bad):**
```
example.com/product
  → 301 to example.com/products/product
  → 301 to blog.example.com/products/product
```

**Correct (1 hop):**
```
example.com/product
  → 301 to blog.example.com/products/product
```

Each redirect should have a single, direct path to its canonical target.

### Why Path-Preserving Redirects?

Redirecting `example.com/oss/project` to `blog.example.com/oss/project` (not just the homepage) preserves the complete URL structure. When external sites link to specific pages, those links continue working after migration. Bookmarks and saved URLs don't break. Most importantly, search engines transfer ranking signals to the corresponding page on the new domain, not just the homepage. This preserves SEO for individual pages, not just overall domain authority. Without path preservation, all external links would funnel to the homepage, losing traffic and context.

### Why Separate Edge and Content Planes?

Separating routing (edge) from delivery (origin) provides operational flexibility. You can migrate from GitHub Pages to Netlify by changing a single CNAME record—the edge routing layer remains unchanged. Edge routing scales independently of content delivery, so high redirect traffic doesn't affect origin performance. Failures are isolated: a Cloudflare outage only affects redirects, not content delivery on the canonical hostname (and vice versa). You can change static site generators (Hugo to Jekyll) or hosting providers without touching DNS configuration. Each plane can evolve independently without coordinating changes across layers.

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

## Debugging and Troubleshooting

When things break (and they will during setup), use this checklist to diagnose issues quickly.

### DNS Configuration Checklist

**Verify proxy status:**
```bash
# Check Cloudflare dashboard
# Apex + www: Orange cloud (proxied)
# Blog subdomain: Gray cloud (DNS only)
```

**Verify DNS propagation:**
```bash
# Should return Cloudflare IPs for apex/www
dig example.com
dig www.example.com

# Should return GitHub Pages IPs for blog
dig blog.example.com
```

### GitHub Pages Checklist

**Custom domain configuration:**
- In repo settings → Pages → Custom domain: `blog.example.com`
- HTTPS checkbox: Enabled
- Check for "Certificate is being provisioned" or "DNS check failed"

**Certificate issues:**
```bash
# Test HTTPS
curl -I https://blog.example.com

# If you see certificate errors:
# 1. Verify blog subdomain is DNS only (not proxied)
# 2. Wait 5-10 minutes for GitHub to retry
# 3. Check GitHub Pages status: https://www.githubstatus.com
```

### Redirect Testing

**Test each redirect rule:**
```bash
# Apex should redirect
curl -I https://example.com
# Expect: HTTP/1.1 301 Moved Permanently
# Expect: location: https://blog.example.com/

# www should redirect preserving path
curl -I https://www.example.com/about?ref=test
# Expect: HTTP/1.1 301 Moved Permanently
# Expect: location: https://blog.example.com/about?ref=test

# Legacy paths should redirect
curl -I https://example.com/oss
# Expect: HTTP/1.1 301 Moved Permanently
# Expect: location: https://blog.example.com/oss

# Canonical host should serve content
curl -I https://blog.example.com
# Expect: HTTP/1.1 200 OK
```

**Wrong status codes:**
- **522** (Connection timed out) - No redirect rules configured, or apex not proxied
- **302** (Temporary redirect) - Wrong redirect type, change to 301
- **404** (Not found) - Target URL doesn't exist on origin
- **526** (Invalid SSL) - GitHub Pages certificate not issued yet

### Cloudflare Analytics

**Check redirect rule match rates:**

In Cloudflare dashboard → Rules → Redirect Rules → Analytics:
- Rules should show non-zero match counts after testing
- If rule shows 0 matches, check rule syntax or order

**Common rule syntax issues:**
- Missing `concat()` function
- Wrong field name (`http.request.uri` vs `http.request.uri.path`)
- Rule order (catch-all shadowing specific rules)

### Common Failure Modes

**Issue: Blog subdomain shows Cloudflare 522 error**

**Cause:** Blog subdomain is proxied (orange cloud) but GitHub Pages can't be reached

**Fix:** Set blog subdomain to DNS only (gray cloud)

**Issue: Certificate errors on blog subdomain**

**Cause:** GitHub Pages ACME validation failing

**Fix:**
1. Verify blog subdomain is DNS only
2. Verify custom domain is set in GitHub Pages settings
3. Wait 10 minutes for retry
4. Check DNS resolution: `dig blog.example.com` should return GitHub Pages IPs

**Issue: Redirect chain (multiple 301s)**

**Cause:** Rules redirect to intermediate URLs that redirect again

**Fix:** Update rules to point directly to final canonical URL (see Redirect Chain Budget section)

**Issue: Query strings dropped on redirect**

**Cause:** Using `http.request.uri.path` instead of `http.request.uri`

**Fix:** Use full URI: `concat("https://blog.example.com", http.request.uri)`

### Monitoring and Validation

**After deployment, verify:**

1. **All redirects are 301** (not 302)
2. **Redirect targets are correct** (location header)
3. **No redirect chains** (1 hop for most URLs)
4. **Canonical host returns 200** (not redirecting)
5. **HTTPS works on all hosts** (no certificate warnings)

**Tools:**
- `curl -I` for manual testing
- Google Search Console for crawl errors
- Cloudflare Analytics for redirect rule metrics
- Browser dev tools (Network tab) for debugging redirect chains

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
