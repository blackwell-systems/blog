---
title: "Mastering ZSH: Part 1 - Hooks and Automation"
date: 2025-12-07
draft: false
series: ["mastering-zsh"]
seriesOrder: 1
tags: ["zsh", "shell-scripting", "automation", "command-line", "productivity", "terminal", "unix", "linux", "macos", "blackdot", "dotfiles", "precmd", "preexec", "chpwd"]
categories: ["tutorials", "shell-scripting"]
description: "Learn how to use ZSH hooks (precmd, preexec, chpwd) to automate your shell. Includes command timing, auto-activate virtualenv, and performance tips."
summary: "Complete guide to ZSH hooks: automate prompts, time commands, activate virtualenvs on cd, and filter secrets from history--without slowing down your terminal."
---

ZSH hooks are built-in functions that run automatically at specific points in your shell lifecycle. Use them to automate command timing, prompt updates, virtualenv activation, and more--without plugins or performance penalties.

This guide covers all six native ZSH hook types with working examples you can paste into your `.zshrc`.

## What ZSH Hooks Actually Do

ZSH hooks are **function arrays** that execute at specific lifecycle points. You register functions in these arrays and ZSH calls them automatically at the right time.

| Hook | When It Runs | Common Use Cases |
|------|--------------|------------------|
| `precmd_functions` | Before each prompt displays | Update git status, refresh context |
| `preexec_functions` | Before each command runs | Start timing, log commands |
| `chpwd_functions` | After directory changes | Activate envs, load project config |
| `zshaddhistory_functions` | Before adding commands to history | Filter secrets |
| `zshexit_functions` | When the shell exits | Cleanup, save state |
| `periodic_functions` | Every N seconds | Periodic checks, refresh cached data |

**Execution order matters:** Functions execute in array order (first to last). If one hook depends on another's output, put it later in the array.

```zsh
precmd_functions=(check_git update_prompt measure_timing)
# Executes: check_git → update_prompt → measure_timing
```

## The Six Core Hook Types

ZSH provides six commonly used built-in hook arrays.

> **Tip:** If you're using `$EPOCHREALTIME`, load the datetime module once:
> ```zsh
> zmodload zsh/datetime
> ```

### 1. `precmd_functions` -- Before Each Prompt

Runs after a command completes but before the next prompt displays. Perfect for status updates.

```zsh
my_precmd() {
    # Update terminal title with current directory
    print -Pn "\e]0;%~\a"
}

precmd_functions+=( my_precmd )
```

**Use cases:** Update git branch, show AWS profile, display exit status, refresh job count

### 2. `preexec_functions` -- Before Each Command

Runs after you press Enter but before the command executes. Receives the command string as `$1`.

```zsh
my_preexec() {
    export CMD_START_TIME=$EPOCHREALTIME
}

preexec_functions+=( my_preexec )
```

**Use cases:** Command timing, lightweight logging, notifications for long commands, frequency tracking

### 3. `chpwd_functions` -- After Directory Changes

Runs whenever the working directory changes via `cd`, `pushd`, `popd`, etc.

```zsh
my_chpwd() {
    if [[ -f .venv/bin/activate ]]; then
        source .venv/bin/activate
    fi
}

chpwd_functions+=( my_chpwd )
```

**Use cases:** Auto-activate envs (Python, Node, Ruby), load project variables, update prompt context, run lightweight setup checks

### 4. `zshexit_functions` -- When Shell Exits

Runs when the shell terminates.

```zsh
my_zshexit() {
    # Example: archive history locally
    cp ~/.zsh_history ~/.zsh_history.bak 2>/dev/null
}

zshexit_functions+=( my_zshexit )
```

**Use cases:** Save persistent state, cleanup temporary files, log session duration

### 5. `periodic_functions` -- Every N Seconds

Runs every `$PERIOD` seconds.

```zsh
PERIOD=300  # 5 minutes

my_periodic() {
    # Lightweight background refresh
    (git fetch --quiet 2>/dev/null &)
}

periodic_functions+=( my_periodic )
```

