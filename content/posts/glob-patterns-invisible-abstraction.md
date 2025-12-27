---
title: "Glob Patterns: The Invisible Abstraction Everyone Uses But Nobody Learns"
date: 2025-12-27
draft: true
tags: ["shell", "unix", "patterns", "glob", "regex", "cli", "developer-tools", "terminal", "bash", "zsh", "gitignore", "file-matching", "pattern-matching"]
categories: ["developer-tools", "tutorials"]
description: "You use glob patterns every day in .gitignore, package.json, and shell commands - but when did you actually learn glob syntax? Most developers never do."
summary: "Glob patterns are everywhere - .gitignore, shell wildcards, build configs - yet most developers learn them by accident through copy-paste. Here's why glob deserves explicit teaching."
---

You write `.gitignore` patterns. You use `*.js` in shell commands. You configure `"files": ["dist/**/*"]` in package.json.

But when did you actually **learn** glob syntax?

Most developers never do. They learn regex (for text matching), then encounter glob patterns in the wild and assume "it's probably like regex." They copy patterns from Stack Overflow, adjust until it works, and move on.

**Glob is the invisible abstraction.** It's everywhere, but nobody teaches it explicitly.

## The History: Glob Came First

Glob patterns appeared in Unix v1 (1971) for filename matching in the shell. Simple wildcards: `*`, `?`, `[...]`.

Regex came later - theoretically in 1968, but practically in the `ed` editor (1973) and `grep` (1974). More powerful, more complex, designed for text processing not filenames.

**For decades, developers learned in this order:**
1. Shell glob patterns (`ls *.txt`)
2. Later: Regex for text processing (`grep '^[A-Z]'`)

They were distinct tools for distinct jobs.

## The Shift: Regex Became Default

Somewhere around the 2000s-2010s, this reversed:

**Why developers learn regex first now:**
1. **Web forms** - Email validation, password rules (regex)
2. **Text editors** - VSCode search, find-and-replace (regex)
3. **Programming languages** - Every language has regex built-in
4. **Online tutorials** - Regex has more visibility, more teaching resources

**Why glob faded into the background:**
1. **IDEs replaced shell workflows** - File trees instead of `ls`, fuzzy search instead of glob patterns
2. **Tools abstract it away** - `cargo test` finds files, no glob needed
3. **Language-specific tooling** - npm, pytest, go handles file discovery
4. **Glob became invisible** - Present in configs, but not explicitly taught

## The Problem: Glob By Copy-Paste

Here's how most developers encounter glob today:

**Scenario 1: .gitignore**
```
# What does this actually mean?
*.log
build/
**/node_modules
dist/**/*.map
```

You copy this from a template. It works. You never learn the rules.

**Scenario 2: Shell wildcards**
```bash
rm temp-*
mv src/**/*.test.js tests/
```

You've seen `*` before. You guess `**` means "recursive." It works. You move on.

**Scenario 3: Build configs**
```json
{
  "files": ["dist/**/*.js", "!dist/**/*.test.js"]
}
```

You copy this from documentation. Adjust the paths. Ship it. Never learn what `!` actually does.

## What You're Actually Using

Glob patterns have specific rules, distinct from regex:

| Pattern | Meaning | Example |
|---------|---------|---------|
| `*` | Match any characters (except `/`) | `*.js` matches `file.js`, not `src/file.js` |
| `**` | Match directories recursively | `src/**/*.js` matches `src/a/b/c/file.js` |
| `?` | Match exactly one character | `file?.js` matches `file1.js`, `fileA.js` |
| `[abc]` | Match one character from set | `file[0-9].js` matches `file5.js` |
| `[!abc]` | Match one character NOT in set | `[!.]*.js` matches `file.js`, not `.hidden.js` |
| `{a,b}` | Match alternatives (brace expansion) | `*.{js,ts}` matches both `.js` and `.ts` files |

**Not regex:**
- No `^` or `$` anchors
- No `+` or `*` quantifiers (glob `*` is different)
- No `\d` or `\w` character classes
- No capture groups or backreferences

## Where Glob Lives Today

**You use glob syntax in:**

1. `.gitignore` and `.dockerignore`
2. Shell wildcards (`ls`, `rm`, `cp`)
3. `rsync --exclude` patterns
4. Build tool configs (webpack, vite, rollup)
5. Test frameworks (pytest, jest)
6. `package.json` "files" field
7. `.npmignore`, `.eslintignore`
8. Makefile targets
9. `fd` and `rg` file filtering
10. GitHub Actions `paths` filters

**Glob is invisible infrastructure.** You interact with it daily without realizing it.

## Why This Matters

**1. You waste time debugging patterns**

Copying `.gitignore` patterns without understanding leads to:
- "Why isn't `*.log` ignoring `logs/debug.log`?" (because `*` doesn't match `/`)
- "Why does `build/` ignore `dist/build/` too?" (trailing `/` has meaning)

**2. You miss powerful features**

Not knowing glob syntax means missing:
- `**` for recursive matching
- `{a,b}` brace expansion for multiple extensions
- `[!...]` negation for "everything except"

**3. You can't transfer knowledge**

Glob appears in so many tools. Learn it once, use it everywhere:
- Same syntax in `.gitignore`, `rsync`, shell commands, build tools
- Transferable knowledge across the entire Unix ecosystem

## The Case for Explicit Teaching

**Glob deserves explicit instruction because:**

1. **It's fundamental** - Older than regex, foundational to Unix
2. **It's everywhere** - More daily usage than regex for most developers
3. **It's distinct** - Not a subset of regex, has its own rules
4. **It's practical** - Immediate utility in shell, git, configs
5. **It's invisible** - Currently learned by accident, poorly

**The current state:** Developers learn regex explicitly (courses, tutorials, practice sites), then encounter glob by accident and guess the rules.

**The better state:** Teach glob as a first-class pattern system with clear rules, examples, and practice.

## What's Next

This is the start of a series on glob patterns:

- **Part 1:** (this post) Why glob is invisible and why it matters
- **Part 2:** Complete glob syntax reference with examples
- **Part 3:** Common glob patterns for `.gitignore`, shell, and build tools
- **Part 4:** Glob vs regex - when to use each

## Try This

Next time you write a `.gitignore` pattern or use `*` in the shell, pause and ask:

- Do I understand why this pattern works?
- Could I write this from scratch without copying?
- What would happen if I changed `*` to `**` or added `[...]`?

If you can't answer confidently, you're using glob by copy-paste. And you're not alone.

---

**What do you think?** Should glob be taught explicitly like regex, or is it fine as an invisible abstraction you learn by osmosis? Let me know.
