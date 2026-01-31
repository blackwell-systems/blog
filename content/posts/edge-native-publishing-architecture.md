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

Cloudflare intercepts traffic *before DNS resolution ever reaches a real server*.

---

## Architecture Goals

**One canonical public site:**
- `https://blog.blackwell-systems.com`

**Preserve legacy links:**
- `https://blackwell-systems.com/oss` → `https://blog.blackwell-systems.com/oss`

**Support marketing www alias:**
- `https://www.blackwell-systems.com` → `https://blog.blackwell-systems.com`

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
- Never fetched from origin—Cloudflare always intercepts

**`www.blackwell-systems.com` (Marketing alias):**
- CNAME to apex
- Proxied through Cloudflare
- Terminates TLS at edge and redirects

**`blog.blackwell-systems.com` (Canonical site):**
- CNAME to GitHub Pages
- **DNS only** (gray cloud, not proxied)
- Served directly by GitHub Pages
- GitHub issues and manages its own TLS certificate

This avoids double-TLS and multi-subdomain certificate conflicts.

---

## The Dummy IP as Infrastructure Trigger

Using `192.0.2.1` as the A record for the apex domain is deliberate, not a placeholder.

In Cloudflare, a **proxied** DNS record isn't just name resolution—it's a signal to Cloudflare's global network to **terminate TLS and process the request**.

### How Cloudflare Proxy Mode Works

When you enable proxy mode (orange cloud) on a DNS record:

1. Cloudflare's authoritative DNS returns **Cloudflare's IP addresses** (not your origin IP)
2. User's browser connects to **Cloudflare's edge node** (nearest PoP)
3. Cloudflare terminates TLS using its own certificate
4. Cloudflare processes **Redirect Rules** before any origin request
5. Only if no redirect matches does Cloudflare forward to origin

Without a proxied record, redirect rules never run. The browser fails DNS lookup before Cloudflare sees the request.

By pointing the apex at a non-routable IP and enabling proxy mode, you create a **serverless routing layer**:

```
User → Cloudflare Edge → Redirect Rules → Real Origin (GitHub)
```

Cloudflare handles identity, legacy paths, and TLS. GitHub only serves the final content.

### Why 192.0.2.1?

This IP is from `TEST-NET-1` (192.0.2.0/24), a range reserved by RFC 5737 for documentation and examples. It's **guaranteed non-routable** on the public internet.

Using a documentation IP makes the intent explicit: this is an edge-only domain that never contacts an origin server.

---

## Redirect Rules: Edge Routing Logic

Cloudflare processes redirect rules **before** any origin request. They run at every edge node globally.

### Rule 1: www → Canonical Blog (301 Permanent)

```
IF Hostname equals www.blackwell-systems.com
THEN 301 redirect to
  concat("https://blog.blackwell-systems.com", http.request.uri)
```

**Preserves:** Path and query strings

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

**Preserves:** Exact path structure

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

Same pattern as Rule 2, preserves consulting namespace.

### Rule 4: Apex Catch-All (301 Permanent)

```
IF Hostname equals blackwell-systems.com
THEN 301 redirect to
  https://blog.blackwell-systems.com/
```

**Fallback:** Handles all other apex traffic

This ensures no request ever reaches the fake IP origin. Cloudflare must redirect, or nothing loads.

### Rule Processing Order

Rules execute in order until a match. If Rule 2 or 3 matches, Rule 4 never runs.

This is critical for namespace preservation—specific paths must be checked before the catch-all.

---

## Request Flow Examples

| Request | Result |
|---------|--------|
| `https://blackwell-systems.com` | → `https://blog.blackwell-systems.com/` |
| `https://blackwell-systems.com/oss` | → `https://blog.blackwell-systems.com/oss` |
| `https://blackwell-systems.com/oss/vaultmux` | → `https://blog.blackwell-systems.com/oss/vaultmux` |
| `https://www.blackwell-systems.com/consulting?x=1` | → `https://blog.blackwell-systems.com/consulting?x=1` |
| `https://blog.blackwell-systems.com/posts/` | Served directly by GitHub Pages |

### Traffic Flow Diagram

```
User → blackwell-systems.com
        ↓
    Cloudflare Edge (TLS termination)
        ↓
   Redirect Rules (policy evaluation)
        ↓
blog.blackwell-systems.com
        ↓
   GitHub Pages (static content delivery)
```

