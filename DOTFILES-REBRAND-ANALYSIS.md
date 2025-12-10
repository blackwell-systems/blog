# Blog Dotfiles → Blackdot Rebrand Analysis

Analysis of all "dotfiles" references in blog posts to determine what should be updated to "blackdot".

## Summary

**Total files with references:** 7
- Blog posts: 4
- Config files: 2
- Documentation: 1

## Decision Framework

**CHANGE to "blackdot":**
- Project name (referring to the specific Blackwell Systems project)
- Commands (`dotfiles` command → `blackdot`)
- Repository URLs (github.com/.../dotfiles → .../blackdot)
- Environment variables (`DOTFILES_*` → `BLACKDOT_*`)
- Documentation URLs (except generic tag/keyword)

**KEEP as "dotfiles":**
- Generic concept references ("dotfiles framework", "most dotfiles")
- SEO keywords and tags (people search for "dotfiles")
- Generic references to configuration files concept
- References to OTHER people's dotfiles

---

## File-by-File Analysis

### 1. `/content/posts/dotfiles-for-ai-development.md`

**Status: Major updates needed**

#### Title & Metadata
- Line 2: `title: "A Dotfiles Framework Built for Claude Code"`
  - **CHANGE** to: `"Blackdot: A Development Framework Built for Claude Code"`
  - Reasoning: This is about YOUR specific product

- Line 5: `tags: ["dotfiles", ...]`
  - **KEEP** "dotfiles" as a tag for SEO
  - **ADD** "blackdot" as additional tag
  - Result: `tags: ["blackdot", "dotfiles", ...]`

- Line 7: `description: "Modular dotfiles framework with..."`
  - **CHANGE** to: `"Blackdot: Modular development framework with..."`

#### Body Content

- Line 17: "treat dotfiles as a **framework**"
  - **CHANGE** to: "treat configuration as a **framework**" OR "Blackdot is a **framework**"
  - Context: Talking about the specific project

- Line 47: "That solved Claude portability. But while building this, I needed:"
  - Paragraph is fine, generic context

- Line 64-73: Command examples `dotfiles features`
  - **CHANGE ALL** to `blackdot features`
  - Lines: 64, 67, 68, 71, 72, 73

- Line 130: `.dotfiles-hooks/` directory
  - **CHANGE** to: `.blackdot-hooks/`

- Line 133-136: Command examples `dotfiles hook`
  - **CHANGE ALL** to `blackdot hook`

- Line 146: `export DOTFILES_VAULT_BACKEND=bitwarden`
  - **CHANGE** to: `export BLACKDOT_VAULT_BACKEND=bitwarden`

- Line 148: `.dotfiles.json`
  - **CHANGE** to: `.blackdot.json`

- Line 149-156: Command examples `dotfiles config`
  - **CHANGE ALL** to `blackdot config`

- Line 156: `~/.config/dotfiles/machine.json`
  - **CHANGE** to: `~/.config/blackdot/machine.json`

- Line 228-234: Command examples `dotfiles setup`, `dotfiles vault`
  - **CHANGE ALL** to `blackdot setup`, `blackdot vault`

- Line 254: URL `https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh`
  - **CHANGE** to: `blackwell-systems/blackdot`

- Line 255: `dotfiles setup`
  - **CHANGE** to: `blackdot setup`

- Line 287: `dotfiles setup`
  - **CHANGE** to: `blackdot setup`

- Line 327: "**Most dotfiles:** Configuration files"
  - **KEEP** - Generic reference to other people's dotfiles

- Line 329: "**This framework:**"
  - Can change to "**Blackdot:**" for clarity

- Line 342-349: "dotclaude and dotfiles are independent"
  - **CHANGE "dotfiles"** to "blackdot" (lines 344, 347, 349)
  - This is about YOUR specific projects

- Line 355: "Want a modular dotfiles system"
  - **KEEP** - Generic concept ("a dotfiles system")

- Line 370: `ghcr.io/blackwell-systems/dotfiles-lite`
  - **CHANGE** to: `blackdot-lite`

