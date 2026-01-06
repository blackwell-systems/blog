# LinkedIn Book Launch Strategy: "You Don't Know JSON"

Strategic approach for launching technical book on LinkedIn, building audience, and establishing authority.

---

## Core Principles

1. **Value-first, not sales-first** - Give away 80% of insights, book is "full analysis"
2. **Credibility through experience** - Share war stories, not achievements
3. **Engagement drives visibility** - Comments and conversations boost algorithm
4. **Mix book content with general posts** - Max 1 book post per week
5. **Build email list for future books** - This is Book 1 of a series

---

## IMMEDIATE LAUNCH STRATEGY (Publishing Today)

**Timeline for same-day launch:**

**Today (within 2 hours):**
1. Publish to Leanpub and get URL
2. Post launch announcement on LinkedIn (see Phase 2, Post 3)
3. Monitor for first 2 hours, reply to all comments
4. Share in relevant groups

**Tomorrow:**
5. Post "The Journey" story (see Pre-Launch Post 1) - establishes backstory

**Day 3:**
6. Post sample chapter or technical insight (see Pre-Launch Post 2)

**Week 1 onward:**
7. Follow normal post-launch content series (controversial takes, war stories, etc.)

**Skip pre-launch, start with launch announcement, then backfill context over next week.**

---

## Phase 1: Pre-Launch (Use if you have 1 week - SKIP IF LAUNCHING TODAY)

### Post 1: The Journey (Day -7)

**Type:** Personal story establishing credibility

**Post:**
```
After 4 years writing API documentation in enterprise hospitality, I noticed something:

Every team struggles with the same JSON decisions:
- When do we need JSON Schema?
- Should we switch to Protocol Buffers?
- How do we handle JWT security properly?
- When is REST enough vs GraphQL vs gRPC?

These aren't syntax questions. They're architecture questions.

So I spent the last month writing the book I wish existed when I was designing my first API at scale.

"You Don't Know JSON" - 107,000 words covering JSON architecture, validation, binary formats, streaming, security, testing, and production patterns.

Publishing on Leanpub next week. Free sample available soon.

#TechnicalWriting #APIs #SoftwareArchitecture
```

**Why this works:**
- Establishes credibility (4 years, enterprise scale)
- Focuses on reader pain points, not your achievement
- Teases without selling yet
- Sets up launch announcement

**Timing:** Post Monday morning (8-10 AM EST for max visibility)

---

### Post 2: Sample Chapter Drop (Day -3)

**Type:** Value content preview

**Post:**
```
Preview from "You Don't Know JSON" - Chapter 2: Why JSON succeeded where XML failed.

It wasn't just simplicity. XML had corporate backing from Sun, IBM, and Microsoft. SOAP had $10M+ marketing budgets.

JSON won because of architecture.

[Attach PDF of Chapter 2 or link to blog post with excerpt]

The full book covers:
- JSON Schema (when validation matters)
- Binary formats (when JSON isn't enough)
- JWT security (algorithm confusion, token attacks)
- Production patterns (pagination, rate limiting, error handling)

Launch: [Date]. Free sample chapters available.

Link in comments.

#JSON #APIDesign #BackendEngineering
```

**Action Items:**
- [ ] Export Chapter 2 as PDF
- [ ] OR write blog post with Chapter 2 excerpt
- [ ] Post link in first comment (algorithm boost)

