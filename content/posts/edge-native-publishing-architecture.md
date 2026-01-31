---
title: "Building an Edge-Native Publishing System with Cloudflare and GitHub Pages"
date: 2026-01-31
draft: false
tags: ["cloudflare", "github-pages", "edge-computing", "cdn", "dns", "tls", "architecture", "static-site", "hugo", "devops", "infrastructure", "networking", "web-architecture", "ssl", "seo", "301-redirects", "serverless"]
categories: ["architecture", "infrastructure"]
description: "How to build a production-grade edge-native publishing system using Cloudflare as an edge router and GitHub Pages as the static origin. Solves the Apex CNAME problem and SSL depth problem simultaneously."
summary: "Modern static architecture isn't just about hosting HTML files—it's about building a high-performance edge redirect engine on top of a zero-maintenance origin. This article explains how to use Cloudflare's edge network to solve classic DNS and TLS problems while preserving SEO and maintaining zero server infrastructure."
---

Modern static architecture isn't just about hosting HTML files. It's about building a **high-performance edge redirect engine** on top of a **zero-maintenance origin**.

This article documents the architecture behind this blog: how Cloudflare functions as an edge router, GitHub Pages serves as the static origin, and how this combination solves two classic web infrastructure problems simultaneously.

---

## The Two Problems

### 1. The Apex CNAME Problem

Root domains (apex domains like `example.com`) cannot use CNAME records in DNS. The DNS spec forbids it because CNAMEs must be the only record at a name, and apex domains need other records (SOA, NS, MX).

This means you can't simply point `example.com` directly at a CDN or hosting provider using a CNAME. You need an A record with an IP address—which defeats the purpose of content delivery networks that use DNS-based routing.

### 2. The SSL Depth Problem

Multi-level subdomains (`www.blog.example.com`) break wildcard TLS certificates. A wildcard cert for `*.example.com` covers `blog.example.com` but not `www.blog.example.com`.

You need separate certificates for each subdomain level, which becomes a coordination nightmare when different services manage different parts of your domain hierarchy.

### The Traditional Workarounds (And Why They Fail)

**ALIAS/ANAME records:** Proprietary DNS extensions that aren't universally supported. They work, but lock you into specific DNS providers.

**Multiple origins:** Running separate servers for apex and subdomain. Doubles infrastructure complexity and maintenance burden.

**Accepting broken www:** Just don't support `www.blog.example.com`. Works until marketing wants it.

**Certificate juggling:** Managing certs across multiple layers. Operationally fragile and error-prone.

None of these are satisfying. Modern infrastructure should solve problems, not accumulate workarounds.

---

## The Solution: Edge-Controlled Static Architecture

By using Cloudflare as an **edge router** and GitHub Pages as a **static origin**, you can solve both problems simultaneously:

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

Cloudflare intercepts traffic for the proxied hostnames *before any origin request is made*.

---

## Architecture Goals

**One canonical public site:**
- `https://blog.blackwell-systems.com`

**Preserve legacy links:**
- `https://blackwell-systems.com/oss` → `https://blog.blackwell-systems.com/oss`

**Support marketing www alias:**
- `https://www.blackwell-systems.com/...` → `https://blog.blackwell-systems.com/...`

**Avoid TLS traps:**
- No `www.blog...` multi-level subdomains
- Each layer manages its own TLS

**Zero origin exposure:**
- No direct access to origin servers
- All traffic flows through edge

**No server maintenance:**
- Static files only
- No runtime, no databases, no server processes

---

## DNS Layer Configuration

| Host | Record | Target | Proxy |
|------|--------|--------|-------|
| `blackwell-systems.com` | A | `192.0.2.1` (dummy) | Proxied |
| `www.blackwell-systems.com` | CNAME | `blackwell-systems.com` | Proxied |
| `blog.blackwell-systems.com` | CNAME | `blackwell-systems.github.io` | DNS only |

### Why This Works

**`blackwell-systems.com` (Apex domain):**
- Uses a dummy IP (`192.0.2.1` from TEST-NET-1, reserved for documentation)
- Proxied through Cloudflare (orange cloud)
- Never fetched from origin—Cloudflare intercepts and redirects

**`www.blackwell-systems.com` (Marketing alias):**
- CNAME to apex
- Proxied through Cloudflare
- Terminates TLS at edge and redirects while preserving full URI

**`blog.blackwell-systems.com` (Canonical site):**
- CNAME to GitHub Pages
- **DNS only** (gray cloud, not proxied)
- Served directly by GitHub Pages (Fastly)
- GitHub issues and manages its own TLS certificate