- Line 371-373: Command examples `dotfiles status`, `dotfiles doctor`
  - **CHANGE** to `blackdot`

- Line 382-389: URLs and commands
  - **CHANGE** all `dotfiles` → `blackdot`

- Line 394-401: Command examples
  - **CHANGE** all `dotfiles` → `blackdot`

- Line 403: `blackwell-systems.github.io/dotfiles`
  - **CHANGE** to: `/blackdot`

- Line 407-410: URLs
  - **CHANGE** all references

**Total changes needed:** ~40+ instances

---

### 2. `/content/posts/managing-claude-code-contexts.md`

**Status: Minimal updates (good separation already)**

- Line 108: "If you use [dotfiles](https://github.com/blackwell-systems/dotfiles)"
  - **CHANGE URL** to: `blackwell-systems/blackdot`
  - **CHANGE TEXT** to: "If you use [blackdot](URL)"

- Line 110: "dotclaude manages... dotfiles manages secrets"
  - **CHANGE** "dotfiles" to "blackdot"
  - Line 110: "dotclaude manages Claude configuration. blackdot manages secrets"

- Line 112: "Switch contexts with dotclaude while secrets stay synced via dotfiles vault"
  - **CHANGE** to: "...via blackdot vault"

**Total changes needed:** 4 instances

---

### 3. `/content/posts/zsh-hooks-guide.md`

**Status: Mixed - some generic, some specific**

- Line 5: `tags: ["zsh", ..., "dotfiles", "precmd", ...]`
  - **KEEP** "dotfiles" tag for SEO
  - **ADD** "blackdot" as additional tag

- Line 446: "see the [dotfiles hook system](URL)"
  - **CHANGE** text to: "[blackdot hook system](URL)"
  - **CHANGE URL** to: `blackwell-systems/blackdot`

- Line 450-453: Command examples `dotfiles hook validate`
  - **CHANGE** to `blackdot hook`

- Line 457: `~/.config/dotfiles/hooks/`
  - **CHANGE** to: `~/.config/blackdot/hooks/`

- Line 515: "see the [dotfiles hook system documentation]"
  - **CHANGE** to: "[blackdot hook system documentation]"
  - **UPDATE URL**

- Line 601: Link to dotfiles hook system
  - **CHANGE** text and URL

**Total changes needed:** 8 instances

---

### 4. `/content/posts/vaultmux-vault-abstraction-go.md`

**Status: Historical context - careful updates needed**

- Line 5: `tags: [..., "dotfiles", ...]`
  - **KEEP** for SEO

- Line 13: "I started with Bitwarden-only shell scripts to restore secrets for my dotfiles"
  - **Context dependent**: This is historical narrative
  - **Option 1:** KEEP as-is (historically accurate)
  - **Option 2:** "...for my configuration management"
  - **Recommendation:** KEEP - accurate historical context

- Line 21: "My dotfiles began with hardcoded Bitwarden calls"
  - **KEEP** - Historical context, describes the evolution

- Line 60: URL to `_interface.md`
  - **CHANGE URL** to: `blackwell-systems/blackdot`

- Lines 66-67, 70: `DOTFILES_VAULT_BACKEND`
  - **CHANGE** to: `BLACKDOT_VAULT_BACKEND`

- Line 86: `$DOTFILES_DIR`
  - **CHANGE** to: `$BLACKDOT_DIR`

- Lines 102-107: `DOTFILES_VAULT_BACKEND` and commands `dotfiles vault restore`
  - **CHANGE ENV VAR** to: `BLACKDOT_VAULT_BACKEND`
  - **CHANGE COMMANDS** to: `blackdot vault restore`

- Line 125: `DOTFILES_VAULT_PREFIX`
  - **CHANGE** to: `BLACKDOT_VAULT_PREFIX`

- Line 296: "My dotfiles now use both:"
  - **CHANGE** to: "Blackdot now uses both:" OR "My framework now uses both:"

- Line 394: URL to dotfiles repo
  - **CHANGE** to: `blackwell-systems/blackdot`

**Total changes needed:** 11 instances

---