**Why this works:**
- Gives away valuable content (builds trust)
- Shows book quality (not just claiming it's good)
- Blog post excerpt drives traffic to your site
- Demonstrates writing ability

**Timing:** Thursday morning (mid-week engagement peak)

---

## Phase 2: Launch Day

### Post 3: Launch Announcement (Day 0)

**Type:** Professional book launch

**Post:**
```
"You Don't Know JSON" is live on Leanpub.

After writing 225,000+ lines of documentation across APIs, open-source tools, and technical articles, I wrote the book that connects JSON syntax to architectural decisions.

This isn't a tutorial. It's a framework for choosing between:
- JSON vs MessagePack vs Protocol Buffers
- REST vs JSON-RPC vs GraphQL
- JWT vs session tokens
- When streaming matters vs batch processing

107,000 words. 14 chapters. 66 diagrams. Real production patterns.

Free sample (3 chapters) available. $29 for the full book.

Link: [Leanpub URL]

Written for backend engineers, architects, and teams making data format decisions that matter.

#TechnicalBook #JSON #APIs #BackendEngineering
```

**Critical Elements:**
- ✅ Lead with the book (not "I'm so proud...")
- ✅ Focus on reader value (decisions they need to make)
- ✅ Mention credentials briefly (225K lines) without bragging
- ✅ Clear pricing transparency
- ✅ Free sample emphasized
- ✅ Clear call to action
- ✅ Target audience specified

**Action Items:**
- [ ] Publish to Leanpub first
- [ ] Get final Leanpub URL
- [ ] Create cover image for post
- [ ] Schedule for Tuesday morning (best launch day)

**Timing:** Tuesday 9 AM EST (peak engagement for professional content)

---

## Phase 3: Post-Launch Content Series (Weeks 1-4)

### Post 4: Controversial Take (Week 1)

**Type:** Thought leadership / engagement bait

**Post:**
```
Unpopular opinion: Protocol Buffers didn't "fail" to replace JSON.

They succeeded at what they're good for: internal high-performance RPCs.

But JSON won the internet because:
- Debugging in production requires human-readable logs
- Browser DevTools can't parse binary formats
- Every language has a JSON parser in stdlib
- Migration cost > performance gains for most APIs

From Chapter 5 of "You Don't Know JSON" - where I break down when binary formats actually make sense.

[Chart showing JSON vs binary decision framework]

Full analysis in the book: [Link]

#APIDevelopment #PerformanceEngineering
```

**Action Items:**
- [ ] Create decision framework diagram (export from Chapter 5)
- [ ] Make it shareable (clear, simple visual)

**Why this works:**
- Controversial statement = engagement
- Shows depth of book content
- Provides actual value (decision framework)
- Not directly selling, but mentions book naturally
- Invites discussion (algorithm boost from comments)

**Engagement Strategy:**
- Reply to every comment
- Ask follow-up questions
- Share others' experiences

---

### Post 5: Real War Story (Week 2)

**Type:** Vulnerability marketing / lessons learned

**Post:**
```
We spent 6 weeks migrating our booking API from JSON to MessagePack.

Performance improved 22%. Great, right?

Except:
- 2 weeks debugging binary payloads in production
- 3 integration partners couldn't handle MessagePack
- Our on-call team couldn't read logs anymore

We rolled back. Learned an expensive lesson about premature optimization.

This is why Chapter 5 of "You Don't Know JSON" includes a migration decision framework - not just "MessagePack is faster."

When binary formats make sense:
✓ Internal services (you control both ends)
✓ >10M requests/day (bandwidth costs matter)
✓ Mobile apps (battery/data limits)

When they don't:
✗ Public APIs (compatibility hell)
✗ <1M requests/day (engineer time > bandwidth cost)
✗ Small teams (debugging overhead)

[Link to book]

What's your experience with binary formats?

#SoftwareEngineering #LessonsLearned
```

**Why this works:**
- Vulnerability (admitting mistakes = credibility)
- Concrete details (numbers, timeline, specific problems)
- Actionable framework (readers can use immediately)
- Question prompts comments = algorithm boost
- Shows book has practical experience, not just theory

**Engagement Strategy:**
- Share your own mistake openly
- Ask others about their experiences
- Build community around shared learning

---

### Post 6: Help Others (Week 3)

**Type:** Educational / helpful framework

**Post:**
```
Common question: "Should I use JSON Schema for validation?"

Short answer: Depends on your API's maturity.

Prototyping (0-100 users):
→ Skip it. TypeScript types are enough.

Production (100-10K users):
→ Yes. Add schema validation to prevent bad data cascading through your system.

Scale (10K+ users):
→ Absolutely. Generate client SDKs, OpenAPI docs, and validation from one schema definition.

From Chapter 3 where I cover schema evolution patterns that saved us from breaking changes.

Full guide: [Link]

What validation patterns work for your team?

#APIValidation #BackendDevelopment
```

**Why this works:**
- Helpful content first (not selling)
- Tiered advice (readers self-select their stage)
- Engagement question (builds discussion)
- Natural book mention (it's the "full guide")
- Demonstrates expertise

**Response Template:**
```
"We use [X]"
→ "Interesting! How are you handling [specific challenge]? In Chapter 3 I cover [related pattern]."
```

---

### Post 7: Technical Deep Dive (Week 4)

**Type:** Education with code example

**Post:**
```
JWT algorithm confusion attacks explained:

Your API accepts RS256 (RSA public key verification).
Attacker changes alg to HS256 (HMAC with shared secret).
Uses your *public* key as the HMAC secret.
Token validates successfully. 🚨

Why? Most JWT libraries trust the alg header by default.

The fix (Node.js):
```javascript
jwt.verify(token, secret, {
  algorithms: ['RS256']  // Whitelist allowed algorithms
});
```

This vulnerability affected Auth0, GitLab, and countless APIs.

Chapter 8 of "You Don't Know JSON" covers 8 JWT attacks and production mitigation patterns.

[Link to book]

Do you explicitly specify allowed algorithms in your JWT verification?

#Security #JWT #BackendSecurity
```

**Why this works:**
- High-value technical content
- Concrete code example
- Scary real-world context (Auth0, GitLab)
- Simple fix (readers can apply immediately)
- Demonstrates book depth

---

## Phase 4: Long-Term Presence (Monthly)

### Post 8: Reader Testimonial (Month 2)

**Type:** Social proof

**Post:**
```
"This book explained JWT algorithm confusion in a way that finally clicked. We immediately audited our token validation - found we were vulnerable. Fixed before it became a $200K problem."

- Senior Engineer, [Company if they permit]

Security is Chapter 8 of "You Don't Know JSON."

Covers:
- Algorithm confusion attacks (RS256 → HS256)
- Token substitution
- Injection vulnerabilities
- DoS through malformed input
- Production security patterns

If your API uses JWTs, this chapter alone is worth $29.

[Link]

#APISecurity #JWT
```

**Action Items:**
- [ ] Reach out to early readers for testimonials
- [ ] Ask permission to use company name (optional)
- [ ] Get specific quote about value

**Why this works:**
- Social proof (someone else says it's good)
- Concrete value ($200K problem prevented)
- Single-chapter value prop (reduces buying friction)
- Quantifiable ROI

---

### Post 9: Behind the Scenes (Month 3)

**Type:** Process / transparency

**Post:**
```
Writing a technical book in 1 month:

- 107,000 words
- 66 mermaid diagrams
- Code examples in 5 languages
- Production patterns from 4 years enterprise experience

How? A system:

1. Outline all chapters first (2 days)
2. Write 3,500 words/day (20 days writing)
3. AI-assisted diagram generation (5 days)
4. Technical review and polish (5 days)
5. Appendices and references (3 days)

Total: 35 days from outline to publication.

The secret: Treat writing like software development. Modular chapters, reusable patterns, version control, automated tooling.

Next book: "You Don't Know REST APIs" - starting outline next week.

[Link to JSON book]

What's your writing process for technical content?

#TechnicalWriting #ProductivityTips
```

**Why this works:**
- Transparency builds trust
- Process content gets shared (others want to learn)
- Teases next book (builds anticipation)
- Positions you as prolific author
- Engagement question

---

### Post 10: Series Announcement (Month 4)

**Type:** Future roadmap

**Post:**
```
"You Don't Know JSON" readers asked for more.

So I'm writing a series.

✅ Book 1: JSON (published)
📝 Book 2: REST APIs (writing now - Q1 2026)
📋 Book 3: GraphQL (planned - Q2 2026)
📋 Book 4: WebSockets (planned - Q3 2026)

Each book: same architectural lens, different format.

Why this matters:
- You don't learn JSON in isolation
- These decisions interconnect
- Understanding trade-offs > memorizing syntax

JSON book readers: You'll get early access to REST API book.

Join the email list: [link]

#TechnicalWriting #APIDevelopment
```

**Action Items:**
- [ ] Set up email list (Leanpub has this built-in)
- [ ] Create series landing page
- [ ] Start REST API book outline

**Why this works:**
- Shows commitment (not one-off)
- Creates urgency (early access for existing readers)
- Builds email list for future launches
- Positions you as series author (more authority)

---

## LinkedIn Profile Updates

### Headline
```
Senior Backend Engineer | Author of "You Don't Know JSON" | Technical Writer | 3x AWS Certified
```

### Featured Section
Add:
1. Book link (Leanpub URL) with cover image
2. Blog (blackwell-systems.github.io/blog)
3. GitHub (github.com/blackwell-systems)

### About Section
Add paragraph:
```
Author of "You Don't Know JSON" (2026) - a 107,000-word technical book covering JSON architecture, API design patterns, security, and production systems. Available on Leanpub.

I write about the invisible infrastructure decisions that shape backend systems: data formats, API protocols, error handling, and architectural patterns that scale.
```

### Experience Section
Add new entry:
```
Author & Technical Writer
Self-Published | Jan 2026 - Present

Published "You Don't Know JSON" - comprehensive technical book (107K words, 66 diagrams) covering JSON ecosystem architecture, validation patterns, binary formats, streaming systems, security, and production API design.

Written for backend engineers and architects making data format decisions at scale.

Portfolio: https://leanpub.com/you-dont-know-json
```

---

## Content Calendar Template

| Week | Post Type | Topic | Goal |
|------|-----------|-------|------|
| -1 | Journey | Why I wrote the book | Build anticipation |
| 0 | Launch | Book announcement | Drive sales |
| 1 | Controversial | Protocol Buffers vs JSON | Engagement |
| 2 | War Story | MessagePack migration fail | Credibility |
| 3 | Helpful | JSON Schema decision framework | Value |
| 4 | Technical | JWT security vulnerability | Education |
| 8 | Social Proof | Reader testimonial | Trust |
| 12 | Process | How I wrote it | Interest |
| 16 | Series | Future books announcement | Email list |

**Cadence:**
- 1 book-related post per week
- Mix with 2-3 general industry posts per week
- Total: 3-4 LinkedIn posts per week

---

## What NOT to Do

### ❌ Avoid These Mistakes

**Don't spam:**
- Max 1 post/week directly about book
- Mix book content with general insights
- People unfollow if you're always selling

**Don't beg:**
- ❌ "Please buy my book" = desperate
- ✅ "Here's value, link if you want more" = professional

**Don't ignore engagement:**
- Reply to every comment within 24 hours
- Thank people who share
- Answer questions = free marketing + algorithm boost
- Comments increase post visibility 10x

**Don't make it about you:**
- ❌ "I'm so proud of this achievement" = uninteresting
- ✅ "This solves your problem" = engaging

**Don't just post and ghost:**
- First 2 hours after posting = critical
- Reply to comments immediately
- Ask follow-up questions
- Start conversations

**Don't forget calls to action:**
- Every post should have: question, link, or next step
- Make it easy for readers to engage

---

## Engagement Response Templates

### When people comment positively:
```
"Great insights! What chapter covers X?"
→ "Chapter [N]! I go into [specific detail about what they asked]. The free sample includes [related content]. Happy to answer questions here or you can check it out: [link]"

"This helped me understand [topic]"
→ "That's great to hear! The full chapter has [additional value like code examples, production patterns]. Feel free to reach out if you have questions about [related topic]."

"Bookmarking this for later"
→ "Appreciate it! If you're working on [related problem], Chapter [N] covers [specific solution]. Let me know if you have questions about [topic]."
```

### When people disagree:
```
"I disagree with [point]"
→ "Interesting perspective! In the book I cover [counterpoint] and [alternative approach]. What's your experience been with [specific aspect]?"

"This doesn't work for [edge case]"
→ "Great point - I address that in [chapter/section]. The trade-off is [explanation]. How are you handling [edge case] currently?"

"[Competing technology] is better"
→ "You're right for [specific use case]! That's exactly why Chapter [N] includes a decision framework. [Technology] wins when [conditions]. What's your tech stack?"
```

### When people ask questions:
```
"How do I [technical question]?"
→ "Good question! [Brief answer]. Chapter [N] covers this in depth with [examples/patterns]. Are you dealing with [related challenge]?"

"Does the book cover [topic]?"
→ "Yes! Chapter [N] has [specific content]. Also covers [related topics] since they're connected. The free sample includes [what's free]. [Link]"

"What's the difference between X and Y?"
→ "[Brief explanation]. This is exactly what Chapter [N] compares - when to use X (scenarios) vs Y (other scenarios). What are you trying to build?"
```

### Building conversations:
- Always ask a follow-up question
- Reference specific book content naturally
- Provide value even if they don't buy
- Build relationship > make sale

---

## Metrics to Track

### LinkedIn Analytics

**Post Performance:**
- Impressions (how many people saw it)
- Engagement rate (likes + comments + shares / impressions)
- Click-through rate (clicks on link / impressions)
- Best posting times (when your audience is active)

**Goals:**
- Engagement rate > 2% (good for technical content)
- 5-10 comments per post minimum
- 20-50 reactions per post

**Profile Metrics:**
- Profile views (should spike after posts)
- Search appearances
- Connection requests (quality > quantity)

### Book Sales Correlation

Track which posts drive sales:
- Use UTM parameters in links: `?utm_source=linkedin&utm_medium=post1`
- Note sales spikes after specific post types
- Double down on what works

### Email List Growth

- Sign-ups per week
- Conversion rate (book buyers → email subscribers)
- Goal: 30-50% of buyers join list

---

## Long-Term Strategy: Building Authority

### Content Themes (Rotate)

**Week 1:** Technical deep dive (code examples, vulnerabilities)
**Week 2:** Decision frameworks (when to use X vs Y)
**Week 3:** War stories (lessons learned, mistakes)
**Week 4:** Industry commentary (trends, hot takes)

**Every 4 weeks:** Book mention or testimonial

### Beyond LinkedIn

**Coordinate across channels:**
- LinkedIn post → Extract to Twitter thread
- LinkedIn post → Expand to blog article
- LinkedIn engagement → Answer on Stack Overflow
- LinkedIn connections → Conference speaking opportunities

**Content Flywheel:**
1. Write book
2. Extract posts
3. Posts drive book sales
4. Book readers join email list
5. Email list buys next book
6. Repeat

---

## Series Launch Strategy

**When Book 2 ready (Q1 2026):**

**Post to existing audience:**
```
For everyone who read "You Don't Know JSON":

Book 2 is ready: "You Don't Know REST APIs"

Covers:
- [Topics]

20% off for JSON book readers: [Link with coupon code]

Thanks for the support on Book 1. Your feedback shaped Book 2.
```

**This is why email list matters:**
- Book 1: Cold launch to strangers
- Book 2: Warm launch to proven buyers
- Book 3: Hot launch to engaged community

---

## Timeline Summary

| Timeframe | Activity | Goal |
|-----------|----------|------|
| Week -1 | Pre-launch posts (2) | Build anticipation |
| Week 0 | Launch announcement | Drive initial sales |
| Weeks 1-4 | Value posts + book mentions | Sustain momentum |
| Month 2 | Testimonials | Social proof |
| Month 3 | Process content | Build interest in series |
| Month 4 | Series announcement | Grow email list |
| Ongoing | 1 book post/week + 2-3 general posts/week | Authority building |

---

## Action Items Checklist

### Pre-Launch
- [ ] Update LinkedIn headline
- [ ] Update LinkedIn About section
- [ ] Add book to LinkedIn Featured section
- [ ] Create new Experience entry for "Author"
- [ ] Export Chapter 2 as PDF or blog post
- [ ] Schedule Post 1 (Journey)
- [ ] Schedule Post 2 (Sample chapter)

### Launch Day
- [ ] Publish to Leanpub
- [ ] Get final book URL
- [ ] Create cover image for post
- [ ] Post launch announcement
- [ ] Monitor for first 2 hours (reply to all comments)
- [ ] Share in relevant groups (Write the Docs, API communities)

### Post-Launch (Weeks 1-4)
- [ ] Create decision framework diagram (Week 1)
- [ ] Write war story post (Week 2)
- [ ] Create helpful framework post (Week 3)
- [ ] Write technical deep dive (Week 4)
- [ ] Reply to all comments within 24 hours
- [ ] Track which posts drive sales

### Long-Term (Months 2-4)
- [ ] Collect reader testimonials
- [ ] Write behind-the-scenes post
- [ ] Set up email list
- [ ] Announce series roadmap
- [ ] Start outlining Book 2

---

## Key Insights

> **Value-first marketing:** Give away 80% of insights for free. Readers think "if free content is this good, the book must be incredible."

> **War stories > achievements:** Sharing mistakes builds more credibility than listing accomplishments.

> **Engagement = visibility:** LinkedIn algorithm prioritizes posts with comments. Ask questions, reply to everyone.

> **Series thinking:** Book 1 is hard. Book 2 launches to warm audience. Book 3 to engaged community. Each compounds.

> **Professional not pushy:** "Here's a framework [link for full analysis]" beats "Buy my book" every time.

---

**Start with Pre-Launch Post 1 next Monday. Launch the following Tuesday.**

**Remember: This is Book 1 of a series. You're building an audience, not just selling one book.**
