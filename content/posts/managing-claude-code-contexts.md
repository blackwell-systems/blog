---
title: "Managing Multiple Claude Code Contexts Without Going Insane"
date: 2025-12-02
draft: false
tags: ["dotclaude", "claude-code", "developer-tools", "productivity"]
categories: ["developer-tools", "tutorials"]
description: "Stop manually editing CLAUDE.md when switching between projects. dotclaude manages Claude Code configuration as version-controlled profiles that merge base practices with project-specific context."
summary: "I work on OSS projects, client work, and employer projects. Each needs different Claude Code configuration. Here's how I stopped manually editing CLAUDE.md every time I switched contexts."
---

I work on three types of projects: OSS contributions, client work, and my employer's codebase. Each needs different Claude Code configuration.

## The Problem

Claude Code reads configuration from `~/.claude/CLAUDE.md`. Every time I switched project types, I needed to manually edit this file:

- OSS projects: Permissive standards, GitHub workflows, public documentation
- Client work: Specific coding standards, their tech stack, compliance requirements
- Employer: Internal standards, company-specific tooling, private APIs

I tried keeping separate CLAUDE.md files and copying them over. That lasted about a week before I forgot which version was active and Claude started applying the wrong standards to the wrong projects.

The bigger issue: all three contexts share some universal practices. Things like "prefer explicit error handling" or "write clear commit messages" apply everywhere. But I was duplicating these across three different files.

## What I Tried First

**Separate Files**: `CLAUDE-oss.md`, `CLAUDE-client.md`, `CLAUDE-work.md`. Copy the right one to `~/.claude/CLAUDE.md` before starting work. This breaks the moment you forget to switch.

**Git Branches**: Keep CLAUDE.md in a git repository with branches per context. Clever until you realize you're now managing a whole repository just for configuration files. Also, merging changes to shared standards across branches is tedious.

**Manual Sections**: One big CLAUDE.md with sections labeled "OSS only" and "Client only". Claude reads the entire file regardless, so it sees conflicting instructions.

None of these scaled.

## The Solution

I built dotclaude to manage Claude configuration as layered profiles. One base configuration for universal practices, multiple profiles that add context-specific details.

```bash
# Switch to OSS work
dotclaude activate oss

# Switch to client work
dotclaude activate client-work
```

The base configuration lives in `base/CLAUDE.md` and contains practices that apply everywhere. Each profile lives in `profiles/[name]/` and adds only what's unique to that context.

When you activate a profile, dotclaude merges the base with the profile and writes the result to `~/.claude/CLAUDE.md`. Claude sees one coherent configuration file.

## How It Works

Directory structure:

```
~/.dotclaude/
├── base/
│   └── CLAUDE.md              # Universal practices
├── profiles/
│   ├── oss/
│   │   └── CLAUDE.md          # OSS-specific additions
│   ├── client-work/
│   │   └── CLAUDE.md          # Client standards
│   └── employer/
│       └── CLAUDE.md          # Company-specific context
```

The merge is additive. Base provides the foundation, profiles extend it:

**Base CLAUDE.md:**
```markdown
# Development Practices

- Prefer explicit error handling over silent failures
- Write clear commit messages
- Add comments for non-obvious logic
```

**Profile client-work/CLAUDE.md:**
```markdown
# Tech Stack

- React 18 with TypeScript
- Material-UI component library
- Jest for testing

# Compliance

- HIPAA-compliant logging (no PII in logs)
- All API calls must use company auth library
```

**Result in ~/.claude/CLAUDE.md:**
Both sections merged together. Claude gets universal practices plus client-specific context.

## Auto-Detection

You can drop a `.dotclaude` file in any project directory:

```bash
echo "client-work" > ~/projects/healthcare-app/.dotclaude
```

Now when you run Claude Code from that directory, dotclaude automatically activates the right profile. No manual switching needed.

## Integration with dotfiles

If you use [dotfiles](https://github.com/blackwell-systems/dotfiles), both systems coordinate automatically.

dotclaude manages Claude configuration (CLAUDE.md, agents, settings). dotfiles manages secrets (SSH keys, AWS credentials) and shell environment. Both respect the `/workspace` symlink for portable sessions across machines.

Switch contexts with dotclaude while secrets stay synced via dotfiles vault. Your OSS SSH key, client AWS credentials, and employer Git config all follow the active profile.

## Multi-Backend Support

Claude Code works with different backends. I use Anthropic Max for OSS work and AWS Bedrock for employer projects (SSO, cost controls, compliance).

dotclaude supports both:

```bash
# OSS work with Max subscription
claude

# Employer work with AWS Bedrock
claude-bedrock
```

Each profile can specify which backend to use. The wrapper scripts handle authentication automatically.

## Who This Is For

This works well if you:

- Work across multiple projects with different standards
- Use Claude Code regularly
- Want version-controlled configuration
- Need to switch contexts frequently
- Work on both OSS and proprietary codebases

If you only work on one type of project, manually editing CLAUDE.md is probably fine. This is for people juggling multiple contexts.

## Get Started

```bash
curl -fsSL \
  https://raw.githubusercontent.com/blackwell-systems/dotclaude/main/install.sh \
  | bash
```

Then create your first profile:

```bash
dotclaude create my-project
# → Creates profile with comprehensive 250+ line template
# → Includes tech stack, coding standards, best practices

dotclaude edit my-project
dotclaude activate my-project
```

The repository is at [github.com/blackwell-systems/dotclaude](https://github.com/blackwell-systems/dotclaude) with full documentation at [blackwell-systems.github.io/dotclaude](https://blackwell-systems.github.io/dotclaude).

## Why I'm Sharing This

I needed a better way to manage Claude contexts. If you're manually editing CLAUDE.md when you switch projects, you might find this useful.

The code is MIT licensed. Fork it, modify it, use what works. If you find issues or have suggestions, open an issue on GitHub.
