---
title: "ZSH Hooks: Automate Your Shell Without Breaking Your Workflow"
date: 2025-12-07
draft: false
tags: ["zsh", "shell-scripting", "automation", "command-line", "productivity", "terminal", "unix", "linux", "macos", "dotfiles"]
description: "Master ZSH hooks to automate repetitive tasks, customize your shell behavior, and build powerful command-line workflows. Learn precmd, preexec, chpwd, and more with practical examples that work in real projects."
summary: "ZSH hooks let you run code at specific points in your shell lifecycle—before commands execute, after directory changes, on prompt display. Here's how to use them without slowing down your terminal."
---

Your terminal shows a git branch in the prompt. Your Python virtualenv activates automatically when you `cd` into a project. Long-running commands show their execution time.

These aren't plugins—they're ZSH hooks. Here's how they work and how to use them without breaking your shell.

## What ZSH Hooks Actually Do

ZSH hooks are function arrays that execute at specific lifecycle points:

- **Before each prompt displays** (update git status, check background jobs)
- **Before each command runs** (start timing, log commands)
- **After directory changes** (activate virtualenvs, load project config)
- **Before adding commands to history** (filter secrets, skip duplicates)
- **When the shell exits** (cleanup, save state)
- **Every N seconds** (periodic checks, refresh data)

You register functions in these arrays. ZSH calls them automatically at the right time.

## The Six Core Hook Types

ZSH provides six built-in hook arrays:

### 1. `precmd_functions` — Before Each Prompt

Runs after a command completes but before the prompt displays. Perfect for updating prompt information.

```zsh
my_precmd() {
    # Update terminal title with current directory
    print -Pn "\e]0;%~\a"
}

precmd_functions+=( my_precmd )
```

**Use cases:**
- Update git branch in prompt
- Show current AWS profile
- Display last command exit status
- Refresh background job count

### 2. `preexec_functions` — Before Each Command

Runs after you press Enter but before the command executes. Gets the command string as `$1`.

```zsh
my_preexec() {
    # Save command start time
    export CMD_START_TIME=$EPOCHREALTIME
}

preexec_functions+=( my_preexec )
```

**Use cases:**
- Command timing
- Log executed commands
- Send notifications for long-running commands
- Track command frequency for analytics

### 3. `chpwd_functions` — After Directory Changes

Runs whenever the working directory changes via `cd`, `pushd`, `popd`, etc.

```zsh
my_chpwd() {
    # Auto-activate Python virtualenv
    if [[ -f .venv/bin/activate ]]; then
        source .venv/bin/activate
    fi
}

chpwd_functions+=( my_chpwd )
```

**Use cases:**
- Auto-activate virtualenvs (Python, Node, Ruby)
- Load project-specific environment variables
- Update prompt with project context
- Auto-run project setup scripts

### 4. `zshexit_functions` — When Shell Exits

Runs when the shell terminates (closing terminal, `exit` command, logout).

```zsh
my_zshexit() {
    # Save session history to cloud
    rsync ~/.zsh_history backup@server:/backups/
}

zshexit_functions+=( my_zshexit )
```

**Use cases:**
- Save persistent state
- Cleanup temporary files
- Sync history to remote storage
- Log session duration

### 5. `periodic_functions` — Every N Seconds

Runs every `$PERIOD` seconds (set `PERIOD=300` for 5 minutes).

```zsh
PERIOD=300  # 5 minutes

my_periodic() {
    # Fetch git updates in background
    (git fetch origin 2>/dev/null &)
}

periodic_functions+=( my_periodic )
```

**Use cases:**
- Background git fetch
- Check for system updates
- Refresh cached data
- Monitor background processes

### 6. `zshaddhistory_functions` — Before Adding to History

Runs before a command is added to history. Return 1 to skip adding, 0 to add.

```zsh
my_zshaddhistory() {
    local cmd="$1"

    # Don't save commands with secrets
    [[ "$cmd" == *"password"* ]] && return 1
    [[ "$cmd" == *"export AWS_SECRET"* ]] && return 1

    return 0  # Add to history
}

zshaddhistory_functions+=( my_zshaddhistory )
```

**Use cases:**
- Filter sensitive commands (passwords, tokens)
- Skip trivial commands (`ls`, `pwd`)
- Deduplicate consecutive identical commands
- Implement custom history rules

## Using `add-zsh-hook` (Recommended)

The `add-zsh-hook` utility provides a cleaner API:

```zsh
# Load the utility
autoload -Uz add-zsh-hook

# Add hooks
add-zsh-hook precmd my_precmd_function
add-zsh-hook chpwd my_chpwd_function

# Remove hooks
add-zsh-hook -d precmd my_precmd_function
```

This handles edge cases (duplicates, errors) better than raw array manipulation.

## Real-World Examples

### Command Timing Display

Show execution time for commands that take longer than 5 seconds:

```zsh
autoload -Uz add-zsh-hook

_timer_preexec() {
    export CMD_START=$EPOCHREALTIME
}

_timer_precmd() {
    if [[ -n "$CMD_START" ]]; then
        local elapsed=$(( EPOCHREALTIME - CMD_START ))
        if (( elapsed > 5 )); then
            echo "⏱  ${elapsed}s"
        fi
        unset CMD_START
    fi
}

add-zsh-hook preexec _timer_preexec
add-zsh-hook precmd _timer_precmd
```

### Auto-Activate Python Virtualenv

Automatically source virtualenv when entering a project:

```zsh
autoload -Uz add-zsh-hook

_auto_venv() {
    # Look for virtualenv
    if [[ -f .venv/bin/activate ]]; then
        source .venv/bin/activate
    elif [[ -f venv/bin/activate ]]; then
        source venv/bin/activate
    elif [[ -n "$VIRTUAL_ENV" ]]; then
        # Deactivate if we left a venv directory
        local venv_dir="${VIRTUAL_ENV%/bin/*}"
        if [[ "$PWD" != "$venv_dir"* ]]; then
            deactivate 2>/dev/null
        fi
    fi
}

add-zsh-hook chpwd _auto_venv
_auto_venv  # Run once on shell start
```

### Smart Git Branch in Prompt

Update prompt with git branch only when in a git repository:

```zsh
autoload -Uz add-zsh-hook vcs_info

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' formats ' %b'
zstyle ':vcs_info:*' actionformats ' %b|%a'

_update_git_prompt() {
    vcs_info
}

add-zsh-hook precmd _update_git_prompt

# In your prompt
PROMPT='%~ ${vcs_info_msg_0_} %# '
```

### Auto-Load Project Environment

Load project-specific environment variables from `.env`:

```zsh
autoload -Uz add-zsh-hook

_load_project_env() {
    # Unload previous project env
    if [[ -n "$_LOADED_ENV_FILE" && "$_LOADED_ENV_FILE" != "$PWD/.env" ]]; then
        # Clear previously set variables (track them yourself or use direnv)
        unset _LOADED_ENV_FILE
    fi

    # Load new project env
    if [[ -f .env ]]; then
        set -a  # Export all variables
        source .env
        set +a
        export _LOADED_ENV_FILE="$PWD/.env"
    fi
}

add-zsh-hook chpwd _load_project_env
_load_project_env  # Run once on shell start
```

### Filter Secrets from History

Prevent commands containing secrets from being saved:

```zsh
_filter_secrets() {
    local cmd="$1"

    # Patterns that indicate secrets
    local patterns=(
        'password'
        'secret'
        'token'
        'api_key'
        'AWS_SECRET'
        'export.*KEY'
    )

    for pattern in "${patterns[@]}"; do
        if [[ "$cmd" =~ "$pattern" ]]; then
            return 1  # Don't save to history
        fi
    done

    return 0  # Save to history
}

zshaddhistory_functions+=( _filter_secrets )
```

## Performance Considerations

Hooks run synchronously and can slow down your shell if not careful.

### Bad: Blocks Every Prompt

```zsh
_slow_precmd() {
    # Network call on every prompt!
    curl -s https://api.example.com/status
}

add-zsh-hook precmd _slow_precmd
```

Every prompt waits for the network call. Your shell feels laggy.

### Better: Background the Operation

```zsh
_fast_precmd() {
    # Run in background, don't block prompt
    (curl -s https://api.example.com/status > /tmp/status &)
}

add-zsh-hook precmd _fast_precmd
```

The prompt displays immediately. The background job completes later.

### Best: Use Periodic Hooks

```zsh
PERIOD=300  # Every 5 minutes

_periodic_check() {
    curl -s https://api.example.com/status > /tmp/status
}

add-zsh-hook periodic _periodic_check
```

Only runs every 5 minutes, not on every prompt.

### Measure Hook Performance

Find slow hooks:

```zsh
# Add timing wrapper
_time_precmd() {
    local start=$EPOCHREALTIME
    # Your precmd code here
    local elapsed=$(( EPOCHREALTIME - start ))
    if (( elapsed > 0.1 )); then
        echo "Warning: precmd took ${elapsed}s" >&2
    fi
}
```

If a hook takes >100ms, it's noticeable. Optimize or background it.

## Advanced Patterns

### Conditional Hook Execution

Only run hooks when needed:

```zsh
_smart_precmd() {
    # Only update git info if in a git repo
    if git rev-parse --git-dir &>/dev/null; then
        vcs_info
    fi
}

add-zsh-hook precmd _smart_precmd
```

### Stateful Hooks

Track state between hook calls:

```zsh
typeset -g _last_pwd=""

_detect_project_change() {
    # Only act on project root changes
    local project_root=$(git rev-parse --show-toplevel 2>/dev/null)

    if [[ "$project_root" != "$_last_pwd" ]]; then
        _last_pwd="$project_root"
        echo "Entered project: $(basename "$project_root")"
        # Load project-specific config
    fi
}

add-zsh-hook chpwd _detect_project_change
```

