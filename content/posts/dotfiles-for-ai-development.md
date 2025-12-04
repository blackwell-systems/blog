---
title: "Stop Losing Your Claude Conversations When Switching Computers"
date: 2025-12-02
draft: false
tags: ["dotfiles", "claude-code", "development-environment"]
description: "The first dotfiles system built for AI-assisted development. Portable Claude Code sessions across machines, multi-vault secret management, and self-healing configuration."
summary: "Start on Mac, continue on Linux, keep your conversation. The first dotfiles system designed for AI-assisted development with portable Claude Code sessions across machines."
---

Start on Mac, continue on Linux, same conversation.

That's the promise. Here's how it works.

## The Problem

I use Claude Code across three machines: a Mac laptop, a Lima VM for testing, and occasionally WSL2. Every dotfiles solution I tried had the same issue - Claude Code sessions wouldn't follow me between machines.

Claude stores sessions based on your working directory path. If you're in `/Users/me/projects/api` on Mac and `/home/me/projects/api` on Linux, those are different sessions. Different paths means lost conversation history when you switch machines.

Most solutions suggest syncing `~/.claude` between machines. That works until you realize your home directory path is different on each platform. The session folder names encode the full path, so syncing the directory doesn't help.

I found [this article about migrating Claude Code sessions](https://www.vincentschmalbach.com/migrate-claude-code-sessions-to-a-new-computer/) and started writing scripts to rewrite all my paths according to the approach outlined there. After a few hours of path manipulation logic, I realized there was a better way.

## The Solution

Create a symlink at the root level that's identical across all platforms:

```bash
/workspace -> ~/workspace
```

Now `/workspace/projects/api` resolves correctly on every machine, but Claude sees the same absolute path. Same path means same session folder means your conversation continues.

Here's what this looks like in practice:

```bash
# On Mac, working in a project
cd /workspace/my-api && claude
# ... work for an hour, Claude learns your codebase ...
# exit

# Later, on Linux VM - SAME conversation continues
cd /workspace/my-api && claude
# Full history intact. No sync. No export. Just works.
```

## What This Looks Like In Practice

Here's the actual setup flow when you run it on a machine with existing credentials:

```console
$ curl -fsSL ... | bash && dotfiles setup

Installing Homebrew...
Installing packages...
Linking shell config (.zshrc, .p10k.zsh)...
Created /workspace symlink for portable Claude sessions

═══════════════════════════════════════════════════════════════
                        Setup Wizard
═══════════════════════════════════════════════════════════════

STEP 3: Vault Configuration
────────────────────────────────────────────────────────────────
Available vault backends:
  1) bitwarden  ← detected
  2) 1password  ← detected
  3) pass
  4) Skip (configure manually)

Select vault backend [1]: 1

Vault configured (bitwarden)
Vault unlocked

STEP 4: Secrets Management
────────────────────────────────────────────────────────────────
Scanning secrets...

  Local only (not in vault):
    • SSH-GitHub-Enterprise → ~/.ssh/id_ed25519_enterprise_ghub
    • SSH-GitHub-Personal → ~/.ssh/id_ed25519_personal
    • AWS-Config → ~/.aws/config
    • Git-Config → ~/.gitconfig

Push local secrets to vault? [y/N]: y

Created vault items:
  ✓ SSH-GitHub-Enterprise
  ✓ SSH-GitHub-Personal
  ✓ AWS-Config
  ✓ Git-Config

STEP 5: Claude Code
────────────────────────────────────────────────────────────────
Install Claude Code CLI? [Y/n]: y

  ✓ Downloaded claude CLI
  ✓ Installed to /usr/local/bin/claude
  ✓ Verified: claude --version

Setup complete!
```

The wizard detects what you already have (vault CLIs, local secrets) and only asks for decisions. It took about 3 minutes on my Mac.

This required bootstrap scripts that work across macOS, several Linux distros, and WSL2. I also needed them to handle secrets (SSH keys, AWS credentials) without storing them in git.

## The Vault Problem

Your SSH keys already live in your password manager. Why copy them manually between machines?

Most dotfiles either ignore secrets or encrypt them in the repository. Ignoring secrets means manually copying SSH keys. Encrypting secrets means your private keys are in version control, even if encrypted.

The vault system uses where you already store secrets. Bitwarden, 1Password, or pass - pick whichever you already use.

New machine? `dotfiles vault restore`. Changed your SSH config? `dotfiles vault sync`. That's it.

Unlike chezmoi's one-way templates or traditional dotfiles with secrets in git, this is bidirectional with drift detection. The system warns before overwriting changes you haven't synced.

No keys in git. No manual copying. Just pull from where you already store secrets.

## What Makes This Different

Unlike chezmoi (one-way templates) or traditional dotfiles (secrets in git), this provides bidirectional vault sync with drift detection.

Most dotfiles are configuration files with an install script. This is configuration files plus:

- Multi-vault backend for secrets (unified API across Bitwarden/1Password/pass)
- Health checker that validates everything and can auto-fix issues
- Drift detection that warns before overwriting unsync'd changes
- Schema validation for SSH keys (correct permissions, key formats)
- Machine-specific templates (one config file becomes many with variables)
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

## Try Before You Trust

Don't trust random install scripts? Test everything in a disposable container first:

```bash
docker run -it --rm ghcr.io/blackwell-systems/dotfiles-lite
dotfiles status    # Poke around safely
dotfiles doctor    # See what it checks
exit               # Container vanishes
```

30-second verification before running anything on your real machine. The container includes the full CLI so you can explore what the system does.

## Get Started

Pick your path based on trust level:

**Skeptical?** Test in Docker first (above), then install for real.

**Ready?** One-line install + 5 minute wizard:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash
dotfiles setup
```

**Minimal?** Shell config only (Zsh, CLI tools, aliases). Add vault and Claude integration later:

```bash
curl -fsSL \
  https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --minimal
# Run 'dotfiles setup' later to enable vault and Claude integration
```

The wizard detects your platform, finds available vault CLIs, and prompts for choices. Takes about 5 minutes on a fresh machine.

Full documentation at [blackwell-systems.github.io/dotfiles](https://blackwell-systems.github.io/dotfiles).

## Why I'm Sharing This

I needed this for my own workflow. Maybe you need it too.

The code is MIT licensed. Fork it, modify it, use what works for you.

**Ready?** Install takes 5 minutes. **Skeptical?** Try the Docker test first. **Questions?** [Open an issue on GitHub](https://github.com/blackwell-systems/dotfiles/issues).
