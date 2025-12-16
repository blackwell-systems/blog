# You Don't Know JSON - Book Directory

This directory contains all materials for transforming the blog series into a comprehensive book.

**Status:** Planning Phase  
**Target Completion:** Q2 2026  
**Current Blog Series:** 8 parts, ~39,000 words complete

---

## Directory Structure

```
book/
├── manuscript/          # All written content
│   ├── chapters/        # Main chapters (markdown)
│   ├── appendices/      # Reference material
│   ├── front-matter/    # Introduction, TOC, preface
│   └── back-matter/     # Conclusion, index, resources
│
├── diagrams/            # Visual content workflow
│   ├── mermaid-source/  # Original .mmd files
│   ├── svg-exports/     # High-res SVG exports
│   └── pdf-final/       # Print-ready vector PDFs
│
├── code-examples/       # Production-ready code
│   ├── javascript/      # Node.js examples
│   ├── go/              # Go examples
│   ├── python/          # Python examples
│   ├── rust/            # Rust examples
│   ├── sql/             # Database examples
│   └── bash/            # Shell scripts
│
├── assets/              # Book production assets
│   ├── images/          # Screenshots, photos
│   ├── fonts/           # Typography
│   └── styles/          # CSS/LaTeX styles
│
├── build/               # Output formats
│   ├── pdf/             # Print and digital PDF
│   ├── epub/            # EPUB ebook
│   ├── mobi/            # Kindle format
│   └── web/             # HTML version
│
└── notes/               # Working notes and research
```

---

## Workflow

### 1. Content Development (`manuscript/`)

**Source:** Blog posts in `/content/posts/you-dont-know-json-*.md`

**Process:**
1. Copy blog markdown to `manuscript/chapters/`
2. Expand with additional content per BOOK_PLAN.md
3. Add cross-references and transitions
4. Write front-matter and back-matter

**Chapter naming:**
- `chapter-01-origins.md`
- `chapter-02-architecture.md`
- `chapter-03-json-schema.md`
- etc.

### 2. Diagrams (`diagrams/`)

**Workflow:**
1. Create/edit in `mermaid-source/*.mmd`
2. Export to `svg-exports/*.svg` (high resolution)
3. Convert to `pdf-final/*.pdf` (print-ready vectors)

**Blog diagrams:** Already exist in blog posts, extract and enhance

**New book diagrams:** See BOOK_PLAN.md "Visual Enhancements" section:
- Architectural evolution timeline
- JSON ecosystem map
- REST vs RPC spectrum
- Binary format selection guide
- etc.

### 3. Code Examples (`code-examples/`)

**Organization:**
- Each language has its own directory
- Examples organized by chapter/concept
- Include README with setup instructions
- All code must be runnable

**Example structure:**
```
code-examples/
├── javascript/
│   ├── chapter-03-schema/
│   │   ├── validation.js
│   │   ├── composition.js
│   │   └── package.json
│   └── progressive-api/    # Running example
└── go/
    ├── chapter-03-schema/
    │   ├── validation.go
    │   └── go.mod
    └── progressive-api/
```

### 4. Assets (`assets/`)

**Images:**
- Screenshots (if needed)
- Photos (if needed)
- Logos (if needed)

**Fonts:**
- Print: Professional serif (body) + monospace (code)
- Digital: Sans-serif (body) + monospace (code)

**Styles:**
- LaTeX templates for PDF
- CSS for HTML/EPUB
- Consistent with blog theme (dark, muted colors)

### 5. Build (`build/`)

**PDF:**
- Print version (grayscale diagrams, optimized for paper)
- Digital version (color diagrams, hyperlinks)

**EPUB:**
- Standard ebook format
- Interactive diagrams (mermaid source)

**MOBI:**
- Kindle format (converted from EPUB)

**Web:**
- HTML version for online reading
- Useful for free tier

---

## Content Status Tracker

### Blog Content (Existing)

- [x] Part 1: Origins (4,163 words)
- [x] Part 2: JSON Schema (4,079 words)
- [x] Part 3: Binary Databases (3,283 words)
- [x] Part 4: Binary APIs (5,187 words)
- [x] Part 5: JSON-RPC (6,734 words)
- [x] Part 6: JSON Lines (6,004 words)
- [x] Part 7: Security (5,441 words)
- [x] Part 8: Lessons/Zeitgeist (3,643 words)