**Edge decision time:** 10-50ms (nearest edge node)  
**Traditional origin redirect:** 200-500ms (roundtrip to origin server)

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

If these links break (404), you lose that traffic. If they redirect incorrectly, you lose context.

### The Solution: Path-Preserving 301 Redirects

By using `concat` with `http.request.uri.path`, the redirect maintains the **exact path structure**:

```
Old: https://blackwell-systems.com/oss/project-alpha
New: https://blog.blackwell-systems.com/oss/project-alpha
```

No path rewriting. No namespace collisions. No broken links.

### Why 301 Matters

**301 Permanent Redirect** signals to search engines:

1. **Transfer authority:** PageRank and ranking signals flow from old URL to new URL
2. **Update index:** Replace old URL with new URL in search results
3. **Merge signals:** Combine historical data with new data

Over time (weeks to months), Google consolidates the old domain's authority into the new domain. You preserve link equity instead of starting from zero.

**302 Temporary Redirect** would **not** transfer authority. Search engines would keep indexing the old URL, treating the redirect as transient.

### Measuring SEO Preservation

Track these metrics post-migration:

- **Redirect coverage:** % of old URLs that successfully redirect (target: 100%)
- **404 rate:** Should drop to near-zero after migration
- **Organic traffic:** Should stabilize within 4-8 weeks
- **Search visibility:** Monitor ranking positions for key pages

If organic traffic drops significantly or doesn't recover, investigate redirect logic or missing redirects.

---

## DNS-Only for Blog Subdomain: TLS Coordination

`blog.blackwell-systems.com` is intentionally **not proxied** through Cloudflare (gray cloud, DNS only).

### The TLS Conflict

GitHub Pages automatically issues **Let's Encrypt certificates** for custom domains via ACME protocol.

The ACME verification process requires GitHub to prove control of the domain by:

1. Creating a TXT record in DNS, or
2. Serving a file at `/.well-known/acme-challenge/`

If you proxy the blog subdomain through Cloudflare:

- DNS queries return **Cloudflare's IP addresses**
- HTTP requests go to **Cloudflare first**
- GitHub's ACME bot sees Cloudflare's infrastructure, not GitHub's
- Certificate issuance **fails or times out**

By setting the subdomain to **DNS only**, DNS queries return GitHub's actual IP addresses, and ACME verification succeeds.

### The Performance Tradeoff

**What you lose:** Cloudflare edge caching for blog content

**What you keep:** GitHub Pages is already served via **Fastly** (a top-tier global CDN with hundreds of edge nodes)

**Net result:** Latency difference is negligible. Both Cloudflare and Fastly have similar edge presence and performance characteristics.

### Why This Architecture Is Correct

**Separation of concerns:**
- Cloudflare manages **identity and routing** (apex, www)
- GitHub manages **content and TLS** (blog subdomain)

**No certificate deadlocks:**
- Each layer owns its own TLS
- No coordination required between providers

**Failure isolation:**
- If GitHub Pages has an outage, only the blog is affected
- If Cloudflare has an outage, only redirects are affected

This is **defense in depth** for web infrastructure.

---

## The Three Planes

This architecture implicitly defines three operational planes:

| Plane | Owner | Responsibility |
|-------|-------|----------------|
| **Edge Plane** | Cloudflare | Identity, TLS, redirects, legacy paths, policy enforcement |
| **Content Plane** | GitHub Pages | Static HTML delivery, CDN caching, origin TLS |
| **Authoring Plane** | Hugo + Git | Content creation, structure, templating, version control |

### Why Planes Matter

**Separation of concerns:** Each plane has a single, clear responsibility

**Independent scaling:** Content can scale independently of routing logic

**Failure isolation:** Outages in one plane don't cascade to others

**Technology flexibility:** Can swap out any plane without affecting others

For example, migrating from GitHub Pages to Netlify only changes the **Content Plane**. The **Edge Plane** (Cloudflare redirects) and **Authoring Plane** (Hugo) remain unchanged.

---

## Why This Architecture Works

### Avoids TLS Traps

- No `www.blog...` multi-level subdomains
- Cloudflare only terminates TLS for one-level hosts (`blackwell-systems.com`, `www.blackwell-systems.com`)
- GitHub manages its own TLS for `blog.blackwell-systems.com`
- No wildcard certificate conflicts

### Edge-First Routing

