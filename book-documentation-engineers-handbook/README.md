# The Documentation Engineer's Handbook

**Working Title:** The Documentation Engineer's Handbook: Building, Scaling, and Maintaining Documentation Systems

**Author:** Dayna Blackwell

**Status:** Outline complete, writing in progress

---

## Project Overview

This book is the first comprehensive guide to documentation engineering as an engineering discipline—covering architecture, tooling, automation, scale, and career development.

**Elevator Pitch:**

*"You wouldn't build a distributed system without CI/CD, monitoring, and incident response. So why are you treating documentation differently? This book shows how to apply engineering rigor to documentation - from architecture and automation to security, debt management, and emergency procedures. Whether you're a software engineer building docs systems or a technical writer learning engineering practices, this is the guide to documentation engineering as a discipline."*

## Target Audience

- Software engineers transitioning to documentation engineering
- Senior engineers building documentation systems
- Technical writers learning engineering practices
- Developer advocates and DevEx engineers
- Engineering managers hiring documentation engineers

## Book Statistics

- **Estimated length:** 135,000-145,000 words (~500-540 pages)
- **Chapters:** 15 main chapters + 3 appendices
- **Timeline:** 9-13 months (outline + writing + editing)
- **Target launch:** Q4 2026

## Book Structure

### Part I: Foundations
1. What Is Documentation Engineering?
2. Documentation Architecture
3. Docs-as-Code Workflows

### Part II: Tooling and Infrastructure
4. Static Site Generators
5. API Documentation
6. Testing Documentation
7. Diagrams and Visual Documentation

### Part III: Scale and Automation
8. Documentation at Scale
9. CI/CD for Documentation
10. Automation and Generation

### Part IV: Organization and Team
11. Building a Documentation Team
12. Contribution Models
13. Documentation Culture

### Part V: Career Development
14. The Documentation Engineer Career Path
15. Speaking and Thought Leadership

### Part VI: Appendices
- Appendix A: Tools Directory
- Appendix B: Templates and Examples
- Appendix C: Resources

## Core Themes

The book is built around 8 recurring themes that appear throughout:

1. **Documentation as Infrastructure** - Treat docs like production systems
2. **Measurable Quality** - Metrics over subjective opinions
3. **Documentation Debt** - Like technical debt, must be managed
4. **Documentation Has Incidents** - P0/P1/P2 severity levels apply
5. **Engineers Build Systems** - Not just content creation
6. **Documentation Security** - Real security vulnerabilities exist
7. **Documentation Engineering is a Career** - $80K-$400K+ compensation
8. **Automation Enables Scale** - Can't manually maintain 100K+ pages

## Directory Structure

```
book-documentation-engineers-handbook/
├── OUTLINE.md                      # Complete book outline
├── README.md                       # This file
├── manuscript/                     # Leanpub manuscript directory
│   ├── frontmatter/               # Introduction, preface
│   ├── part-1-foundations/        # Chapters 1-3
│   ├── part-2-tooling-and-infrastructure/  # Chapters 4-7
│   ├── part-3-scale-and-automation/        # Chapters 8-10
│   ├── part-4-organization-and-team/       # Chapters 11-13
│   ├── part-5-career-development/          # Chapters 14-15
│   ├── part-6-appendices/         # Appendices A-C
│   └── backmatter/                # Conclusion, about author
├── examples/                       # Code examples and configs
│   ├── github-actions/            # GitHub Actions workflows
│   ├── gitlab-ci/                 # GitLab CI configs
│   ├── mermaid-diagrams/          # Diagram examples
│   └── code-examples/             # Code snippets
└── assets/                         # Images and diagrams
    ├── diagrams/                  # Architecture diagrams
    └── screenshots/               # Screenshot examples
```

## Writing Progress

Track progress by checking which chapter files exist and have content:

- [ ] Front Matter
  - [ ] Introduction
  - [ ] Preface
- [ ] Part I: Foundations
  - [ ] Chapter 1: What Is Documentation Engineering?
  - [ ] Chapter 2: Documentation Architecture
  - [ ] Chapter 3: Docs-as-Code Workflows
- [ ] Part II: Tooling and Infrastructure
  - [ ] Chapter 4: Static Site Generators
  - [ ] Chapter 5: API Documentation
  - [ ] Chapter 6: Testing Documentation
  - [ ] Chapter 7: Diagrams and Visual Documentation
- [ ] Part III: Scale and Automation
  - [ ] Chapter 8: Documentation at Scale
  - [ ] Chapter 9: CI/CD for Documentation
  - [ ] Chapter 10: Automation and Generation
- [ ] Part IV: Organization and Team
  - [ ] Chapter 11: Building a Documentation Team
  - [ ] Chapter 12: Contribution Models
  - [ ] Chapter 13: Documentation Culture
- [ ] Part V: Career Development
  - [ ] Chapter 14: The Documentation Engineer Career Path
  - [ ] Chapter 15: Speaking and Thought Leadership
- [ ] Part VI: Appendices
  - [ ] Appendix A: Tools Directory
  - [ ] Appendix B: Templates and Examples
  - [ ] Appendix C: Resources
- [ ] Back Matter
  - [ ] Conclusion
  - [ ] About the Author

## Publishing Strategy

**Primary:** Leanpub
- Publish in progress
- Gather reader feedback
- Variable pricing model
- 80% royalty rate

**Secondary:** Amazon KDP (non-exclusive)
- After v1.0 complete
- Broader discoverability
- 70% royalty (at $9.99+)

**Optional:** Print-on-demand for conferences

## Key Differentiators

What makes this book unique:

- **First comprehensive documentation engineering book** (not just "technical writing")
- **Engineering-first approach** (architecture, CI/CD, security, incidents)
- **Practical code examples** (complete GitHub Actions workflows, debt scoring algorithms)
- **Real-world case studies** (zombie docs, shadow docs, security breaches)
- **Career guidance** (salary ranges, interview questions, career ladders)
- **Operational focus** (incident response, emergency updates, on-call procedures)

## Related Works

This book differs from existing documentation books:

- **"Docs Like Code" (Anne Gentle)** - Covers docs-as-code basics; this book goes deeper into engineering
- **"The Product is Docs" (Splunk team)** - Product management focus; this book is engineering-focused
- **"Modern Technical Writing" (Andrew Etter)** - Writing-focused; this book is systems-focused

## Author

Dayna Blackwell is a software architect, technical author, and founder of Blackwell Systems. With 225,000+ lines of published documentation across 10+ open-source projects and five years building enterprise systems, Dayna brings an engineering-first approach to documentation.

**Previous book:** *You Don't Know JSON* (Leanpub, 2025)

## Contact

- **Email:** dayna@blackwell-systems.com
- **GitHub:** [@blackwell-systems](https://github.com/blackwell-systems)
- **Blog:** https://blog.blackwell-systems.com

---

**Last updated:** 2026-01-06
