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
```gitignore
# What does this actually mean?
*.log
build/
**/node_modules
dist/**/*.map
```

You copy this from a template. It works. You never learn the rules.

**Then it breaks:**
- Why doesn't `*.log` ignore `logs/debug.log`? (because `*` doesn't cross directory boundaries)
- Why does `node_modules/` ignore `src/vendor/node_modules/`? (because trailing `/` means "directory anywhere")
- What's the difference between `**/foo` and `foo/**`? (you have no idea)

**Scenario 2: Shell wildcards**
```bash
rm temp-*
mv src/**/*.test.js tests/
```

You've seen `*` before. You guess `**` means "recursive." It works. You move on.

**Until it doesn't:**
```bash
rm *.tmp
# Works in current dir

rm **/*.tmp  
# Why does this work in zsh but not bash?
# (bash needs `shopt -s globstar`)
```

**Scenario 3: Build configs**
```json
{
  "files": ["dist/**/*.js", "!dist/**/*.test.js"]
}
```

You copy this from documentation. Adjust the paths. Ship it. Never learn what `!` actually does.

**Then you need to modify it:**
- How do I exclude multiple patterns?
- Can I use `{js,ts}` here?
- Why isn't `[!.]*.js` working?

You're stuck copy-pasting variations until something works.

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

## Common Mistakes (Because Nobody Teaches This)

**Mistake 1: Using regex syntax in glob**
```bash
# Doesn't work - no + quantifier in glob
ls file*.+js

# Glob doesn't have character classes
ls \d{3}-report.txt

# What you actually need
ls file*.js        # * already means "zero or more"
ls [0-9][0-9][0-9]-report.txt
```

**Mistake 2: Expecting `*` to be recursive**
```gitignore
# Only ignores *.log in root directory
*.log

# Ignores *.log in all subdirectories
**/*.log

# Ignores *.log everywhere (root + subdirs)
*.log
**/*.log
```

**Mistake 3: Misunderstanding trailing `/`**
```gitignore
# Matches file OR directory named "build"
build

# Only matches directory named "build"
build/
```

**Mistake 4: Forgetting shell-specific behavior**
```bash
# zsh: recursive glob works by default
ls **/*.js

# bash: needs globstar enabled first
shopt -s globstar
ls **/*.js
```

**Mistake 5: Not knowing brace expansion**
```bash
# Verbose
cp file.js backup/
cp file.ts backup/
cp file.jsx backup/

# Concise
cp *.{js,ts,jsx} backup/
```

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

## Start Learning Glob Today

Here's a practical path to learn glob explicitly:

**1. Learn the core patterns (5 minutes)**

Practice in your shell right now:

```bash
# List all .js files in current directory
ls *.js

# List all .js files recursively
ls **/*.js

# List files starting with "test" and one more character
ls test?.js

# List files with numbers
ls file[0-9].txt

# List multiple extensions
ls *.{js,ts,jsx}
```

**2. Fix your .gitignore (10 minutes)**

Open your `.gitignore` and understand every line:

```gitignore
# What these actually mean:
*.log          # All .log files in root only
**/*.log       # All .log files in any subdirectory
logs/          # Directory named "logs" anywhere
/logs/         # Only logs/ in root directory
*.log          # Ignore pattern
!important.log # But keep this one (negation)
```

**3. Practice with real scenarios**

Try these exercises:

```bash
# Find all test files
ls **/*test.js

# Copy all source files to backup
cp src/**/*.{js,ts} backup/

# Remove all temp files except one
rm temp-*.txt
# (How would you exclude temp-important.txt?)

# Create .gitignore to ignore:
# - All .log files everywhere
# - node_modules directory anywhere
# - dist/ but only in root
# - All .map files in dist/ recursively
```

**4. Build intuition through experimentation**

Create a test directory and try patterns:

```bash
mkdir -p test/{a,b,c}/{1,2,3}
touch test/{a,b,c}/{1,2,3}/file.txt
touch test/a/1/special.log

# Now experiment:
ls test/*/1/*.txt        # What matches?
ls test/**/file.txt      # What's different?
ls test/a/*/*.{txt,log}  # How does this work?
```

## Try This

Next time you write a `.gitignore` pattern or use `*` in the shell, pause and ask:

- Do I understand **why** this pattern works?
- Could I write this from scratch without copying?
- What would happen if I changed `*` to `**` or added `[...]`?

If you can't answer confidently, you're using glob by copy-paste. And you're not alone - but now you know how to change that.

## What's Next

This is Part 1 of a series on glob patterns. Coming soon:

- **Part 2:** Complete glob syntax reference with edge cases
- **Part 3:** Mastering .gitignore patterns
- **Part 4:** Glob vs regex: when to use each
- **Part 5:** Advanced glob: negation, ranges, and tool-specific extensions