- All redirects happen at Cloudflare edge (10-50ms)
- No unnecessary origin requests
- No origin latency (no roundtrip)
- Policy changes propagate globally in seconds

### Zero Origin Exposure

- Apex IP is fake (`192.0.2.1`)
- Origin IP never appears in DNS
- Users cannot bypass Cloudflare
- DDoS protection by default

### Host Portability

- Can move from GitHub Pages to Netlify, Vercel, S3, etc.
- Only the blog CNAME changes in DNS
- Edge routing logic remains identical
- Zero downtime migration

### No Server Maintenance

- Static files only (pre-rendered HTML)
- No runtime vulnerabilities
- No database patches
- No server updates
- No scaling concerns

### Cost Efficiency

**Monthly costs:**
- Cloudflare: $0 (Free plan)
- GitHub Pages: $0 (public repos)
- Domain: ~$1/month (varies by TLD)

**Total: ~$12/year for domain registration.**

No hosting fees. No bandwidth charges. No compute costs.

---

## Performance Characteristics

### Traditional Redirect Topology

```
Client → Origin Server (200-500ms roundtrip)
         ↓
       301 Response
         ↓
    Redirect to blog
```

**Total latency:** 200-500ms depending on origin distance and server response time

**Failure modes:** Origin downtime, network issues, server overload

### Edge Redirect Topology

```
Client → Cloudflare Edge (10-50ms nearest node)
         ↓
    Redirect Rules (edge computation)
         ↓
       301 Response
```

**Total latency:** 10-50ms (edge decision only, no origin roundtrip)

**Failure modes:** Cloudflare global outage (extremely rare, <99.99% uptime)

### Why Edge Is Faster

**No origin involved:** Redirect decision happens at the edge node closest to the user

**Global distribution:** Cloudflare has 330+ edge locations worldwide

**In-memory evaluation:** Redirect rules execute in Cloudflare's edge runtime (V8 isolates)

**No cold starts:** Unlike serverless functions, edge rules are always warm

For a user in Tokyo, the redirect happens in Tokyo. For a user in London, the redirect happens in London. Origin location becomes irrelevant.

---

## Email Infrastructure: The Deliverability Trifecta

While not directly related to web architecture, email configuration shares DNS with web hosting and is worth documenting.

### The Three Records

| Record | Purpose |
|--------|---------|
| **MX** | Tells the world where mail is delivered |
| **SPF** | Authorizes which servers can send mail |
| **DKIM** | Cryptographically signs each message |

Together, these form the **golden ratio of deliverability**.

### MX Records (Mail Exchange)

```
Priority 10: mx.zoho.com (primary)
Priority 20: mx2.zoho.com (backup)
Priority 50: mx3.zoho.com (backup)
```

When someone sends email to `support@blackwell-systems.com`, their mail server:

1. Queries DNS for MX records
2. Sorts by priority (lowest first)
3. Attempts delivery to `mx.zoho.com`
4. Falls back to `mx2.zoho.com` if primary is unavailable

### SPF Record (Sender Policy Framework)

```
v=spf1 include:zohomail.com ~all
```

This authorizes Zoho to send email on behalf of `blackwell-systems.com`.

When a recipient's mail server receives an email claiming to be from `@blackwell-systems.com`, it:

1. Checks the sending server's IP
2. Queries DNS for the SPF record
3. Verifies the IP is authorized by `zohomail.com`
4. Accepts or rejects based on match

**Without SPF:** Email is more likely to be marked as spam or rejected outright.

### DKIM Record (Domain Keys Identified Mail)

```
Type: CNAME
Name: zmail._domainkey
Target: zoho-provided signing key
```

DKIM provides cryptographic proof that:

1. The email was sent by an authorized server (Zoho)
2. The email content hasn't been tampered with in transit

Zoho signs each outgoing email with a private key. Recipients verify the signature using the public key published in DNS.

**Without DKIM:** Recipients cannot verify email authenticity, increasing spam risk.

### Why Most Setups Fail

Many people configure **MX** and **SPF** but skip **DKIM**.

Gmail, Outlook, and other major providers use all three records to compute a spam score. Missing DKIM significantly increases the chance of landing in spam folders.

This setup includes all three, which means mail is verifiable, tamper-proof, and far less likely to be filtered.

---

## Architectural Invariants

These rules define the system's behavior and should remain true regardless of implementation changes:

### 1. All Identity Lives at the Edge

