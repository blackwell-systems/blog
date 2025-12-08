---
title: "A Dotfiles Framework Built for Claude Code and Modern Development"
date: 2025-12-06
draft: false
tags: ["dotfiles", "claude-code", "development-environment", "framework", "automation", "zsh", "rust", "go", "python", "aws"]
categories: ["developer-tools"]
description: "Modular dotfiles framework with Claude Code session portability, multi-vault secrets, developer tool integration (AWS/Rust/Go/Python), extensible hooks, and feature-based control. Built for developers who work across machines."
summary: "Start on Mac, continue on Linux—same Claude conversation. Plus integrated AWS/Rust/Go/Python tools, extensible hooks, multi-vault secrets, and modular architecture. A framework, not just dotfiles."
---

Start on Mac, continue on Linux, same Claude conversation.

That's how this started.

I solved it with a simple `/workspace → ~/workspace` symlink so Claude sees the same absolute path everywhere.

But the real outcome wasn't just portability. It was a new way to treat dotfiles as a **framework**: a feature registry, multi-vault secrets, layered configuration, and an extensible hook system—all fully opt-in, with no need to fork the core.

**This works great on a single Linux machine too.** The framework's modularity, vault system, hooks, and dev tool integrations stand on their own.

## The Problem That Started It

I use Claude Code across three machines: Mac laptop, Lima VM, and WSL2. Claude stores sessions by working directory path. `/Users/me/api` on Mac and `/home/me/api` on Linux are different sessions—different paths mean lost conversation history.