This avoids double-TLS and multi-subdomain certificate conflicts.

---

## The Dummy IP as Infrastructure Trigger

Using `192.0.2.1` as the A record for the apex domain is deliberate, not a placeholder.

In Cloudflare, a **proxied** DNS record isn't just name resolution—it's a signal to Cloudflare's global network to **terminate TLS and process the request**.

### How Cloudflare Proxy Mode Works

When you enable proxy mode (orange cloud) on a DNS record:

1. Cloudflare's authoritative DNS returns **Cloudflare IPs** (not your origin IP)
2. Browser connects to the **nearest Cloudflare edge**
3. Cloudflare terminates TLS using its certificate
4. Cloudflare evaluates **Redirect Rules** at the edge
5. Only if nothing matches does Cloudflare attempt an origin connection

Without a proxied record, redirect rules never run—the browser fails before Cloudflare ever sees the request.

By pointing the apex at a non-routable IP and enabling proxy mode, you create a **serverless routing layer**:

```
User → Cloudflare Edge → Redirect Rules → Real Origin (GitHub)
```

### Why 192.0.2.1?

This IP is from `TEST-NET-1` (192.0.2.0/24), a range reserved by RFC 5737 for documentation and examples. It's **guaranteed non-routable** on the public internet.

Using a documentation IP makes the intent explicit: this is an edge-only hostname that should never talk to an origin.

---

## Redirect Rules: Edge Routing Logic

All user-facing redirects are implemented as **Cloudflare Redirect Rules** (declarative edge policy).

Cloudflare processes redirect rules **before** any origin request. They run at every edge node globally.

### Rule 1: www → Canonical Blog (301 Permanent)

```
IF Hostname equals www.blackwell-systems.com
THEN 301 redirect to
  concat("https://blog.blackwell-systems.com", http.request.uri)
```

**Preserves:** path + query string

**Example:**
```
https://www.blackwell-systems.com/about?ref=home
  → https://blog.blackwell-systems.com/about?ref=home
```

### Rule 2: /oss Legacy Path (301 Permanent)

```
IF Hostname equals blackwell-systems.com
AND (URI Path equals /oss OR starts with /oss/)
THEN 301 redirect to
  concat("https://blog.blackwell-systems.com", http.request.uri.path)
```

**Example:**
```
https://blackwell-systems.com/oss/project-alpha
  → https://blog.blackwell-systems.com/oss/project-alpha
```

### Rule 3: /consulting Legacy Path (301 Permanent)

```
IF Hostname equals blackwell-systems.com
AND (URI Path equals /consulting OR starts with /consulting/)
THEN 301 redirect to
  concat("https://blog.blackwell-systems.com", http.request.uri.path)
```

Same pattern as `/oss`, preserves consulting namespace.

### Rule 4: Product Canonicalization (301 Permanent)

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
- Preserves historical product URLs shared before the `/products/` hierarchy existed
- Consolidates SEO authority onto a single canonical URL
- Prevents "content identity fragmentation" where the same product is reachable at multiple public paths

### Rule 5: Apex Catch-All (301 Permanent)

```
IF Hostname equals blackwell-systems.com
THEN 301 redirect to
  https://blog.blackwell-systems.com/
```

**Fallback:** Handles all other apex traffic, ensuring no request ever reaches the dummy IP origin.

### Rule Processing Order

Rules execute in order until a match. If Rules 2, 3, or 4 match, Rule 5 never runs.

This is critical: the catch-all must always be last.

---

## Request Flow Examples

| Request | Result |
|---------|--------|
| `https://blackwell-systems.com` | → `https://blog.blackwell-systems.com/` |
| `https://blackwell-systems.com/oss` | → `https://blog.blackwell-systems.com/oss` |
| `https://blackwell-systems.com/oss/vaultmux` | → `https://blog.blackwell-systems.com/oss/vaultmux` |
| `https://blackwell-systems.com/gcp-emulator-pro` | → `https://blog.blackwell-systems.com/products/gcp-emulator-pro/` |
| `https://www.blackwell-systems.com/consulting?x=1` | → `https://blog.blackwell-systems.com/consulting?x=1` |
| `https://blog.blackwell-systems.com/posts/` | Served directly by GitHub Pages |

### Traffic Flow Diagram

```
User → blackwell-systems.com / www.blackwell-systems.com
        ↓
    Cloudflare Edge (TLS termination)
        ↓
   Redirect Rules (policy evaluation)
        ↓
blog.blackwell-systems.com
        ↓
   GitHub Pages (static content delivery)
```