**Invariant:** Cloudflare owns all hostname resolution for user-facing domains.

**Implication:** Origin servers never make identity decisions. They receive pre-authenticated, pre-routed traffic.

### 2. Origins Must Never Be Trusted with Routing

**Invariant:** Origin servers serve content, not routes.

**Implication:** A compromised origin cannot redirect users to malicious sites. Routing policy is enforced at the edge.

### 3. Legacy Paths Are First-Class Citizens

**Invariant:** Old URLs must continue working indefinitely.

**Implication:** URL structure is a contract with users and search engines. Breaking links breaks trust and SEO.

### 4. TLS Is Owned by Exactly One Layer

**Invariant:** Each subdomain level has a single TLS authority.

**Implication:** No certificate coordination required between Cloudflare and GitHub Pages. Each manages its own certs.

### 5. Policy Changes Must Be Global

**Invariant:** Redirect rules propagate to all edge nodes within seconds.

**Implication:** DNS TTLs are irrelevant for routing changes. Cloudflare's edge runtime updates globally.

### 6. Static Content Only

**Invariant:** No server-side code execution.

**Implication:** Attack surface is minimal. No RCE vulnerabilities, no SQL injection, no authentication bypasses.

---

## Common Mistakes to Avoid

### Mistake 1: Proxying the Blog Subdomain

**Wrong:**
```
blog.blackwell-systems.com → Cloudflare (proxied)
                          → GitHub Pages
```

**Problem:** GitHub Pages cannot issue TLS certificates because ACME verification fails.

**Correct:**
```
blog.blackwell-systems.com → DNS only → GitHub Pages
```

GitHub's ACME bot sees the correct infrastructure and issues certs successfully.

### Mistake 2: Using 302 Redirects

**Wrong:**
```
302 Temporary Redirect
```

**Problem:** Search engines don't transfer authority. Old URLs stay in index indefinitely.

**Correct:**
```
301 Permanent Redirect
```

Signals to search engines that the old URL is permanently replaced.

### Mistake 3: Forgetting Query String Preservation

**Wrong:**
```
concat("https://blog.blackwell-systems.com", http.request.uri.path)
```

**Problem:** Drops query strings like `?ref=twitter&utm_source=social`.

**Correct:**
```
concat("https://blog.blackwell-systems.com", http.request.uri)
```

Preserves full URI including query strings.

### Mistake 4: No Catch-All Rule

**Wrong:**
```
Only specific path rules (/oss, /consulting)
No fallback for apex domain
```

**Problem:** Requests to `blackwell-systems.com/` hit the dummy origin and fail with 522 errors.

**Correct:**
```
Rule 4 (catch-all) handles all other apex traffic
```

Ensures every request to apex domain redirects successfully.

### Mistake 5: Wrong Rule Order

**Wrong:**
```
1. Apex catch-all (too broad)
2. Specific path rules (never reached)
```

**Problem:** Catch-all matches first, specific rules never execute.

**Correct:**
```
1. www → blog
2. /oss paths
3. /consulting paths
4. Apex catch-all (last)
```

Most specific rules first, catch-all last.

---

## Migration Strategy

If you're moving to this architecture from a traditional hosting setup, follow this sequence:

### Phase 1: Prepare Static Site

1. Build static site with Hugo/Jekyll/Next.js/etc.
2. Deploy to GitHub Pages or similar
3. Verify site works at `username.github.io/repo`
4. Do **not** configure custom domain yet

### Phase 2: Configure DNS (Low Risk)

1. Add Cloudflare nameservers to domain registrar
2. Wait for propagation (24-48 hours)
3. Verify Cloudflare is authoritative: `dig NS example.com`

### Phase 3: Set Up Blog Subdomain (Safe)

1. Add CNAME: `blog.example.com` → `username.github.io`
2. **DNS only** (gray cloud)
3. Configure custom domain in GitHub Pages settings
4. Wait for GitHub to issue Let's Encrypt certificate (5-10 minutes)
5. Verify HTTPS works: `curl -I https://blog.example.com`

### Phase 4: Test Redirects (Low Risk)

1. Add dummy IP to apex: `example.com` → `192.0.2.1`
2. Enable proxy (orange cloud)
3. Add redirect rules (without enabling yet)
4. Test with Cloudflare's rule simulator
5. Enable rules one at a time
6. Verify each redirect manually