**Use cases:** Background git fetch, refresh cached data, check update indicators, monitor background processes

### 6. `zshaddhistory_functions` -- Before Adding to History

Runs before a command is added to history. Return 1 to skip, 0 to add.

```zsh
my_zshaddhistory() {
    local cmd="$1"

    [[ "$cmd" == *"password"* ]] && return 1
    [[ "$cmd" == *"AWS_SECRET"* ]] && return 1

    return 0
}

zshaddhistory_functions+=( my_zshaddhistory )
```

**Use cases:** Filter sensitive commands, skip trivial commands, deduplicate spammy entries

## Using `add-zsh-hook` (Recommended)

`add-zsh-hook` offers a cleaner API and avoids some edge cases.

```zsh
autoload -Uz add-zsh-hook

add-zsh-hook precmd my_precmd
add-zsh-hook chpwd  my_chpwd

# Remove a hook
add-zsh-hook -d precmd my_precmd
```

## Real-World Examples

### Command Timing Display

Show timing only for commands over 5 seconds:

```zsh
autoload -Uz add-zsh-hook
zmodload zsh/datetime

_timer_preexec() {
    CMD_START=$EPOCHREALTIME
}

_timer_precmd() {
    [[ -z "$CMD_START" ]] && return

    local elapsed=$(( EPOCHREALTIME - CMD_START ))
    if (( elapsed > 5 )); then
        echo "⏱  ${elapsed}s"
    fi

    unset CMD_START
}

add-zsh-hook preexec _timer_preexec
add-zsh-hook precmd  _timer_precmd
```

### Auto-Activate Python Virtualenv

```zsh
autoload -Uz add-zsh-hook

_auto_venv() {
    if [[ -f .venv/bin/activate ]]; then
        source .venv/bin/activate
        return
    fi

    if [[ -f venv/bin/activate ]]; then
        source venv/bin/activate
        return
    fi

    # Optional: deactivate when leaving a project venv directory
    if [[ -n "$VIRTUAL_ENV" ]]; then
        local venv_root="${VIRTUAL_ENV:h}"
        if [[ "$PWD" != "$venv_root"* ]]; then
            deactivate 2>/dev/null
        fi
    fi
}

add-zsh-hook chpwd _auto_venv
_auto_venv  # Run once on shell start
```

### Smart Git Branch in Prompt

```zsh
autoload -Uz add-zsh-hook vcs_info
setopt prompt_subst

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' formats ' %b'
zstyle ':vcs_info:*' actionformats ' %b|%a'

_update_git_prompt() {
    git rev-parse --git-dir &>/dev/null || return
    vcs_info
}

add-zsh-hook precmd _update_git_prompt

PROMPT='%~${vcs_info_msg_0_} %# '
```

### Auto-Load Project Environment

This is simple and works--but for complex env management, `direnv` is safer.

```zsh
autoload -Uz add-zsh-hook

_load_project_env() {
    [[ -f .env ]] || return
    set -a
    source .env
    set +a
}

add-zsh-hook chpwd _load_project_env
_load_project_env  # Run once on shell start
```

### Filter Secrets from History

Conservative, simple filtering. Patterns are intentionally broad to avoid false negatives:

```zsh
_filter_secrets() {
    local cmd="$1"
    local patterns=(
        'password'
        'secret'
        'token'
        'api_key'
        'AWS_SECRET'
        'export[[:space:]]+.*KEY='
    )

    for pattern in "${patterns[@]}"; do
        [[ "$cmd" =~ "$pattern" ]] && return 1
    done

    return 0
}

zshaddhistory_functions+=( _filter_secrets )
```

## Performance Considerations

Hooks run synchronously and can slow down your shell if you're not careful. **Hooks are the wrong place for network calls unless you cache the results.**

### Bad: Block Every Prompt

```zsh
autoload -Uz add-zsh-hook

_slow_precmd() {
    curl -s https://api.example.com/status
}

add-zsh-hook precmd _slow_precmd
```

