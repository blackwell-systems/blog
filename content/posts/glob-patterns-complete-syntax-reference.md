---
title: "Glob Patterns: Complete Syntax Reference with Examples"
date: 2025-12-27
draft: false
series: ["glob-patterns"]
seriesOrder: 2
tags: ["shell", "unix", "patterns", "glob", "cli", "developer-tools", "terminal", "bash", "zsh", "reference", "syntax", "gitignore", "file-matching"]
categories: ["developer-tools", "tutorials"]
description: "Complete reference for glob pattern syntax - wildcards, character classes, brace expansion, and shell-specific features. Every pattern explained with examples."
summary: "Part 2: A comprehensive reference covering every glob pattern from basic wildcards to advanced features like brace expansion and extended globs. Learn the rules that apply everywhere."
---

In [Part 1](/posts/glob-patterns-invisible-abstraction/), we covered why glob patterns are everywhere but never taught explicitly. This is the reference you wish existed when you first encountered `**/*.js` or tried to write a `.gitignore`.

**This is your glob syntax cheat sheet.** Bookmark it. Use it when debugging patterns. Reference it when writing configs.

## Table of Contents

- [The Core Patterns (Universal)](#the-core-patterns-universal) - `*`, `**`, `?`, `[...]`, `[!...]`
- [Brace Expansion](#brace-expansion-shell-feature) - `{a,b}`, `{1..5}`
- [Extended Globs](#extended-globs-shell-specific) - `?(pattern)`, `*(pattern)`, `+(pattern)`, `@(a|b)`, `!(pattern)`
- [Dotfile Handling](#dotfile-handling-hidden-files) - Shell differences for hidden files
- [Tool-Specific Behavior](#tool-specific-behavior) - .gitignore, rsync, find
- [Common Edge Cases and Gotchas](#common-edge-cases-and-gotchas) - What breaks and why
- [Quick Reference Table](#quick-reference-table) - All patterns at a glance
- [Practice Exercises](#practice-exercises) - Test your understanding

## The Core Patterns (Universal)

These patterns work in all shells and most tools (git, rsync, build tools, etc.).

### `*` - Match Any Characters (Except Path Separator)

Matches zero or more characters, but **does not cross directory boundaries**.

```bash
# Matches files in current directory only
*.txt
# Matches: file.txt, readme.txt, .txt (yes, zero characters)
# Doesn't match: dir/file.txt, src/readme.txt

# In subdirectories
src/*.js
# Matches: src/app.js, src/index.js
# Doesn't match: src/lib/utils.js, app.js

# Multiple in one pattern
test-*.log.*
# Matches: test-app.log.1, test-api.log.gz
# Doesn't match: test.log, prod-app.log.1
```

**Important edge case:**
```bash
*
# Matches ALL files/dirs in current level
# Including hidden files in zsh (not bash by default)
```

### `**` - Match Directories Recursively

Matches any number of directories (including zero).

```bash
# All .js files anywhere under src/
src/**/*.js
# Matches: src/app.js, src/lib/utils.js, src/a/b/c/deep.js

# All files directly under src/ or any subdirectory
src/**
# Matches: src/app.js, src/lib/, src/lib/utils.js

# Prefix form - directories before a file
**/config.json
# Matches: config.json, src/config.json, src/nested/config.json

# Middle form - directories between paths
src/**/test/*.js
# Matches: src/test/app.test.js, src/lib/test/utils.test.js
# Doesn't match: src/lib/app.js
```

**Shell-specific behavior:**
```bash
# zsh: works by default
ls **/*.js

# bash: needs globstar enabled
shopt -s globstar
ls **/*.js

# Without globstar in bash, ** is treated as *
```

### `?` - Match Exactly One Character

Matches any single character (except path separator).

```bash
# Files with single-character variation
file?.txt
# Matches: file1.txt, fileA.txt, file_.txt
# Doesn't match: file.txt, file12.txt

# Multiple in pattern
test-??.log
# Matches: test-01.log, test-AB.log
# Doesn't match: test-1.log, test-123.log

# Combined with *
log-202?-*.txt
# Matches: log-2024-jan.txt, log-2025-dec.txt
# Doesn't match: log-24-jan.txt, log-2024.txt
```

### `[...]` - Match One Character From Set

Matches exactly one character from the bracketed set.

```bash
# Specific characters
file[123].txt
# Matches: file1.txt, file2.txt, file3.txt
# Doesn't match: file4.txt, file12.txt

# Ranges
log-[0-9].txt
# Matches: log-5.txt, log-9.txt
# Doesn't match: log-A.txt, log-10.txt

file[a-z].js
# Matches: filea.js, filez.js
# Doesn't match: fileA.js, file1.js

# Mixed ranges and characters
[a-zA-Z0-9_].txt
# Matches: a.txt, Z.txt, 5.txt, _.txt

# Multiple ranges
[0-9][0-9]-[a-z].log
# Matches: 01-a.log, 99-z.log
# Doesn't match: 1-a.log, 01-A.log
```

**Common ranges:**
- `[0-9]` - Digits
- `[a-z]` - Lowercase letters
- `[A-Z]` - Uppercase letters
- `[a-zA-Z]` - All letters
- `[a-zA-Z0-9]` - Alphanumeric

### `[!...]` - Match One Character NOT in Set

Negation - matches any character except those in the brackets.

```bash
# Exclude specific characters
[!.]*.txt
# Matches: file.txt, readme.txt
# Doesn't match: .hidden.txt, .gitignore.txt

# Exclude ranges
file[!0-9].txt
# Matches: fileA.txt, file_.txt
# Doesn't match: file5.txt

# Common pattern: exclude hidden files
[!.]*
# Matches: file.txt, src/
# Doesn't match: .git, .env
```

**Note:** Some tools use `[^...]` instead of `[!...]` for negation (both work in most shells).

## Brace Expansion (Shell Feature)

Not strictly glob, but commonly used with globs. Expands to multiple patterns.

```bash
# Multiple extensions
*.{js,ts,jsx}
# Expands to: *.js *.ts *.jsx
# Matches: app.js, index.ts, component.jsx

# Multiple directories
{src,test,lib}/**/*.js
# Expands to: src/**/*.js test/**/*.js lib/**/*.js

# Multiple filename parts
file-{1,2,3}.txt
# Expands to: file-1.txt file-2.txt file-3.txt

# Ranges (numeric)
file{1..5}.txt
# Expands to: file1.txt file2.txt file3.txt file4.txt file5.txt

# Ranges (alphabetic)
test{a..d}.js
# Expands to: testa.js testb.js testc.js testd.js

# Nested braces
{src,test}/{unit,integration}/*.js
# Expands to:
#   src/unit/*.js
#   src/integration/*.js
#   test/unit/*.js
#   test/integration/*.js
```

**Important:** Brace expansion happens **before** globbing. The shell expands `{a,b}` first, then applies glob patterns to each result.

## Extended Globs (Shell-Specific)

Available in bash (with `shopt -s extglob`) and zsh (enabled by default).

### `?(pattern)` - Match Zero or One Occurrence

```bash
# Optional prefix
file?(s).txt
# Matches: file.txt, files.txt

# Optional extension
readme?(.md)
# Matches: readme, readme.md
```

### `*(pattern)` - Match Zero or More Occurrences

```bash
# Zero or more digits
file*(0-9).txt
# Matches: file.txt, file1.txt, file123.txt

# Repeated pattern
+(test)-*.js
# Matches: test-app.js, testtest-app.js
```

### `+(pattern)` - Match One or More Occurrences

```bash
# At least one digit
file+(0-9).txt
# Matches: file1.txt, file123.txt
# Doesn't match: file.txt

# At least one occurrence
+(test)-app.js
# Matches: test-app.js, testtest-app.js
# Doesn't match: -app.js
```

### `@(pattern|pattern)` - Match Exactly One Pattern

```bash
# Match exact alternatives
@(README|LICENSE|CHANGELOG).*
# Matches: README.md, LICENSE.txt, CHANGELOG.md
# Doesn't match: CONTRIBUTING.md

# With extensions
file.@(js|ts|jsx|tsx)
# Matches: file.js, file.ts, file.jsx, file.tsx
# Doesn't match: file.json
```

### `!(pattern)` - Match Anything Except Pattern

```bash
# Exclude specific names
!(test|spec).js
# Matches: app.js, index.js
# Doesn't match: test.js, spec.js

# Exclude pattern
!(*.tmp)
# Matches: file.txt, data.json
# Doesn't match: temp.tmp, file.tmp
```

**Enable in bash:**
```bash
shopt -s extglob
```

**Available by default in zsh.**

## Dotfile Handling (Hidden Files)

Different shells have different defaults for matching dotfiles (files starting with `.`).

```bash
# Bash: * doesn't match dotfiles by default
ls *
# Matches: file.txt, readme.md
# Doesn't match: .gitignore, .env

# Explicitly include dotfiles in bash
ls .*
# Matches: .gitignore, .env
# Also matches: . and .. (special directories)

# Better pattern for dotfiles in bash
ls .[!.]*
# Matches: .gitignore, .env
# Doesn't match: . or ..

# Zsh: * matches dotfiles by default (configurable)
ls *
# Matches: file.txt, .gitignore, .env
```

**In .gitignore:**
```gitignore
# Matches hidden files explicitly
.*

# Exclude . and .. pattern
.*
!.gitignore

# Pattern without leading . matches non-hidden
*.log      # Doesn't match .hidden.log
```

## Tool-Specific Behavior

### .gitignore Patterns

Git has its own glob interpretation with special rules:

```gitignore
# Pattern without / matches anywhere in tree
node_modules
# Matches: node_modules/, src/node_modules/, lib/vendor/node_modules/

# Leading / anchors to repository root
/build
# Matches: build/ (in root only)
# Doesn't match: src/build/, lib/build/

# Trailing / matches directories only
logs/
# Matches: logs/ (directory)
# Doesn't match: logs (file)

# ** for recursive matching
dist/**/*.map
# Matches: dist/app.js.map, dist/src/lib/utils.js.map

# ! for negation (must come after matching pattern)
*.log
!important.log
# Ignores all .log files except important.log

# ** in middle of pattern
src/**/test/*.js
# Matches: src/test/app.test.js, src/lib/test/utils.test.js
```

**Pattern order matters in .gitignore:**
```gitignore
# Wrong - negation before match
!important.log
*.log
# Result: All .log files ignored (including important.log)

# Correct - negation after match
*.log
!important.log
# Result: All .log files ignored except important.log
```

### rsync Patterns

```bash
# Include/exclude patterns
rsync -av --exclude='*.tmp' --exclude='*.log' src/ dest/

# ** works in rsync
rsync -av --exclude='**/node_modules/' src/ dest/

# Complex patterns
rsync -av \
  --exclude='*.tmp' \
  --exclude='**/test/**' \
  --include='*.js' \
  --exclude='*' \
  src/ dest/
```

### find Command (Not Glob, But Similar)

```bash
# -name uses glob patterns
find . -name "*.js"
find . -name "test*.js"

# -path for full path matching
find . -path "*/test/*.js"

# -iname for case-insensitive
find . -iname "*.JS"
```

## Common Edge Cases and Gotchas

### 1. Empty Directories

```bash
# Pattern matching empty directory
ls dir/
# If dir/ is empty, returns nothing (not an error)

# Pattern matching non-existent path
ls nonexistent/*.js
# Bash: error (no match)
# Zsh: passes literal string 'nonexistent/*.js' to command
```

### 2. Literal Special Characters

```bash
# Match files with actual * in name
\*.txt
# Matches file named: *.txt

# Match files with [ in name
\[test\].txt
# Matches file named: [test].txt

# Or use quotes
'*.txt'
"*.txt"
# Literal asterisk, not glob
```

### 3. Case Sensitivity

```bash
# Case-sensitive by default
*.js
# Matches: file.js
# Doesn't match: file.JS, file.Js

# Case-insensitive in zsh (optional)
setopt nocaseglob
*.js
# Now matches: file.js, file.JS, file.Js

# Case-insensitive pattern
*.[jJ][sS]
# Matches: file.js, file.JS, file.Js, file.jS
```

### 4. Null Glob (No Matches)

```bash
# Bash default: literal string if no match
echo *.xyz
# Output: *.xyz (if no .xyz files exist)

# Zsh default: error if no match
echo *.xyz
# Error: no matches found

# Zsh option for bash-like behavior
setopt nonomatch
echo *.xyz
# Output: *.xyz (if no match)
```

## Quick Reference Table

| Pattern | Meaning | Example | Matches |
|---------|---------|---------|---------|
| `*` | Any characters (no `/`) | `*.js` | `file.js`, not `src/file.js` |
| `**` | Recursive directories | `src/**/*.js` | `src/a/b/c.js` |
| `?` | Exactly one character | `file?.js` | `file1.js`, `fileA.js` |
| `[abc]` | One char from set | `[0-9].txt` | `5.txt`, `9.txt` |
| `[!abc]` | One char NOT in set | `[!.]*.txt` | `file.txt`, not `.hidden.txt` |
| `{a,b}` | Alternatives (brace) | `*.{js,ts}` | `app.js`, `app.ts` |
| `?(pattern)` | Zero or one | `file?(s).txt` | `file.txt`, `files.txt` |
| `*(pattern)` | Zero or more | `file*([0-9]).txt` | `file.txt`, `file123.txt` |
| `+(pattern)` | One or more | `file+([0-9]).txt` | `file1.txt`, not `file.txt` |
| `@(a\|b)` | Exactly one of | `@(LICENSE\|README)` | `LICENSE`, `README` |
| `!(pattern)` | Anything except | `!(*.tmp)` | `file.js`, not `temp.tmp` |

## Practice Exercises

Test your understanding with these scenarios:

**Exercise 1:** Write patterns for:
```bash
# All JavaScript files in src/, recursively
# Answer: src/**/*.js

# All test files (ending in .test.js or .spec.js)
# Answer: *.{test,spec}.js or **/*.{test,spec}.js (recursive)

# All files except .log and .tmp
# Answer: !(*.log|*.tmp)  (with extglob)

# All files with 3-digit prefix (001-999)
# Answer: [0-9][0-9][0-9]-*
```

**Exercise 2:** What do these match?
```bash
src/*/test/*.js
# Matches: src/lib/test/app.test.js
# Doesn't match: src/test/app.test.js (too shallow)
#                 src/a/b/test/app.test.js (too deep)

**/[!.]*.js
# Matches: file.js, src/app.js
# Doesn't match: .hidden.js, src/.config.js

{src,test}/**/{unit,integration}/*.js
# Expands to 4 patterns, matches files in:
#   src/**/unit/*.js
#   src/**/integration/*.js
#   test/**/unit/*.js
#   test/**/integration/*.js
```

## What's Next

Now that you know the complete syntax, the next parts cover practical applications:

- **Part 3:** Mastering .gitignore patterns with real-world examples
- **Part 4:** Glob vs regex - when to use each and how they differ
- **Part 5:** Advanced patterns - negation strategies, performance, tool-specific extensions

**Bookmark this page.** You'll reference it when debugging patterns, writing configs, or explaining glob to teammates.
