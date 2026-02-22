---
title: "Stop Committing PDFs: Use GitHub Releases as Your Library Backend"
date: 2026-02-22
draft: false
tags: ["git", "github", "pdf", "documentation", "storage", "git-lfs", "releases", "library", "tools", "workflow", "migration", "shelfctl"]
categories: ["tools", "git"]
description: "Git history bloats forever when you commit PDFs. Git LFS costs money. Here's how to use GitHub Release assets as free, CDN-backed storage for your document library while keeping git repos lightweight."
summary: "Every PDF committed to git history stays there forever, bloating clones even after deletion. Git LFS adds cost and friction. GitHub Release assets offer a better approach: free CDN-backed storage with on-demand downloads, lightweight repos, and built-in migration tools."
---

You know that moment when you clone a repo and it takes forever because someone committed PDFs three years ago? Or when you discover your "books" repo is 2GB even though you deleted half the files last month?

Yeah. Git never forgets.

## The Pain

Here's what happens when you commit PDFs to git:

1. You add `machine-learning.pdf` (45MB) and commit it
2. Later you realize it's the wrong version and delete it
3. You add the correct version and commit again
4. Your repo looks clean, but `git clone` still downloads both PDFs
5. Forever

Every PDF that ever touched your git history stays there. Even after you delete the file, run BFG Repo-Cleaner, and sacrifice a rubber duck to the git gods. The weight never leaves. Every clone, every fetch, every new contributor pays the price.

If you've been using GitHub for personal document storage, you've probably hit one of these walls:

- GitHub's 100MB file size limit (hard stop)
- Repo clones taking minutes for a "simple" books collection
- That awkward moment when a collaborator asks why a 50-file repo is 3GB

## Why the Usual Fixes Suck

**"Just delete the files!"**

Doesn't work. Git history remembers everything. Your repo stays bloated. Clones stay slow.

**"Use git filter-repo or BFG!"**

Sure, if you want to rewrite history, force-push, and break every clone. Plus you'll do it again next month when you add more PDFs. Not a workflow, it's a fight.

**"Switch to Git LFS!"**

Now you're paying for storage and bandwidth. GitHub Free gives you 1GB storage and 1GB/month bandwidth with LFS. After that, it's $5/month per 50GB data pack. For a personal library. And you still need special tooling, migration effort, and every clone needs the LFS client.

Also, Git LFS doesn't actually solve the "download on-demand" problem. You still fetch a pointer, then fetch the file. It's better than raw commits, but it's not free, and it's not simple.

## The Trick: Releases as Object Storage

Here's the escape hatch: GitHub Release assets are free, CDN-backed, and support per-file HTTP downloads. They're designed for distributing software releases, but there's nothing stopping you from using them as a document backend.

The insight is simple:

- Store PDFs/EPUBs as **Release assets** (outside git history entirely)
- Store metadata as **a tiny YAML file** (inside git)
- Download individual files on-demand from GitHub's CDN

Your git repo stays lightweight. Your documents get free, reliable hosting. You only download what you actually open.

```
shelf-programming/
├── catalog.yml           # 5KB, tracked in git
├── README.md             # 2KB, tracked in git
└── releases/library/     # Exists on GitHub, not in git
    ├── sicp.pdf          # 6MB, release asset
    ├── taocp-vol1.pdf    # 12MB, release asset
    └── gopl.pdf          # 4MB, release asset
```

The entire git repo is 7KB. The library is 22MB. Cloning takes 0.2 seconds. Opening a book downloads only that book.

## The Workflow

This is what shelfctl implements:

**One shelf repo per topic:**

```bash
shelf-programming
shelf-history
shelf-research-papers
```

Each shelf is a normal GitHub repo. Public or private, your choice. No special setup.

**catalog.yml for metadata:**

```yaml
- id: sicp
  title: "Structure and Interpretation of Computer Programs"
  author: "Abelson & Sussman"
  tags: ["lisp", "cs", "textbook"]
  format: pdf
  checksum:
    sha256: a1b2c3d4...
  source:
    type: github_release
    release: library
    asset: sicp.pdf
```

Searchable, greppable, versionable. All the benefits of git for metadata, none of the bloat for files.

**On-demand download with `shelfctl open`:**

```bash
$ shelfctl open sicp
Downloading sicp.pdf (6.2 MB)...
[████████████████████] 100%
Opening sicp.pdf
```

First time downloads from GitHub's CDN. Subsequent opens use your local cache. On another machine? Same command fetches it again on-demand.

You can have a 100GB library across multiple shelves, but if you only read 10 books, you only download 800MB.

## Migration: The Killer Feature

The real value isn't starting fresh. It's fixing the mess you already have.

If you've got PDFs scattered across repos, committed and re-committed, tangled in git history, here's how you escape:

**1. Scan your existing repo:**

```bash
shelfctl migrate scan --source you/old-books-repo > queue.txt
```

This outputs a list of every PDF/EPUB/MOBI in the repo, with suggested IDs and metadata.

**2. Create organized shelves:**