### Phase 5: Cutover (Reversible)

1. Update MX/SPF/DKIM records for email (if applicable)
2. Monitor DNS propagation globally
3. Check analytics for traffic shifts
4. Verify all legacy URLs redirect correctly

**Rollback plan:** Change apex back to old IP, disable redirect rules. DNS TTL determines rollback time.

### Phase 6: Monitor (Critical)

**Week 1-2:**
- Check Google Search Console for crawl errors
- Monitor 404 rates in analytics
- Verify redirect chains aren't too long (max 2 hops)
- Track organic traffic for anomalies

**Week 3-8:**
- Watch for SEO impact (traffic should stabilize)
- Monitor page load times
- Check for broken links reported by users

**Month 3+:**
- Review Google's index (should show new URLs)
- Confirm old URLs redirect permanently
- Archive old infrastructure

---

## Monitoring and Observability

### Key Metrics to Track

**Redirect performance:**
- Average edge response time (target: <50ms)
- 3xx response rate (should be high for redirected domains)
- 5xx error rate (should be zero)

**Origin health:**
- GitHub Pages uptime (check status.github.com)
- Content delivery latency
- Cache hit rate (if using Cloudflare cache)

**SEO health:**
- Organic traffic trends
- 404 error rate (target: <0.1%)
- Redirect chain depth (target: ≤2)

**Email deliverability:**
- Bounce rate
- SPF/DKIM pass rate
- Spam complaints

### Cloudflare Analytics

Access via Cloudflare dashboard:

- **Traffic:** Requests by country, edge response time
- **Security:** Threats blocked, firewall events
- **DNS:** Query volume, response times
- **Redirect Rules:** Match rate, execution time

### GitHub Pages Status

Monitor at https://www.githubstatus.com

Typical uptime: 99.95%+

---

## Cost Analysis

### Operational Costs

| Component | Cost | Notes |
|-----------|------|-------|
| Domain registration | $10-15/year | Varies by TLD |
| Cloudflare Free | $0/month | Includes edge routing, DDoS protection, SSL |
| GitHub Pages | $0/month | Free for public repos |
| Email (Zoho) | $1/month | Optional, for professional email |

**Total: $10-27/year**

### Hidden Savings

**No server costs:**
- VPS: $5-50/month saved
- Managed hosting: $20-200/month saved
- Load balancer: $20-50/month saved

**No scaling costs:**
- Traffic spikes: $0 additional cost
- Bandwidth: Unlimited on both platforms
- Compute: Pre-rendered, no scaling needed

**No operational overhead:**
- Server maintenance: 0 hours/month
- Security patches: 0 hours/month
- Scaling decisions: 0 hours/month

**Estimated annual savings: $500-$3000** compared to traditional VPS hosting.

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
- **Global performance (10-50ms edge latency)**
- **~$10-27/year total cost**

You haven't just deployed a static site. You've built an **edge-native publishing system** with the same architectural pattern used by modern documentation platforms, open-source portals, and SaaS marketing stacks.

The key insight: **Modern static architecture is about where decisions happen, not what you're serving.**

By moving identity, routing, and policy enforcement to the edge, you eliminate origin latency, origin failures, and origin complexity. The origin becomes a simple content repository, not a routing engine.

This is infrastructure as it should be: **simple, fast, and invisible.**

---

## Further Reading

**Cloudflare Documentation:**
- [Redirect Rules](https://developers.cloudflare.com/rules/url-forwarding/)
- [DNS Proxy Status](https://developers.cloudflare.com/dns/manage-dns-records/reference/proxied-dns-records/)
- [SSL/TLS Overview](https://developers.cloudflare.com/ssl/)

**GitHub Pages:**
- [Custom Domains](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site)
- [HTTPS for Custom Domains](https://docs.github.com/en/pages/getting-started-with-github-pages/securing-your-github-pages-site-with-https)

**DNS and TLS:**
- [RFC 5737 - IPv4 Address Blocks for Documentation](https://datatracker.ietf.org/doc/html/rfc5737)
- [Let's Encrypt ACME Protocol](https://letsencrypt.org/how-it-works/)

**SEO:**
- [Google's Guide to 301 Redirects](https://developers.google.com/search/docs/crawling-indexing/301-redirects)
- [Migrating Sites with URL Changes](https://developers.google.com/search/docs/crawling-indexing/site-move-with-url-changes)