**Total:** ~39,000 words

### Book Expansion Needed

**Existing chapters to expand:**
- [ ] Chapter 1: +2,000 words (XML contrast, history)
- [ ] Chapter 3: +3,000 words (code generation)
- [ ] Chapter 4: +3,500 words (benchmarks, deployment)
- [ ] Chapter 5: +1,800 words (real-world examples)
- [ ] Chapter 6: +1,300 words (WebSocket patterns)
- [ ] Chapter 7: +2,000 words (data engineering)
- [ ] Chapter 8: +2,600 words (attack scenarios)
- [ ] Chapter 9: +2,400 words (future predictions)

**New chapters to write:**
- [ ] Chapter 2: Architecture (7,000 words)
- [ ] Chapter 10: JSON5/HJSON/YAML/TOML (7,000 words)
- [ ] Chapter 11: API Design (8,000 words)
- [ ] Chapter 12: Data Pipelines (8,000 words)
- [ ] Chapter 13: Testing (7,000 words)
- [ ] Chapter 14: Future/Alternatives (6,000 words)

**Additional content:**
- [ ] Introduction (2,500 words)
- [ ] Conclusion (2,500 words)
- [ ] Appendix A: JSON Spec (2,000 words)
- [ ] Appendix B: Quick Reference (1,000 words)
- [ ] Appendix C: Resources (1,000 words)

**Target:** 109,600 words (~244 pages)

---

## Production Tools

### Writing
- **Editor:** Any markdown editor
- **Format:** Markdown (easily converts to everything)
- **Version control:** Git (this repo)

### Diagrams
- **Tool:** Mermaid CLI or online editor
- **Export:** SVG → PDF conversion via Inkscape/ImageMagick
- **Quality:** 300 DPI minimum for print

### Code
- **Testing:** All examples must run without modification
- **Formatting:** Language-specific formatters (prettier, gofmt, black, rustfmt)
- **Documentation:** README per language with setup

### Conversion
- **Markdown → LaTeX → PDF:** Pandoc + LaTeX
- **Markdown → EPUB:** Pandoc
- **EPUB → MOBI:** Calibre
- **Markdown → HTML:** Custom generator or Pandoc

---

## Publishing Platforms

### Self-Publishing Options

**Leanpub:**
- Markdown-native (easy conversion)
- Publish in stages (beta → final)
- 90% royalty
- Can update anytime

**Gumroad:**
- Simple payment
- PDF/EPUB distribution
- 90% royalty

**Amazon KDP:**
- Massive reach
- Print-on-demand available
- 70% royalty
- Less control

### Traditional Publishing

**Potential publishers:**
- O'Reilly Media
- Pragmatic Programmers
- Manning Publications
- No Starch Press

---

## Timeline (Proposed)

**Q1 2026 (Jan-Mar):** Refinement
- Edit existing content
- Write Chapter 2 (Architecture)
- Create all diagrams in print-ready format
- Set up code repository

**Q2 2026 (Apr-Jun):** New Content
- Write Chapters 10-14
- Write Introduction, Conclusion
- Create Appendices

**Q3 2026 (Jul-Sep):** Production
- Technical review
- Copy editing
- Layout and formatting
- Build PDF/EPUB/MOBI

**Q4 2026 (Oct-Dec):** Launch
- Beta release
- Marketing
- Public launch

---

## Notes

- See `/BOOK_PLAN.md` for comprehensive planning document
- Blog posts remain free (goodwill, SEO, marketing)
- Book adds significant value (expanded content, organization, reference material)
- Code repository will be separate GitHub repo (linked from book)
- Diagrams must work in both print (grayscale) and digital (color)

---

## Getting Started

1. **Copy blog content to manuscript:**
   ```bash
   # Copy existing blog posts
   for i in {1..8}; do
     cp content/posts/you-dont-know-json-part-$i-*.md \
        book/manuscript/chapters/chapter-0$i-*.md
   done
   ```

2. **Extract diagrams:**
   ```bash
   # Extract mermaid blocks from blog posts
   grep -A 20 "{{< mermaid >}}" content/posts/*.md > book/diagrams/extracted.txt
   ```

3. **Start editing:**
   - Begin with Chapter 1
   - Add cross-references
   - Expand with additional content
   - Track progress in this README

---

**Last Updated:** 2025-12-16