**Edge decision time:** 10–50ms (nearest edge node)  
**Traditional origin redirect:** 200–500ms (roundtrip to origin server)

No origin latency. No origin failures. Global performance regardless of user location.

---

## Legacy Path Preservation: SEO Architecture

Path-specific rules (`/oss`, `/consulting`) do real SEO work.

### The Problem: Link Equity Fragmentation

When you migrate domains or restructure URLs, you risk losing years of accumulated SEO value:

- Backlinks from external sites pointing to old URLs
- Search engine index entries for old URLs
- Social media shares with old URLs
- Bookmarks and saved links

If these links break (404), you lose traffic. If they redirect incorrectly, you lose context.

### The Solution: Path-Preserving 301 Redirects

Using `http.request.uri.path` preserves the exact path structure:

```
Old: https://blackwell-systems.com/oss/project-alpha
New: https://blog.blackwell-systems.com/oss/project-alpha
```

### Why 301 Matters

**301 Permanent Redirect** signals to search engines:

1. **Transfer authority:** ranking signals flow to the new URL
2. **Update index:** replace old URL in results
3. **Merge signals:** combine historical data with new data

Over time, search engines consolidate the old domain's authority into the new domain.

---

## DNS-Only for Blog Subdomain: TLS Coordination

`blog.blackwell-systems.com` is intentionally **not proxied** through Cloudflare (DNS only).

### The TLS Conflict

GitHub Pages automatically issues **Let's Encrypt certificates** for custom domains via ACME.

If you proxy the blog subdomain through Cloudflare:

- DNS resolves to Cloudflare infrastructure
- GitHub's certificate automation may fail verification or stall

By setting the blog subdomain to **DNS only**, GitHub Pages can validate and issue certificates cleanly.

### The Performance Tradeoff

You lose Cloudflare caching on the canonical blog host, but GitHub Pages already serves through a global CDN (Fastly). In practice, the difference is negligible.

---

## The Three Planes

| Plane | Owner | Responsibility |
|-------|-------|----------------|
| **Edge Plane** | Cloudflare | Identity, TLS (apex/www), redirects, legacy paths, policy enforcement |
| **Content Plane** | GitHub Pages | Static HTML delivery, CDN caching, origin TLS for `blog.*` |
| **Authoring Plane** | Hugo + Git | Content creation, structure, templating, version control |

---

## Common Mistakes to Avoid

### Mistake 1: Proxying the Blog Subdomain

**Wrong:**
```
blog.blackwell-systems.com → Cloudflare (proxied) → GitHub Pages
```

**Correct:**
```
blog.blackwell-systems.com → DNS only → GitHub Pages
```

### Mistake 2: Using 302 Redirects

302 is treated as temporary. Use **301** to transfer authority and consolidate indexing.

### Mistake 3: Forgetting Query String Preservation

If you want to preserve query strings, use:

```
http.request.uri
```

Using:

```
http.request.uri.path
```

drops query strings like `?utm_source=...`.

(For this setup, the `www` rule correctly preserves queries; path-specific rules preserve structure.)

---

## Conclusion

This architecture provides a production-grade publishing system with:

- **Cloudflare as edge router + policy engine**
- **GitHub Pages as static origin**
- **One canonical hostname**
- **Legacy compatibility via path-preserving redirects**
- **Zero origin exposure**
- **No TLS coordination issues**
- **No server maintenance**
- **Global redirect performance (10–50ms edge latency)**
- **~$10–27/year total cost**

You haven't just deployed a static site. You've built an **edge-native publishing system** where routing decisions happen close to users and the origin stays simple and zero-maintenance.

---

## Further Reading

**Cloudflare Documentation:**
- Redirect Rules: https://developers.cloudflare.com/rules/url-forwarding/
- Proxied DNS records: https://developers.cloudflare.com/dns/manage-dns-records/reference/proxied-dns-records/
- SSL/TLS overview: https://developers.cloudflare.com/ssl/

**GitHub Pages:**
- Custom domains: https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site
- HTTPS for custom domains: https://docs.github.com/en/pages/getting-started-with-github-pages/securing-your-github-pages-site-with-https

**DNS and TLS:**
- RFC 5737 (documentation IPs): https://datatracker.ietf.org/doc/html/rfc5737
- Let's Encrypt (how it works): https://letsencrypt.org/how-it-works/

**SEO:**
- Google 301 guidance: https://developers.google.com/search/docs/crawling-indexing/301-redirects
- Site move with URL changes: https://developers.google.com/search/docs/crawling-indexing/site-move-with-url-changes