Network calls on every prompt will make your shell feel broken.

### Better: Background the Operation

```zsh
autoload -Uz add-zsh-hook

_fast_precmd() {
    (curl -s https://api.example.com/status > /tmp/status &)
}

add-zsh-hook precmd _fast_precmd
```

The prompt displays immediately. The background job completes later.

### Best: Use Periodic Hooks

```zsh
PERIOD=300  # 5 minutes

_periodic_check() {
    curl -s https://api.example.com/status > /tmp/status
}

periodic_functions+=( _periodic_check )
```

Only runs every 5 minutes, not on every prompt.

### Measure Hook Performance

```zsh
zmodload zsh/datetime

_time_precmd() {
    local start=$EPOCHREALTIME

    # Your real precmd work here

    local elapsed=$(( EPOCHREALTIME - start ))
    if (( elapsed > 0.1 )); then
        echo "Warning: precmd took ${elapsed}s" >&2
    fi
}
```

Anything consistently above ~100ms will be noticeable.

## Advanced Patterns

### Conditional Hook Execution

```zsh
autoload -Uz add-zsh-hook vcs_info

_smart_precmd() {
    git rev-parse --git-dir &>/dev/null || return
    vcs_info
}

add-zsh-hook precmd _smart_precmd
```

### Stateful Hooks

```zsh
autoload -Uz add-zsh-hook

typeset -g _last_project=""

_detect_project_change() {
    local project_root
    project_root=$(git rev-parse --show-toplevel 2>/dev/null) || return

    if [[ "$project_root" != "$_last_project" ]]; then
        _last_project="$project_root"
        echo "Entered project: ${project_root:t}"
    fi
}

add-zsh-hook chpwd _detect_project_change
```

### Async Hooks (Experimental)

