# Leanpub Browser Setup Checklist

## Step 1: Create Book on Leanpub (FREE Plan)

- [ ] Go to https://leanpub.com/create
- [ ] Click "Continue" with **FREE plan**
- [ ] Book title: `You Don't Know JSON`
- [ ] Subtitle: `Beyond Six Data Types: The Complete Ecosystem`
- [ ] URL slug: `you-dont-know-json` (or your preference)
- [ ] How to write: **Browser**

## Step 2: Configure Book Settings

- [ ] Set minimum price: $19
- [ ] Set suggested price: $29
- [ ] Set reader can pay up to: $49
- [ ] **UNCHECK** "Make this book available in Reader Membership"
- [ ] Save settings

## Step 3: Create Chapter Structure

In Leanpub's browser interface, create 19 chapters with these exact names:

```
1. Introduction
2. Chapter 1: Origins
3. Chapter 2: Modular Architecture
4. Chapter 3: JSON Schema
5. Chapter 4: Binary Databases
6. Chapter 5: Binary APIs
7. Chapter 6: JSON-RPC
8. Chapter 7: JSON Lines
9. Chapter 8: Security
10. Chapter 9: Lessons
11. Chapter 10: Human-Friendly Variants
12. Chapter 11: API Design
13. Chapter 12: Data Pipelines
14. Chapter 13: Testing Systems
15. Chapter 14: Beyond JSON
16. Conclusion
17. Appendix A: JSON Specification Summary
18. Appendix B: Quick Reference Guide
19. Appendix C: Resources and Further Reading
```

## Step 4: Copy/Paste Content

Files are ready in: `leanpub-browser-ready/`

**For each chapter:**

1. Open file in your editor:
   ```bash
   # Example for first file
   cat leanpub-browser-ready/01-introduction.md
   ```

2. Select all (Ctrl+A or Cmd+A)
3. Copy (Ctrl+C or Cmd+C)
4. Go to Leanpub chapter editor
5. Paste (Ctrl+V or Cmd+V)
6. Save chapter

**Repeat for all 19 files** (they're numbered in order: 01- through 19-)

**Checklist:**
- [ ] 01-introduction.md → Introduction
- [ ] 02-chapter-01-origins.md → Chapter 1: Origins
- [ ] 03-chapter-02-architecture.md → Chapter 2: Modular Architecture
- [ ] 04-chapter-03-json-schema.md → Chapter 3: JSON Schema
- [ ] 05-chapter-04-binary-databases.md → Chapter 4: Binary Databases
- [ ] 06-chapter-05-binary-apis.md → Chapter 5: Binary APIs
- [ ] 07-chapter-06-json-rpc.md → Chapter 6: JSON-RPC
- [ ] 08-chapter-07-json-lines.md → Chapter 7: JSON Lines
- [ ] 09-chapter-08-security.md → Chapter 8: Security
- [ ] 10-chapter-09-lessons.md → Chapter 9: Lessons
- [ ] 11-chapter-10-human-friendly.md → Chapter 10: Human-Friendly Variants
- [ ] 12-chapter-11-api-design.md → Chapter 11: API Design
- [ ] 13-chapter-12-data-pipelines.md → Chapter 12: Data Pipelines
- [ ] 14-chapter-13-testing.md → Chapter 13: Testing Systems
- [ ] 15-chapter-14-future.md → Chapter 14: Beyond JSON
- [ ] 16-conclusion.md → Conclusion
- [ ] 17-appendix-a-specification.md → Appendix A
- [ ] 18-appendix-b-quick-reference.md → Appendix B
- [ ] 19-appendix-c-resources.md → Appendix C

## Step 5: Preview Your Book

- [ ] Click "Preview" button
- [ ] Wait 2-5 minutes for build
- [ ] Download PDF
- [ ] Review:
  - [ ] All chapters present
  - [ ] Mermaid diagrams rendered correctly
  - [ ] Table of contents generated
  - [ ] No formatting issues

## Step 6: Iterate (If Needed)

If you find issues:
1. Edit chapter in Leanpub browser
2. Save changes
3. Click "Preview" again
4. Download new PDF

You have **20 previews per month** on FREE plan.

## Step 7: Publish (When Ready)

- [ ] Final preview looks good
- [ ] Click "Publish" button
- [ ] Your book is live!
- [ ] Share the link: `leanpub.com/you-dont-know-json`

## Tips

**Faster copy/paste:**
- Open all 19 files in tabs
- Go through them sequentially
- Copy → Switch to Leanpub → Paste → Next
- Should take 15-20 minutes total

**Mermaid diagrams:**
- They'll render automatically in Leanpub
- No pre-rendering needed
- If one doesn't render, check for syntax errors in that chapter

**Troubleshooting:**
- If preview fails, check Leanpub's error message
- Usually it's a markdown syntax issue
- Fix in browser editor, save, preview again

## Upgrade Path (Optional)

If you want GitHub sync later:
1. Upgrade to STANDARD ($8.99/month)
2. Export from browser to GitHub repo
3. Switch to "Cloud" mode
4. Downgrade to FREE when done editing

---

**You're ready to go! The hard work (writing) is done—now it's just copy/paste.**