I found [this article about migrating Claude sessions](https://www.vincentschmalbach.com/migrate-claude-code-sessions-to-a-new-computer/) and started writing path rewriting scripts. After a few hours, I realized there was a simpler way.

## The Solution: Root-Level Symlink

```bash
/workspace -> ~/workspace
```

Now `/workspace/api` resolves correctly on every machine, but Claude sees the same absolute path. Same path = same session folder = conversation continues.

```bash
# Mac
cd /workspace/api && claude
# ... work for an hour, Claude learns your codebase ...

# Later, Linux VM - SAME conversation
cd /workspace/api && claude
# Full history intact. No sync. No export.
```

## From a Portability Hack to a Framework

The `/workspace` trick solved a real problem. The bigger discovery was that dotfiles can be a **control plane**: features, hooks, layered config, and vault-backed state—without forks.

That solved Claude portability. But while building this, I needed:
- Secrets synced without storing in git (SSH keys, AWS credentials)
- Shell config that didn't break when switching contexts
- Developer tools (AWS, Rust, Go, Python) with consistent aliases
- Health checks to catch broken configs
- Extensibility without editing core code

That became a framework.

## The Control Plane: Features + Hooks + Layers

Everything optional is a feature. Enable what you need, skip what you don't.

```bash
# See what's available
dotfiles features

# Enable specific features
dotfiles features enable vault --persist
dotfiles features enable aws_helpers

# Apply presets for common setups
dotfiles features preset claude      # Claude-optimized
dotfiles features preset developer   # Full dev stack
dotfiles features preset minimal     # Shell only
```

### Feature Categories

**Core** (always enabled):
- Shell configuration (ZSH, prompt, core aliases)

**Optional** (framework capabilities):
- `workspace_symlink` - `/workspace` for portable Claude sessions
- `claude_integration` - Claude Code hooks and settings
- `vault` - Multi-vault secrets (Bitwarden/1Password/pass)
- `templates` - Machine-specific configs with filters
- `hooks` - Lifecycle event system (multiple trigger points)
- `config_layers` - Hierarchical config (env > project > machine > user)
- `drift_check` - Detect unsync'd changes before overwriting
- `backup_auto` - Automatic backups before destructive ops

**Integrations** (developer tools):
- `aws_helpers` - AWS SSO profiles, helpers, tab completion
- `cdk_tools` - AWS CDK aliases and environment management
- `rust_tools` - Cargo aliases, clippy, watch, coverage
- `go_tools` - Go build/test/lint helpers
- `python_tools` - uv integration, pytest aliases, auto-venv
- `nvm_integration` - Lazy-loaded Node.js version management
- `sdkman_integration` - Java/Gradle/Kotlin version management
- `modern_cli` - eza, bat, ripgrep, fzf, zoxide

Dependencies auto-resolve. Enable `claude_integration` and it enables `workspace_symlink` automatically.

### Hook System: Opt-In Automation

**Hooks are opt-in automation, not hidden magic.** You can list, validate, and run each hook manually.

The hook system triggers custom scripts at multiple lifecycle points:

```bash
# Available hooks
shell_init             # Shell starts
directory_change       # cd into directory
pre_vault_pull         # Before pulling secrets
post_vault_pull        # After pulling secrets
pre_vault_push         # Before pushing secrets
post_vault_push        # After pushing secrets
doctor_check           # Health validation runs
pre_uninstall          # Before uninstalling
```

**Example: Auto-activate Python venv on cd**

```bash
# hooks/10-python-venv.sh
if [[ -f .venv/bin/activate ]]; then
    source .venv/bin/activate
fi
```

Hooks auto-discover from `~/hooks/` and `.dotfiles-hooks/` in project directories. Priority-based execution (00-99, lower runs first).

```bash
dotfiles hook list                    # Show all hooks
dotfiles hook run directory_change    # Test hook manually
dotfiles hook validate                # Validate all hook scripts
```

No core file edits needed. Drop scripts in `hooks/`, they run automatically.

### Configuration Layers

Hierarchical config resolution with 5 layers:

```bash
# Precedence: env > project > machine > user > defaults
export DOTFILES_VAULT_BACKEND=bitwarden   # env layer
echo '{"vault":{"backend":"pass"}}' > .dotfiles.json  # project layer

dotfiles config get vault.backend
# → bitwarden (env wins)

dotfiles config show vault.backend
# Shows all layers and which one is active
```

Project configs (`.dotfiles.json`) travel with repos. Machine configs (`~/.config/dotfiles/machine.json`) stay local.

## Optional Integrations: AWS/Rust/Go/Python

The framework includes dozens of curated aliases and helpers for common development workflows. All tools are **optional integrations**—enable only what you use.

### AWS & CDK

```bash
# AWS SSO with tab completion
awslogin <TAB>         # Shows available profiles
awsset production

# CDK shortcuts
cdkd                   # cdk deploy
cdks                   # cdk synth
cdkdf                  # cdk diff
cdkhotswap api-stack   # Deploy with hotswap
```

### Rust Development

```bash
# Cargo shortcuts
cb                     # cargo build
cr                     # cargo run
ct                     # cargo test
cc                     # cargo check
cw                     # cargo watch -x check

# Helpers
rust-new my-project    # Scaffold new project
rust-lint              # Run clippy with strict settings
```

### Go Development

```bash
# Go shortcuts
gob                    # go build ./...
got                    # go test ./...
gof                    # go fmt ./...
gocover                # Run tests with coverage report

# Helpers
go-new my-api          # Scaffold new project
go-lint                # Run golangci-lint
```

### Python with uv

Built on [uv](https://github.com/astral-sh/uv) for fast Python package management.

```bash
# uv shortcuts
uvs                    # uv sync
uvr script.py          # uv run
uva package            # uv add
pt                     # pytest
ptc                    # pytest with coverage

# Auto-venv activation
cd my-project          # Prompts: "Activate .venv? [Y/n]"
# Configurable: notify/auto/off
```

## Vault System: Multi-Backend Secrets

Your SSH keys already live in your password manager. Use them directly.

```bash
# Choose your backend
dotfiles setup          # Wizard detects Bitwarden/1Password/pass

# Sync secrets
dotfiles vault pull     # Pull from vault to filesystem
dotfiles vault push     # Push local changes to vault
dotfiles vault sync     # Bidirectional sync with drift detection
```

**Drift detection** warns before overwriting:

```
⚠ Drift detected:
  • SSH-GitHub-Personal
    Vault:  SHA256:abc...
    Local:  SHA256:def...

Overwrite local with vault? [y/N]:
```

Secrets never touch git. The vault system uses your existing password manager.

## Setup Wizard

The current wizard flow walks through 7 steps:

```console
$ curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash
$ dotfiles setup

    ____        __  _____ __
   / __ \____  / /_/ __(_) /__  _____
  / / / / __ \/ __/ /_/ / / _ \/ ___/
 / /_/ / /_/ / /_/ __/ / /  __(__  )
/_____/\____/\__/_/ /_/_/\___/____/

Setup Wizard

Current Status:
───────────────
  [ ] Workspace  (Workspace directory)
  [ ] Symlinks   (Shell config linked)
  [ ] Packages   (Homebrew packages)
  [ ] Vault      (Vault backend)
  [ ] Secrets    (SSH keys, AWS, Git)
  [ ] Claude     (Claude Code integration)
  [ ] Templates  (Machine-specific configs)

╔═══════════════════════════════════════════════════════════════╗
║ Step 1 of 7: Workspace
╠═══════════════════════════════════════════════════════════════╣
║ ███░░░░░░░░░░░░░░░░ 14%
╚═══════════════════════════════════════════════════════════════╝

Configure workspace directory for portable Claude sessions.
Default: ~/workspace (symlinked from /workspace)

Use default? [Y/n]:
```

Each step is optional. Exit anytime, resume later with `dotfiles setup`.

### Package Tiers

Choose your installation size:

| Tier | Packages | Time | What's Included |
|------|----------|------|-----------------|
| **Minimal** | 18 | ~2 min | Essentials (git, zsh, jq) |
| **Enhanced** | 43 | ~5 min | Modern CLI tools (recommended) |
| **Full** | 61 | ~10 min | Everything including Docker, Node |

The wizard presents this interactively. Your choice persists in config.

## Modular Shell Config

Instead of one 1000-line `.zshrc`, there are modular files in `zsh.d/`:

```
zsh/zsh.d/
├── 00-init.zsh           # Core initialization
├── 10-environment.zsh    # ENV vars
├── 20-history.zsh        # History config
├── 30-completion.zsh     # Tab completion
├── 40-aliases.zsh        # Aliases
├── 50-aws.zsh           # AWS helpers (if aws_helpers enabled)
├── 51-rust.zsh          # Rust tools (if rust_tools enabled)
└── 90-hooks.zsh          # Hook system integration
```

Each module handles one thing. Disable per-machine by symlinking to `.skip`:

```bash
ln -s 50-aws.zsh 50-aws.zsh.skip    # Skip AWS module
```

Modules load in order (00-99). Feature guards prevent loading disabled integrations.

## What Makes This Different

**Most dotfiles:** Configuration files + install script.

**This framework:**
- **Feature Registry** - Modular control plane for all optional components
- **Hook System** - Extensible automation at multiple lifecycle points
- **Multi-Vault** - Unified API for Bitwarden/1Password/pass
- **Developer Tools** - Integrated AWS/Rust/Go/Python with curated aliases
- **Configuration Layers** - Hierarchical resolution (env > project > machine)
- **Drift Detection** - Warns before overwriting unsync'd changes
- **Template Filters** - `{{ var | upper }}` pipeline transformations
- **Health Checks** - Validates everything, auto-fixes common issues
- **Claude Portability** - `/workspace` symlink for session sync

Designed for developers who want consistency and control.

## Integration with dotclaude

**dotclaude and dotfiles are independent.** They integrate cleanly through shared assumptions like `/workspace` and feature gating, but neither requires the other.

- **dotclaude** - Manages Claude configuration (CLAUDE.md, agents, settings)
- **dotfiles** - Manages secrets, shell, and development environment

Both respect `/workspace` for portable sessions. Switch Claude contexts with dotclaude while secrets stay synced via dotfiles vault.

## Who This Is For

This framework works best if you:

- Want a modular dotfiles system you can grow over time
- Prefer opt-in features instead of monolithic installs
- Need vault-backed secrets without committing anything to git
- Like automation you can understand and control (hooks + doctor)
- Use AWS/Rust/Go/Python and want consistent helpers

**If you also use Claude Code or work across machines, the `/workspace` portability becomes a genuinely great bonus.**

If you don't use Claude or don't switch machines, you still get a clean feature registry, hooks, vault-backed secrets, and layered config.

## Try Before You Trust

Test in a disposable container first (if you publish the lite image):

```bash
docker run -it --rm ghcr.io/blackwell-systems/dotfiles-lite
dotfiles status    # Poke around safely
dotfiles doctor    # See health checks
exit               # Container vanishes
```

30-second verification before running on your real machine.

## Get Started

```bash
# Full install (recommended for Claude Code users)
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash
dotfiles setup

# Minimal install (shell config only, add features later)
curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash -s -- --minimal

# Custom workspace location
WORKSPACE_TARGET=~/code curl -fsSL https://raw.githubusercontent.com/blackwell-systems/dotfiles/main/install.sh | bash
```

The wizard detects your platform, finds available vault CLIs, and prompts for choices. Takes ~2–10 minutes depending on tier selection.

**Started minimal? Add features later:**

```bash
dotfiles features enable vault --persist        # Enable vault
dotfiles features enable rust_tools --persist   # Enable Rust tools
dotfiles features preset developer              # Enable full dev stack
dotfiles setup                                  # Re-run wizard for vault setup
```

Full documentation at [blackwell-systems.github.io/dotfiles](https://blackwell-systems.github.io/dotfiles).

---

**Code:** [github.com/blackwell-systems/dotfiles](https://github.com/blackwell-systems/dotfiles)
**Docs:** [blackwell-systems.github.io/dotfiles](https://blackwell-systems.github.io/dotfiles)
**Changelog:** [CHANGELOG.md](https://github.com/blackwell-systems/dotfiles/blob/main/CHANGELOG.md)
**License:** MIT