```bash
# Create a programming shelf (private repo by default)
shelfctl init --repo shelf-programming --create-repo --create-release

# Create a history shelf
shelfctl init --repo shelf-history --create-repo --create-release

# Or make a public shelf
shelfctl init --repo shelf-public --create-repo --create-release --private=false
```

The `--create-repo` flag creates the GitHub repo. `--create-release` sets up the initial release tag. Both are automated.

**3. Edit queue.txt to assign shelves:**

The scan produces lines like:

```
path/to/book.pdf → suggested-id → programming
another-book.pdf → another-id → history
```

You can edit the shelf assignments, IDs, or add metadata. Then:

**4. Migrate in batches:**

```bash
shelfctl migrate batch queue.txt --n 10 --continue
```

This will:

- Download each file from the old repo's git history
- Upload it as a release asset in the target shelf
- Create catalog entries with checksums
- Track progress so you can resume if interrupted

The `--n 10` flag processes 10 books, then stops (to avoid rate limits). The `--continue` flag lets you resume where you left off.

**5. Open books from your new shelves:**

```bash
shelfctl open sicp  # Instant, no clone required
```

No more cloning bloated repos. No more waiting for git to decompress objects. Just download the file you want from the CDN and open it.

## Real-World Migration Example

Let's say you have `old-books-repo` with 200 PDFs committed over 3 years. The repo is 1.2GB. Clones take 90 seconds. You want to split it into topic-based shelves.

```bash
# 1. Scan the old repo
shelfctl migrate scan --source you/old-books-repo > queue.txt

# 2. Create three new shelves
shelfctl init --repo shelf-programming --create-repo --create-release
shelfctl init --repo shelf-history --create-repo --create-release
shelfctl init --repo shelf-fiction --create-repo --create-release

# 3. Edit queue.txt to assign books to shelves
# (Change "programming" to "history" or "fiction" as needed)

# 4. Migrate in batches of 20
shelfctl migrate batch queue.txt --n 20 --continue
# Run this multiple times until all books are migrated

# 5. Archive the old repo
# (Don't delete it yet - keep it as backup for a few weeks)
```

Now:

- `shelf-programming` is 15KB (git repo) + 450MB (assets)
- `shelf-history` is 12KB (git repo) + 300MB (assets)
- `shelf-fiction` is 18KB (git repo) + 500MB (assets)

Clones are instant. You can browse metadata without downloading anything. Books are opened on-demand.

## When Not to Use This

This approach is great for personal document libraries, but it's not universal. Don't use Release assets if:

**You need git versioning of binaries:**

If you're editing PDFs and want to track changes, commit them. Git is designed for versioning. Use LFS if needed, but keep them in git history.

**You need collaborative editing:**

GitHub Releases are immutable once published. If multiple people need to edit and re-upload versions of the same document, you want git commits (or a different tool entirely).

**You're building a software project with documentation:**

If you're shipping a project and the PDFs are part of the release artifacts (like a manual), commit them or use LFS. Don't fight your build system.

**You want GitHub-native search:**

Release assets don't show up in GitHub code search. The catalog is searchable, but not the PDF contents. If you need full-text search across documents, you'll need external tooling.

**You need fine-grained access control per file:**

GitHub repo permissions are all-or-nothing. If you need per-file permissions, you're better off with a dedicated document management system.

The use case here is narrow: personal or small-team document libraries where you want simple, free, reliable storage without git history bloat.

## Why This Works

GitHub doesn't charge for Release assets (within reasonable use). They're served from a CDN. They support HTTP range requests (partial downloads). They're as permanent as the repo itself.

This isn't a hack. GitHub designed Releases for distributing files. The only twist is using them for books instead of binaries.

Metadata stays in git because that's what git is good at: small text files that change over time. You get version history, diffs, and search for free.

The split is clean:

- **Git** = small, structured, versionable (catalog.yml)
- **Releases** = large, immutable, downloadable (PDFs)

Each does what it's designed for. No fighting the tools.

## Try It

shelfctl implements this entire workflow. It's open source, written in Go, and takes 2 minutes to set up.

**Install:**

```bash
# Download from releases page, or:
go install github.com/blackwell-systems/shelfctl/cmd/shelfctl@latest
```

**Authenticate:**

```bash
export GITHUB_TOKEN=$(gh auth token)  # If you use GitHub CLI
# Or create a token at https://github.com/settings/tokens
```

**Create your first shelf:**

```bash
shelfctl init --repo shelf-books --create-repo --create-release
```

**Add a book:**

```bash
shelfctl shelve ~/Downloads/book.pdf --shelf books --title "My Book"
```

**Open it later:**

```bash
shelfctl open my-book
```

Done. Your library lives in GitHub Releases. Your git history stays clean. Your clones stay fast.

---

**Project:** https://github.com/blackwell-systems/shelfctl
**Docs:** https://blackwell-systems.github.io/shelfctl/
**Tutorial:** https://blackwell-systems.github.io/shelfctl/TUTORIAL/

If this solves a problem you've been fighting, star the repo or try it out. If you hit issues, file them. If you want to contribute, see CONTRIBUTING.md.

---

*Meet Shelby, the shelfctl mascot. Shelby is a terminal wearing a bookshelf like a sweater, because why not.*
