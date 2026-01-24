# Dev.to Article Conversions

This folder contains Dev.to-ready versions of blog articles.

## Files

### multicore-killed-oop-full.md
- **Length:** 1,697 lines (~15,000 words)
- **Complete version** with all sections
- Includes critical "Value Semantics at Scale" section explaining when Java/Spring is fine
- All Hugo shortcodes converted to standard markdown
- Canonical URL set to preserve SEO

### multicore-killed-oop.md
- **Length:** 594 lines (~8,000 words)  
- **Condensed version** for readers who want shorter content
- Covers core thesis but omits some technical depth

## Conversion Notes

**What was changed:**
- Hugo `{{< callout >}}` → Simple blockquotes `>`
- Hugo `{{< relref >}}` → Full URLs
- Hugo `{{< mermaid >}}` → Standard mermaid code blocks
- Box-drawing characters → ASCII (`+-|`)
- Unicode arrows → ASCII (`^`, `->`)
- All non-ASCII characters stripped

**Front matter format:**
```yaml
---
title: "Article Title"
published: true
description: "SEO description"
tags: tag1, tag2, tag3, tag4
canonical_url: https://blog.blackwell-systems.com/posts/article-slug/
---
```

## Usage

1. Copy entire file contents
2. Paste into Dev.to "Create Post" editor
3. Dev.to will parse the front matter automatically
4. Preview before publishing
5. The canonical_url ensures Google credits your blog as the original source

## Sections Included (Full Version)

1. The OOP Design Choice: References by Default
2. The Multicore Catalyst (2005-2010)
3. Threads Existed Before Multicore
4. Why Reference Semantics Broke with Concurrency
5. The Post-OOP Response: Value Semantics for Safe Concurrency
6. The Performance Bonus: Cache Locality
7. Inheritance: The Cache Locality Killer
8. The Lock Bottleneck: How Mutexes Kill Parallelism
9. The Three Factors: Why Multicore Killed OOP
10. When OOP Still Makes Sense
11. Lessons Learned
12. Value Semantics at Scale: Why Copy-by-Value Enables Massive Throughput
13. The Pendulum Swings
14. What This Means for You
15. Conclusion
16. Further Reading
