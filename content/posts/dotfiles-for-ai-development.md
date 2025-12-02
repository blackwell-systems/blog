---
title: "Why I Built Another Dotfiles System"
date: 2025-12-02
draft: false
tags: ["dotfiles", "claude-code", "development-environment"]
---

There are hundreds of dotfiles repositories on GitHub. I built another one anyway.

## The Problem

I use Claude Code across three machines: a Mac laptop, a Lima VM for testing, and occasionally WSL2. Every dotfiles solution I tried had the same issue - Claude Code sessions wouldn't follow me between machines.

Claude stores sessions based on your working directory path. If you're in `/Users/me/projects/api` on Mac and `/home/me/projects/api` on Linux, those are different sessions. Different paths means lost conversation history when you switch machines.

Most solutions suggest syncing `~/.claude` between machines. That works until you realize your home directory path is different on each platform. The session folder names encode the full path, so syncing the directory doesn't help.

After reading [this article about migrating Claude Code sessions](https://www.vincentschmalbach.com/migrate-claude-code-sessions-to-a-new-computer/), I realized there was a better way.

## The Solution

Create a symlink at the root level that's identical across all platforms:

```bash
/workspace -> ~/workspace
```

Now `/workspace/projects/api` resolves correctly on every machine, but Claude sees the same absolute path. Same path means same session folder means your conversation continues.

This required bootstrap scripts that work across macOS, several Linux distros, and WSL2. I also needed them to handle secrets (SSH keys, AWS credentials) without storing them in git.

## The Vault Problem

Most dotfiles either ignore secrets or have you encrypt them in the repository. Both options are bad.

Ignoring secrets means manually copying SSH keys between machines. Encrypting secrets in git means your private keys are in version control, even if encrypted.

I already use Bitwarden for passwords. Why not store SSH keys there too?

The vault system in this repo supports three backends: Bitwarden, 1Password, and pass. Your SSH keys, AWS credentials, and git config go in whichever vault you already use. The `dotfiles vault restore` command pulls them down on new machines.

No keys in git. No manual copying. It just works.

## What Makes This Different

Most dotfiles are configuration files with an install script. This is configuration files plus:

- Multi-vault backend for secrets (unified API across Bitwarden/1Password/pass)
- Health checker that validates everything and can auto-fix issues
- Drift detection that warns before overwriting unsync'd changes
- Schema validation for SSH keys (correct permissions, key formats)
- Machine-specific templates (one config file becomes many with variables)
- 80+ unit tests
- Claude Code session portability via `/workspace` symlink

The shell configuration is also more maintainable than most. Instead of one 1000-line `.zshrc`, there are 10 modules in `zsh.d/`. Each module handles one thing: environment variables, aliases, AWS helpers, git shortcuts, etc. You can disable modules per-machine by symlinking to `.skip` files.

## Integration with dotclaude

If you use [dotclaude](https://github.com/blackwell-systems/dotclaude) for profile management, both systems coordinate automatically.

dotclaude manages your Claude configuration (CLAUDE.md files, agents, settings). dotfiles manages secrets and shell environment. They both respect the `/workspace` symlink for portable sessions.

You can switch between work contexts (OSS, client, employer) with dotclaude while secrets stay synced via dotfiles vault. No manual coordination needed.

## Who This Is For

This repo works best if you:

- Use Claude Code regularly across multiple machines
- Already use a password manager (Bitwarden, 1Password, or pass)
- Want secrets synced automatically but not in git
- Need health validation and drift detection
- Work on macOS, Linux, or WSL2 (or multiple)

If you don't use Claude Code, most of this still works. The vault system, health checks, and modular shell config are useful regardless. The `/workspace` portability is mainly for Claude sessions.

## Get Started

The installer is interactive by default:

```bash
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh -o install.sh && bash install.sh --interactive
```

It detects your platform, finds available vault CLIs, and prompts for choices. Takes about 5 minutes on a fresh machine.

If you want to inspect before running, the repository is at [github.com/blackwell-systems/dotfiles](https://github.com/blackwell-systems/dotfiles) with full documentation at [blackwell-systems.github.io/dotfiles](https://blackwell-systems.github.io/dotfiles).

## Why I'm Sharing This

I needed this for my own workflow. Maybe you need it too.

The code is MIT licensed. Fork it, modify it, use what works for you. If you find issues or have suggestions, open an issue on GitHub.