### 5. `/content/about.md`

**Status: Update project references**

- Line 13: `**[dotfiles](URL)** - Modular dotfiles framework`
  - **CHANGE** to: `**[blackdot](URL)** - Modular development framework`
  - **UPDATE URL** to: `blackwell-systems/blackdot`

- Line 23: `- **Dotfiles & Configuration**`
  - **KEEP** as category name (generic concept)
  - OR **CHANGE** to: `- **Configuration & Dev Environment**`

- Line 24: Reference to dotclaude and dotfiles
  - **CHANGE** "dotfiles" to "blackdot" where it refers to your project

- Line 30: Issues link
  - **UPDATE URL** to: `blackwell-systems/blackdot`

- Line 139: Link to dotfiles repo
  - **CHANGE** to: `blackwell-systems/blackdot`

**Total changes needed:** 5 instances

---

### 6. `/README.md`

**Status: Update project references**

- Line 11: "Technical writing on developer tools, AI workflows, and dotfiles"
  - **KEEP** "dotfiles" - generic concept
  - OR add: "...and dotfiles (including blackdot)"

- Line 23: "- **Dotfiles & Configuration**"
  - **KEEP** as category (or update to "Configuration & Dev Environment")

- Line 24: "Deep dives into dotclaude, dotfiles"
  - **CHANGE** "dotfiles" to "blackdot"

- Line 139: Link
  - **CHANGE URL** to: `blackwell-systems/blackdot`

**Total changes needed:** 2-3 instances

---

### 7. `/hugo.toml`

**Status: Update keywords/metadata**

- Line 14: `keywords = ['dotfiles', ...]`
  - **KEEP** 'dotfiles' for SEO
  - **ADD** 'blackdot' to keywords list
  - Result: `keywords = ['blackdot', 'dotfiles', ...]`

**Total changes needed:** 1 instance (addition)

---

## Recommended Changes Summary

### High Priority (Functionality Breaking)
1. **Commands**: All `dotfiles` command examples → `blackdot`
2. **URLs**: All repo URLs → `/blackdot`
3. **Env vars**: `DOTFILES_*` → `BLACKDOT_*`
4. **Paths**: `.config/dotfiles`, `.dotfiles-hooks` → `blackdot` equivalents

### Medium Priority (Branding)
5. **Project name references**: "dotfiles framework" → "blackdot" (when referring to YOUR project)
6. **Documentation links**: Update all doc URLs

### Low Priority (Keep for SEO/Context)
7. **Tags**: Keep "dotfiles" tag, add "blackdot"
8. **Generic references**: "most dotfiles", "a dotfiles system" - KEEP
9. **Historical narrative**: "My dotfiles began..." - KEEP or note it's now blackdot

---

## Implementation Plan

### Phase 1: Critical Updates (Blog Post 1 - dotfiles-for-ai-development.md)
- Update all command examples
- Update all URLs and links
- Update env vars and paths
- Update project-specific references
- Keep generic "dotfiles" concept references

### Phase 2: Other Posts
- Update references in other 3 blog posts
- Update about.md
- Update README.md

### Phase 3: Metadata
- Add "blackdot" to keywords
- Add "blackdot" to tags (keep "dotfiles" too)

---

## Special Considerations

### SEO Impact
- "dotfiles" is a highly-searched term
- Keep it in tags, keywords, and generic references
- Use "blackdot" for specific project references
- This gives you BOTH search visibility

### Historical Accuracy
- Posts like vaultmux describe evolution from shell scripts
- "My dotfiles began with..." is historically accurate
- Could add footnote: "Now called blackdot"
- OR just update casually: "My configuration framework began..."

### Blog Post Titles
- Current: "A Dotfiles Framework Built for Claude Code"
- Options:
  1. "Blackdot: A Framework Built for Claude Code" (clear branding)
  2. "A Development Framework for Claude Code" (generic, loses brand)
  3. Current title + subtitle clarifying it's now blackdot
- **Recommendation:** Update to include "Blackdot" in title for clarity

---

*Analysis complete. Ready to implement selective replacements.*
