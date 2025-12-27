---
title: "Mastering ZSH: Part 4 - Completion System Demystified"
date: 2025-12-27
draft: false
series: ["mastering-zsh"]
seriesOrder: 4
tags: ["zsh", "completion", "tab-completion", "shell-scripting", "command-line", "productivity", "terminal", "compinit", "compdef", "automation"]
categories: ["tutorials", "shell-scripting"]
description: "Understand how ZSH's completion system works - why git <tab> knows subcommands, how to build custom completions, and the architecture behind context-aware suggestions."
summary: "Part 4: Learn how ZSH completions work under the hood. Build custom completions for your scripts, understand _arguments and completion contexts, and make tab completion actually useful."
---

You type `git <tab>` and see subcommands. Type `git commit -<tab>` and see flags. Type `git checkout <tab>` and see branches.

How does ZSH know what to suggest? Why does `cd <tab>` only show directories, but `ls <tab>` shows files?

**This is the completion system.** It's invisible infrastructure that makes your shell feel intelligent.

Most developers use completions daily but never understand how they work. This changes that.

## Table of Contents

- [What Completions Actually Are](#what-completions-actually-are) - Functions that generate suggestions
- [The Completion Architecture](#the-completion-architecture) - compinit, compdef, and _arguments
- [How Git Completion Works](#how-git-completion-works) - Real example breakdown
- [Building Your First Completion](#building-your-first-completion) - Step-by-step guide
- [Context-Aware Completions](#context-aware-completions) - Different suggestions per position
- [Performance and Caching](#performance-and-caching) - Making completions fast
- [Common Patterns](#common-patterns) - Copy-paste solutions
- [Debugging Completions](#debugging-completions) - When tab doesn't work

## What Completions Actually Are

Completions are **functions that generate suggestions** based on:
- What command you're typing
- What position in the command line you're at
- What you've typed so far

```bash
# Basic completion: just list files
cd <tab>
# Calls _cd function, which suggests directories only

# Context-aware completion: different per subcommand
git <tab>
# Calls _git function, which checks position
# Position 1 (after "git"): suggest subcommands
# Position 2+ (after "git commit"): suggest flags

# State-aware completion: knows your environment
git checkout <tab>
# Calls _git, which runs: git branch --list
# Dynamically generates suggestions from your repo
```

**Key insight:** Completions are code that runs when you press tab. They can do anything - read files, call commands, parse state.

## The Completion Architecture

ZSH's completion system has three layers:

### Layer 1: compinit (System Initialization)

```bash
# In your .zshrc
autoload -Uz compinit
compinit
```

This loads the completion system. Without this, you only get basic filename completion.

**What compinit does:**
1. Loads completion functions from `fpath` directories
2. Creates the `_main_complete` dispatcher
3. Sets up keybindings (tab → complete-word)
4. Initializes completion cache

**Where completions live:**
```bash
echo $fpath
# /usr/share/zsh/functions/Completion/...
# /usr/local/share/zsh/site-functions
# ~/.zsh/completions
```

### Layer 2: compdef (Register Completions)

```bash
# Register _git function for git command
compdef _git git

# Register same completion for multiple commands
compdef _cargo cargo cargo-clippy cargo-fmt

# Register pattern-based completion
compdef '_files -g "*.pdf"' evince okular
```

`compdef` maps commands to completion functions. When you type `git <tab>`, ZSH looks up which function to call.

**Check what's registered:**
```bash
# See completion for git
which _git

# List all registered completions
compdef -p
```

### Layer 3: _arguments (Parse and Complete)

The workhorse function that handles flags, options, and arguments.

```bash
_arguments \
  '-h[Show help]' \
  '-v[Verbose output]' \
  '*:filename:_files'
```

This declares:
- `-h` flag with description "Show help"
- `-v` flag with description "Verbose output"
- `*` any number of arguments, type "filename", completed by `_files` function

## How Git Completion Works

Let's trace what happens when you type `git commit -<tab>`:

```bash
# 1. You press tab
git commit -<tab>

# 2. ZSH calls _main_complete
# 3. _main_complete looks up: which function handles "git"?
#    Answer: _git (registered via compdef)

# 4. _git function executes
_git() {
  # Figure out which subcommand (commit, checkout, etc.)
  local subcommand=$words[2]
  
  # Call subcommand-specific handler
  case $subcommand in
    commit) _git-commit ;;
    checkout) _git-checkout ;;
    ...
  esac
}

# 5. _git-commit runs
_git-commit() {
  _arguments \
    '-m[Commit message]:message' \
    '--amend[Amend previous commit]' \
    '--no-verify[Skip pre-commit hooks]' \
    '*:file:__git_changed_files'
}

# 6. _arguments sees you typed '-' and offers matching flags:
#    -m, --amend, --no-verify, etc.
```

**Key points:**
- `_git` delegates to subcommand handlers (`_git-commit`, `_git-checkout`)
- Each subcommand has its own `_arguments` spec
- Dynamic completions call helper functions (`__git_changed_files`)

## Building Your First Completion

Let's build completion for a simple script: `deploy [staging|production] [service]`

### Step 1: Create the Completion Function

```bash
# ~/.zsh/completions/_deploy
#compdef deploy

_deploy() {
  local -a environments services
  
  environments=(
    'staging:Deploy to staging environment'
    'production:Deploy to production (requires approval)'
  )
  
  services=(
    'api:Backend API service'
    'web:Frontend web application'
    'worker:Background job worker'
  )
  
  _arguments \
    '1:environment:->environment' \
    '2:service:->service' \
    && return 0
  
  case $state in
    environment)
      _describe 'environment' environments
      ;;
    service)
      _describe 'service' services
      ;;
  esac
}

_deploy "$@"
```

**Explanation:**
- `#compdef deploy` - Registers this function for the `deploy` command
- `'1:environment:->environment'` - First arg, named "environment", set state
- `_describe` - Display options with descriptions
- Format: `'value:description'`

### Step 2: Add to fpath and Load

```bash
# In .zshrc
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit
compinit
```

### Step 3: Test

```bash
deploy <tab>
# Shows: staging, production (with descriptions)

deploy staging <tab>
# Shows: api, web, worker (with descriptions)
```

## Context-Aware Completions

Different suggestions based on what you've already typed:

```bash
# Example: docker run completion
_docker-run() {
  _arguments \
    '(-d --detach)'{-d,--detach}'[Run in background]' \
    '(-it)'{-i,--interactive,-t,--tty}'[Interactive TTY]' \
    '--name[Container name]:name' \
    '1:image:__docker_images' \
    '*:command:_command_names'
}

# Key patterns:
# '(-d --detach)'{-d,--detach} - Mutually exclusive flags
# ':name' - Requires user input, no completion
# ':name:__docker_images' - Complete with custom function
# '*:command' - Multiple arguments allowed
```

### Position-Based Completion

```bash
_mycommand() {
  case $CURRENT in
    2) # First argument
      _describe 'action' '(start stop restart status)'
      ;;
    3) # Second argument (only if first was 'start')
      if [[ $words[2] == 'start' ]]; then
        _files -g '*.conf'
      fi
      ;;
  esac
}
```

**Variables available:**
- `$CURRENT` - Current word position (1-indexed)
- `$words` - Array of all words on command line
- `$words[2]` - Second word (first arg after command)

### Dynamic Completions

```bash
# Complete with live data
__project_names() {
  local -a projects
  projects=( ${(f)"$(ls ~/projects)"} )
  _describe 'project' projects
}

# Complete with command output
__git_branches() {
  local -a branches
  branches=( ${(f)"$(git branch --format='%(refname:short)')"} )
  _describe 'branch' branches
}
```

**Pattern:** `${(f)"$(command)"}` - Split command output by lines into array

## Performance and Caching

Completions run on every tab press. Slow completions = frustrating shell.

### Problem: Expensive Operations

```bash
# BAD: Slow API call on every tab
__projects() {
  local projects=$(curl -s api.example.com/projects)
  # Takes 500ms every time you press tab
}
```

### Solution 1: Cache Results

```bash
# GOOD: Cache for 5 minutes
__projects() {
  local cache=~/.cache/zsh/projects
  local cache_timeout=300  # 5 minutes
  
  if [[ ! -f $cache ]] || \
     [[ $(($(date +%s) - $(stat -f %m $cache))) -gt $cache_timeout ]]; then
    curl -s api.example.com/projects > $cache
  fi
  
  local -a projects
  projects=( ${(f)"$(cat $cache)"} )
  _describe 'project' projects
}
```

### Solution 2: Lazy Evaluation

```bash
# Only fetch if user actually tabs
_arguments \
  '1:project:->project'

case $state in
  project)
    # Only runs if user tabs at this position
    __fetch_projects
    ;;
esac
```

### Solution 3: compinit Caching

```bash
# In .zshrc - cache completion dump
autoload -Uz compinit

# Only regenerate once per day
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C  # Skip security check, use cached
fi
```

**Impact:** Reduces shell startup time from 500ms to 50ms.

## Common Patterns

### Pattern 1: File Type Filtering

```bash
# Only PDF files
_arguments '*:pdf:_files -g "*.pdf"'

# Only directories
_arguments '1:directory:_directories'

# Images only
_arguments '*:image:_files -g "*.{jpg,png,gif}"'
```

### Pattern 2: Multiple Commands, Same Completion

```bash
# Use same completion for cargo variants
compdef _cargo cargo cargo-clippy cargo-fmt cargo-build
```

### Pattern 3: Subcommand Dispatch

```bash
_myapp() {
  local -a subcommands
  subcommands=(
    'init:Initialize new project'
    'build:Build project'
    'test:Run tests'
  )
  
  if (( CURRENT == 2 )); then
    _describe 'subcommand' subcommands
  else
    local subcommand=$words[2]
    case $subcommand in
      init) _myapp_init ;;
      build) _myapp_build ;;
      test) _myapp_test ;;
    esac
  fi
}
```

### Pattern 4: Flag + Value Completion

```bash
_arguments \
  '--env[Environment]:environment:(dev staging prod)' \
  '--port[Port number]:port' \
  '--config[Config file]:file:_files -g "*.yml"'
```

**Syntax:**
- `'--flag[Description]:label'` - Flag requires value, no completion
- `'--flag[Description]:label:(a b c)'` - Complete from list
- `'--flag[Description]:label:_function'` - Complete with function

## Debugging Completions

### Completion Not Working?

```bash
# 1. Check if completion function exists
which _git

# 2. Check if it's registered
compdef -p | grep git

# 3. Test completion manually
_git
# Should show: "usage: git [--version] ..."

# 4. Enable debug output
zstyle ':completion:*' verbose yes
# Now tab shows where completions come from
```

### See What's Being Completed

```bash
# Show completion context
^Xh  # Ctrl+X then h
# Shows: completing for git subcommand

# Show completion matches
^Xc  # Ctrl+X then c
# Shows: what would be completed
```

### Completion Function Not Found

```bash
# Check fpath
echo $fpath

# Reload completions
rm ~/.zcompdump
compinit

# Manually load function
autoload -Uz _git
```

## Real-World Example: Custom Script Completion

Let's build completion for a deployment script that:
- Reads available environments from a file
- Dynamically lists services from a config
- Only allows valid flag combinations

```bash
# ~/.zsh/completions/_deploy
#compdef deploy

_deploy() {
  local curcontext="$curcontext" state line
  typeset -A opt_args
  
  _arguments -C \
    '(-h --help)'{-h,--help}'[Show help]' \
    '(-n --dry-run)'{-n,--dry-run}'[Show what would be deployed]' \
    '--rollback[Rollback to previous version]' \
    '1:environment:->environment' \
    '2:service:->service' \
    && return 0
  
  case $state in
    environment)
      local -a envs
      # Read from config file
      if [[ -f ~/.deploy/environments ]]; then
        envs=( ${(f)"$(cat ~/.deploy/environments)"} )
      else
        envs=('staging' 'production')
      fi
      _describe 'environment' envs
      ;;
      
    service)
      local env=$words[2]
      local -a services
      
      # Different services per environment
      case $env in
        staging)
          services=('api' 'web' 'worker' 'all')
          ;;
        production)
          # Only show production services if approved
          if [[ -f ~/.deploy/.approved ]]; then
            services=('api' 'web')
          else
            _message 'production deployment requires approval'
            return 1
          fi
          ;;
      esac
      
      _describe 'service' services
      ;;
  esac
}

_deploy "$@"
```

**Features:**
- Reads environment list from file
- Different service completions per environment
- Blocks production unless approved
- Supports flags with descriptions
- Handles `--help` and `--dry-run`

## Advanced: _arguments Specification Format

```bash
_arguments \
  # Flags
  '-v[Verbose]' \
  '(-q --quiet)'{-q,--quiet}'[Quiet mode]' \
  
  # Flags with values
  '--port[Port]:port:(8000 8080 3000)' \
  '--config[Config]:file:_files -g "*.yml"' \
  
  # Optional arguments
  '::optional arg:_files' \
  
  # Multiple arguments
  '*:files:_files' \
  
  # Exclusive flags (can't use together)
  '(--json --yaml)--json[JSON output]' \
  '(--json --yaml)--yaml[YAML output]' \
  
  # Position-specific
  '1:command:(start stop restart)' \
  '2:target:_directories'
```

**Symbols:**
- `'1:'` - First position argument
- `'::' ` - Optional argument
- `'*:'` - Multiple arguments allowed
- `'(-a -b)'` - Mutually exclusive with -a and -b

## What's Next

**Use completions immediately:**
- Build completion for your deployment scripts
- Add completion for project-specific commands
- Cache expensive API calls for fast tab completion

The completion system is ZSH's killer feature. Now you know how to use it.