### Async Hooks

Use `zsh/zpty` module for truly async hooks:

```zsh
autoload -Uz add-zsh-hook

# Start async worker
zmodload zsh/zpty

_async_precmd() {
    # Spawn background process with zpty
    zpty -b async_worker git fetch origin 2>&1
}

add-zsh-hook precmd _async_precmd
```

(For production use, consider [zsh-async](https://github.com/mafredri/zsh-async) plugin)

## Debugging Hooks

### List All Registered Hooks

```zsh
# Show all precmd hooks
echo $precmd_functions

# Show all chpwd hooks
echo $chpwd_functions
```

### Temporarily Disable Hooks

```zsh
# Save hooks
local saved_precmd=("${precmd_functions[@]}")

# Clear hooks
precmd_functions=()

# Run command without hooks
some_command

# Restore hooks
precmd_functions=("${saved_precmd[@]}")
```

### Debug Hook Execution

```zsh
# Trace hook calls
setopt XTRACE

# Run a command (shows all hook execution)
ls

# Disable tracing
unsetopt XTRACE
```

## Hook Management at Scale

For complex setups with many hooks, consider a structured approach.

### File-Based Hook Organization

Instead of cramming everything in `.zshrc`:

```
~/.config/zsh/hooks/
├── precmd/
│   ├── 10-git-status.zsh
│   ├── 20-aws-profile.zsh
│   └── 90-prompt-update.zsh
├── chpwd/
│   ├── 10-venv-activate.zsh
│   └── 20-project-env.zsh
└── preexec/
    └── 10-command-timing.zsh
```

Load them in `.zshrc`:

```zsh
# Load all hooks
for hook_dir in ~/.config/zsh/hooks/*/; do
    for hook_file in "$hook_dir"*.zsh(N); do
        source "$hook_file"
    done
done
```

### Hook System with Feature Gating

For a production implementation with enable/disable, ordering, and validation, see the [dotfiles hook system](https://github.com/blackwell-systems/dotfiles/blob/main/docs/hooks.md). It provides:

- **Priority-based execution** (00-99 prefixes)
- **Feature gating** (enable/disable hooks via config)
- **Validation** (`dotfiles hook validate`)
- **Testing** (`dotfiles hook test <event>`)
- **Visibility** (`dotfiles hook list`)

Example from that system:

```zsh
# ~/.config/dotfiles/hooks/directory_change/10-python-venv.sh
#!/bin/bash

if [[ -f .venv/bin/activate ]]; then
    source .venv/bin/activate
fi
```

The numeric prefix (10-) controls execution order. The system handles registration automatically.

## Common Pitfalls

### 1. Modifying Global State

```zsh
# BAD: Changes directory in hook
_bad_chpwd() {
    cd /tmp  # Infinite loop!
}
```

`chpwd` hooks trigger on `cd`, which causes another `chpwd`, which causes another `cd`...

### 2. Assuming Hooks Run

Hooks don't run in non-interactive shells (scripts, cron jobs):

```bash
#!/bin/bash
# precmd hooks WON'T run here
```

Only in interactive ZSH sessions.

### 3. Forgetting to Unset State

```zsh
_leaky_preexec() {
    export TEMP_VAR="value"
    # Never unset - leaks into environment
}
```

Clean up temporary variables in corresponding `precmd`.

## When Not to Use Hooks

Hooks aren't always the answer:

- **Expensive operations**: Use cron jobs or systemd timers instead
- **Critical path operations**: Don't rely on hooks for deployment steps
- **Cross-shell compatibility**: Hooks are ZSH-specific (Bash uses `PROMPT_COMMAND`)

## Summary

ZSH hooks let you inject custom behavior at six key points:

1. **precmd** - Before prompt (update status)
2. **preexec** - Before command (timing, logging)
3. **chpwd** - After `cd` (auto-activate envs)
4. **zshexit** - On shell exit (cleanup)
5. **periodic** - Every N seconds (background tasks)
6. **zshaddhistory** - Before history save (filter secrets)

Use `add-zsh-hook` for cleaner management. Background slow operations. Measure performance.

For structured hook management with ordering, validation, and feature gating, see the [dotfiles hook system documentation](https://github.com/blackwell-systems/dotfiles/blob/main/docs/hooks.md).

---

**Further Reading:**
- [ZSH Manual: Hook Functions](http://zsh.sourceforge.net/Doc/Release/Functions.html#Hook-Functions)
- [dotfiles hook system](https://github.com/blackwell-systems/dotfiles/blob/main/docs/hooks.md)
- [zsh-async](https://github.com/mafredri/zsh-async) - Production async hooks

**Shell:** ZSH 5.0+