ZSH can do async patterns, but most users should reach for [zsh-async](https://github.com/mafredri/zsh-async) for production use.

```zsh
autoload -Uz add-zsh-hook
zmodload zsh/zpty

_async_precmd() {
    # Example only: be careful not to spam processes
    zpty -b async_worker git fetch --quiet 2>&1
}

add-zsh-hook precmd _async_precmd
```

This is experimental--use `zsh-async` if you need reliable async behavior.

## Debugging Hooks

### List Registered Hooks

```zsh
echo $precmd_functions
echo $preexec_functions
echo $chpwd_functions
```

### Temporarily Disable Hooks

```zsh
local saved_precmd=("${precmd_functions[@]}")
precmd_functions=()

# Run something "clean"
some_command

precmd_functions=("${saved_precmd[@]}")
```

### Trace Hook Execution

```zsh
setopt XTRACE
ls  # Shows all hook execution
unsetopt XTRACE
```

## Hook Management at Scale

### File-Based Organization

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
for hook_dir in ~/.config/zsh/hooks/*/; do
    for hook_file in "$hook_dir"*.zsh(N); do
        source "$hook_file"
    done
done
```

### A Production-Grade Hook System

If you want ordering, enable/disable control, validation, and visibility at scale, see the [blackdot hook system](https://github.com/blackwell-systems/blackdot/blob/main/docs/hooks.md), which provides:

- **Priority-based execution** (00-99 prefixes)
- **Feature gating** (enable/disable hooks via config)
- **Validation** (`blackdot hook validate`)
- **Testing** (`blackdot hook run <event>`)
- **Visibility** (`blackdot hook list`)

Example:

```sh
# ~/.config/blackdot/hooks/directory_change/10-python-venv.sh
#!/bin/bash

if [[ -f .venv/bin/activate ]]; then
    source .venv/bin/activate
fi
```

The numeric prefix (10-) controls execution order. The system handles registration automatically.

## Common Pitfalls

### 1. Triggering Infinite Loops

```zsh
_bad_chpwd() {
    cd /tmp  # chpwd triggers another chpwd...
}
```

`chpwd` hooks trigger on `cd`, which causes another `chpwd`, which causes another `cd`...

### 2. Assuming Hooks Run in Scripts

Hooks are for *interactive* ZSH sessions. They won't run in non-interactive shells (scripts, cron jobs).

### 3. Leaking State

```zsh
_leaky_preexec() {
    export TEMP_VAR="value"
    # Never unset - leaks into environment
}
```

If `preexec` sets globals, make sure `precmd` clears them.

## When Not to Use Hooks

Hooks aren't always the right tool:

- **Expensive operations** → use cron/systemd timers
- **Critical deployment steps** → don't hide them in shell lifecycle magic
- **Cross-shell setups** → remember Bash uses `PROMPT_COMMAND`

## Summary

ZSH hooks let you inject clean automation at six key points:

- `precmd` -- before prompt (update status)
- `preexec` -- before command (timing, logging)
- `chpwd` -- after `cd` (env activation)
- `zshexit` -- on exit (cleanup)
- `periodic` -- every N seconds (background refresh)
- `zshaddhistory` -- before history save (filter secrets)

Use `add-zsh-hook` for clean registration. Keep hooks fast. Cache or background anything that might block.

For structured hook management with ordering, validation, and feature gating, see the [blackdot hook system documentation](https://github.com/blackwell-systems/blackdot/blob/main/docs/hooks.md).

## Frequently Asked Questions

### What are ZSH hooks?

ZSH hooks are **function arrays** built into the shell that execute automatically at specific lifecycle points--before prompts display, before commands run, after directory changes, etc. You add functions to these arrays and ZSH calls them at the right time.

### How do I add a hook to ZSH?

Use `add-zsh-hook` for the cleanest approach:

```zsh
autoload -Uz add-zsh-hook
add-zsh-hook precmd my_function_name
```

Or append directly to the hook array:

```zsh
precmd_functions+=( my_function_name )
```

### Why is my ZSH prompt slow after adding hooks?

Hooks run synchronously. If you're making network calls, doing expensive computations, or running slow external commands in `precmd`, every prompt waits for them to complete. Solution: background slow operations with `(command &)` or move them to `periodic` hooks.

### How do I auto-activate Python virtualenv when I cd into a project?

Add this to your `.zshrc`:

```zsh
autoload -Uz add-zsh-hook

_auto_venv() {
    [[ -f .venv/bin/activate ]] && source .venv/bin/activate
}

add-zsh-hook chpwd _auto_venv
```

### How do I time long-running commands in ZSH?

Use `preexec` to save start time and `precmd` to calculate elapsed time:

```zsh
autoload -Uz add-zsh-hook
zmodload zsh/datetime

_timer_preexec() { CMD_START=$EPOCHREALTIME }

_timer_precmd() {
    [[ -z "$CMD_START" ]] && return
    local elapsed=$(( EPOCHREALTIME - CMD_START ))
    (( elapsed > 5 )) && echo "⏱  ${elapsed}s"
    unset CMD_START
}

add-zsh-hook preexec _timer_preexec
add-zsh-hook precmd _timer_precmd
```

### How do I prevent sensitive commands from being saved to history?

Use `zshaddhistory` to filter commands before they're saved:

```zsh
_filter_secrets() {
    [[ "$1" == *"password"* ]] && return 1
    [[ "$1" == *"secret"* ]] && return 1
    return 0
}

zshaddhistory_functions+=( _filter_secrets )
```

Return 1 to skip saving, 0 to save.

### Can I use ZSH hooks in Bash?

No, ZSH hooks are ZSH-specific. Bash has `PROMPT_COMMAND` for prompt-time hooks but doesn't have equivalents for `preexec`, `chpwd`, or the other ZSH hook types. Consider switching to ZSH for full hook support.

---

**Further Reading:**
- [ZSH Manual: Hook Functions](http://zsh.sourceforge.net/Doc/Release/Functions.html#Hook-Functions)
- [blackdot hook system](https://github.com/blackwell-systems/blackdot/blob/main/docs/hooks.md)
- [zsh-async](https://github.com/mafredri/zsh-async) - Production async hooks

**Shell:** ZSH 5.0+
